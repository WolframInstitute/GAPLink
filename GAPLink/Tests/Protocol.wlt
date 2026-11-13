(* Tests for Kernel/Internal/Protocol.wl: the text form of values and the frames that carry them. They need no GAP. *)

PacletDirectoryLoad[DirectoryName[$TestFileName, 2]]
Needs["WolframInstitute`GAPLink`"]

encodeValue = WolframInstitute`GAPLink`PackageScope`gapLinkProtocolEncodeValue;
decodeValue = WolframInstitute`GAPLink`PackageScope`gapLinkProtocolDecodeValue;
encodeFrame = WolframInstitute`GAPLink`PackageScope`gapLinkProtocolEncodeFrame;
readFrame = WolframInstitute`GAPLink`PackageScope`gapLinkProtocolReadFrame;
objectReference = WolframInstitute`GAPLink`PackageScope`gapLinkProtocolObjectReference;

token = "0123456789abcdef0123456789abcdef";
otherToken = "fedcba9876543210fedcba9876543210";
asciiBytes[text_String] := ByteArray[ToCharacterCode[text, "ASCII"]]
makeFrame[channel_String, requestID_Integer, payload___] := encodeFrame[channel, token, requestID, payload]
readChannel[channel_String, bytes_ByteArray, requestID_Integer] := readFrame[channel, bytes, token, requestID]
joinBytes[parts__ByteArray] := ByteArray[Catenate[Normal /@ {parts}]]

(* An encoded value inside the given number of lists. *)
nestedLists[encoded_String, depth_Integer] := Nest["l" <> IntegerString[StringLength[#]] <> ":" <> # &, encoded, depth]

(* Reads a frame that arrives in two pieces, cut after count bytes, and says whether its payload came through. *)
splitReadQ[bytes_List, count_Integer, requestID_Integer, payload_Association] :=
	Module[{first, second},
		first = readChannel["Response", ByteArray[Take[bytes, count]], requestID];
		If[count === Length[bytes],
			first["Status"] === "Complete" && first["Payload"] === payload,

			second = readChannel["Response", joinBytes[first["Buffer"], ByteArray[Drop[bytes, count]]], requestID];
			And[first["Status"] === "Incomplete", second["Status"] === "Complete", second["Payload"] === payload]
		]
	]

VerificationTest[
	encodeValue /@ {
		42,
		1 / 3,
		True,
		Missing["GAPFail"],
		"Hi",
		ByteArray[{0, 255}],
		{True, 42},
		<|"A" -> 1|>
	},
	{
		"i2:42",
		"q8:i1:1i1:3",
		"t0:",
		"x0:",
		"s4:4869",
		"b4:00ff",
		"l8:t0:i2:42",
		"r9:s2:41i1:1"
	},
	TestID -> "Encode-Basic-Values"
]

VerificationTest[
	encodeValue[3.14],
	"d24:i16:7070651414971679i1:2",
	TestID -> "Encode-Machine-Real"
]

VerificationTest[
	encodeValue /@ {
		"",
		ByteArray[{}],
		Cycles[{}],
		{},
		<||>
	},
	{"s0:", "b0:", "p0:", "l0:", "r0:"},
	TestID -> "Encode-Empty-Values"
]

VerificationTest[
	Module[{values},
		values = {
			0,
			-123456789012345678901234567890,
			-7 / 11,
			True,
			False,
			Null,
			Missing["GAPFail"],
			0.,
			3.14,
			5.*^-324,
			$MaxMachineNumber,
			"plain \[Pi]\n" <> FromCharacterCode[{0}],
			ByteArray[{0, 1, 127, 128, 255}],
			Cycles[{}],
			Cycles[{{1, 3, 2}, {4, 5}}],
			{},
			{1, {2, 3}, <|"a" -> False|>},
			<||>,
			<|"a" -> 1, "z" -> {2, 3}|>,
			objectReference[17]
		};
		AllTrue[values, decodeValue[encodeValue[#]] === # &]
	],
	True,
	TestID -> "Roundtrip-Supported-Values"
]

VerificationTest[
	{
		encodeValue[<|"HPC" -> 1, "Build" -> 2|>],
		decodeValue["r31:s10:4275696c64i1:2s6:485043i1:1"]
	},
	{
		"r31:s10:4275696c64i1:2s6:485043i1:1",
		<|"Build" -> 2, "HPC" -> 1|>
	},
	TestID -> "Sort-Record-Keys"
]

VerificationTest[
	FailureQ /@ {
		encodeValue[1.2`20],
		encodeValue[<|1 -> "value"|>],
		encodeValue[objectReference[0]],
		encodeValue[Sin[x]]
	},
	{True, True, True, True},
	TestID -> "Reject-Unsupported-Values"
]

