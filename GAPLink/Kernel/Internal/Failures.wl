(* ::Package:: *)

(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{invalidArgumentsFailure, innerFailure, gapFailure, gapStartFailure, gapInvalidResponse, $notFailure}];

(* ::Section:: *)
(*Usage Messages*)

invalidArgumentsFailure::usage = "invalidArgumentsFailure[function] issues the message function::args and gives the Failure that a public \
function returns for arguments that match none of its definitions. The Failure has the tag \"InvalidArguments\".";
innerFailure::usage = "innerFailure[failure] gives the Failure that a failed confirmation passed up: the confirmed expression when it is \
itself a Failure, and failure otherwise. Used as the second argument of Enclose, it keeps the tag and the data of a Failure that a helper made.";
gapFailure::usage = "gapFailure[tag, message] gives a Failure with the tag and the message.\n\
gapFailure[tag, message, data] adds the fields of the association data, such as \"Function\" or \"TimeConstraint\".";
gapStartFailure::usage = "gapStartFailure[reason, message] gives the Failure with the tag \"GAPStartFailed\" for a GAP that could not be found or \
started. reason is a short name such as \"ExecutableNotFound\".\n\
gapStartFailure[reason, message, data] adds the fields of the association data.";
gapInvalidResponse::usage = "gapInvalidResponse[] gives the Failure with the tag \"GAPProtocolError\" for a response from GAP that is missing or \
has the wrong form.";
$notFailure::usage = "$notFailure is the pattern of a value that is not a Failure. ConfirmMatch[value, $notFailure] passes a value from GAP such \
as Missing[\"GAPFail\"], which Confirm would reject.";

(* ::Section:: *)
(*Function Definitions*)

$notFailure = Except[_Failure];

(* Every public function ends with Name[___] := invalidArgumentsFailure[Name]. The message is the generic one
   every symbol inherits (General::args), so no file defines its own. *)
invalidArgumentsFailure[function_Symbol] := (
	Message[MessageName[function, "args"], function];
	Failure["InvalidArguments", <|"MessageTemplate" -> MessageName[function, "args"], "MessageParameters" -> {function}|>]
)

(* Enclose[body, innerFailure] returns a helper's own Failure, such as one with the tag "GAPInvalidSession", in place
   of a "ConfirmationFailed" Failure around it. A failed ConfirmAssert or ConfirmBy is returned as it is. *)
innerFailure[failure_Failure] := Replace[failure["Expression"], Except[_Failure] -> failure]

(* Every Failure of GAPLink has a message template and message parameters; see decision 0006. *)
gapFailure[tag_String, message_String, data_Association] := Failure[tag, Join[<|"MessageTemplate" -> message, "MessageParameters" -> <||>|>, data]]
gapFailure[tag_String, message_String] := gapFailure[tag, message, <||>]

gapStartFailure[reason_String, message_String, data_Association] := gapFailure["GAPStartFailed", message, Join[<|"Reason" -> reason|>, data]]
gapStartFailure[reason_String, message_String] := gapStartFailure[reason, message, <||>]

gapInvalidResponse[] := gapFailure["GAPProtocolError", "GAP returned an invalid response."]
