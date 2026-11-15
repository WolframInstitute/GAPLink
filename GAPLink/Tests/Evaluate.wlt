(* Tests for Kernel/Evaluate.wl that need no GAP: the options and what an evaluation gives before it reaches a session. *)

PacletDirectoryLoad[DirectoryName[$TestFileName, 2]]
Needs["WolframInstitute`GAPLink`"]

VerificationTest[
	Options[GAPEvaluate],
	{
		TimeConstraint -> Infinity,
		"Output" -> "Print",
		"ReturnType" -> "Automatic"
	},
	TestID -> "Evaluate-Defaults"
]

VerificationTest[
	MatchQ[
		{
			GAPEvaluate[GAPSession["missing"], "1;", TimeConstraint -> 0],
			GAPEvaluate[GAPSession["missing"], "1;", "Output" -> "Other"],
			GAPEvaluate[GAPSession["missing"], "1;", "ReturnType" -> "Other"],
			GAPEvaluate[GAPSession["missing"], "1;", "Other" -> 1]
		},
		{Failure["GAPInvalidOption", _] ..}
	],
	True,
	TestID -> "Reject-Evaluate-Options"
]

(* Code that is no string and a first argument that is not a session give their own Failure, without a message.
   Projects that use GAPLink rely on that. *)
VerificationTest[
	{
		MatchQ[GAPEvaluate[GAPSession["missing"], 1], Failure["GAPUnsupportedValue", _]],
		MatchQ[GAPEvaluate["missing", "1;"], Failure["GAPInvalidSession", _]],
		MatchQ[GAPEvaluate[None, "1;", "ReturnType" -> "Object"], Failure["GAPInvalidSession", _]],
		MatchQ[GAPEvaluate[Failure["GAPStartFailed", <||>], "1;"], Failure["GAPInvalidSession", _]],
		MatchQ[GAPEvaluate[GAPSession["missing"], ""], Failure["GAPInvalidSession", _]]
	},
	{True, True, True, True, True},
	TestID -> "Reject-Evaluate-Target"
]

(* A call without arguments matches no form: it gives the Failure of the catch-all and the message GAPEvaluate::args. *)
VerificationTest[
	Module[{failure},
		failure = GAPEvaluate[];
		{First[failure], failure["MessageParameters"]}
	],
	{"InvalidArguments", {GAPEvaluate}},
	{GAPEvaluate::args},
	TestID -> "Reject-Evaluate-Without-Arguments"
]
