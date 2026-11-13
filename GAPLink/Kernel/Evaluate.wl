(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[GAPEvaluate];

(* ::Section:: *)
(*Usage Messages*)

GAPEvaluate::usage = "GAPEvaluate[session, code] runs GAP code, a string, and gives the value of its last command.\n\
The options are TimeConstraint -> Infinity, \"Output\" -> \"Print\" (or \"Capture\", \"Discard\") and \"ReturnType\" -> \"Automatic\" (or \
\"Object\").";
gapEvaluateResponse::usage = "gapEvaluateResponse[payload, errorOutput] gives the result or the Failure that the payload of the response to an \
evaluation holds. errorOutput is what GAP wrote to standard error.";

(* ::Section:: *)
(*Function Definitions*)

Options[GAPEvaluate] = {
	TimeConstraint -> Infinity,
	"Output" -> "Print",
	"ReturnType" -> "Automatic"
};

gapEvaluateResponse[payload_Association, errorOutput_ByteArray] :=
	Module[{status, message},
		status = Lookup[payload, "Status", None];
		message = Replace[Lookup[payload, "Message", None], Except[_String] -> "GAP could not run the code."];
		Which[
			status === "OK" && KeyExistsQ[payload, "Result"],
				payload["Result"],
			status === "GAPError",
				gapFailure[status, "GAP reported an error.", <|"GAPMessage" -> gapLinkBytes[errorOutput]|>],
			status === "GAPUnsupportedValue",
				gapFailure[status, message],
			True,
				gapInvalidResponse[]
		]
	]
gapEvaluateResponse[_, _ByteArray] := gapInvalidResponse[]

(* The request is encoded once before the session is asked, so that code that cannot be sent leaves the session as it is. *)
GAPEvaluate[session_GAPSession, code_String, opts : OptionsPattern[]] :=
	Enclose[
		Module[{output, returnType, timeConstraint, payload, response, result},
			{output, returnType, timeConstraint} = ConfirmMatch[gapLinkRequestOptions[GAPEvaluate, {opts}], $notFailure];
			payload = <|"Operation" -> "Evaluate", "Code" -> code, "ReturnType" -> returnType|>;
			ConfirmMatch[gapLinkProtocolEncodeValue[payload], $notFailure];
			response = ConfirmMatch[gapLinkRunSessionRequest[session, payload, timeConstraint], $notFailure];
			result = gapEvaluateResponse[response["Payload"], response["StandardError"]];
			gapLinkOutput[gapLinkFinishResult[session, result], response, output]
		],
		innerFailure
	]
(* These two forms gave a Failure without a message before every function had a catch-all, and projects that use
   GAPLink rely on that: a session followed by anything but code and options, and a first argument that is not a session. *)
GAPEvaluate[_GAPSession, ___] := gapFailure["GAPUnsupportedValue", "The GAP code must be a string."]
GAPEvaluate[Except[_GAPSession], ___] := gapInvalidSession[]
GAPEvaluate[___] := invalidArgumentsFailure[GAPEvaluate]
