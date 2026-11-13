(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[GAPCall];

(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{gapLinkBytes, gapLinkOptionValues, gapLinkOutput, gapLinkRequestOptions}];

(* ::Section:: *)
(*Usage Messages*)

GAPCall::usage = "GAPCall[session, name, args] calls a GAP function by its global name or record path.\n\
GAPCall[session, function, args] calls a GAP function kept as a GAPObject.\n\
The options are TimeConstraint -> Infinity, \"Output\" -> \"Print\" (or \"Capture\", \"Discard\"), \"ReturnType\" -> \"Automatic\" (or \"Object\") \
and \"GAPOptions\" -> <||>, an association of GAP's named options.";
gapLinkBytes::usage = "gapLinkBytes[bytes] gives the text of a byte array that holds valid UTF-8, and the byte array itself otherwise.";
gapLinkOptionValues::usage = "gapLinkOptionValues[function, rules, names] gives the values of the options named in the list names, from the list \
of rules given in a call and the defaults of function. A rule for a name that is not an option of function gives a Failure.";
gapLinkOutput::usage = "gapLinkOutput[value, response, mode] gives the result of a call in the output mode. \"Discard\" gives value. \"Print\" \
writes what GAP printed and gives value. \"Capture\" gives an association with the \"Result\", the \"StandardOutput\" and the \"StandardError\"; \
a Failure gets the two outputs as fields.";
gapLinkRequestOptions::usage = "gapLinkRequestOptions[function, rules] gives {output, returnType, timeConstraint} for a call of function with \
the given list of option rules, or the Failure for the first option that is not valid.";
gapLinkWriteBytes::usage = "gapLinkWriteBytes[bytes, streams] writes a byte array to the list of output streams: as text when it holds valid \
UTF-8, and as bytes otherwise. Nothing is written for an empty byte array.";
gapCallResponse::usage = "gapCallResponse[payload, name, errorOutput] gives the result or the Failure that the payload of the response to a call \
holds. name labels the function in a Failure, and errorOutput is what GAP wrote to standard error.";
gapCheckedRequestOptions::usage = "gapCheckedRequestOptions[values] gives the list {output, returnType, timeConstraint} when all three are \
valid, and the Failure for the first that is not. A Failure in place of the list is passed on.";
gapCheckedGAPOptions::usage = "gapCheckedGAPOptions[value] gives value when it is an association with string keys, and a Failure otherwise.";
gapCallPayload::usage = "gapCallPayload[name, exported, returnType] gives the request for a call. exported is the list {target, arguments, \
options} that gapLinkObjectArguments gave. A Null among the arguments or options gives a Failure, because GAP has no such value.";
gapCallLabel::usage = "gapCallLabel[name] gives the name of the called function for a Failure: the name itself, or \"GAP function\" for a GAPObject.";

(* ::Section:: *)
(*Function Definitions*)

Options[GAPCall] = {
	TimeConstraint -> Infinity,
	"Output" -> "Print",
	"ReturnType" -> "Automatic",
	"GAPOptions" -> <||>
};

gapLinkBytes[bytes_ByteArray] := Replace[gapLinkUTF8Text[Normal[bytes]], None -> bytes]

gapLinkWriteBytes[bytes_ByteArray, streams_List] :=
	If[Length[bytes] > 0,
		Replace[
			gapLinkBytes[bytes],
			{
				text_String :> WriteString[streams, text],
				raw_ByteArray :> Quiet[BinaryWrite[streams, Normal[raw], "Byte"], All]
			}
		]
	]

gapLinkOutput[value_, _Association, "Discard"] := value
gapLinkOutput[value_, response_Association, "Print"] := (
	gapLinkWriteBytes[response["StandardOutput"], $Output];
	gapLinkWriteBytes[response["StandardError"], $Messages];
	value
)
gapLinkOutput[Failure[tag_, data_Association], response_Association, "Capture"] :=
	Failure[
		tag,
		Join[data, <|"StandardOutput" -> gapLinkBytes[response["StandardOutput"]], "StandardError" -> gapLinkBytes[response["StandardError"]]|>]
	]
gapLinkOutput[value_, response_Association, "Capture"] :=
	<|"Result" -> value, "StandardOutput" -> gapLinkBytes[response["StandardOutput"]], "StandardError" -> gapLinkBytes[response["StandardError"]]|>

gapCallResponse[payload_Association, name_String, errorOutput_ByteArray] :=
	Module[{status, message},
		status = Lookup[payload, "Status", None];
		message = Replace[Lookup[payload, "Message", None], Except[_String] -> "GAP could not run the function."];
		Which[
			status === "OK" && KeyExistsQ[payload, "Result"],
				payload["Result"],
			status === "GAPError",
				gapFailure[status, "GAP reported an error.", <|"Function" -> name, "GAPMessage" -> gapLinkBytes[errorOutput]|>],
			MatchQ[status, "GAPFunctionNotFound" | "GAPUnsupportedValue" | "GAPInvalidObject"],
				gapFailure[status, message, <|"Function" -> name|>],
			True,
				gapInvalidResponse[]
		]
	]
gapCallResponse[_, _String, _ByteArray] := gapInvalidResponse[]

gapLinkOptionValues[function_Symbol, rules_List, names_List] :=
	Module[{givenRules, knownNames, unknownRule},
		givenRules = Flatten[rules];
		knownNames = Keys[Options[function]];
		unknownRule = SelectFirst[givenRules, !MemberQ[knownNames, First[#]] &, None];
		If[unknownRule === None,
			Map[OptionValue[function, givenRules, #] &, names],
			gapOptionFailure[First[unknownRule]]
		]
	]

gapCheckedRequestOptions[{output_, returnType_, timeConstraint_}] :=
	Which[
		!gapTimeConstraintQ[timeConstraint],
			gapOptionFailure[TimeConstraint],
		!MemberQ[{"Print", "Capture", "Discard"}, output],
			gapOptionFailure["Output"],
		!MemberQ[{"Automatic", "Object"}, returnType],
			gapOptionFailure["ReturnType"],
		True,
			{output, returnType, timeConstraint}
	]
gapCheckedRequestOptions[failure_Failure] := failure

gapLinkRequestOptions[function_Symbol, rules_List] :=
	gapCheckedRequestOptions[gapLinkOptionValues[function, rules, {"Output", "ReturnType", TimeConstraint}]]

gapCheckedGAPOptions[gapOptions_Association] := If[AllTrue[Keys[gapOptions], StringQ], gapOptions, gapOptionFailure["GAPOptions"]]
gapCheckedGAPOptions[_] := gapOptionFailure["GAPOptions"]

gapCallLabel[name_String] := name
gapCallLabel[_GAPObject] := "GAP function"

gapCallPayload[name : (_String | _GAPObject), {target_, sentArguments_List, sentOptions_Association}, returnType_String] :=
	If[FreeQ[{sentArguments, sentOptions}, Null],
		Join[
			<|"Operation" -> "Call", "Arguments" -> sentArguments, "ReturnType" -> returnType|>,
			<|If[StringQ[name], "Name", "Function"] -> target|>,
			If[sentOptions === <||>, <||>, <|"Options" -> sentOptions|>]
		],
		gapFailure["GAPUnsupportedValue", "The value cannot be sent to GAP.", <|"Type" -> "Null"|>]
	]

(* The request is encoded once before the session is asked, so that a value that cannot be sent leaves the session
   as it is. *)
GAPCall[session_GAPSession, name : (_String | _GAPObject), arguments : Longest[Except[_Rule | _RuleDelayed]...], opts : OptionsPattern[]] :=
	Enclose[
		Module[{output, returnType, timeConstraint, gapOptions, exported, payload, response, result},
			{output, returnType, timeConstraint} = ConfirmMatch[gapLinkRequestOptions[GAPCall, {opts}], $notFailure];
			gapOptions = ConfirmMatch[gapCheckedGAPOptions[OptionValue["GAPOptions"]], $notFailure];
			exported = ConfirmMatch[gapLinkObjectArguments[session, {name, {arguments}, gapOptions}], $notFailure];
			payload = ConfirmMatch[gapCallPayload[name, exported, returnType], $notFailure];
			ConfirmMatch[gapLinkProtocolEncodeValue[payload], $notFailure];
			response = ConfirmMatch[gapLinkRunSessionRequest[session, payload, timeConstraint], $notFailure];
			result = gapCallResponse[response["Payload"], gapCallLabel[name], response["StandardError"]];
			gapLinkOutput[gapLinkFinishResult[session, result], response, output]
		],
		innerFailure
	]
(* These two forms gave a Failure without a message before every function had a catch-all, and projects that use
   GAPLink rely on that: a session followed by arguments of another form, and a first argument that is not a session. *)
GAPCall[_GAPSession, __] := gapFailure["GAPFunctionNotFound", "The GAP function name is not valid."]
GAPCall[Except[_GAPSession], __] := gapInvalidSession[]
GAPCall[___] := invalidArgumentsFailure[GAPCall]
