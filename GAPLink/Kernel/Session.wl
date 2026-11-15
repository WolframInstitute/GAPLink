(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{StartGAPSession, GAPSession}];

(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{
	gapLinkCreateSession, gapLinkRunSessionRequest, gapLinkSessionData, gapLinkSetSessionData, gapLinkStopSession, gapLinkFinishResult,
	gapInvalidSession, gapOptionFailure, gapCheckedOption, gapTimeConstraintQ
}];

(* ::Section:: *)
(*Usage Messages*)

StartGAPSession::usage = "StartGAPSession[] starts GAP and gives a GAPSession, or a Failure when GAP cannot be found or started.\n\
StartGAPSession[\"Executable\" -> path] uses the GAP program at path.\n\
The option \"Executable\" -> Automatic uses the GAP in the paclet, then a GAP on PATH, then one in a common installation folder. \
TimeConstraint -> 30 limits the start, in seconds.";
GAPSession::usage = "GAPSession[...] represents a GAP session. StartGAPSession creates it, and it stays as it is: it is the handle of the session.\n\
session[\"property\"] reads a session property. session[\"Properties\"] lists the properties.";
gapLinkCreateSession::usage = "gapLinkCreateSession[state] registers the state of a started GAP, an association, and gives its GAPSession.";
gapLinkRunSessionRequest::usage = "gapLinkRunSessionRequest[session, payload, timeConstraint] sends the association payload to the GAP of a session \
that is ready and gives the response, as gapLinkRequest does, or a Failure. The session is busy while the request runs, and stopped when GAP \
no longer runs afterwards.";
gapLinkSessionData::usage = "gapLinkSessionData[session] gives the state of a session, an association, or a Failure with the tag \
\"GAPInvalidSession\" when the session is not known. A session whose GAP has ended is marked as stopped.";
gapLinkSetSessionData::usage = "gapLinkSetSessionData[session, state] stores the association state as the state of the session.";
gapLinkStopSession::usage = "gapLinkStopSession[session] ends the GAP of the session, marks the session as stopped and its objects as stale.";
gapLinkFinishResult::usage = "gapLinkFinishResult[session, result] gives the result of a request in the form the caller sees: a value with its \
object references replaced by GAPObject, or the Failure. A Failure with the tag \"GAPProtocolError\" stops the session first.";
gapInvalidSession::usage = "gapInvalidSession[] gives the Failure with the tag \"GAPInvalidSession\".";
gapOptionFailure::usage = "gapOptionFailure[option] gives the Failure with the tag \"GAPInvalidOption\" for the option with the given name.";
gapCheckedOption::usage = "gapCheckedOption[option, value, test] gives value when test[value] gives True, and the Failure for the option otherwise.";
gapTimeConstraintQ::usage = "gapTimeConstraintQ[value] gives True when value is a positive number or Infinity.";
$gapLinkSessions::usage = "$gapLinkSessions holds the state of every session of this kernel, by session ID.";
$gapSessionProperties::usage = "$gapSessionProperties lists the names of the properties of a session.";
gapExecutableOptionQ::usage = "gapExecutableOptionQ[value] gives True when value is Automatic or a string that is not blank.";
gapSessionState::usage = "gapSessionState[sessionID] gives the state of the session with the given ID, or the Failure for a session that is not \
known. A session that is ready or busy while its GAP no longer runs is marked as stopped first.";
gapMarkSessionStopped::usage = "gapMarkSessionStopped[sessionID, state] stores the state with the status \"Stopped\", marks the objects of the \
session as stale and gives the stored state.";
gapReadySessionState::usage = "gapReadySessionState[session] gives the state of a session that is ready for a request, or the Failure for a \
session that is busy or not valid.";
gapFinishSessionRequest::usage = "gapFinishSessionRequest[session, state, result] stores the state of the session after a request and gives \
result. After a response the session is ready again. After a Failure it is ready if GAP still runs, and stopped otherwise.";
gapSessionProperty::usage = "gapSessionProperty[state, property] gives the value of a property that is read from the state of a session, and \
Missing[\"UnknownProperty\", property] for a name that is not a property.";
gapPackageVersionsQ::usage = "gapPackageVersionsQ[packages] gives True when packages is an association from package names to version strings.";
gapSessionLoadedPackages::usage = "gapSessionLoadedPackages[session] asks GAP for its loaded packages and gives an association from each name to \
its version, or a Failure. A response of another form stops the session.";
gapSessionPropertyValue::usage = "gapSessionPropertyValue[session, property] gives the value of a property of a session, or the Failure for a \
session that is not valid.";
gapPauseBriefly::usage = "gapPauseBriefly[process] waits a hundredth of a second and gives process.";
gapCloseProcess::usage = "gapCloseProcess[process] closes the input of a running process and waits up to one second for it to end, then ends it. \
Any other value in place of a process is ignored.";
gapCloseSession::usage = "gapCloseSession[state] asks the GAP of a ready session to quit, and ends its process if it does not.";
gapForgetSession::usage = "gapForgetSession[session, sessionID, state] closes the GAP of the session, keeps only what a closed session still \
reports, marks its objects as stale and gives Null.";
gapDeleteSession::usage = "gapDeleteSession[session] closes a session and gives Null, also when the session was closed before. A session that is \
not known gives a Failure.";
gapSessionStatusBox::usage = "gapSessionStatusBox[session, form] gives the boxes of the status of a session, or of \"Invalid\", in the given form.";

