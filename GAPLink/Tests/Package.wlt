(* Tests for Kernel/Package.wl that need no GAP: the options and what the functions give before they reach a session. *)

PacletDirectoryLoad[DirectoryName[$TestFileName, 2]]
Needs["WolframInstitute`GAPLink`"]

VerificationTest[
	{Options[GAPPackageAvailableQ], Options[LoadGAPPackage]},
	{
		{TimeConstraint -> Infinity, "Version" -> Automatic},
		{TimeConstraint -> Infinity, "Version" -> Automatic}
	},
	TestID -> "Package-Defaults"
]

VerificationTest[
	MatchQ[
		{
			GAPPackageAvailableQ[GAPSession["missing"], "example", TimeConstraint -> 0],
			GAPPackageAvailableQ[GAPSession["missing"], "example", "Version" -> ""],
			LoadGAPPackage[GAPSession["missing"], "example", "Version" -> 1],
			LoadGAPPackage[GAPSession["missing"], "example", "Other" -> 1]
		},
		{Failure["GAPInvalidOption", _] ..}
	],
	True,
	TestID -> "Reject-Package-Options"
]

(* A name that is blank or no string and a first argument that is not a session give their own Failure, without a
   message. Projects that use GAPLink rely on that. *)
VerificationTest[
	{
		MatchQ[GAPPackageAvailableQ[GAPSession["missing"], ""], Failure["GAPUnsupportedValue", _]],
		MatchQ[LoadGAPPackage[GAPSession["missing"], 1], Failure["GAPUnsupportedValue", _]],
		MatchQ[GAPPackageAvailableQ[GAPSession["missing"], "example"], Failure["GAPInvalidSession", _]],
		MatchQ[LoadGAPPackage["missing", "example"], Failure["GAPInvalidSession", _]],
		MatchQ[GAPPackageAvailableQ[None, "example"], Failure["GAPInvalidSession", _]]
	},
	{True, True, True, True, True},
	TestID -> "Reject-Package-Target"
]

(* A call without arguments matches no form. The predicate gives False; LoadGAPPackage gives the Failure of the
   catch-all and the message LoadGAPPackage::args. *)
VerificationTest[
	GAPPackageAvailableQ[],
	False,
	TestID -> "Package-Predicate-Is-False-Without-Arguments"
]

VerificationTest[
	Module[{failure},
		failure = LoadGAPPackage[];
		{First[failure], failure["MessageParameters"]}
	],
	{"InvalidArguments", {LoadGAPPackage}},
	{LoadGAPPackage::args},
	TestID -> "Reject-Package-Without-Arguments"
]
