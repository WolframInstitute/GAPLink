(* ::Package:: *)

(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{gapLinkGAPCommand, gapLinkGAPEnvironment, gapLinkRequest, gapLinkStartGAP, gapLinkStopProcess, gapLinkValidateGAPHello, gapProcessRunningQ}];

(* ::Section:: *)
(*Usage Messages*)

gapLinkGAPCommand::usage = "gapLinkGAPCommand[executable] gives the command, a list of strings, that starts the GAP program at the path executable \
with the GAPLink startup file, or a Failure. A Windows .bat launcher is replaced by the Bash and GAP programs of its installation.";
gapLinkGAPEnvironment::usage = "gapLinkGAPEnvironment[executable, environment] gives the environment, an association of variables, in which the \
GAP program at the path executable starts. For a Windows .bat launcher it clears the variables that would make Bash read startup files.";
gapLinkRequest::usage = "gapLinkRequest[state, payload, timeConstraint] sends the association payload to the GAP process of the session state and \
waits for the response, for at most timeConstraint seconds. It gives an association with the new \"State\", the \"Payload\" of the response and the \
\"StandardOutput\" and \"StandardError\" that GAP wrote, or a Failure. A request that fails after it was sent stops the process.";
gapLinkStartGAP::usage = "gapLinkStartGAP[path, timeConstraint] starts the GAP program at path, or the one that Automatic finds, and greets it \
within timeConstraint seconds. It gives the state of the new session, an association, or a Failure with the tag \"GAPStartFailed\".\n\
gapLinkStartGAP[path] allows $gapLinkStartupTimeout seconds.\n\
gapLinkStartGAP[] finds GAP and allows $gapLinkStartupTimeout seconds.";
gapLinkStopProcess::usage = "gapLinkStopProcess[process] ends the process if it is running. Any other value in place of a process is ignored.";
gapLinkValidateGAPHello::usage = "gapLinkValidateGAPHello[payload] checks the payload of the response to the first request. It gives the \
information about GAP, an association with \"Tested\" added, or a Failure when the response is not valid or the GAP is not supported.";
gapProcessRunningQ::usage = "gapProcessRunningQ[process] gives True when process is a process that is running.";
$gapLinkStartupTimeout::usage = "$gapLinkStartupTimeout is the number of seconds that GAP has to start when no time constraint is given.";
$gapLinkGAPArguments::usage = "$gapLinkGAPArguments lists the command-line arguments that GAP is started with.";
$gapWindowsScript::usage = "$gapWindowsScript is the Bash script that starts GAP on Windows. Its arguments are the GAP program, the startup file and \
the arguments of GAP.";
gapLinkStartupFile::usage = "gapLinkStartupFile[] gives the path of the GAP file that runs the GAPLink side of the protocol.";
gapWindowsCommand::usage = "gapWindowsCommand[launcher, startup] gives the command that starts the GAP of the Windows installation with the \
launcher at the path launcher, or a Failure when its Bash or its GAP program cannot be found.";
gapProcessBytes::usage = "gapProcessBytes[stream] gives the bytes that are ready on the stream of a process, as a byte array, without waiting.";
gapJoinBytes::usage = "gapJoinBytes[left, right] gives one byte array with the bytes of left and then those of right.";
gapEmptyChannel::usage = "gapEmptyChannel[buffer] gives the state of a channel that has read nothing yet, with the byte array buffer left over \
from the request before.";
gapAdvancedChannel::usage = "gapAdvancedChannel[channelState, frame] gives the state of a channel after one reading, given the result of \
gapLinkProtocolReadFrame. A Failure in place of the frame is passed on.";
gapReadChannel::usage = "gapReadChannel[channel, channelState, bytes, token, requestID] adds the byte array bytes to a channel and looks for \
the frame of the request. It gives the new state of the channel, or a Failure.";
gapPolledChannel::usage = "gapPolledChannel[channel, channelState, streamName, link] reads what is ready on the stream that link holds under \
streamName into a channel that is not done. It gives the new state with \"Received\" set to whether bytes arrived, or a Failure.";
gapResponseParts::usage = "gapResponseParts[output, error] gives the response that two finished channels hold: the payload, the output on both \
streams and the bytes left over for the next request.";
gapPollChannels::usage = "gapPollChannels[poll, link] reads both streams of the GAP process once. poll is an association with the channel \
states \"Output\" and \"Error\" and the \"Result\", which is None until the response is complete or has failed. It pauses when nothing arrived.";
gapLinkWaitForResponse::usage = "gapLinkWaitForResponse[state, requestID] reads the output of the GAP process of the session state until the \
response to the request is complete. It gives the response, or a Failure when the data is not valid or the process stopped.";
gapVersionParts::usage = "gapVersionParts[version] gives {major, minor, patch} for a version string of three numbers, and None for any other string.";
gapHelloInfoQ::usage = "gapHelloInfoQ[info] gives True when info is an association with the fields that GAP must report about itself.";
gapSupportedVersionQ::usage = "gapSupportedVersionQ[parts] gives True when the version {major, minor, patch} is GAP 4.14 or later in GAP 4.";
gapTestedVersionQ::usage = "gapTestedVersionQ[parts] gives True when the version {major, minor, patch} is one that GAPLink is tested with.";
gapRunningProcess::usage = "gapRunningProcess[process] gives process when it is running, and a Failure with the tag \"GAPProcessStopped\" otherwise.";
gapSentFrame::usage = "gapSentFrame[process, frame] writes the byte array frame to the process. It gives True, or stops the process and gives a \
Failure when the process does not take the bytes.";
gapAwaitedResponse::usage = "gapAwaitedResponse[state, requestID, timeConstraint] waits for the response to a request for at most timeConstraint \
seconds. On a Failure, a timeout or an abort it stops the process.";
gapStartupRequestFailure::usage = "gapStartupRequestFailure[failure] gives the \"GAPStartFailed\" Failure for a first request that failed.";
gapStartedProcess::usage = "gapStartedProcess[command, environment] starts the command in the environment and gives the process, or a Failure.";
gapGreetedProcess::usage = "gapGreetedProcess[state, timeConstraint] sends the first request to a new GAP process and gives the result of \
gapLinkRequest, or a \"GAPStartFailed\" Failure.";
gapValidatedHello::usage = "gapValidatedHello[process, payload] gives the information about GAP from the first response, or stops the process and \
gives the Failure when the response is not acceptable.";