(* ::Section:: *)
(*Function Definitions*)

$gapLinkSessions = <||>;
$gapSessionProperties = {"Status", "Executable", "Version", "Packages", "LoadedPackages", "Backend", "Properties"};

gapInvalidSession[] := gapFailure["GAPInvalidSession", "The GAP session is not valid."]

gapOptionFailure[option : (_String | _Symbol)] := gapFailure["GAPInvalidOption", "The option value is not valid.", <|"Option" -> option|>]

(* allow BarePattern: value is whatever the caller gave for the option, and test decides whether it is valid *)
gapCheckedOption[option : (_String | _Symbol), value_, test_Symbol] := If[TrueQ[test[value]], value, gapOptionFailure[option]]

gapExecutableOptionQ[Automatic] := True
gapExecutableOptionQ[path_String] := StringLength[StringTrim[path]] > 0
gapExecutableOptionQ[___] := False

gapTimeConstraintQ[Infinity] := True
gapTimeConstraintQ[value_?NumberQ] := TrueQ[Positive[value]]
gapTimeConstraintQ[___] := False

Options[StartGAPSession] = {
	"Executable" -> Automatic,
	TimeConstraint -> 30
};

StartGAPSession[OptionsPattern[]] :=
	Enclose[
		Module[{executable, timeConstraint, state},
			executable = ConfirmMatch[gapCheckedOption["Executable", OptionValue["Executable"], gapExecutableOptionQ], $notFailure];
			timeConstraint = ConfirmMatch[gapCheckedOption[TimeConstraint, OptionValue[TimeConstraint], gapTimeConstraintQ], $notFailure];
			state = ConfirmMatch[gapLinkStartGAP[executable, timeConstraint], $notFailure];
			gapLinkCreateSession[state]
		],
		innerFailure
	]
StartGAPSession[___] := invalidArgumentsFailure[StartGAPSession]

gapLinkCreateSession[state_Association] :=
	Module[{sessionID},
		sessionID = CreateUUID[];
		AssociateTo[$gapLinkSessions, sessionID -> Join[state, <|"Status" -> "Ready", "Backend" -> "Process"|>]];
		GAPSession[sessionID]
	]

gapMarkSessionStopped[sessionID_String, state_Association] :=
	Module[{stopped},
		stopped = Append[state, "Status" -> "Stopped"];
		AssociateTo[$gapLinkSessions, sessionID -> stopped];
		gapLinkInvalidateSessionObjects[GAPSession[sessionID]];
		stopped
	]

gapSessionState[sessionID_String] :=
	Module[{state},
		state = Lookup[$gapLinkSessions, sessionID, None];
		Which[
			!AssociationQ[state],
				gapInvalidSession[],
			MemberQ[{"Ready", "Busy"}, state["Status"]] && !gapProcessRunningQ[state["Process"]],
				gapMarkSessionStopped[sessionID, state],
			True,
				state
		]
	]

gapLinkSessionData[GAPSession[sessionID_String]] := gapSessionState[sessionID]
gapLinkSessionData[_GAPSession] := gapInvalidSession[]

gapLinkSetSessionData[GAPSession[sessionID_String], state_Association] := AssociateTo[$gapLinkSessions, sessionID -> state]

gapLinkStopSession[session_GAPSession] :=
	Module[{state},
		state = gapLinkSessionData[session];
		If[AssociationQ[state],
			gapLinkStopProcess[Lookup[state, "Process", None]];
			gapLinkSetSessionData[session, Append[state, "Status" -> "Stopped"]];
			gapLinkInvalidateSessionObjects[session]
		];
		Null
	]

gapLinkFinishResult[session_GAPSession, failure : Failure["GAPProtocolError", _]] := (
	gapLinkStopSession[session];
	failure
)
gapLinkFinishResult[_GAPSession, failure_Failure] := failure
gapLinkFinishResult[session_GAPSession, value_] := gapLinkImportObjects[session, value]

gapReadySessionState[session_GAPSession] :=
	Replace[
		gapLinkSessionData[session],
		state_Association :> Switch[state["Status"],
			"Ready",
				state,
			"Busy",
				gapFailure["GAPSessionBusy", "The GAP session is busy."],
			_,
				gapInvalidSession[]
		]
	]

gapFinishSessionRequest[session_GAPSession, state_Association, failure_Failure] :=
	Module[{status},
		status = If[gapProcessRunningQ[state["Process"]], "Ready", "Stopped"];
		gapLinkSetSessionData[session, Append[state, "Status" -> status]];
		If[status === "Stopped", gapLinkInvalidateSessionObjects[session]];
		failure
	]
