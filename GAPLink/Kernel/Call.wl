(* ::Package:: *)

PackageExported[GAPCall]

PackageScoped["gapLinkBytes"]
PackageScoped["gapLinkOutput"]
PackageScoped["gapLinkRequestOptions"]

GAPCall::usage = "GAPCall[session, name, args] calls a named GAP function."

Options[GAPCall] = {
    TimeConstraint -> Infinity,
    "Output" -> "Print",
    "ReturnType" -> "Automatic"
};

gapLinkBytes[bytes_ByteArray] := Module[{text},
    text = Quiet @ Check[FromCharacterCode[Normal[bytes], "UTF-8"], $Failed];
    If[
        StringQ[text] && ToCharacterCode[text, "UTF-8"] === Normal[bytes],
        text,
        bytes
    ]
]

gapLinkWriteBytes[ByteArray[{}], _] := Null
gapLinkWriteBytes[bytes_ByteArray, streams_] := Replace[
    gapLinkBytes[bytes],
    {
        text_String :> WriteString[streams, text],
        raw_ByteArray :> Quiet @ BinaryWrite[streams, Normal[raw], "Byte"]
    }
]

gapLinkOutput[value_, response_Association, "Discard"] := value

gapLinkOutput[value_, response_Association, "Print"] := (
    gapLinkWriteBytes[response["StandardOutput"], $Output];
    gapLinkWriteBytes[response["StandardError"], $Messages];
    value
)

gapLinkOutput[value_, response_Association, "Capture"] := Module[
    {output = gapLinkBytes[response["StandardOutput"]],
     error = gapLinkBytes[response["StandardError"]]},
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
            <|"Function" -> name, "GAPMessage" -> gapLinkBytes[error]|>
        ],
        "GAPFunctionNotFound", gapSessionFailure[
            status, message, <|"Function" -> name|>
        ],
        "GAPUnsupportedValue", gapSessionFailure[
            status, message, <|"Function" -> name|>
        ],
        "GAPInvalidObject", gapSessionFailure[
            status, message, <|"Function" -> name|>
        ],
        _, gapSessionFailure[
            "GAPProtocolError", "GAP returned an invalid response."
        ]
    ]
]

gapLinkRequestOptions[head_Symbol, rules_List] := Module[{bad, values},
    bad = SelectFirst[
        rules,
        !MemberQ[First /@ Options[head], First[#]] &,
        None
    ];
    If[bad =!= None, Return[gapOptionFailure[First[bad]]]];
    values = OptionValue[head, rules, #] & /@
        {"Output", "ReturnType", TimeConstraint};
    Which[
        !gapTimeConstraintQ[values[[3]]], gapOptionFailure[TimeConstraint],
        !MemberQ[{"Print", "Capture", "Discard"}, values[[1]]],
            gapOptionFailure["Output"],
        !MemberQ[{"Automatic", "Object"}, values[[2]]],
            gapOptionFailure["ReturnType"],
        True, values
    ]
]

GAPCall[
    session_GAPSession, name_String,
    arguments : Longest[Except[_Rule | _RuleDelayed]...],
    opts : OptionsPattern[]
] := Module[
    {args = {arguments}, options, output, payload, response, result,
     returnType, time},
    options = gapLinkRequestOptions[GAPCall, {opts}];
    If[FailureQ[options], Return[options]];
    {output, returnType, time} = options;
    args = gapLinkObjectArguments[session, args];
    If[FailureQ[args], Return[args]];
    If[!FreeQ[args, Null], Return @ gapSessionFailure[
        "GAPUnsupportedValue", "The value cannot be sent to GAP.",
        <|"Type" -> "Null"|>
    ]];
    payload = <|
        "Operation" -> "Call",
        "Name" -> name,
        "Arguments" -> args,
        "ReturnType" -> returnType
    |>;
    result = gapLinkProtocolEncodeValue[payload];
    If[FailureQ[result], Return[result]];
    response = gapLinkRunSessionRequest[session, payload, time];
    If[FailureQ[response], Return[response]];
    result = gapCallResponse[response["Payload"], name, response["StandardError"]];
    If[MatchQ[result, Failure["GAPProtocolError", _]],
        gapLinkStopSession[session]
    ];
    If[!FailureQ[result], result = gapLinkImportObjects[session, result]];
    gapLinkOutput[result, response, output]
]

GAPCall[_GAPSession, _, ___] := gapSessionFailure[
    "GAPFunctionNotFound", "The GAP function name is not valid."
]
GAPCall[_, _, ___] := gapInvalidSession[]
