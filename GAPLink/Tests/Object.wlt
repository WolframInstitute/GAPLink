(* Tests for Kernel/Object.wl that need no GAP: unknown objects, object references and formatting. *)

PacletDirectoryLoad[DirectoryName[$TestFileName, 2]]
Needs["WolframInstitute`GAPLink`"]

importObjects = WolframInstitute`GAPLink`PackageScope`gapLinkImportObjects;
objectReference = WolframInstitute`GAPLink`PackageScope`gapLinkProtocolObjectReference;

VerificationTest[
	{
		MatchQ[Normal[GAPObject["missing"]], Failure["GAPInvalidObject", _]],
		MatchQ[DeleteObject[GAPObject["missing"]], Failure["GAPInvalidObject", _]],
		MatchQ[Normal[GAPObject[1]], Failure["GAPInvalidObject", _]]
	},
	{True, True, True},
	TestID -> "Reject-Unknown-Object"
]

(* The same reference gives the same GAPObject, at every level of the value. *)
VerificationTest[
	MatchQ[
		importObjects[GAPSession["object-test"], {objectReference[1], <|"value" -> objectReference[1]|>}],
		{object_GAPObject, <|"value" -> object_GAPObject|>}
	],
	True,
	TestID -> "Import-Nested-Objects"
]

VerificationTest[
	FreeQ[
		ToBoxes[GAPObject["missing"], StandardForm],
		_ToBoxes,
		Infinity
	],
	True,
	TestID -> "Format-Object"
]