gapFinishSessionRequest[session_GAPSession, _Association, response_Association] := (
	gapLinkSetSessionData[session, Append[response["State"], "Status" -> "Ready"]];
	response
)

(* Only one request runs in a session at a time. An abort while GAP works leaves GAP in an unknown state, so it
   stops the session; see decision 0006. *)
gapLinkRunSessionRequest[session_GAPSession, payload_Association, timeConstraint_?gapTimeConstraintQ] :=
	Enclose[
		Module[{state, result},
			state = ConfirmMatch[gapReadySessionState[session], $notFailure];
			gapLinkSetSessionData[session, Append[state, "Status" -> "Busy"]];
			result = CheckAbort[
				gapLinkRequest[state, payload, timeConstraint],
				gapLinkStopSession[session];
				Abort[]
			];
			gapFinishSessionRequest[session, state, result]
		],
		innerFailure
	]

gapSessionProperty[state_Association, "Status"] := state["Status"]
gapSessionProperty[state_Association, "Executable"] := state["Executable"]
gapSessionProperty[state_Association, "Version"] := state["Info"]["GAPVersion"]
gapSessionProperty[state_Association, "Packages"] := state["Info"]["Packages"]
gapSessionProperty[state_Association, "Backend"] := state["Backend"]
gapSessionProperty[_Association, "Properties"] := $gapSessionProperties
gapSessionProperty[_Association, property_String] := Missing["UnknownProperty", property]

gapPackageVersionsQ[packages_Association] := MatchQ[Normal[packages], {(_String -> _String) ...}]
gapPackageVersionsQ[___] := False

gapSessionLoadedPackages[session_GAPSession] :=
	Enclose[
		Module[{response, payload, packages},
			response = ConfirmMatch[gapLinkRunSessionRequest[session, <|"Operation" -> "LoadedPackages"|>, 5], $notFailure];
			payload = Replace[response["Payload"], Except[_Association] -> <||>];
			packages = Lookup[payload, "Result", None];
			If[Lookup[payload, "Status", None] === "OK" && gapPackageVersionsQ[packages],
				packages,

				gapLinkStopSession[session];
				gapInvalidResponse[]
			]
		],
		innerFailure
	]

gapSessionPropertyValue[session_GAPSession, property_String] :=
	Replace[
		gapLinkSessionData[session],
		state_Association :> If[property === "LoadedPackages", gapSessionLoadedPackages[session], gapSessionProperty[state, property]]
	]

(* GAPSession[...] itself has no definition, because it is the handle of a session. Only a property request evaluates. *)
GAPSession[sessionData___][property_String] := gapSessionPropertyValue[GAPSession[sessionData], property]
GAPSession[___][___] := invalidArgumentsFailure[GAPSession]

gapPauseBriefly[process_ProcessObject] := (
	Pause[.01];
	process
)

gapCloseProcess[process_ProcessObject] :=
	If[ProcessStatus[process] === "Running",
		Quiet[Check[Close[ProcessConnection[process, "StandardInput"]], Null], All];
		TimeConstrained[
			NestWhile[gapPauseBriefly, process, ProcessStatus[#] === "Running" &],
			1,
			gapLinkStopProcess[process]
		]
	]
gapCloseProcess[_] := Null

gapCloseSession[state_Association] :=
	Module[{process, response},
		process = Lookup[state, "Process", None];
		If[state["Status"] === "Ready",
			response = gapLinkRequest[state, <|"Operation" -> "Close"|>, 5];
			If[FailureQ[response] || response["Payload"] =!= <|"Result" -> Null, "Status" -> "OK"|>, gapLinkStopProcess[process]]
		];
		gapCloseProcess[process]
	]

gapForgetSession[session_GAPSession, sessionID_String, state_Association] := (
	gapCloseSession[state];
	AssociateTo[$gapLinkSessions, sessionID -> Join[KeyTake[state, {"Executable", "Info", "Backend"}], <|"Status" -> "Closed"|>]];
	gapLinkInvalidateSessionObjects[session];
	Null
)

gapDeleteSession[session : GAPSession[sessionID_String]] :=
	Module[{state},
		state = gapLinkSessionData[session];
		Which[
			FailureQ[state],
				state,
			state["Status"] === "Closed",
				Null,
			True,
				gapForgetSession[session, sessionID, state]
		]
	]
gapDeleteSession[_GAPSession] := gapInvalidSession[]

GAPSession /: DeleteObject[session_GAPSession] := gapDeleteSession[session]

gapSessionStatusBox[session_GAPSession, form : (StandardForm | TraditionalForm)] :=
	ToBoxes[Replace[gapLinkSessionData[session], {state_Association :> state["Status"], _ -> "Invalid"}], form]

(* With puts the computed box into InterpretationBox, which holds its arguments. *)
GAPSession /: MakeBoxes[session : GAPSession[_String], form : (StandardForm | TraditionalForm)] :=
	With[{statusBox = gapSessionStatusBox[session, form]},
		InterpretationBox[RowBox[{"GAPSession", "[", statusBox, "]"}], session]
	]
