(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[GAPObject];

(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{gapLinkImportObjects, gapLinkInvalidateSessionObjects, gapLinkObjectArguments}];

(* ::Section:: *)
(*Usage Messages*)

GAPObject::usage = "GAPObject[...] represents a value kept in a GAP session. GAPCall and GAPEvaluate create it, and it stays as it is: it is the \
handle of the value. Normal[object] copies the value, and DeleteObject[object] releases it.";
gapLinkImportObjects::usage = "gapLinkImportObjects[session, value] gives value with each object reference from GAP replaced by the GAPObject of \
the session for it, inside lists and associations too.";
gapLinkInvalidateSessionObjects::usage = "gapLinkInvalidateSessionObjects[session] marks every active object of the session as stale and gives Null.";
gapLinkObjectArguments::usage = "gapLinkObjectArguments[session, values] gives the list values with each GAPObject replaced by its object \
reference for GAP, inside lists and associations too, or a Failure when an object is not an active object of the session.";
$gapLinkObjects::usage = "$gapLinkObjects holds, for the key of every GAPObject of this kernel, its session, its number in GAP and its status.";
$gapObjectTag::usage = "$gapObjectTag is the tag with which an object that cannot be sent ends the export of the arguments.";
gapInvalidObject::usage = "gapInvalidObject[] gives the Failure with the tag \"GAPInvalidObject\".";
gapObjectData::usage = "gapObjectData[object] gives the record of a GAPObject, an association, or a Failure when the object is not known.";
gapSetObjectStatus::usage = "gapSetObjectStatus[object, status] stores the status \"Active\", \"Stale\" or \"Deleted\" for an object.";
gapStaleIfOwned::usage = "gapStaleIfOwned[objectData, session] gives the record of an object with the status \"Stale\" when it is an active \
object of the session, and unchanged otherwise.";
gapActiveObjectQ::usage = "gapActiveObjectQ[objectData, session, objectID] gives True when the record is of the active object of the session \
that GAP keeps under the number objectID.";
gapRegisterObject::usage = "gapRegisterObject[session, objectID] records a new active object of the session and gives its GAPObject.";
gapCreateObject::usage = "gapCreateObject[session, objectID] gives the GAPObject of the session for the number objectID in GAP: the one that \
is active for that number, or a new one.";
gapLiveObjectReference::usage = "gapLiveObjectReference[session, object, objectData] gives the object reference of an active object when its \
session still runs. Otherwise it marks the object as stale and gives a Failure.";
gapObjectReference::usage = "gapObjectReference[session, object] gives the object reference that names the GAPObject to GAP, or a Failure when \
the object is not an active object of the session.";
gapExportObjects::usage = "gapExportObjects[session, value] gives value with each GAPObject replaced by its object reference. An object that \
is not valid ends the export: its Failure is thrown with $gapObjectTag.";
gapObjectResult::usage = "gapObjectResult[payload] gives the result or the Failure that the payload of a response about an object holds.";
gapObjectResponse::usage = "gapObjectResponse[session, response] gives the value that the response to a request about an object holds, or a \
Failure. A response that is not valid stops the session.";
gapNormalObject::usage = "gapNormalObject[object] copies the value of a GAPObject from GAP, or gives a Failure.";
gapRequestObjectRelease::usage = "gapRequestObjectRelease[object, session] asks GAP to release the object and marks it as deleted. It gives Null, or \
a Failure.";
gapReleaseObject::usage = "gapReleaseObject[object, session] releases an active object. When the session no longer runs it only marks the object as \
stale.";
gapDeleteObject::usage = "gapDeleteObject[object] releases a GAPObject and gives Null, also when it was released before. An object that is not \
known gives a Failure.";
gapObjectStatus::usage = "gapObjectStatus[key] gives the status of the object with the given key, or \"Invalid\" when it is not known.";

(* ::Section:: *)
(*Function Definitions*)

$gapLinkObjects = <||>;
$gapObjectTag = "GAPLinkInvalidObject";

gapInvalidObject[] := gapFailure["GAPInvalidObject", "The GAP object is not valid."]

gapObjectData[GAPObject[key_String]] := Lookup[$gapLinkObjects, key, gapInvalidObject[]]
gapObjectData[_GAPObject] := gapInvalidObject[]

gapSetObjectStatus[GAPObject[key_String], status_String] := AssociateTo[$gapLinkObjects, key -> Append[$gapLinkObjects[key], "Status" -> status]]

gapStaleIfOwned[objectData_Association, session_GAPSession] :=
	If[objectData["Status"] === "Active" && objectData["Session"] === session, Append[objectData, "Status" -> "Stale"], objectData]

gapLinkInvalidateSessionObjects[session_GAPSession] := (
	$gapLinkObjects = Map[gapStaleIfOwned[#, session] &, $gapLinkObjects];
	Null
)

gapActiveObjectQ[objectData_Association, session_GAPSession, objectID_Integer] :=
	objectData["Status"] === "Active" && objectData["ID"] === objectID && objectData["Session"] === session

gapRegisterObject[session_GAPSession, objectID_Integer] :=
	Module[{key},
		key = CreateUUID[];
		AssociateTo[$gapLinkObjects, key -> <|"Session" -> session, "ID" -> objectID, "Status" -> "Active"|>];
		GAPObject[key]
	]

(* One value in GAP has one GAPObject, so that the same value compares as the same object. *)
gapCreateObject[session_GAPSession, objectID_Integer] :=
	Module[{existingKey},
		existingKey = SelectFirst[Keys[$gapLinkObjects], gapActiveObjectQ[$gapLinkObjects[#], session, objectID] &, None];
		If[StringQ[existingKey], GAPObject[existingKey], gapRegisterObject[session, objectID]]
	]

gapLinkImportObjects[session_GAPSession, gapLinkProtocolObjectReference[objectID_Integer]] := gapCreateObject[session, objectID]
gapLinkImportObjects[session_GAPSession, values_List] := Map[gapLinkImportObjects[session, #] &, values]
gapLinkImportObjects[session_GAPSession, values_Association] := Map[gapLinkImportObjects[session, #] &, values]
gapLinkImportObjects[_GAPSession, value_] := value

gapLiveObjectReference[session_GAPSession, object_GAPObject, objectData_Association] :=
	Module[{state},
		state = gapLinkSessionData[session];
		If[FailureQ[state] || !MemberQ[{"Ready", "Busy"}, state["Status"]],
			gapSetObjectStatus[object, "Stale"];
			gapInvalidObject[],

			gapLinkProtocolObjectReference[objectData["ID"]]
		]
	]

gapObjectReference[session_GAPSession, object_GAPObject] :=
	Module[{objectData},
		objectData = gapObjectData[object];
		Which[
			FailureQ[objectData],
				objectData,
			objectData["Status"] =!= "Active" || objectData["Session"] =!= session,
				gapInvalidObject[],
			True,
				gapLiveObjectReference[session, object, objectData]
		]
	]

gapExportObjects[session_GAPSession, object_GAPObject] :=
	Replace[gapObjectReference[session, object], failure_Failure :> Throw[failure, $gapObjectTag]]
gapExportObjects[session_GAPSession, values_List] := Map[gapExportObjects[session, #] &, values]
gapExportObjects[session_GAPSession, values_Association] := Map[gapExportObjects[session, #] &, values]
gapExportObjects[_GAPSession, value_] := value

gapLinkObjectArguments[session_GAPSession, values_List] := Catch[gapExportObjects[session, values], $gapObjectTag]

gapObjectResult[payload_Association] :=
	Module[{status, message},
		status = Lookup[payload, "Status", None];
		message = Replace[Lookup[payload, "Message", None], Except[_String] -> "The GAP object could not be used."];
		Which[
			status === "OK" && KeyExistsQ[payload, "Result"],
				payload["Result"],
			status === "GAPInvalidObject",
				gapInvalidObject[],
			status === "GAPUnsupportedValue",
				gapFailure[status, message],
			True,
				gapInvalidResponse[]
		]
	]
gapObjectResult[_] := gapInvalidResponse[]

gapObjectResponse[session_GAPSession, response_Association] := gapLinkFinishResult[session, gapObjectResult[response["Payload"]]]

gapNormalObject[object_GAPObject] :=
	Enclose[
		Module[{objectData, session, reference, response, result},
			objectData = ConfirmMatch[gapObjectData[object], $notFailure];
			session = objectData["Session"];
			reference = ConfirmMatch[gapObjectReference[session, object], $notFailure];
			response = ConfirmMatch[gapLinkRunSessionRequest[session, <|"Operation" -> "Normal", "Object" -> reference|>, Infinity], $notFailure];
			result = gapObjectResponse[session, response];
			If[MatchQ[result, Failure["GAPInvalidObject", _]], gapSetObjectStatus[object, "Stale"]];
			result
		],
		innerFailure
	]

gapRequestObjectRelease[object_GAPObject, session_GAPSession] :=
	Enclose[
		Module[{reference, response, result},
			reference = ConfirmMatch[gapObjectReference[session, object], $notFailure];
			response = ConfirmMatch[gapLinkRunSessionRequest[session, <|"Operation" -> "Release", "Objects" -> {reference}|>, 5], $notFailure];
			result = gapObjectResponse[session, response];
			If[result === Null, gapSetObjectStatus[object, "Deleted"]];
			result
		],
		innerFailure
	]

gapReleaseObject[object_GAPObject, session_GAPSession] :=
	Module[{state},
		state = gapLinkSessionData[session];
		If[FailureQ[state] || MemberQ[{"Stopped", "Closed"}, state["Status"]],
			gapSetObjectStatus[object, "Stale"];
			Null,

			gapRequestObjectRelease[object, session]
		]
	]

gapDeleteObject[object_GAPObject] :=
	Module[{objectData},
		objectData = gapObjectData[object];
		Which[
			FailureQ[objectData],
				objectData,
			objectData["Status"] =!= "Active",
				Null,
			True,
				gapReleaseObject[object, objectData["Session"]]
		]
	]

GAPObject /: Normal[object_GAPObject] := gapNormalObject[object]
GAPObject /: DeleteObject[object_GAPObject] := gapDeleteObject[object]

gapObjectStatus[key_String] := Lookup[$gapLinkObjects, key, <|"Status" -> "Invalid"|>]["Status"]

(* With puts the computed box into InterpretationBox, which holds its arguments. *)
GAPObject /: MakeBoxes[object : GAPObject[key_String], form : (StandardForm | TraditionalForm)] :=
	With[{statusBox = ToBoxes[gapObjectStatus[key], form]},
		InterpretationBox[RowBox[{"GAPObject", "[", statusBox, "]"}], object]
	]
