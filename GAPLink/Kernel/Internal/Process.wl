(* ::Package:: *)

PackageScoped["gapLinkGAPCommand"]
PackageScoped["gapLinkRequest"]
PackageScoped["gapLinkStartGAP"]
PackageScoped["gapLinkStopProcess"]
PackageScoped["gapLinkValidateGAPHello"]

$gapLinkStartupTimeout = 30;

gapStartFailure[reason_String, message_String, data_: <||>] := Failure[
    "GAPStartFailed",
    Join[
        <|
            "MessageTemplate" -> message,
            "MessageParameters" -> <||>,
            "Reason" -> reason
        |>,
        data
    ]
]

gapLinkStartupFile[] := PacletObject[
    "WolframInstitute/GAPLink"
]["AssetLocation", "GAPStartup"]

gapLinkGAPCommand[executable_String] := Module[{startup = gapLinkStartupFile[]},
    Which[
        MemberQ[{"bat", "cmd"}, ToLowerCase @ FileExtension[executable]],
            gapStartFailure[
                "ShellLauncher", "GAP's batch launcher is not supported."
            ],
        !FileExistsQ[startup],
            gapStartFailure[
                "StartupFileNotFound", "The GAP startup file could not be found."
            ],
        True,
            {executable, "-q", "-n", "-A", "-r", "--nointeract", startup}
    ]
]

gapProcessBytes[stream_] := Replace[
    Quiet @ Check[ReadString[stream, EndOfBuffer], ""],
    {text_String :> ByteArray[ToCharacterCode[text]], _ -> ByteArray[{}]}
]

gapJoinBytes[left_ByteArray, right_ByteArray] :=
    ByteArray[Join[Normal[left], Normal[right]]]

gapEmptyChannel[buffer_: ByteArray[{}]] := <|
    "Done" -> False,
    "Output" -> ByteArray[{}],
    "Buffer" -> buffer
|>

gapReadChannel[
    channel_String, state_Association, stream_, token_String, requestID_Integer
] := Module[{result, buffer},
    buffer = gapJoinBytes[state["Buffer"], gapProcessBytes[stream]];
    result = gapLinkProtocolReadFrame[channel, buffer, token, requestID];
    If[FailureQ[result], Return[result]];
    If[result["Status"] === "Complete",
        <|
            "Done" -> True,
            "Output" -> gapJoinBytes[state["Output"], result["Output"]],
            "Buffer" -> result["Rest"],
            "Frame" -> result
        |>,
        <|
            "Done" -> False,
            "Output" -> gapJoinBytes[state["Output"], result["Output"]],
            "Buffer" -> result["Buffer"]
        |>
    ]
]

gapProcessFailure[tag_String, message_String, data_: <||>] := Failure[
    tag,
    Join[
        <|"MessageTemplate" -> message, "MessageParameters" -> <||>|>,
        data
    ]
]

gapLinkWaitForResponse[state_Association, requestID_Integer] := Module[
    {error, next, output, process = state["Process"], token = state["Token"]},
    output = gapEmptyChannel[state["StandardOutputBuffer"]];
    error = gapEmptyChannel[state["StandardErrorBuffer"]];
    While[True,
        If[!output["Done"],
            next = gapReadChannel[
                "Response", output,
                ProcessConnection[process, "StandardOutput"], token, requestID
            ];
            If[FailureQ[next], Return[next]];
            output = next
        ];
        If[!error["Done"],
            next = gapReadChannel[
                "ErrorEnd", error,
                ProcessConnection[process, "StandardError"], token, requestID
            ];
            If[FailureQ[next], Return[next]];
            error = next
        ];
        If[output["Done"] && error["Done"],
            Return @ <|
                "Payload" -> output["Frame"]["Payload"],
                "StandardOutput" -> output["Output"],
                "StandardError" -> error["Output"],
                "StandardOutputBuffer" -> output["Buffer"],
                "StandardErrorBuffer" -> error["Buffer"]
            |>
        ];
        If[ProcessStatus[process] =!= "Running", Return @ gapProcessFailure[
            "GAPProcessStopped", "The GAP process stopped."
        ]];
        Pause[.01]
    ]
]

gapVersionParts[version_String] := If[
    StringMatchQ[
        version,
        DigitCharacter.. ~~ "." ~~ DigitCharacter.. ~~ "." ~~ DigitCharacter..
    ],
    FromDigits /@ StringSplit[version, "."],
    $Failed
]

