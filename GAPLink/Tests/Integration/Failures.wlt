(* Integration tests of the cases that stop a session: a time limit, an abort and a GAP that quits. They need GAP;
   set GAPLINK_GAP to choose one. *)

PacletDirectoryLoad[DirectoryName[$TestFileName, 3]]
Needs["WolframInstitute`GAPLink`"]

gapExecutable = Replace[Environment["GAPLINK_GAP"], Except[_String] | "" -> Automatic];

(* What must hold after a session stopped: the request gave the expected result, the session is stopped, its objects
   are no longer valid and it takes no more calls. *)
stoppedChecks[session_GAPSession, object_GAPObject, expectedResultQ : (True | False)] :=
	<|
		"Result" -> expectedResultQ,
		"Status" -> session["Status"] === "Stopped",
		"Object" -> MatchQ[Normal[object], Failure["GAPInvalidObject", _]],
		"Call" -> MatchQ[GAPCall[session, "IdFunc", 1], Failure["GAPInvalidSession", _]]
	|>

stoppedExpected = <|"Result" -> True, "Status" -> True, "Object" -> True, "Call" -> True|>;

(* Starts GAP, keeps an object, applies run to the session and checks what is left. resultQ says whether the result
   of run is the expected one. A GAP that does not start gives its Failure, so that the test fails and shows why. *)
stoppedTest[run_Function, resultQ_Function] :=
	Module[{session, object, result},
		session = StartGAPSession["Executable" -> gapExecutable];
		If[FailureQ[session],
			session,

			WithCleanup[
				object = GAPCall[session, "SymmetricGroup", 4, "ReturnType" -> "Object"];
				result = run[session];
				stoppedChecks[session, object, TrueQ[resultQ[result]]],
				DeleteObject /@ {object, session}
			]
		]
	]

VerificationTest[
	stoppedTest[
		GAPEvaluate[#, "while true do od;", TimeConstraint -> 1 / 10, "Output" -> "Discard"] &,
		MatchQ[#, Failure["GAPTimeConstraintExceeded", KeyValuePattern["TimeConstraint" -> 1 / 10]]] &
	],
	stoppedExpected,
	TestID -> "Stop-After-GAP-Timeout"
]

VerificationTest[
	stoppedTest[
		GAPEvaluate[
			#, "while true do WriteAll(OutputTextUser(), ListWithIdenticalEntries(8192, 'x')); od;",
			TimeConstraint -> 1 / 10, "Output" -> "Discard"
		] &,
		MatchQ[#, Failure["GAPTimeConstraintExceeded", _]] &
	],
	stoppedExpected,
	TestID -> "Stop-After-Timeout-With-Continuous-Output"
]

VerificationTest[
	stoppedTest[
		CheckAbort[
			TimeConstrained[GAPEvaluate[#, "while true do od;", "Output" -> "Discard"], 1 / 10, Abort[]],
			$Aborted
		] &,
		# === $Aborted &
	],
	stoppedExpected,
	TestID -> "Stop-After-Wolfram-Abort"
]

VerificationTest[
	stoppedTest[
		GAPEvaluate[#, "ForceQuitGap(7);", "Output" -> "Discard"] &,
		MatchQ[#, Failure["GAPProcessStopped", _]] &
	],
	stoppedExpected,
	TestID -> "Detect-Stopped-GAP"
]