(* ::Section:: *)
(*Function Definitions*)

(* Calls that ask about a process or read and write its streams quiet every message. Whatever such a call reports,
   the result is the same: GAP is treated as stopped, and the caller gets a Failure. *)

$gapLinkStartupTimeout = 30;
$gapLinkGAPArguments = {"-q", "-n", "-A", "-r", "--nointeract"};

$gapWindowsScript = StringJoin[
	"export PATH=\"/usr/local/bin:/usr/bin:/bin:$PATH\" && ",
	"gap=$(/usr/bin/cygpath -u \"$1\") && ",
	"startup=$(/usr/bin/cygpath -u \"$2\") && ",
	"shift 2 && exec \"$gap\" \"$@\" \"$startup\""
];

gapLinkStartupFile[] := PacletObject["WolframInstitute/GAPLink"]["AssetLocation", "GAPStartup"]

gapWindowsCommand[launcher_String, startup_String] :=
	Module[{root, bash, gapPrograms},
		root = DirectoryName[launcher];
		bash = FileNameJoin[{root, "runtime", "bin", "bash.exe"}];
		gapPrograms = FileNames["gap.exe", Select[FileNames["gap-*", FileNameJoin[{root, "runtime", "opt"}]], DirectoryQ]];
		Which[
			FileType[bash] =!= File || gapPrograms === {},
				gapStartFailure["WindowsLauncherNotFound", "GAP's Windows files could not be found.", <|"Path" -> launcher|>],
			Length[gapPrograms] =!= 1,
				gapStartFailure["WindowsLauncherAmbiguous", "More than one Windows GAP program was found.", <|"Path" -> launcher|>],
			True,
				Join[{bash, "--noprofile", "--norc", "-c", $gapWindowsScript, "GAPLink", First[gapPrograms], startup}, $gapLinkGAPArguments]
		]
	]

