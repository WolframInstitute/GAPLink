Needs["WolframInstitute`GAPLink`"];

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
            GAPEvaluate[
                GAPSession["missing"], "1;", "ReturnType" -> "Other"
            ],
            GAPEvaluate[GAPSession["missing"], "1;", "Other" -> 1]
        },
        {Failure["GAPInvalidOption", _] ..}
    ],
    True,
    TestID -> "Reject-Evaluate-Options"
]

VerificationTest[
    {
        MatchQ[GAPEvaluate[GAPSession["missing"], 1],
            Failure["GAPUnsupportedValue", _]],
        MatchQ[GAPEvaluate["missing", "1;"],
            Failure["GAPInvalidSession", _]],
        MatchQ[GAPEvaluate[GAPSession["missing"], ""],
            Failure["GAPInvalidSession", _]]
    },
    {True, True, True},
    TestID -> "Reject-Evaluate-Target"
]