VerificationTest[
	AllTrue[
		{encodeValue[Sin[x]], decodeValue[""]},
		StringQ[#["MessageTemplate"]] && AssociationQ[#["MessageParameters"]] &
	],
	True,
	TestID -> "Failures-Have-Messages"
]

VerificationTest[
	AllTrue[
		{
			"",
			"i01:1",
			"i2:1",
			"s2:zz",
			"s2:ff",
			"q8:i1:0i1:3",
			"d8:i1:2i1:1",
			"p8:i1:2i1:2",
			"r18:s2:7ai1:1s2:61i1:2",
			"i1:1i1:2"
		},
		FailureQ[decodeValue[#]] &
	],
	True,
	TestID -> "Reject-Invalid-Values"
]

VerificationTest[
	{
		!FailureQ @ decodeValue @ nestedLists["n0:", 128],
		FailureQ @ decodeValue @ nestedLists["n0:", 129]
	},
	{True, True},
	TestID -> "Limit-Value-Depth"
]

VerificationTest[
	FromCharacterCode @ Normal @ makeFrame["Request", 1, 42],
	"GAPLINK:" <> token <> ":1:Q:1:5:i2:42",
	TestID -> "Encode-Request-Frame"
]

VerificationTest[
	FromCharacterCode @ Normal @ makeFrame["ErrorEnd", 7],
	"GAPLINK:" <> token <> ":1:E:7:0:",
	TestID -> "Encode-Error-End"
]

VerificationTest[
	Module[{payload, frame, buffer, result},
		payload = <|"Result" -> 42, "Status" -> "OK"|>;
		frame = makeFrame["Response", 9, payload];
		buffer = joinBytes[asciiBytes["printed"], frame, asciiBytes["rest"]];
		result = readChannel["Response", buffer, 9];
		{
			result["Status"],
			result["Output"],
			result["Payload"],
			result["Rest"]
		}
	],
	{
		"Complete",
		asciiBytes["printed"],
		<|"Result" -> 42, "Status" -> "OK"|>,
		asciiBytes["rest"]
	},
	TestID -> "Read-Response-Frame"
]

VerificationTest[
	Module[{payload, bytes},
		payload = <|"Result" -> {1, 2, 3}, "Status" -> "OK"|>;
		bytes = Normal[makeFrame["Response", 11, payload]];
		AllTrue[Range[0, Length[bytes]], splitReadQ[bytes, #, 11, payload] &]
	],
	True,
	TestID -> "Read-Split-Frame"
]

VerificationTest[
	Module[{result},
		result = readChannel["Response", asciiBytes["textGAPLI"], 1];
		{result["Status"], result["Output"], result["Buffer"]}
	],
	{"Incomplete", asciiBytes["text"], asciiBytes["GAPLI"]},
	TestID -> "Keep-Partial-Marker"
]

VerificationTest[
	Module[{wrong, right, buffer, result},
		wrong = encodeFrame["Response", otherToken, 13, <|"Result" -> 1|>];
		right = makeFrame["Response", 13, <|"Result" -> 2|>];
		buffer = joinBytes[wrong, right];
		result = readChannel["Response", buffer, 13];
		{result["Output"], result["Payload"]}
	],
	{
		encodeFrame["Response", otherToken, 13, <|"Result" -> 1|>],
		<|"Result" -> 2|>
	},
	TestID -> "Ignore-Other-Token"
]

VerificationTest[
	Module[{frame, buffer, result, output},
		frame = makeFrame["Response", 15, <|"Result" -> 1|>];
		output = ByteArray[{255, 0, 65}];
		buffer = joinBytes[output, frame];
		result = readChannel["Response", buffer, 15];
		result["Output"]
	],
	ByteArray[{255, 0, 65}],
	TestID -> "Keep-Raw-Output"
]

VerificationTest[
	Module[{frame, text},
		frame = makeFrame["Response", 17, <|"Result" -> 1|>];
		text = FromCharacterCode[Normal[frame]];
		frame = asciiBytes @ StringReplace[text, ":1:R:17:" -> ":2:R:17:"];
		FailureQ[readChannel["Response", frame, 17]]
	],
	True,
	TestID -> "Reject-Protocol-Version"
]

VerificationTest[
	FailureQ @ readChannel["Response", makeFrame["Response", 19, <|"Result" -> 1|>], 20],
	True,
	TestID -> "Reject-Request-ID"
]

VerificationTest[
	FailureQ @ readChannel["Response", makeFrame["Request", 21, <|"Operation" -> "Hello"|>], 21],
	True,
	TestID -> "Reject-Frame-Kind"
]

VerificationTest[
	AllTrue[
		{
			"GAPLINK:" <> token <> ":1:R:1:x:i1:1",
			"GAPLINK:" <> token <> ":1:R:1:05:i1:1",
			"GAPLINK:" <> token <> ":1:R:1:0:"
		},
		FailureQ @ readChannel["Response", asciiBytes[#], 1] &
	],
	True,
	TestID -> "Reject-Payload-Length"
]

VerificationTest[
	Module[{frame, buffer, result},
		frame = makeFrame["ErrorEnd", 23];
		buffer = joinBytes[asciiBytes["warning"], frame, asciiBytes["rest"]];
		result = readChannel["ErrorEnd", buffer, 23];
		{
			result["Status"],
			result["Output"],
			result["Rest"]
		}
	],
	{"Complete", asciiBytes["warning"], asciiBytes["rest"]},
	TestID -> "Read-Error-End"
]

VerificationTest[
	FailureQ @ encodeFrame["Request", "bad-token", 1, 42],
	True,
	TestID -> "Reject-Bad-Token"
]

(* A buffer or a token of the wrong form is not read at all. *)
VerificationTest[
	Map[
		#["Reason"] &,
		{
			readFrame["Response", {1, 2}, token, 1],
			readFrame["Response", asciiBytes["text"], "bad-token", 1],
			readFrame["Response", asciiBytes["text"], token, 0],
			readFrame["Other", asciiBytes["text"], token, 1]
		}
	],
	{"InvalidFrame", "InvalidFrame", "InvalidFrame", "InvalidFrame"},
	TestID -> "Reject-Bad-Read-Arguments"
]

(* The length of a value is read no further than its limit allows. *)
VerificationTest[
	Map[
		decodeValue[#]["Reason"] &,
		{"i:5", "i05:12345", "i99999999999:1", "i000000000000000000001:5", "i2:5", "z0:"}
	],
	{"InvalidLength", "InvalidLength", "ValueTooLarge", "InvalidLength", "ShortValue", "UnknownTag"},
	TestID -> "Report-Why-A-Value-Is-Invalid"
]