gapLinkValidateGAPHello[payload_] := Module[{hpc, info, parts, status},
    If[!AssociationQ[payload], Return @ gapStartFailure[
        "InvalidHello", "GAP returned an invalid hello response."
    ]];
    status = Lookup[payload, "Status", Missing["Status"]];
    If[status =!= "OK", Return @ gapStartFailure[
        "HelloFailed", "GAP rejected the hello request.",
        <|"GAPMessage" -> Lookup[payload, "Message", ""]|>
    ]];
    info = Lookup[payload, "Result", Missing["Result"]];
    hpc = If[AssociationQ[info], Lookup[info, "HPC", None], None];
    If[
        !AssociationQ[info] ||
        Lookup[info, "ProtocolVersion", 0] =!= 1 ||
        !And @@ (StringQ[Lookup[info, #, None]] & /@
            {"GAPVersion", "Build", "System", "Processor"}) ||
        !MatchQ[Lookup[info, "Packages", None], {___String}] ||
        !MemberQ[{True, False}, hpc],
        Return @ gapStartFailure[
            "InvalidHello", "GAP returned an invalid hello response."
        ]
    ];
    If[hpc, Return @ gapStartFailure[
        "UnsupportedGAP", "HPC-GAP is not supported."
    ]];
    parts = gapVersionParts[info["GAPVersion"]];
    If[
        parts === $Failed || parts[[1]] =!= 4 || parts[[2]] < 14,
        Return @ gapStartFailure[
            "UnsupportedVersion", "This GAP version is not supported.",
            <|"GAPVersion" -> info["GAPVersion"]|>
        ]
    ];
    Append[info, "Tested" -> 14 <= parts[[2]] <= 16]
]

gapLinkStopProcess[process_ProcessObject] := If[
    ProcessStatus[process] === "Running",
    Quiet @ Check[KillProcess[process], Null]
]

gapLinkRequest[state_Association, payload_, time_] := Module[
    {frame, process = state["Process"], requestID, response, timedOut, updated},
    If[ProcessStatus[process] =!= "Running", Return @ gapProcessFailure[
        "GAPProcessStopped", "The GAP process stopped."
    ]];
    requestID = state["NextRequestID"];
    frame = gapLinkProtocolEncodeFrame[
        "Request", state["Token"], requestID, payload
    ];
    If[FailureQ[frame], Return[frame]];
    If[!TrueQ @ Quiet @ Check[
        BinaryWrite[
            ProcessConnection[process, "StandardInput"], Normal[frame], "Byte"
        ];
        Flush[ProcessConnection[process, "StandardInput"]];
        True,
        False
    ],
        gapLinkStopProcess[process];
        Return @ gapProcessFailure[
            "GAPProcessStopped", "GAP did not accept the request."
        ]
    ];

    timedOut = Unique[];
    response = CheckAbort[
        TimeConstrained[
            gapLinkWaitForResponse[state, requestID], time, timedOut
        ],
        gapLinkStopProcess[process];
        Abort[]
    ];
    If[response === timedOut,
        gapLinkStopProcess[process];
        Return @ gapProcessFailure[
            "GAPTimeConstraintExceeded", "The GAP request took too long.",
            <|"TimeConstraint" -> time|>
        ]
    ];
    If[FailureQ[response],
        gapLinkStopProcess[process];
        Return[response]
    ];
    updated = Join[
        state,
        <|
            "NextRequestID" -> requestID + 1,
            "StandardOutputBuffer" -> response["StandardOutputBuffer"],
            "StandardErrorBuffer" -> response["StandardErrorBuffer"]
        |>
    ];
    <|
        "State" -> updated,
        "Payload" -> response["Payload"],
        "StandardOutput" -> response["StandardOutput"],
        "StandardError" -> response["StandardError"]
    |>
]

gapStartupRequestFailure[Failure["GAPTimeConstraintExceeded", _]] :=
    gapStartFailure[
        "TimeConstraintExceeded", "GAP did not start in time."
    ]

gapStartupRequestFailure[Failure["GAPProcessStopped", _]] := gapStartFailure[
    "ProcessStopped", "GAP stopped during startup."
]

gapStartupRequestFailure[_Failure] := gapStartFailure[
    "InvalidResponse", "GAP returned an invalid startup response."
]

gapLinkStartGAP[path_: Automatic, time_: $gapLinkStartupTimeout] := Module[
    {command, environment, executable, info, process, request, state, token},
    executable = gapLinkFindGAPExecutable[path];
    If[FailureQ[executable], Return[executable]];
    command = gapLinkGAPCommand[executable];
    If[FailureQ[command], Return[command]];

    token = ToLowerCase @ StringReplace[CreateUUID[], "-" -> ""];
    environment = Append[Association @ GetEnvironment[], "GAPLINK_TOKEN" -> token];
    process = Quiet @ Check[
        StartProcess[command, ProcessEnvironment -> environment],
        $Failed
    ];
    If[Head[process] =!= ProcessObject, Return @ gapStartFailure[
        "StartProcessFailed", "GAP could not be started."
    ]];

    state = <|
        "Process" -> process,
        "Executable" -> executable,
        "Token" -> token,
        "NextRequestID" -> 1,
        "StandardOutputBuffer" -> ByteArray[{}],
        "StandardErrorBuffer" -> ByteArray[{}]
    |>;
    request = gapLinkRequest[state, <|"Operation" -> "Hello"|>, time];
    If[FailureQ[request],
        Return[gapStartupRequestFailure[request]]
    ];
    If[ProcessStatus[process] =!= "Running",
        Return @ gapStartFailure[
            "ProcessStopped", "GAP stopped during startup."
        ]
    ];
    info = gapLinkValidateGAPHello[request["Payload"]];
    If[FailureQ[info],
        gapLinkStopProcess[process];
        Return[info]
    ];
    Join[
        request["State"],
        <|"Info" -> info|>,
        KeyTake[request, {"StandardOutput", "StandardError"}]
    ]
]
