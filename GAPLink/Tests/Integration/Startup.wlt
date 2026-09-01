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

failedChecks[checks__Rule] := Cases[
    {checks},
    (name_String -> result_) /; !TrueQ[result] :> name
]

VerificationTest[
    Module[{details, failures, loaded, process, session, state},
        session = StartGAPSession["Executable" -> gapExecutable];
        If[FailureQ[session], Print["ERROR: ", session]; Return[{"Start GAP"}]];
        WithCleanup[
            state = sessionData[session];
            details = state["Info"];
            process = state["Process"];
            loaded = session["LoadedPackages"];
            Print[
                "  GAP ", session["Version"],
                If[TrueQ[details["Tested"]], "", " (untested)"], " | ",
                details["System"], " ", details["Processor"]
            ];
            failures = failedChecks[
                "Session status" -> session["Status"] === "Ready",
                "Request ID" -> state["NextRequestID"] === 2,
                "Protocol version" -> details["ProtocolVersion"] === 1,
                "Tested version" -> MemberQ[{True, False}, details["Tested"]],
                "Package list" -> MatchQ[session["Packages"], {___String}],
                "Loaded packages" -> AssociationQ[loaded] &&
                    MatchQ[Normal[loaded], {(_String -> _String) ...}],
                "GAP version" -> expectedVersion === Automatic ||
                    session["Version"] === expectedVersion
            ];
            DeleteObject[session];
            Join[
                failures,
                failedChecks[
                    "Closed status" -> session["Status"] === "Closed",
                    "Process stopped" -> ProcessStatus[process] =!= "Running",
                    "Exit code" -> ProcessInformation[process, "ExitCode"] === 0
                ]
            ],
            DeleteObject[session]
        ]
    ],
    {},
    TestID -> "Start-And-Close-GAP-Session"
]

VerificationTest[
    Module[{afterError, captured, error, missing, result, session, values},
        session = StartGAPSession["Executable" -> gapExecutable];
        If[FailureQ[session], Print["ERROR: ", session]; Return[{"Start GAP"}]];
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
            failedChecks[
                "Values" -> result === values,
                "Captured output" -> captured === <|
                    "Result" -> Null,
                    "StandardOutput" -> "hello",
                    "StandardError" -> ""
                |>,
                "Missing function" ->
                    MatchQ[missing, Failure["GAPFunctionNotFound", _]],
                "GAP error" -> MatchQ[error, Failure["GAPError", _]],
                "Error output" ->
                    StringContainsQ[error["StandardError"], "Error"],
                "Call after error" -> afterError === 6,
                "Session status" -> session["Status"] === "Ready"
            ],
            DeleteObject[session]
        ]
    ],
    {},
    TestID -> "Call-GAP-Functions"
]

