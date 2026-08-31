(* ::Package:: *)

PackageExported[GAPEvaluate]

GAPEvaluate::usage = "GAPEvaluate[session, code] runs GAP code."

Options[GAPEvaluate] = {
    TimeConstraint -> Infinity,
    "Output" -> "Print",
    "ReturnType" -> "Automatic"
};

gapEvaluateResponse[payload_, error_] := Module[{message, status},
    If[!AssociationQ[payload], Return @ gapSessionFailure[
        "GAPProtocolError", "GAP returned an invalid response."
    ]];
    status = Lookup[payload, "Status", Missing["Status"]];
    If[status === "OK" && KeyExistsQ[payload, "Result"],
        Return[payload["Result"]]
    ];
    message = Lookup[payload, "Message", "GAP could not run the code."];
    Switch[status,
        "GAPError", gapSessionFailure[
            status, "GAP reported an error.",
            <|"GAPMessage" -> gapLinkBytes[error]|>
        ],
        "GAPUnsupportedValue", gapSessionFailure[status, message],
        _, gapSessionFailure[
            "GAPProtocolError", "GAP returned an invalid response."
        ]
    ]
]

GAPEvaluate[
    session_GAPSession, code_String, opts : OptionsPattern[]
] := Module[
    {options, output, payload, response, result, returnType, rules, time},
    rules = Cases[{opts}, _Rule | _RuleDelayed, Infinity];
    options = gapLinkRequestOptions[GAPEvaluate, rules];
    If[FailureQ[options], Return[options]];
    {output, returnType, time} = options;
    payload = <|
        "Operation" -> "Evaluate",
        "Code" -> code,
        "ReturnType" -> returnType
    |>;
    result = gapLinkProtocolEncodeValue[payload];
    If[FailureQ[result], Return[result]];
    response = gapLinkRunSessionRequest[session, payload, time];
    If[FailureQ[response], Return[response]];
    result = gapEvaluateResponse[
        response["Payload"], response["StandardError"]
    ];
    If[MatchQ[result, Failure["GAPProtocolError", _]],
        gapLinkStopSession[session]
    ];
    If[!FailureQ[result], result = gapLinkImportObjects[session, result]];
    gapLinkOutput[result, response, output]
]

GAPEvaluate[_GAPSession, ___] := gapSessionFailure[
    "GAPUnsupportedValue", "The GAP code must be a string."
]
GAPEvaluate[_, ___] := gapInvalidSession[]
