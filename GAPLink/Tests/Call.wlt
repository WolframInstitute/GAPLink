Needs["WolframInstitute`GAPLink`"];

VerificationTest[
    Options[GAPCall],
    {TimeConstraint -> Infinity, "Output" -> "Print"},
    TestID -> "Call-Defaults"
]

VerificationTest[
    MatchQ[
        {
            GAPCall[GAPSession["missing"], "Size", TimeConstraint -> 0],
            GAPCall[GAPSession["missing"], "Size", "Output" -> "Other"],
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
            GAPCall[GAPSession["missing"], "IdFunc", Hold[1]]
        },
        {Failure["GAPUnsupportedValue", _] ..}
    ],
    True,
    TestID -> "Reject-Call-Values"
]

VerificationTest[
    {
        MatchQ[GAPCall[GAPSession["missing"], 1],
            Failure["GAPFunctionNotFound", _]],
        MatchQ[GAPCall["missing", "Size"], Failure["GAPInvalidSession", _]]
    },
    {True, True},
    TestID -> "Reject-Call-Target"
]