VerificationTest[
    Module[
        {
            cross, cyclic, deleted, failures, forced, group, mutable, nested,
            record, second, session, stale, staleResult, unsupported
        },
        session = StartGAPSession["Executable" -> gapExecutable];
        second = StartGAPSession["Executable" -> gapExecutable];
        If[FailureQ[session] || FailureQ[second],
            DeleteObject /@ Select[{session, second}, Head[#] === GAPSession &];
            Return[{"Start GAP"}]
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
            failures = failedChecks[
                "GAP object" -> Head[group] === GAPObject,
                "Object call" -> GAPCall[session, "Size", group] === 24,
                "Forced object" -> Normal[forced] === 42,
                "Nested object" -> MatchQ[nested, {_GAPObject, 7}] &&
                    GAPCall[session, "Size", nested[[1]]] === 24,
                "Record object" ->
                    MatchQ[record, <|"group" -> _GAPObject, "n" -> 9|>] &&
                    GAPCall[session, "Size", record["group"]] === 24,
                "Mutable object" ->
                    GAPCall[session, "Add", mutable, 3] === Null &&
                    Normal[mutable] === {1, 2, 3},
                "Cyclic object" ->
                    GAPCall[session, "Add", cyclic, cyclic] === Null &&
                    MatchQ[
                        Normal[cyclic], Failure["GAPUnsupportedValue", _]
                    ],
                "Cross-session object" ->
                    MatchQ[cross, Failure["GAPInvalidObject", _]],
                "Unsupported object" ->
                    MatchQ[unsupported, Failure["GAPUnsupportedValue", _]],
                "First session status" -> session["Status"] === "Ready",
                "Second session status" -> second["Status"] === "Ready"
            ];
            DeleteObject[group];
            deleted = GAPCall[session, "Size", group];
            DeleteObject /@ {forced, mutable, cyclic};
            stale = GAPCall[session, "SymmetricGroup", 3];
            DeleteObject[session];
            staleResult = Normal[stale];
            Join[
                failures,
                failedChecks[
                    "Deleted object" ->
                        MatchQ[deleted, Failure["GAPInvalidObject", _]],
                    "Repeated delete" -> DeleteObject[group] === Null,
                    "Stale object" ->
                        MatchQ[staleResult, Failure["GAPInvalidObject", _]],
                    "Delete stale object" -> DeleteObject[stale] === Null,
                    "Closed session" -> session["Status"] === "Closed"
                ]
            ],
            DeleteObject /@ {session, second}
        ]
    ],
    {},
    TestID -> "Use-GAP-Objects"
]

VerificationTest[
    Module[
        {
            afterError, captured, empty, error, forced, group, multiple,
            session, syntax, value
        },
        session = StartGAPSession["Executable" -> gapExecutable];
        If[FailureQ[session], Print["ERROR: ", session]; Return[{"Start GAP"}]];
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
            failedChecks[
                "Value" -> value === 16,
                "Multiple statements" -> multiple === 7,
                "No value" -> empty === Null,
                "Captured output" -> captured === <|
                    "Result" -> Null,
                    "StandardOutput" -> "hello",
                    "StandardError" -> ""
                |>,
                "GAP object" -> Head[group] === GAPObject &&
                    GAPCall[session, "Size", group] === 24,
                "Forced object" -> Head[forced] === GAPObject &&
                    Normal[forced] === 42,
                "GAP error" -> MatchQ[error, Failure["GAPError", _]] &&
                    StringContainsQ[error["StandardError"], "Error"],
                "Syntax error" -> MatchQ[syntax, Failure["GAPError", _]] &&
                    MatchQ[syntax["StandardError"], _String | _ByteArray] &&
                    !MemberQ[{"", ByteArray[{}]}, syntax["StandardError"]],
                "Evaluate after error" -> afterError === 42,
                "Session status" -> session["Status"] === "Ready"
            ],
            DeleteObject /@ Cases[{group, forced}, _GAPObject];
            DeleteObject[session]
        ]
    ],
    {},
    TestID -> "Evaluate-GAP-Code"
]

VerificationTest[
    Module[
        {
            available, exact, loaded, loadedPackages, missing, missingLoad,
            second, session
        },
        session = StartGAPSession["Executable" -> gapExecutable];
        If[FailureQ[session], Print["ERROR: ", session]; Return[{"Start GAP"}]];
        WithCleanup[
            available = GAPPackageAvailableQ[session, "gapdoc"];
            missing = GAPPackageAvailableQ[
                session, "GAPLinkMissingPackage"
            ];
            missingLoad = LoadGAPPackage[
                session, "GAPLinkMissingPackage"
            ];
            loaded = LoadGAPPackage[session, "gapdoc"];
            loadedPackages = KeyMap[ToLowerCase, session["LoadedPackages"]];
            exact = If[
                AssociationQ[loaded],
                GAPPackageAvailableQ[
                    session, "gapdoc",
                    "Version" -> "=" <> loaded["Version"]
                ],
                False
            ];
            second = LoadGAPPackage[session, "gapdoc"];
            failedChecks[
                "Available package" -> available === True,
                "Missing package" -> missing === False,
                "Missing package failure" -> MatchQ[
                    missingLoad, Failure["GAPPackageNotAvailable", _]
                ] && missingLoad["Package"] === "GAPLinkMissingPackage",
                "Load package" -> MatchQ[
                    loaded, <|"Name" -> "gapdoc", "Version" -> _String|>
                ],
                "Loaded package report" ->
                    loadedPackages["gapdoc"] === loaded["Version"],
                "Repeated load" -> second === loaded,
                "Exact version" -> exact === True,
                "GAP package state" ->
                    GAPCall[session, "IsPackageLoaded", "gapdoc"] === True,
                "Session status" -> session["Status"] === "Ready"
            ],
            DeleteObject[session]
        ]
    ],
    {},
    TestID -> "Use-GAP-Package"
]
