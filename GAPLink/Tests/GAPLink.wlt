VerificationTest[
    PacletObjectQ[PacletObject["WolframInstitute/GAPLink"]],
    True,
    TestID -> "Paclet-Found"
]

VerificationTest[
    Needs["WolframInstitute`GAPLink`"],
    Null,
    TestID -> "Paclet-Loads-Without-Messages"
]

VerificationTest[
    MemberQ[$Packages, "WolframInstitute`GAPLink`"],
    True,
    TestID -> "Paclet-Context-Loaded"
]

VerificationTest[
    StringMatchQ[
        PacletObject["WolframInstitute/GAPLink"]["Version"],
        DigitCharacter.. ~~ "." ~~ DigitCharacter.. ~~ "." ~~ DigitCharacter..
    ],
    True,
    TestID -> "Paclet-Version-Is-Semantic"
]

VerificationTest[
    Names["WolframInstitute`GAPLink`*"],
    {
        "GAPCall", "GAPEvaluate", "GAPObject", "GAPSession",
        "StartGAPSession"
    },
    TestID -> "Export-Public-API"
]
