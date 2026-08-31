(* ::Package:: *)

PackageScoped["gapLinkGAPCommand"]
PackageScoped["gapLinkStartGAP"]
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

gapEmptyChannel[] := <|
    "Done" -> False,
    "Output" -> ByteArray[{}],
    "Buffer" -> ByteArray[{}]
|>

gapReadChannel[channel_String, state_Association, stream_, token_String] := Module[
    {result, buffer},
    buffer = gapJoinBytes[state["Buffer"], gapProcessBytes[stream]];
    result = gapLinkProtocolReadFrame[channel, buffer, token, 1];
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

gapLinkWaitForHello[process_ProcessObject, token_String] := Module[
    {error = gapEmptyChannel[], output = gapEmptyChannel[], next},
    While[True,
        If[!output["Done"],
            next = gapReadChannel[
                "Response", output,
                ProcessConnection[process, "StandardOutput"], token
            ];
            If[FailureQ[next], Return @ gapStartFailure[
                "InvalidResponse", "GAP returned an invalid startup response."
            ]];
            output = next
        ];
        If[!error["Done"],
            next = gapReadChannel[
                "ErrorEnd", error,
                ProcessConnection[process, "StandardError"], token
            ];
            If[FailureQ[next], Return @ gapStartFailure[
                "InvalidResponse", "GAP returned an invalid startup response."
            ]];
            error = next
        ];
        If[output["Done"] && error["Done"],
            If[ProcessStatus[process] =!= "Running", Return @ gapStartFailure[
                "ProcessStopped", "GAP stopped during startup."
            ]];
            Return @ <|
                "Payload" -> output["Frame"]["Payload"],
                "StandardOutput" -> output["Output"],
                "StandardError" -> error["Output"],
                "StandardOutputBuffer" -> output["Buffer"],
                "StandardErrorBuffer" -> error["Buffer"]
            |>
        ];
        If[ProcessStatus[process] =!= "Running", Return @ gapStartFailure[
            "ProcessStopped", "GAP stopped during startup."
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

gapStopProcess[process_ProcessObject] := If[
    ProcessStatus[process] === "Running",
    Quiet @ Check[KillProcess[process], Null]
]

gapLinkStartGAP[path_: Automatic, time_: $gapLinkStartupTimeout] := Module[
    {command, environment, executable, frame, handshake, info, process, timedOut, token},
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

    frame = gapLinkProtocolEncodeFrame[
        "Request", token, 1, <|"Operation" -> "Hello"|>
    ];
    If[!TrueQ @ Quiet @ Check[
        BinaryWrite[
            ProcessConnection[process, "StandardInput"], Normal[frame], "Byte"
        ];
        Flush[ProcessConnection[process, "StandardInput"]];
        True,
        False
    ],
        gapStopProcess[process];
        Return @ gapStartFailure[
            "RequestFailed", "GAP did not accept the startup request."
        ]
    ];

    timedOut = Unique[];
    handshake = CheckAbort[
        TimeConstrained[gapLinkWaitForHello[process, token], time, timedOut],
        gapStopProcess[process];
        Abort[]
    ];
    If[handshake === timedOut,
        gapStopProcess[process];
        Return @ gapStartFailure[
            "TimeConstraintExceeded", "GAP did not start in time."
        ]
    ];
    If[FailureQ[handshake],
        gapStopProcess[process];
        Return[handshake]
    ];
    info = gapLinkValidateGAPHello[handshake["Payload"]];
    If[FailureQ[info],
        gapStopProcess[process];
        Return[info]
    ];
    Join[
        <|
            "Process" -> process,
            "Executable" -> executable,
            "Token" -> token,
            "NextRequestID" -> 2,
            "Info" -> info
        |>,
        KeyDrop[handshake, "Payload"]
    ]
]
