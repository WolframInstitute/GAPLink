Needs["WolframInstitute`GAPLink`"];

startGAP = Symbol[
    "WolframInstitute`GAPLink`PackageScope`gapLinkStartGAP"
];
gapExecutable = Replace[
    Quiet @ Environment["GAPLINK_GAP"],
    {path_String /; path =!= "" :> path, _ -> Automatic}
];
expectedVersion = Replace[
    Quiet @ Environment["GAPLINK_EXPECTED_GAP_VERSION"],
    {version_String /; version =!= "" :> version, _ -> Automatic}
];

stopGAP[session_Association] := Module[{process = session["Process"]},
    Quiet @ Check[Close[ProcessConnection[process, "StandardInput"]], Null];
    TimeConstrained[
        While[ProcessStatus[process] === "Running", Pause[.01]],
        5,
        Quiet @ Check[KillProcess[process], Null]
    ]
]
stopGAP[_] := Null

VerificationTest[
    Module[{session = startGAP[gapExecutable], info},
        If[FailureQ[session], Print["ERROR: ", session]; Return[False]];
        WithCleanup[
            info = session["Info"];
            Print[
                "  GAP ", info["GAPVersion"],
                If[TrueQ[info["Tested"]], "", " (untested)"], " | ",
                info["System"], " ", info["Processor"]
            ];
            ProcessStatus[session["Process"]] === "Running" &&
                info["ProtocolVersion"] === 1 &&
                MemberQ[{True, False}, info["Tested"]] &&
                MatchQ[info["Packages"], {___String}] &&
                (expectedVersion === Automatic ||
                    info["GAPVersion"] === expectedVersion),
            stopGAP[session]
        ]
    ],
    True,
    TestID -> "Start-GAP-And-Read-Hello"
]
