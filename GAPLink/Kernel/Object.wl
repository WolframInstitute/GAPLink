(* ::Package:: *)

PackageExported[GAPObject]

PackageScoped["gapLinkImportObjects"]
PackageScoped["gapLinkInvalidateSessionObjects"]
PackageScoped["gapLinkObjectArguments"]

GAPObject::usage = "GAPObject[...] represents a value kept in a GAP session."

$gapLinkObjects = <||>;

gapInvalidObject[] := gapSessionFailure[
    "GAPInvalidObject", "The GAP object is not valid."
]

gapObjectData[GAPObject[key_String]] := Lookup[
    $gapLinkObjects, key, gapInvalidObject[]
]
gapObjectData[_GAPObject] := gapInvalidObject[]

gapSetObjectStatus[GAPObject[key_String], status_String] := AssociateTo[
    $gapLinkObjects, key -> Append[$gapLinkObjects[key], "Status" -> status]
]

gapLinkInvalidateSessionObjects[session_GAPSession] := (
    $gapLinkObjects = Map[
        If[
            #1["Status"] === "Active" && SameQ[#1["Session"], session],
            Append[#1, "Status" -> "Stale"],
            #1
        ] &,
        $gapLinkObjects
    ];
    Null
)

gapCreateObject[session_GAPSession, id_Integer] := Module[{key},
    key = SelectFirst[
        Keys[$gapLinkObjects],
        Function[name, With[{data = $gapLinkObjects[name]},
            data["Status"] === "Active" && data["ID"] === id &&
                SameQ[data["Session"], session]
        ]],
        Missing["NotFound"]
    ];
    If[StringQ[key], Return[GAPObject[key]]];
    key = CreateUUID[];
    AssociateTo[$gapLinkObjects, key -> <|
        "Session" -> session, "ID" -> id, "Status" -> "Active"
    |>];
    GAPObject[key]
]

gapLinkImportObjects[
    session_GAPSession, gapLinkProtocolObjectReference[id_Integer]
] := gapCreateObject[session, id]

gapLinkImportObjects[session_GAPSession, values_List] :=
    gapLinkImportObjects[session, #] & /@ values

gapLinkImportObjects[session_GAPSession, values_Association] :=
    Map[gapLinkImportObjects[session, #] &, values]

gapLinkImportObjects[_GAPSession, value_] := value

gapObjectReference[session_GAPSession, object_GAPObject] := Module[
    {data = gapObjectData[object], state},
    If[FailureQ[data], Return[data]];
    If[data["Status"] =!= "Active" || !SameQ[data["Session"], session],
        Return[gapInvalidObject[]]
    ];
    state = gapLinkSessionData[session];
    If[
        FailureQ[state] || !MemberQ[{"Ready", "Busy"}, state["Status"]],
        gapSetObjectStatus[object, "Stale"];
        Return[gapInvalidObject[]]
    ];
    gapLinkProtocolObjectReference[data["ID"]]
]

gapExportObjects[session_, object_GAPObject, tag_] := With[
    {reference = gapObjectReference[session, object]},
    If[FailureQ[reference], Throw[reference, tag], reference]
]

gapExportObjects[session_, values_List, tag_] :=
    gapExportObjects[session, #, tag] & /@ values

gapExportObjects[session_, values_Association, tag_] :=
    Map[gapExportObjects[session, #, tag] &, values]

gapExportObjects[_, value_, _] := value

gapLinkObjectArguments[session_GAPSession, values_] := Module[{tag = Unique[]},
    Catch[gapExportObjects[session, values, tag], tag]
]

gapObjectResponse[session_GAPSession, payload_] := Module[{message, status},
    If[!AssociationQ[payload],
        gapLinkStopSession[session];
        Return @ gapSessionFailure[
            "GAPProtocolError", "GAP returned an invalid response."
        ]
    ];
    status = Lookup[payload, "Status", Missing["Status"]];
    If[status === "OK" && KeyExistsQ[payload, "Result"],
        Return[gapLinkImportObjects[session, payload["Result"]]]
    ];
    message = Lookup[payload, "Message", "The GAP object could not be used."];
    Switch[status,
        "GAPInvalidObject", gapInvalidObject[],
        "GAPUnsupportedValue", gapSessionFailure[status, message],
        _,
            gapLinkStopSession[session];
            gapSessionFailure[
                "GAPProtocolError", "GAP returned an invalid response."
            ]
    ]
]

gapNormalObject[object_GAPObject] := Module[
    {data = gapObjectData[object], reference, response, result, session},
    If[FailureQ[data], Return[data]];
    session = data["Session"];
    reference = gapObjectReference[session, object];
    If[FailureQ[reference], Return[reference]];
    response = gapLinkRunSessionRequest[
        session, <|"Operation" -> "Normal", "Object" -> reference|>, Infinity
    ];
    If[FailureQ[response], Return[response]];
    result = gapObjectResponse[session, response["Payload"]];
    If[MatchQ[result, Failure["GAPInvalidObject", _]],
        gapSetObjectStatus[object, "Stale"]
    ];
    result
]

gapDeleteObject[object_GAPObject] := Module[
    {data = gapObjectData[object], reference, response, result, session, state},
    If[FailureQ[data], Return[data]];
    If[data["Status"] =!= "Active", Return[Null]];
    session = data["Session"];
    state = gapLinkSessionData[session];
    If[FailureQ[state] || MemberQ[{"Stopped", "Closed"}, state["Status"]],
        gapSetObjectStatus[object, "Stale"];
        Return[Null]
    ];
    reference = gapObjectReference[session, object];
    If[FailureQ[reference], Return[reference]];
    response = gapLinkRunSessionRequest[
        session, <|"Operation" -> "Release", "Objects" -> {reference}|>, 5
    ];
    If[FailureQ[response], Return[response]];
    result = gapObjectResponse[session, response["Payload"]];
    If[result === Null, gapSetObjectStatus[object, "Deleted"]];
    result
]

GAPObject /: Normal[object_GAPObject] := gapNormalObject[object]
GAPObject /: DeleteObject[object_GAPObject] := gapDeleteObject[object]

GAPObject /: MakeBoxes[object : GAPObject[key_String], form_] := With[
    {status = Lookup[$gapLinkObjects, key, <|"Status" -> "Invalid"|>]["Status"]},
    InterpretationBox[
        RowBox[{"GAPObject", "[", ToBoxes[status, form], "]"}],
        object
    ]
]
