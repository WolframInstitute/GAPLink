(* ::Package:: *)

PackageExported[StartGAPSession]
PackageExported[GAPSession]

PackageScoped["gapLinkCreateSession"]
PackageScoped["gapLinkSessionData"]

StartGAPSession::usage = "StartGAPSession[] starts GAP. StartGAPSession[\"Executable\" -> path] uses the GAP program at path."
GAPSession::usage = "GAPSession[...] represents a GAP session. session[\"property\"] reads a session property."

$gapLinkSessions = <||>;
$gapSessionProperties = {
    "Status", "Executable", "Version", "Packages", "Backend", "Properties"
};

gapSessionFailure[tag_String, message_String, data_: <||>] := Failure[
    tag,
    Join[
        <|"MessageTemplate" -> message, "MessageParameters" -> <||>|>,
        data
    ]
]

gapOptionFailure[option_] := gapSessionFailure[
    "GAPInvalidOption", "The option value is not valid.", <|"Option" -> option|>
]

gapExecutableOptionQ[Automatic] := True
gapExecutableOptionQ[path_String] := StringLength[StringTrim[path]] > 0
gapExecutableOptionQ[_] := False

gapTimeConstraintQ[Infinity] := True
gapTimeConstraintQ[value_] := TrueQ[NumberQ[value] && Positive[value]]

Options[StartGAPSession] = {
    "Executable" -> Automatic,
    TimeConstraint -> 30
};

StartGAPSession[OptionsPattern[]] := Module[
    {executable = OptionValue["Executable"], state, time = OptionValue[TimeConstraint]},
    If[!gapExecutableOptionQ[executable],
        Return[gapOptionFailure["Executable"]]
    ];
    If[!gapTimeConstraintQ[time],
        Return[gapOptionFailure[TimeConstraint]]
    ];
    state = gapLinkStartGAP[executable, time];
    If[FailureQ[state], state, gapLinkCreateSession[state]]
]

gapLinkCreateSession[state_Association] := Module[{id = CreateUUID[]},
    AssociateTo[
        $gapLinkSessions,
        id -> Join[state, <|"Status" -> "Ready", "Backend" -> "Process"|>]
    ];
    GAPSession[id]
]

gapInvalidSession[] := gapSessionFailure[
    "GAPInvalidSession", "The GAP session is not valid."
]

gapSessionState[id_String] := Module[
    {state = Lookup[$gapLinkSessions, id, Missing["NotFound"]]},
    If[MissingQ[state], Return[gapInvalidSession[]]];
    If[
        MemberQ[{"Ready", "Busy"}, state["Status"]] &&
            !TrueQ @ Quiet @ Check[
                ProcessStatus[state["Process"]] === "Running",
                False
            ],
        state = Append[state, "Status" -> "Stopped"];
        AssociateTo[$gapLinkSessions, id -> state]
    ];
    state
]

gapLinkSessionData[GAPSession[id_String]] := gapSessionState[id]
gapLinkSessionData[_GAPSession] := gapInvalidSession[]

gapSessionProperty[state_, "Status"] := state["Status"]
gapSessionProperty[state_, "Executable"] := state["Executable"]
gapSessionProperty[state_, "Version"] := state["Info"]["GAPVersion"]
gapSessionProperty[state_, "Packages"] := state["Info"]["Packages"]
gapSessionProperty[state_, "Backend"] := state["Backend"]
gapSessionProperty[_, "Properties"] := $gapSessionProperties
gapSessionProperty[_, property_] := Missing["UnknownProperty", property]

(session_GAPSession)[property_String] := Module[
    {state = gapLinkSessionData[session]},
    If[FailureQ[state], state, gapSessionProperty[state, property]]
]

gapCloseProcess[process_ProcessObject] := If[
    ProcessStatus[process] === "Running",
    Quiet @ Check[Close[ProcessConnection[process, "StandardInput"]], Null];
    TimeConstrained[
        While[ProcessStatus[process] === "Running", Pause[.01]],
        1,
        gapLinkStopProcess[process]
    ]
]
gapCloseProcess[_] := Null

gapCloseSession[state_Association] := Module[
    {process = Lookup[state, "Process", None], response},
    If[state["Status"] === "Ready",
        response = gapLinkRequest[state, <|"Operation" -> "Close"|>, 5];
        If[
            FailureQ[response] ||
                response["Payload"] =!= <|"Result" -> Null, "Status" -> "OK"|>,
            gapLinkStopProcess[process]
        ]
    ];
    gapCloseProcess[process]
]

gapDeleteSession[session : GAPSession[id_String]] := Module[{state},
    state = gapLinkSessionData[session];
    If[FailureQ[state], Return[state]];
    If[state["Status"] === "Closed", Return[Null]];
    gapCloseSession[state];
    AssociateTo[
        $gapLinkSessions,
        id -> Join[
            KeyTake[state, {"Executable", "Info", "Backend"}],
            <|"Status" -> "Closed"|>
        ]
    ];
    Null
]
gapDeleteSession[_GAPSession] := gapInvalidSession[]

GAPSession /: DeleteObject[session_GAPSession] := gapDeleteSession[session]

GAPSession /: MakeBoxes[session : GAPSession[_String], form_] := With[
    {
        statusBox = ToBoxes[
            Replace[
                gapLinkSessionData[session],
                {state_Association :> state["Status"], _ -> "Invalid"}
            ],
            form
        ]
    },
    InterpretationBox[
        RowBox[{"GAPSession", "[", statusBox, "]"}],
        session
    ]
]
