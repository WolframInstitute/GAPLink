Needs["WolframInstitute`GAPLink`"];

sessionData = Symbol[
    "WolframInstitute`GAPLink`PackageScope`gapLinkSessionData"
];
gapExecutable = Replace[
    Quiet @ Environment["GAPLINK_GAP"],
    {path_String /; path =!= "" :> path, _ -> Automatic}
];
expectedVersion = Replace[
    Quiet @ Environment["GAPLINK_EXPECTED_GAP_VERSION"],
    {version_String /; version =!= "" :> version, _ -> Automatic}
];

VerificationTest[
    Module[{closed, details, process, session, state, valid},
        session = StartGAPSession["Executable" -> gapExecutable];
        If[FailureQ[session], Print["ERROR: ", session]; Return[False]];
        WithCleanup[
            state = sessionData[session];
            details = state["Info"];
            process = state["Process"];
            Print[
                "  GAP ", session["Version"],
                If[TrueQ[details["Tested"]], "", " (untested)"], " | ",
                details["System"], " ", details["Processor"]
            ];
            valid = session["Status"] === "Ready" &&
                state["NextRequestID"] === 2 &&
                details["ProtocolVersion"] === 1 &&
                MemberQ[{True, False}, details["Tested"]] &&
                MatchQ[session["Packages"], {___String}] &&
                (expectedVersion === Automatic ||
                    session["Version"] === expectedVersion);
            DeleteObject[session];
            closed = session["Status"] === "Closed" &&
                ProcessStatus[process] =!= "Running" &&
                ProcessInformation[process, "ExitCode"] === 0;
            valid && closed,
            DeleteObject[session]
        ]
    ],
    True,
    TestID -> "Start-And-Close-GAP-Session"
]

VerificationTest[
    Module[{afterError, captured, error, missing, result, session, values},
        session = StartGAPSession["Executable" -> gapExecutable];
        If[FailureQ[session], Print["ERROR: ", session]; Return[False]];
        WithCleanup[
            values = {
                12345678901234567890, -2/3, True, False,
                Missing["GAPFail"], 1.5, "GAP \[Lambda]", ByteArray[{0, 255}],
                Cycles[{}], Cycles[{{1, 2, 3}}], {}, {1, 2}, <||>,
                <|"a" -> Missing["GAPFail"], "b" -> 2|>
            };
            result = GAPCall[session, "IdFunc", values];
            captured = GAPCall[
                session, "Print", "hello", "Output" -> "Capture"
            ];
            missing = GAPCall[
                session, "GAPLinkMissingFunction", "Output" -> "Discard"
            ];
            error = GAPCall[
                session, "QuoInt", 1, 0, "Output" -> "Capture"
            ];
            afterError = GAPCall[session, "Sum", {1, 2, 3}];
            result === values &&
                captured === <|
                    "Result" -> Null,
                    "StandardOutput" -> "hello",
                    "StandardError" -> ""
                |> &&
                MatchQ[missing, Failure["GAPFunctionNotFound", _]] &&
                MatchQ[error, Failure["GAPError", _]] &&
                StringContainsQ[error["StandardError"], "Error"] &&
                afterError === 6 && session["Status"] === "Ready",
            DeleteObject[session]
        ]
    ],
    True,
    TestID -> "Call-GAP-Functions"
]
