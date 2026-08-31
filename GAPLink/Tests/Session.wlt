Needs["WolframInstitute`GAPLink`"];

createSession = Symbol[
    "WolframInstitute`GAPLink`PackageScope`gapLinkCreateSession"
];

fakeState = <|
    "Executable" -> "/test/gap",
    "Process" -> None,
    "Info" -> <|
        "GAPVersion" -> "4.15.1",
        "Packages" -> {"GAPDoc", "primgrp"}
    |>
|>;

VerificationTest[
    Options[StartGAPSession],
    {"Executable" -> Automatic, TimeConstraint -> 30},
    TestID -> "Session-Defaults"
]

VerificationTest[
    MatchQ[
        {
            StartGAPSession["Executable" -> ""],
            StartGAPSession[TimeConstraint -> 0],
            StartGAPSession[TimeConstraint -> -1]
        },
        {Failure["GAPInvalidOption", _] ..}
    ],
    True,
    TestID -> "Reject-Session-Options"
]

VerificationTest[
    Module[{session = createSession[fakeState]},
        {
            Head[session],
            session["Status"],
            session["Executable"],
            session["Version"],
            session["Packages"],
            session["Backend"],
            session["Properties"],
            session["Other"]
        }
    ],
    {
        GAPSession,
        "Stopped",
        "/test/gap",
        "4.15.1",
        {"GAPDoc", "primgrp"},
        "Process",
        {
            "Status", "Executable", "Version", "Packages",
            "LoadedPackages", "Backend", "Properties"
        },
        Missing["UnknownProperty", "Other"]
    },
    TestID -> "Read-Session-Properties"
]

VerificationTest[
    FailureQ[GAPSession["missing"]["Status"]],
    True,
    TestID -> "Reject-Unknown-Session"
]

VerificationTest[
    Module[{session = createSession[fakeState]},
        MatchQ[session["LoadedPackages"], Failure["GAPInvalidSession", _]]
    ],
    True,
    TestID -> "Reject-Loaded-Packages-Without-GAP"
]

VerificationTest[
    Module[{session = createSession[fakeState]},
        DeleteObject[session];
        {session["Status"], DeleteObject[session]}
    ],
    {"Closed", Null},
    TestID -> "Delete-Session-Twice"
]
