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
