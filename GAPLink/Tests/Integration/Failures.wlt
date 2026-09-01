Needs["WolframInstitute`GAPLink`"];

gapExecutable = Replace[
    Quiet @ Environment["GAPLINK_GAP"],
    {path_String /; path =!= "" :> path, _ -> Automatic}
];

stoppedChecks[session_, object_, result_] := <|
    "Result" -> TrueQ[result],
    "Status" -> session["Status"] === "Stopped",
    "Object" -> MatchQ[Normal[object], Failure["GAPInvalidObject", _]],
    "Call" -> MatchQ[
        GAPCall[session, "IdFunc", 1], Failure["GAPInvalidSession", _]
    ]
|>;

stoppedExpected = <|
    "Result" -> True, "Status" -> True, "Object" -> True, "Call" -> True
|>;

stoppedTest[run_, resultQ_] := Module[{object, result, session},
    session = StartGAPSession["Executable" -> gapExecutable];
    If[FailureQ[session], Return[$Failed]];
    WithCleanup[
        object = GAPCall[
            session, "SymmetricGroup", 4, "ReturnType" -> "Object"
        ];
        result = run[session];
        stoppedChecks[session, object, resultQ[result]],
        DeleteObject /@ {object, session}
    ]
];

VerificationTest[
    stoppedTest[
        GAPEvaluate[
            #, "while true do od;",
            TimeConstraint -> 1/10, "Output" -> "Discard"
        ] &,
        MatchQ[
            #,
            Failure[
                "GAPTimeConstraintExceeded",
                KeyValuePattern["TimeConstraint" -> 1/10]
            ]
        ] &
    ],
    stoppedExpected,
    TestID -> "Stop-After-GAP-Timeout"
]

VerificationTest[
    stoppedTest[
        CheckAbort[
            TimeConstrained[
                GAPEvaluate[#, "while true do od;", "Output" -> "Discard"],
                1/10,
                Abort[]
            ],
            $Aborted
        ] &,
        # === $Aborted &
    ],
    stoppedExpected,
    TestID -> "Stop-After-Wolfram-Abort"
]

VerificationTest[
    stoppedTest[
        GAPEvaluate[#, "ForceQuitGap(7);", "Output" -> "Discard"] &,
        MatchQ[#, Failure["GAPProcessStopped", _]] &
    ],
    stoppedExpected,
    TestID -> "Detect-Stopped-GAP"
]
