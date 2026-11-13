(* Integration tests of a session from start to close: calls, objects, evaluation and packages. They need GAP; set
   GAPLINK_GAP to choose one and GAPLINK_EXPECTED_GAP_VERSION to check its version. *)

PacletDirectoryLoad[DirectoryName[$TestFileName, 3]]
Needs["WolframInstitute`GAPLink`"]

sessionData = WolframInstitute`GAPLink`PackageScope`gapLinkSessionData;

gapExecutable = Replace[Environment["GAPLINK_GAP"], Except[_String] | "" -> Automatic];
expectedVersion = Replace[Environment["GAPLINK_EXPECTED_GAP_VERSION"], Except[_String] | "" -> Automatic];

(* The names of the checks that did not give True. A test expects none. *)
failedChecks[checks__Rule] := Cases[{checks}, (name_String -> result_) /; !TrueQ[result] :> name]

(* Starts GAP, gives body[session] and closes the session. When GAP does not start, the result names the Failure, so
   that the test fails and shows why. *)
withSession[body_Function] :=
	Module[{session},
		session = StartGAPSession["Executable" -> gapExecutable];
		If[FailureQ[session], {"Start GAP" -> session}, WithCleanup[body[session], DeleteObject[session]]]
	]

packageVersionsQ[packages_Association] := MatchQ[Normal[packages], {(_String -> _String) ...}]
packageVersionsQ[___] := False

VerificationTest[
	withSession[
		Function[session,
			Module[{state, details, process, loaded, failures},
				state = sessionData[session];
				details = state["Info"];
				process = state["Process"];
				loaded = session["LoadedPackages"];
				failures = failedChecks[
					"Session status" -> session["Status"] === "Ready",
					"Request ID" -> state["NextRequestID"] === 2,
					"Protocol version" -> details["ProtocolVersion"] === 1,
					"Tested version" -> MemberQ[{True, False}, details["Tested"]],
					"Package list" -> MatchQ[session["Packages"], {___String}],
					"Loaded packages" -> packageVersionsQ[loaded],
					"GAP version" -> expectedVersion === Automatic || session["Version"] === expectedVersion
				];
				DeleteObject[session];
				Join[
					failures,
					failedChecks[
						"Closed status" -> session["Status"] === "Closed",
						"Process stopped" -> ProcessStatus[process] =!= "Running",
						"Exit code" -> ProcessInformation[process, "ExitCode"] === 0
					]
				]
			]
		]
	],
	{},
	TestID -> "Start-And-Close-GAP-Session"
]

VerificationTest[
	withSession[
		Function[session,
			Module[{values, result, captured, missing, error, afterError},
				values = {
					12345678901234567890, -2 / 3, True, False,
					Missing["GAPFail"], 1.5, "GAP \[Lambda]", ByteArray[{0, 255}],
					Cycles[{}], Cycles[{{1, 2, 3}}], {}, {1, 2}, <||>,
					<|"a" -> Missing["GAPFail"], "b" -> 2|>
				};
				result = GAPCall[session, "IdFunc", values];
				captured = GAPCall[session, "Print", "hello", "Output" -> "Capture"];
				missing = GAPCall[session, "GAPLinkMissingFunction", "Output" -> "Discard"];
				error = GAPCall[session, "QuoInt", 1, 0, "Output" -> "Capture"];
				afterError = GAPCall[session, "Sum", {1, 2, 3}];
				failedChecks[
					"Values" -> result === values,
					"Captured output" -> captured === <|"Result" -> Null, "StandardOutput" -> "hello", "StandardError" -> ""|>,
					"Missing function" -> MatchQ[missing, Failure["GAPFunctionNotFound", _]],
					"GAP error" -> MatchQ[error, Failure["GAPError", _]],
					"Error output" -> StringContainsQ[error["StandardError"], "Error"],
					"Call after error" -> afterError === 6,
					"Session status" -> session["Status"] === "Ready"
				]
			]
		]
	],
	{},
	TestID -> "Call-GAP-Functions"
]

(* A call that matches no form does not reach GAP, and the session stays ready. *)
VerificationTest[
	withSession[
		Function[session,
			{First[GAPCall[session]], First[GAPCall[session, 1]], First[GAPEvaluate[None, "1;"]], session["Status"]}
		]
	],
	{"InvalidArguments", "GAPFunctionNotFound", "GAPInvalidSession", "Ready"},
	{GAPCall::args},
	TestID -> "Reject-Call-That-Matches-No-Form"
]

VerificationTest[
	withSession[
		Function[session,
			withSession[
				Function[second,
					Module[{group, forced, nested, record, mutable, cyclic, cross, unsupported, failures, deleted, stale, staleResult},
						group = GAPCall[session, "SymmetricGroup", 4];
						forced = GAPCall[session, "IdFunc", 42, "ReturnType" -> "Object"];
						nested = GAPCall[session, "IdFunc", {group, 7}];
						record = GAPCall[session, "IdFunc", <|"group" -> group, "n" -> 9|>];
						mutable = GAPCall[session, "IdFunc", {1, 2}, "ReturnType" -> "Object"];
						cyclic = GAPCall[session, "IdFunc", {}, "ReturnType" -> "Object"];
						cross = GAPCall[second, "Size", group];
						unsupported = Normal[group];
						failures = failedChecks[
							"GAP object" -> MatchQ[group, _GAPObject],
							"Object call" -> GAPCall[session, "Size", group] === 24,
							"Forced object" -> Normal[forced] === 42,
							"Nested object" -> MatchQ[nested, {_GAPObject, 7}] && GAPCall[session, "Size", First[nested]] === 24,
							"Record object" -> MatchQ[record, <|"group" -> _GAPObject, "n" -> 9|>] && GAPCall[session, "Size", record["group"]] === 24,
							"Mutable object" -> GAPCall[session, "Add", mutable, 3] === Null && Normal[mutable] === {1, 2, 3},
							"Cyclic object" -> GAPCall[session, "Add", cyclic, cyclic] === Null && MatchQ[Normal[cyclic], Failure["GAPUnsupportedValue", _]],
							"Cross-session object" -> MatchQ[cross, Failure["GAPInvalidObject", _]],
							"Unsupported object" -> MatchQ[unsupported, Failure["GAPUnsupportedValue", _]],
							"First session status" -> session["Status"] === "Ready",
							"Second session status" -> second["Status"] === "Ready"
						];
						DeleteObject[group];
						deleted = GAPCall[session, "Size", group];
						DeleteObject /@ {forced, mutable, cyclic};
						stale = GAPCall[session, "SymmetricGroup", 3];
						DeleteObject[session];
						staleResult = Normal[stale];
						Join[
							failures,
							failedChecks[
								"Deleted object" -> MatchQ[deleted, Failure["GAPInvalidObject", _]],
								"Repeated delete" -> DeleteObject[group] === Null,
								"Stale object" -> MatchQ[staleResult, Failure["GAPInvalidObject", _]],
								"Delete stale object" -> DeleteObject[stale] === Null,
								"Closed session" -> session["Status"] === "Closed"
							]
						]
					]
				]
			]
		]
	],
	{},
	TestID -> "Use-GAP-Objects"
]

VerificationTest[
	withSession[
		Function[session,
			Module[{value, multiple, empty, captured, group, forced, error, syntax, afterError, failures},
				value = GAPEvaluate[session, "GAPLinkIntegrationValue := 4;;\nGAPLinkIntegrationValue ^ 2;"];
				multiple = GAPEvaluate[session, "1 + 1;\n3 + 4;"];
				empty = GAPEvaluate[session, "# no value\n"];
				captured = GAPEvaluate[session, "Print(\"hello\");", "Output" -> "Capture"];
				group = GAPEvaluate[session, "SymmetricGroup(4);"];
				forced = GAPEvaluate[session, "42;", "ReturnType" -> "Object"];
				error = GAPEvaluate[session, "1 / 0;", "Output" -> "Capture"];
				syntax = GAPEvaluate[session, "1 + ;", "Output" -> "Capture"];
				afterError = GAPEvaluate[session, "6 * 7;"];
				GAPEvaluate[session, "Unbind(GAPLinkIntegrationValue);", "Output" -> "Discard"];
				failures = failedChecks[
					"Value" -> value === 16,
					"Multiple statements" -> multiple === 7,
					"No value" -> empty === Null,
					"Captured output" -> captured === <|"Result" -> Null, "StandardOutput" -> "hello", "StandardError" -> ""|>,
					"GAP object" -> MatchQ[group, _GAPObject] && GAPCall[session, "Size", group] === 24,
					"Forced object" -> MatchQ[forced, _GAPObject] && Normal[forced] === 42,
					"GAP error" -> MatchQ[error, Failure["GAPError", _]] && StringContainsQ[error["StandardError"], "Error"],
					"Syntax error" -> MatchQ[syntax, Failure["GAPError", _]] && MatchQ[syntax["StandardError"], Except["" | ByteArray[{}], _String | _ByteArray]],
					"Evaluate after error" -> afterError === 42,
					"Session status" -> session["Status"] === "Ready"
				];
				DeleteObject /@ Cases[{group, forced}, _GAPObject];
				failures
			]
		]
	],
	{},
	TestID -> "Evaluate-GAP-Code"
]

VerificationTest[
	withSession[
		Function[session,
			Module[{available, missing, missingLoad, loaded, loadedPackages, exact, second},
				available = GAPPackageAvailableQ[session, "gapdoc"];
				missing = GAPPackageAvailableQ[session, "GAPLinkMissingPackage"];
				missingLoad = LoadGAPPackage[session, "GAPLinkMissingPackage"];
				loaded = LoadGAPPackage[session, "gapdoc"];
				loadedPackages = KeyMap[ToLowerCase, session["LoadedPackages"]];
				exact = If[AssociationQ[loaded], GAPPackageAvailableQ[session, "gapdoc", "Version" -> "=" <> loaded["Version"]], False];
				second = LoadGAPPackage[session, "gapdoc"];
				failedChecks[
					"Available package" -> available === True,
					"Missing package" -> missing === False,
					"Missing package failure" -> MatchQ[missingLoad, Failure["GAPPackageNotAvailable", KeyValuePattern["Package" -> "GAPLinkMissingPackage"]]],
					"Load package" -> MatchQ[loaded, <|"Name" -> "gapdoc", "Version" -> _String|>],
					"Loaded package report" -> loadedPackages["gapdoc"] === loaded["Version"],
					"Repeated load" -> second === loaded,
					"Exact version" -> exact === True,
					"GAP package state" -> GAPCall[session, "IsPackageLoaded", "gapdoc"] === True,
					"Blank package name" -> MatchQ[GAPPackageAvailableQ[session, " "], Failure["GAPUnsupportedValue", _]],
					"Session status" -> session["Status"] === "Ready"
				]
			]
		]
	],
	{},
	TestID -> "Use-GAP-Package"
]
