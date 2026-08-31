Needs["WolframInstitute`GAPLink`"];

{importObjects, objectReference} = Symbol[
    "WolframInstitute`GAPLink`PackageScope`" <> #
] & /@ {"gapLinkImportObjects", "gapLinkProtocolObjectReference"};

VerificationTest[
    {
        MatchQ[Normal[GAPObject["missing"]], Failure["GAPInvalidObject", _]],
        MatchQ[DeleteObject[GAPObject["missing"]],
            Failure["GAPInvalidObject", _]],
        MatchQ[Normal[GAPObject[1]], Failure["GAPInvalidObject", _]]
    },
    {True, True, True},
    TestID -> "Reject-Unknown-Object"
]

VerificationTest[
    Module[{result},
        result = importObjects[
            GAPSession["object-test"],
            {objectReference[1], <|"value" -> objectReference[1]|>}
        ];
        MatchQ[result, {_GAPObject, <|"value" -> _GAPObject|>}] &&
            SameQ[result[[1]], result[[2]]["value"]]
    ],
    True,
    TestID -> "Import-Nested-Objects"
]