gapLinkGAPCommand[executable_String] :=
	Module[{startup},
		startup = gapLinkStartupFile[];
		Which[
			!FileExistsQ[startup],
				gapStartFailure["StartupFileNotFound", "The GAP startup file could not be found."],
			ToLowerCase @ FileExtension[executable] === "bat",
				gapWindowsCommand[executable, startup],
			ToLowerCase @ FileExtension[executable] === "cmd",
				gapStartFailure["ShellLauncher", "GAP's command launcher is not supported."],
			True,
				Join[{executable}, $gapLinkGAPArguments, {startup}]
		]
	]

gapLinkGAPEnvironment[executable_String, environment_Association] :=
	If[ToLowerCase @ FileExtension[executable] === "bat",
		Join[environment, <|"BASH_ENV" -> "", "ENV" -> "", "TERM" -> ""|>],
		environment
	]

gapProcessRunningQ[process_ProcessObject] := TrueQ[Quiet[Check[ProcessStatus[process] === "Running", False], All]]
gapProcessRunningQ[___] := False

gapLinkStopProcess[process_ProcessObject] := If[ProcessStatus[process] === "Running", Quiet[Check[KillProcess[process], Null], All]]
gapLinkStopProcess[_] := Null

(* A process that has ended may have no stream left; then there is nothing to read. *)
gapProcessBytes[stream_InputStream] :=
	Replace[
		Quiet[Check[ReadString[stream, EndOfBuffer], ""], All],
		{text_String :> ByteArray[ToCharacterCode[text]], _ -> ByteArray[{}]}
	]
gapProcessBytes[_] := ByteArray[{}]

gapJoinBytes[left_ByteArray, right_ByteArray] := ByteArray[Join[Normal[left], Normal[right]]]

gapEmptyChannel[buffer_ByteArray] := <|"Done" -> False, "Output" -> ByteArray[{}], "Buffer" -> buffer|>

gapAdvancedChannel[channelState_Association, frame_Association] :=
	If[frame["Status"] === "Complete",
		<|"Done" -> True, "Output" -> gapJoinBytes[channelState["Output"], frame["Output"]], "Buffer" -> frame["Rest"], "Frame" -> frame|>,
		<|"Done" -> False, "Output" -> gapJoinBytes[channelState["Output"], frame["Output"]], "Buffer" -> frame["Buffer"]|>
	]
gapAdvancedChannel[_Association, failure_Failure] := failure

gapReadChannel[channel_String, channelState_Association, bytes_ByteArray, token_String, requestID_Integer] :=
	gapAdvancedChannel[channelState, gapLinkProtocolReadFrame[channel, gapJoinBytes[channelState["Buffer"], bytes], token, requestID]]

gapPolledChannel[channel_String, channelState_Association, streamName_String, link_Association] :=
	Module[{bytes},
		If[channelState["Done"],
			Append[channelState, "Received" -> False],

			bytes = gapProcessBytes[link[streamName]];
			Replace[
				gapReadChannel[channel, channelState, bytes, link["Token"], link["RequestID"]],
				advanced_Association :> Append[advanced, "Received" -> Length[bytes] > 0]
			]
		]
	]

gapResponseParts[output_Association, error_Association] :=
	<|
		"Payload" -> output["Frame"]["Payload"],
		"StandardOutput" -> output["Output"],
		"StandardError" -> error["Output"],
		"StandardOutputBuffer" -> output["Buffer"],
		"StandardErrorBuffer" -> error["Buffer"]
	|>

(* One reading of both streams. The response is complete when the response frame has arrived on standard output and
   the frame that ends the error output on standard error. A Failure on the first stream ends the reading before the
   second stream is read. *)
gapPollChannels[poll_Association, link_Association] :=
	Module[{output, error},
		output = gapPolledChannel["Response", poll["Output"], "StandardOutput", link];
		error = If[FailureQ[output], poll["Error"], gapPolledChannel["ErrorEnd", poll["Error"], "StandardError", link]];
		Which[
			FailureQ[output],
				Append[poll, "Result" -> output],
			FailureQ[error],
				Append[poll, "Result" -> error],
			output["Done"] && error["Done"],
				Append[poll, "Result" -> gapResponseParts[output, error]],
			ProcessStatus[link["Process"]] =!= "Running",
				Append[poll, "Result" -> gapFailure["GAPProcessStopped", "The GAP process stopped."]],
			True,
				If[!(output["Received"] || error["Received"]), Pause[.01]];
				<|"Output" -> output, "Error" -> error, "Result" -> None|>
		]
	]

