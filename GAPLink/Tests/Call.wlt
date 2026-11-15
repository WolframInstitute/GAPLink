(* Tests for Kernel/Call.wl that need no GAP: the options and what a call gives before it reaches a session. *)

PacletDirectoryLoad[DirectoryName[$TestFileName, 2]]
Needs["WolframInstitute`GAPLink`"]

VerificationTest[
	Options[GAPCall],
	{
		TimeConstraint -> Infinity,
		"Output" -> "Print",
		"ReturnType" -> "Automatic",
		"GAPOptions" -> <||>
	},
	TestID -> "Call-Defaults"
]

VerificationTest[
	MatchQ[
		{
			GAPCall[GAPSession["missing"], "Size", TimeConstraint -> 0],
			GAPCall[GAPSession["missing"], "Size", "Output" -> "Other"],
			GAPCall[GAPSession["missing"], "Size", "ReturnType" -> "Other"],
			GAPCall[GAPSession["missing"], "Size", "GAPOptions" -> {}],
			GAPCall[GAPSession["missing"], "Size", "GAPOptions" -> <|1 -> True|>],
			GAPCall[GAPSession["missing"], "Size", "Other" -> 1]
		},
		{Failure["GAPInvalidOption", _] ..}
	],
	True,
	TestID -> "Reject-Call-Options"
]

VerificationTest[
	MatchQ[
		{
			GAPCall[GAPSession["missing"], "IdFunc", Null],
			GAPCall[GAPSession["missing"], "IdFunc", Hold[1]],
			GAPCall[GAPSession["missing"], "IdFunc", Cycles[{{1, 1000000000}}]]
		},
		{Failure["GAPUnsupportedValue", _] ..}
	],
	True,
	TestID -> "Reject-Call-Values"
]

VerificationTest[
	MatchQ[
		GAPCall[GAPSession["missing"], "IdFunc", {}],
		Failure["GAPInvalidSession", _]
	],
	True,
	TestID -> "Keep-Empty-List-Argument"
]

(* A name that is no string and a first argument that is not a session give their own Failure, without a message.
   Projects that use GAPLink rely on that. *)
VerificationTest[
	{
		MatchQ[GAPCall[GAPSession["missing"], 1], Failure["GAPFunctionNotFound", _]],
		MatchQ[GAPCall["missing", "Size"], Failure["GAPInvalidSession", _]],
		MatchQ[GAPCall[None, "Size", 1, "ReturnType" -> "Object"], Failure["GAPInvalidSession", _]],
		MatchQ[GAPCall[Failure["GAPStartFailed", <||>], "Size", 1], Failure["GAPInvalidSession", _]]
	},
	{True, True, True, True},
	TestID -> "Reject-Call-Target"
]

(* A call with fewer than two arguments matches no form: it gives the Failure of the catch-all and the message
   GAPCall::args. *)
VerificationTest[
	Module[{failure},
		failure = GAPCall[];
		{First[failure], failure["MessageParameters"]}
	],
	{"InvalidArguments", {GAPCall}},
	{GAPCall::args},
	TestID -> "Reject-Call-Without-Arguments"
]

VerificationTest[
	First[GAPCall[GAPSession["missing"]]],
	"InvalidArguments",
	{GAPCall::args},
	TestID -> "Reject-Call-Without-Name"
]
