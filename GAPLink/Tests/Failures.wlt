(* Tests for Kernel/Internal/Failures.wl: the Failure of a call that matches no form, and the helpers that build
   GAPLink's own failures and pass them up. They need no GAP. *)

PacletDirectoryLoad[DirectoryName[$TestFileName, 2]]
Needs["WolframInstitute`GAPLink`"]

invalidArgumentsFailure = WolframInstitute`GAPLink`PackageScope`invalidArgumentsFailure;
innerFailure = WolframInstitute`GAPLink`PackageScope`innerFailure;
gapFailure = WolframInstitute`GAPLink`PackageScope`gapFailure;
notFailure = WolframInstitute`GAPLink`PackageScope`$notFailure;

(* A function of this test file that ends with the catch-all, as every public function does. *)
doubleCount[count_Integer?NonNegative] := 2 * count
doubleCount[___] := invalidArgumentsFailure[doubleCount]

VerificationTest[
	doubleCount[3],
	6,
	TestID -> "Catch-All-Leaves-Valid-Calls-Alone"
]

VerificationTest[
	Module[{failure},
		failure = doubleCount["three"];
		{FailureQ[failure], First[failure], failure["MessageParameters"]}
	],
	{True, "InvalidArguments", {doubleCount}},
	{doubleCount::args},
	TestID -> "Catch-All-Gives-Invalid-Arguments-Failure"
]

VerificationTest[
	StringContainsQ[doubleCount[]["Message"], "called with invalid parameters."],
	True,
	{doubleCount::args},
	TestID -> "Catch-All-Carries-The-Generic-Message"
]

VerificationTest[
	gapFailure["GAPError", "GAP reported an error.", <|"Function" -> "Size"|>],
	Failure["GAPError", <|"MessageTemplate" -> "GAP reported an error.", "MessageParameters" -> <||>, "Function" -> "Size"|>],
	TestID -> "Failure-Has-Message-Fields-Then-Data"
]

(* A helper's own Failure comes back from Enclose with its tag and its data, and the code after it does not run. *)
VerificationTest[
	Enclose[
		ConfirmMatch[gapFailure["GAPInvalidSession", "The GAP session is not valid."], notFailure];
		"reached",
		innerFailure
	],
	Failure["GAPInvalidSession", <|"MessageTemplate" -> "The GAP session is not valid.", "MessageParameters" -> <||>|>],
	TestID -> "Inner-Failure-Keeps-The-Tag"
]

(* GAP's fail is a value and not a failure, so it passes the confirmation. *)
VerificationTest[
	Enclose[ConfirmMatch[Missing["GAPFail"], notFailure], innerFailure],
	Missing["GAPFail"],
	TestID -> "GAP-Fail-Passes-The-Confirmation"
]

VerificationTest[
	First @ Enclose[ConfirmAssert[1 === 2, "The numbers differ."], innerFailure],
	"ConfirmationFailed",
	TestID -> "Inner-Failure-Keeps-A-Failed-Assertion"
]