gapLinkWaitForResponse[state_Association, requestID_Integer] :=
	Module[{process, link, firstPoll, lastPoll},
		process = state["Process"];
		link = <|
			"Process" -> process,
			"Token" -> state["Token"],
			"RequestID" -> requestID,
			"StandardOutput" -> ProcessConnection[process, "StandardOutput"],
			"StandardError" -> ProcessConnection[process, "StandardError"]
		|>;
		firstPoll = <|
			"Output" -> gapEmptyChannel[state["StandardOutputBuffer"]],
			"Error" -> gapEmptyChannel[state["StandardErrorBuffer"]],
			"Result" -> None
		|>;
		lastPoll = NestWhile[gapPollChannels[#, link] &, firstPoll, #Result === None &];
		lastPoll["Result"]
	]

gapVersionParts[version_String] :=
	If[StringMatchQ[version, DigitCharacter.. ~~ "." ~~ DigitCharacter.. ~~ "." ~~ DigitCharacter..],
		Map[FromDigits, StringSplit[version, "."]],
		None
	]

gapHelloInfoQ[info_Association] :=
	And[
		Lookup[info, "ProtocolVersion", 0] === 1,
		AllTrue[Lookup[info, {"GAPVersion", "Build", "System", "Processor"}, None], StringQ],
		MatchQ[Lookup[info, "Packages", None], {___String}],
		MatchQ[Lookup[info, "HPC", None], True | False]
	]
gapHelloInfoQ[___] := False

gapSupportedVersionQ[{4, minor_Integer, _Integer}] := minor >= 14
gapSupportedVersionQ[___] := False

gapTestedVersionQ[{4, minor_Integer, _Integer}] := 14 <= minor <= 16
gapTestedVersionQ[___] := False

gapLinkValidateGAPHello[payload_Association] :=
	Module[{info, versionParts},
		info = Lookup[payload, "Result", None];
		versionParts = If[gapHelloInfoQ[info], gapVersionParts[info["GAPVersion"]], None];
		Which[
			Lookup[payload, "Status", None] =!= "OK",
				gapStartFailure["HelloFailed", "GAP rejected the hello request.", <|"GAPMessage" -> Lookup[payload, "Message", ""]|>],
			!gapHelloInfoQ[info],
				gapStartFailure["InvalidHello", "GAP returned an invalid hello response."],
			info["HPC"],
				gapStartFailure["UnsupportedGAP", "HPC-GAP is not supported."],
			!gapSupportedVersionQ[versionParts],
				gapStartFailure["UnsupportedVersion", "This GAP version is not supported.", <|"GAPVersion" -> info["GAPVersion"]|>],
			True,
				Append[info, "Tested" -> gapTestedVersionQ[versionParts]]
		]
	]
gapLinkValidateGAPHello[_] := gapStartFailure["InvalidHello", "GAP returned an invalid hello response."]

gapRunningProcess[process_ProcessObject] :=
	If[ProcessStatus[process] === "Running", process, gapFailure["GAPProcessStopped", "The GAP process stopped."]]
gapRunningProcess[_] := gapFailure["GAPProcessStopped", "The GAP process stopped."]

gapSentFrame[process_ProcessObject, frame_ByteArray] :=
	Module[{sentQ},
		sentQ = TrueQ @ Quiet[
			Check[
				BinaryWrite[ProcessConnection[process, "StandardInput"], Normal[frame], "Byte"];
				True,

				False
			],
			All
		];
		If[sentQ,
			True,

			gapLinkStopProcess[process];
			gapFailure["GAPProcessStopped", "GAP did not accept the request."]
		]
	]

(* A request that ran out of time leaves GAP in an unknown state, so the process is stopped; see decision 0006. *)
gapAwaitedResponse[state_Association, requestID_Integer, timeConstraint_?gapTimeConstraintQ] :=
	Module[{process, timeoutFailure, response},
		process = state["Process"];
		timeoutFailure = gapFailure["GAPTimeConstraintExceeded", "The GAP request took too long.", <|"TimeConstraint" -> timeConstraint|>];
		response = CheckAbort[
			TimeConstrained[gapLinkWaitForResponse[state, requestID], timeConstraint, timeoutFailure],
			gapLinkStopProcess[process];
			Abort[]
		];
		If[FailureQ[response], gapLinkStopProcess[process]];
		response
	]

gapLinkRequest[state_Association, payload_Association, timeConstraint_?gapTimeConstraintQ] :=
	Enclose[
		Module[{process, requestID, frame, response, nextState},
			process = ConfirmMatch[gapRunningProcess[state["Process"]], $notFailure];
			requestID = state["NextRequestID"];
			frame = ConfirmMatch[gapLinkProtocolEncodeFrame["Request", state["Token"], requestID, payload], $notFailure];
			ConfirmMatch[gapSentFrame[process, frame], $notFailure];
			response = ConfirmMatch[gapAwaitedResponse[state, requestID, timeConstraint], $notFailure];
			nextState = Join[
				state,
				<|
					"NextRequestID" -> requestID + 1,
					"StandardOutputBuffer" -> response["StandardOutputBuffer"],
					"StandardErrorBuffer" -> response["StandardErrorBuffer"]
				|>
			];
			<|
				"State" -> nextState,
				"Payload" -> response["Payload"],
				"StandardOutput" -> response["StandardOutput"],
				"StandardError" -> response["StandardError"]
			|>
		],
		innerFailure
	]

gapStartupRequestFailure[Failure["GAPTimeConstraintExceeded", _]] := gapStartFailure["TimeConstraintExceeded", "GAP did not start in time."]
gapStartupRequestFailure[Failure["GAPProcessStopped", _]] := gapStartFailure["ProcessStopped", "GAP stopped during startup."]
gapStartupRequestFailure[_Failure] := gapStartFailure["InvalidResponse", "GAP returned an invalid startup response."]

gapStartedProcess[command : {__String}, environment_Association] :=
	Replace[
		Quiet[Check[StartProcess[command, ProcessEnvironment -> environment], None], All],
		Except[_ProcessObject] :> gapStartFailure["StartProcessFailed", "GAP could not be started."]
	]

gapGreetedProcess[state_Association, timeConstraint_?gapTimeConstraintQ] :=
	Module[{request},
		request = gapLinkRequest[state, <|"Operation" -> "Hello"|>, timeConstraint];
		Which[
			FailureQ[request],
				gapStartupRequestFailure[request],
			ProcessStatus[state["Process"]] =!= "Running",
				gapStartFailure["ProcessStopped", "GAP stopped during startup."],
			True,
				request
		]
	]

gapValidatedHello[process_ProcessObject, payload_Association] :=
	Module[{info},
		info = gapLinkValidateGAPHello[payload];
		If[FailureQ[info], gapLinkStopProcess[process]];
		info
	]

gapLinkStartGAP[path : (_String | Automatic), timeConstraint_?gapTimeConstraintQ] :=
	Enclose[
		Module[{executable, command, token, environment, process, state, request, info},
			executable = ConfirmMatch[gapLinkFindGAPExecutable[path], $notFailure];
			command = ConfirmMatch[gapLinkGAPCommand[executable], $notFailure];
			token = ToLowerCase @ StringReplace[CreateUUID[], "-" -> ""];
			environment = gapLinkGAPEnvironment[executable, Append[Association @ GetEnvironment[], "GAPLINK_TOKEN" -> token]];
			process = ConfirmMatch[gapStartedProcess[command, environment], $notFailure];
			state = <|
				"Process" -> process,
				"Executable" -> executable,
				"Token" -> token,
				"NextRequestID" -> 1,
				"StandardOutputBuffer" -> ByteArray[{}],
				"StandardErrorBuffer" -> ByteArray[{}]
			|>;
			request = ConfirmMatch[gapGreetedProcess[state, timeConstraint], $notFailure];
			info = ConfirmMatch[gapValidatedHello[process, request["Payload"]], $notFailure];
			Join[request["State"], <|"Info" -> info|>, KeyTake[request, {"StandardOutput", "StandardError"}]]
		],
		innerFailure
	]
gapLinkStartGAP[path : (_String | Automatic)] := gapLinkStartGAP[path, $gapLinkStartupTimeout]
gapLinkStartGAP[] := gapLinkStartGAP[Automatic, $gapLinkStartupTimeout]
