Needs["WolframInstitute`GAPLink`"];

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
            GAPPackageAvailableQ[
                GAPSession["missing"], "example", TimeConstraint -> 0
            ],
            GAPPackageAvailableQ[
                GAPSession["missing"], "example", "Version" -> ""
            ],
            LoadGAPPackage[
                GAPSession["missing"], "example", "Version" -> 1
            ],
            LoadGAPPackage[
                GAPSession["missing"], "example", "Other" -> 1
            ]
        },
        {Failure["GAPInvalidOption", _] ..}
    ],
    True,
    TestID -> "Reject-Package-Options"
]

VerificationTest[
    {
        MatchQ[GAPPackageAvailableQ[GAPSession["missing"], ""],
            Failure["GAPUnsupportedValue", _]],
        MatchQ[LoadGAPPackage[GAPSession["missing"], 1],
            Failure["GAPUnsupportedValue", _]],
        MatchQ[GAPPackageAvailableQ[GAPSession["missing"], "example"],
            Failure["GAPInvalidSession", _]],
        MatchQ[LoadGAPPackage["missing", "example"],
            Failure["GAPInvalidSession", _]]
    },
    {True, True, True, True},
    TestID -> "Reject-Package-Target"
]
