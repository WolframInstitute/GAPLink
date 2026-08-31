(* ::Package:: *)

PackageExported[GAPCall]

GAPCall::usage = "GAPCall[session, name, args] calls a named GAP function."

Options[GAPCall] = {
    TimeConstraint -> Infinity,
    "Output" -> "Print"
};

gapCallBytes[bytes_ByteArray] := Module[{text},
    text = Quiet @ Check[FromCharacterCode[Normal[bytes], "UTF-8"], $Failed];
    If[
        StringQ[text] && ToCharacterCode[text, "UTF-8"] === Normal[bytes],
        text,
        bytes
    ]
]

gapWriteBytes[ByteArray[{}], _] := Null
gapWriteBytes[bytes_ByteArray, streams_] := Replace[
    gapCallBytes[bytes],
    {
        text_String :> WriteString[streams, text],
        raw_ByteArray :> Quiet @ BinaryWrite[streams, Normal[raw], "Byte"]
    }
]

gapCallOutput[value_, response_Association, "Discard"] := value

gapCallOutput[value_, response_Association, "Print"] := (
    gapWriteBytes[response["StandardOutput"], $Output];
    gapWriteBytes[response["StandardError"], $Messages];
    value
)

gapCallOutput[value_, response_Association, "Capture"] := Module[
    {output = gapCallBytes[response["StandardOutput"]],
     error = gapCallBytes[response["StandardError"]]},
    If[FailureQ[value],
        value /. Failure[tag_, data_] :> Failure[
            tag,
            Join[data, <|"StandardOutput" -> output, "StandardError" -> error|>]
        ],
        <|"Result" -> value, "StandardOutput" -> output, "StandardError" -> error|>
    ]
]

gapCallResponse[payload_, name_String, error_] := Module[{message, status},
    If[!AssociationQ[payload], Return @ gapSessionFailure[
        "GAPProtocolError", "GAP returned an invalid response."
    ]];
    status = Lookup[payload, "Status", Missing["Status"]];
    If[status === "OK" && KeyExistsQ[payload, "Result"],
        Return[payload["Result"]]
    ];
    message = Lookup[payload, "Message", "GAP could not run the function."];
    Switch[status,
        "GAPError", gapSessionFailure[
            status, "GAP reported an error.",
            <|"Function" -> name, "GAPMessage" -> gapCallBytes[error]|>
        ],
        "GAPFunctionNotFound", gapSessionFailure[
            status, message, <|"Function" -> name|>
        ],
        "GAPUnsupportedValue", gapSessionFailure[
            status, message, <|"Function" -> name|>
        ],
        _, gapSessionFailure[
            "GAPProtocolError", "GAP returned an invalid response."
        ]
    ]
]

GAPCall[
    session_GAPSession, name_String, arguments___, opts : OptionsPattern[]
] := Module[
    {args = {arguments}, bad, output, payload, response, result, time},
    bad = SelectFirst[
        {opts},
        !MemberQ[First /@ Options[GAPCall], First[#]] &,
        None
    ];
    If[bad =!= None, Return[gapOptionFailure[First[bad]]]];
    output = OptionValue["Output"];
    time = OptionValue[TimeConstraint];
    If[!gapTimeConstraintQ[time], Return[gapOptionFailure[TimeConstraint]]];
    If[!MemberQ[{"Print", "Capture", "Discard"}, output],
        Return[gapOptionFailure["Output"]]
    ];
    If[!FreeQ[args, Null], Return @ gapSessionFailure[
        "GAPUnsupportedValue", "The value cannot be sent to GAP.",
        <|"Type" -> "Null"|>
    ]];
    payload = <|
        "Operation" -> "Call",
        "Name" -> name,
        "Arguments" -> args,
        "ReturnType" -> "Automatic"
    |>;
    result = gapLinkProtocolEncodeValue[payload];
    If[FailureQ[result], Return[result]];
    response = gapLinkRunSessionRequest[session, payload, time];
    If[FailureQ[response], Return[response]];
    result = gapCallResponse[response["Payload"], name, response["StandardError"]];
    If[MatchQ[result, Failure["GAPProtocolError", _]],
        gapLinkStopProcess[gapLinkSessionData[session]["Process"]];
        gapLinkSetSessionData[
            session, Append[gapLinkSessionData[session], "Status" -> "Stopped"]
        ]
    ];
    gapCallOutput[result, response, output]
]

GAPCall[_GAPSession, _, ___] := gapSessionFailure[
    "GAPFunctionNotFound", "The GAP function name is not valid."
]
GAPCall[_, _, ___] := gapInvalidSession[]
