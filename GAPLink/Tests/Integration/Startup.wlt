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

VerificationTest[
    Module[
        {
            cross, cyclic, deleted, forced, group, mutable, nested, record,
            second, session, stale, staleResult, unsupported, valid
        },
        session = StartGAPSession["Executable" -> gapExecutable];
        second = StartGAPSession["Executable" -> gapExecutable];
        If[FailureQ[session] || FailureQ[second],
            DeleteObject /@ Select[{session, second}, Head[#] === GAPSession &];
            Return[False]
        ];
        WithCleanup[
            group = GAPCall[session, "SymmetricGroup", 4];
            forced = GAPCall[
                session, "IdFunc", 42, "ReturnType" -> "Object"
            ];
            nested = GAPCall[session, "IdFunc", {group, 7}];
            record = GAPCall[
                session, "IdFunc", <|"group" -> group, "n" -> 9|>
            ];
            mutable = GAPCall[
                session, "IdFunc", {1, 2}, "ReturnType" -> "Object"
            ];
            cyclic = GAPCall[
                session, "IdFunc", {}, "ReturnType" -> "Object"
            ];
            cross = GAPCall[second, "Size", group];
            unsupported = Normal[group];
            valid = Head[group] === GAPObject &&
                GAPCall[session, "Size", group] === 24 &&
                Normal[forced] === 42 &&
                MatchQ[nested, {_GAPObject, 7}] &&
                GAPCall[session, "Size", nested[[1]]] === 24 &&
                MatchQ[record, <|"group" -> _GAPObject, "n" -> 9|>] &&
                GAPCall[session, "Size", record["group"]] === 24 &&
                GAPCall[session, "Add", mutable, 3] === Null &&
                Normal[mutable] === {1, 2, 3} &&
                GAPCall[session, "Add", cyclic, cyclic] === Null &&
                MatchQ[Normal[cyclic], Failure["GAPUnsupportedValue", _]] &&
                MatchQ[cross, Failure["GAPInvalidObject", _]] &&
                MatchQ[unsupported, Failure["GAPUnsupportedValue", _]] &&
                session["Status"] === "Ready" &&
                second["Status"] === "Ready";
            DeleteObject[group];
            deleted = GAPCall[session, "Size", group];
            DeleteObject /@ {forced, mutable, cyclic};
            stale = GAPCall[session, "SymmetricGroup", 3];
            DeleteObject[session];
            staleResult = Normal[stale];
            valid &&
                MatchQ[deleted, Failure["GAPInvalidObject", _]] &&
                DeleteObject[group] === Null &&
                MatchQ[staleResult, Failure["GAPInvalidObject", _]] &&
                DeleteObject[stale] === Null &&
                session["Status"] === "Closed",
            DeleteObject /@ {session, second}
        ]
    ],
    True,
    TestID -> "Use-GAP-Objects"
]

VerificationTest[
    Module[
        {
            afterError, captured, empty, error, forced, group, multiple,
            session, syntax, value
        },
        session = StartGAPSession["Executable" -> gapExecutable];
        If[FailureQ[session], Print["ERROR: ", session]; Return[False]];
        WithCleanup[
            value = GAPEvaluate[
                session,
                "GAPLinkIntegrationValue := 4;;\n" <>
                    "GAPLinkIntegrationValue ^ 2;"
            ];
            multiple = GAPEvaluate[session, "1 + 1;\n3 + 4;"];
            empty = GAPEvaluate[session, "# no value\n"];
            captured = GAPEvaluate[
                session, "Print(\"hello\");", "Output" -> "Capture"
            ];
            group = GAPEvaluate[session, "SymmetricGroup(4);"];
            forced = GAPEvaluate[
                session, "42;", "ReturnType" -> "Object"
            ];
            error = GAPEvaluate[
                session, "1 / 0;", "Output" -> "Capture"
            ];
            syntax = GAPEvaluate[
                session, "1 + ;", "Output" -> "Capture"
            ];
            afterError = GAPEvaluate[session, "6 * 7;"];
            GAPEvaluate[
                session, "Unbind(GAPLinkIntegrationValue);",
                "Output" -> "Discard"
            ];
            value === 16 && multiple === 7 && empty === Null &&
                captured === <|
                    "Result" -> Null,
                    "StandardOutput" -> "hello",
                    "StandardError" -> ""
                |> &&
                Head[group] === GAPObject &&
                GAPCall[session, "Size", group] === 24 &&
                Head[forced] === GAPObject && Normal[forced] === 42 &&
                MatchQ[error, Failure["GAPError", _]] &&
                StringContainsQ[error["StandardError"], "Error"] &&
                MatchQ[syntax, Failure["GAPError", _]] &&
                MatchQ[syntax["StandardError"], _String | _ByteArray] &&
                !MemberQ[{"", ByteArray[{}]}, syntax["StandardError"]] &&
                afterError === 42 && session["Status"] === "Ready",
            DeleteObject /@ Cases[{group, forced}, _GAPObject];
            DeleteObject[session]
        ]
    ],
    True,
    TestID -> "Evaluate-GAP-Code"
]

VerificationTest[
    Module[
        {available, exact, loaded, missing, missingLoad, second, session},
        session = StartGAPSession["Executable" -> gapExecutable];
        If[FailureQ[session], Print["ERROR: ", session]; Return[False]];
        WithCleanup[
            available = GAPPackageAvailableQ[session, "example"];
            missing = GAPPackageAvailableQ[
                session, "GAPLinkMissingPackage"
            ];
            missingLoad = LoadGAPPackage[
                session, "GAPLinkMissingPackage"
            ];
            loaded = LoadGAPPackage[session, "example"];
            exact = If[
                AssociationQ[loaded],
                GAPPackageAvailableQ[
                    session, "example",
                    "Version" -> "=" <> loaded["Version"]
                ],
                False
            ];
            second = LoadGAPPackage[session, "example"];
            available === True && missing === False &&
                MatchQ[missingLoad,
                    Failure["GAPPackageNotAvailable", _]] &&
                missingLoad["Package"] === "GAPLinkMissingPackage" &&
                MatchQ[loaded,
                    <|"Name" -> "example", "Version" -> _String|>] &&
                second === loaded && exact === True &&
                GAPCall[session, "IsPackageLoaded", "example"] === True &&
                session["Status"] === "Ready",
            DeleteObject[session]
        ]
    ],
    True,
    TestID -> "Use-GAP-Package"
]
