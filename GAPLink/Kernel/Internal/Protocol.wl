(* ::Package:: *)

(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{
	gapLinkProtocolDecodeValue, gapLinkProtocolEncodeFrame, gapLinkProtocolEncodeValue, gapLinkProtocolObjectReference, gapLinkProtocolReadFrame,
	gapLinkUTF8Text
}];

(* ::Section:: *)
(*Usage Messages*)

gapLinkProtocolEncodeValue::usage = "gapLinkProtocolEncodeValue[value] gives the text that carries value to GAP, or a Failure when the value \
cannot be sent. Integers, rationals, machine reals, True, False, Null, Missing[\"GAPFail\"], strings, byte arrays, Cycles, lists, associations with \
string keys and object references can be sent. The text is a tag letter, the length of the data, a colon and the data; see docs/protocol.md.";
gapLinkProtocolDecodeValue::usage = "gapLinkProtocolDecodeValue[encoded] gives the value that the text encoded carries, or a Failure with the tag \
\"GAPProtocolError\" and a \"Reason\" when the text is not one complete, canonical value.";
gapLinkProtocolEncodeFrame::usage = "gapLinkProtocolEncodeFrame[channel, token, requestID, payload] gives the frame, a byte array, that carries the \
value payload on the channel \"Request\" or \"Response\".\n\
gapLinkProtocolEncodeFrame[\"ErrorEnd\", token, requestID] gives the frame that ends the error output of a request.\n\
token is a string of 32 lowercase hexadecimal digits and requestID a positive integer. Any other arguments give a Failure.";
gapLinkProtocolReadFrame::usage = "gapLinkProtocolReadFrame[channel, buffer, token, requestID] looks for the frame of a request in the byte array \
buffer. It gives an association with \"Status\" -> \"Complete\", the \"Output\" before the frame, the \"Rest\" after it and, except on the channel \
\"ErrorEnd\", the \"Payload\". When the frame has not arrived in full it gives \"Status\" -> \"Incomplete\" with the \"Output\" that is certainly \
not part of a frame and the \"Buffer\" to keep. A frame that is not valid gives a Failure.";
gapLinkProtocolObjectReference::usage = "gapLinkProtocolObjectReference[objectID] represents, in a value sent to GAP or received from it, the \
object that GAP keeps under the positive integer objectID.";
gapLinkUTF8Text::usage = "gapLinkUTF8Text[codes] gives the text that the list of byte values codes holds in UTF-8, or None when the bytes are not \
the UTF-8 form of a text.";
$protocolVersion::usage = "$protocolVersion is the version of the frame format.";
$protocolMaxPayloadBytes::usage = "$protocolMaxPayloadBytes is the largest size of an encoded value, in bytes.";
$protocolMaxDepth::usage = "$protocolMaxDepth is the deepest level at which a value may sit inside lists and records.";
$protocolMaxID::usage = "$protocolMaxID is the largest request number and object number.";
$protocolFrameCodes::usage = "$protocolFrameCodes gives the letter that marks each channel in a frame.";
$protocolChildTag::usage = "$protocolChildTag is the tag under which the decoder collects the values inside a container.";
protocolFailure::usage = "protocolFailure[reason] gives the Failure with the tag \"GAPProtocolError\" for protocol data that is not valid. reason \
is a short name such as \"InvalidLength\".";
unsupportedValue::usage = "unsupportedValue[value] gives the Failure with the tag \"GAPUnsupportedValue\" for a value that cannot be sent to GAP. \
It reports the head of the value, not the value.";
protocolApply::usage = "protocolApply[value, function] gives function[value], or value itself when it is a Failure.";
protocolTokenQ::usage = "protocolTokenQ[token] gives True when token is a string of 32 lowercase hexadecimal digits.";
protocolIDQ::usage = "protocolIDQ[number] gives True when number is an integer from 1 to $protocolMaxID.";
protocolNode::usage = "protocolNode[tag, data] gives the encoded value with the tag letter and the data text, or a Failure when it is too large.";
protocolHex::usage = "protocolHex[bytes] gives the list of byte values as text, two lowercase hexadecimal digits each.";
protocolSortKeys::usage = "protocolSortKeys[keys] sorts a list of strings by their UTF-8 bytes, the order that record keys are sent in.";
protocolEncodeParts::usage = "protocolEncodeParts[values, depth] gives the joined encodings of the values inside a container at the given depth, \
or the first Failure among them.";
protocolEncodeContainer::usage = "protocolEncodeContainer[tag, values, depth] gives the encoded container with the tag letter that holds the list \
values, or a Failure when a value cannot be sent or would sit deeper than $protocolMaxDepth.";
protocolMachineRealParts::usage = "protocolMachineRealParts[value] gives {mantissa, exponent} for a machine real: an odd integer mantissa with \
value == mantissa * 2^(exponent - bits), where bits is the bit length of the mantissa. Zero gives {0, 0}.";
protocolNonzeroRealParts::usage = "protocolNonzeroRealParts[exact] gives {mantissa, exponent} for a nonzero rational number whose denominator is \
a power of two.";
protocolEncodeNode::usage = "protocolEncodeNode[value, depth] gives the encoding of a value that sits at the given depth, or a Failure.";
protocolRecordParts::usage = "protocolRecordParts[record] gives the keys and values of an association with string keys as one flat list, key1, \
value1, key2, value2 and so on, with the keys in sending order.";
protocolDigitQ::usage = "protocolDigitQ[byte] gives True when the byte value is an ASCII digit.";
protocolUnsignedData::usage = "protocolUnsignedData[data, reason] gives the nonnegative integer that the list of byte values data writes in \
decimal without leading zeros, or the protocol Failure with the reason.";
protocolIntegerData::usage = "protocolIntegerData[data] gives the integer that the list of byte values data writes in decimal, with a minus sign \
for a negative number, or a Failure.";
protocolHexDigitQ::usage = "protocolHexDigitQ[byte] gives True when the byte value is a digit or a lowercase letter from a to f.";
protocolHexData::usage = "protocolHexData[data] gives the byte values that the list data writes as pairs of hexadecimal digits, or a Failure.";
protocolStringData::usage = "protocolStringData[data] gives the string whose UTF-8 bytes the list data writes in hexadecimal, or a Failure.";
protocolTextValue::usage = "protocolTextValue[codes] gives the text of a list of UTF-8 byte values, or a Failure when they are not valid UTF-8.";
protocolLengthStep::usage = "protocolLengthStep[bytes, {position, dataLength}] reads the digit at position into the length and gives the next state.";
protocolLengthContinuesQ::usage = "protocolLengthContinuesQ[bytes, limit, {position, dataLength}] gives True while the byte at position is a \
digit within the limit and the length read so far is within $protocolMaxPayloadBytes.";
protocolCheckedLength::usage = "protocolCheckedLength[bytes, digitStart, limit, {position, dataLength}] checks the length field that ended at \
position: it gives {dataLength, position}, with position at the colon, or a Failure.";
protocolLengthField::usage = "protocolLengthField[bytes, digitStart, limit] reads the length field of a value, the decimal digits from digitStart \
up to a colon, and gives {dataLength, colonPosition} or a Failure.";
protocolNodeData::usage = "protocolNodeData[bytes, dataStart, dataEnd] gives the bytes of the data of a value, an empty list when it has none.";
protocolEmptyValue::usage = "protocolEmptyValue[data, value, reason] gives value when the list data is empty, and the protocol Failure with the \
reason otherwise.";
protocolRationalValue::usage = "protocolRationalValue[parts] gives the rational number for the list {numerator, denominator} in lowest terms with \
a denominator above 1, or a Failure.";
protocolMachineRealValue::usage = "protocolMachineRealValue[parts] gives the machine real for the list {mantissa, exponent} that \
protocolMachineRealParts gives for it, or a Failure.";
protocolPermutationValue::usage = "protocolPermutationValue[parts] gives the Cycles of the permutation whose list of images is parts, or a Failure.";
protocolRecordValue::usage = "protocolRecordValue[parts] gives the association for the flat list key1, value1, key2, value2 and so on, with \
distinct string keys in sending order, or a Failure.";
protocolObjectReferenceValue::usage = "protocolObjectReferenceValue[objectID] gives the object reference with the number objectID, or a Failure \
when it is not a valid object number.";
protocolObjectValue::usage = "protocolObjectValue[data] gives the object reference whose number the list of byte values data writes, or a Failure.";
protocolNodeValue::usage = "protocolNodeValue[tag, bytes, dataStart, dataEnd, depth] gives the value with the tag letter whose data is the bytes \
from dataStart to dataEnd, or a Failure.";
protocolDecodeBody::usage = "protocolDecodeBody[bytes, start, limit, depth, lengthField] decodes the value that starts at start, given its length \
field as {dataLength, colonPosition} or a Failure. It gives {value, nextPosition} or a Failure.";
protocolDecodeNode::usage = "protocolDecodeNode[bytes, start, limit, depth] decodes the value that starts at position start of the list of byte \
values and ends no later than limit. It gives {value, nextPosition} or a Failure.";
protocolDecodeChild::usage = "protocolDecodeChild[bytes, position, end, depth] decodes one value inside a container at the given depth, collects \
it under $protocolChildTag and gives the position after it, or a Failure.";
protocolDecodeChildren::usage = "protocolDecodeChildren[bytes, start, end, depth] gives the list of values that fill the bytes from start to end \
inside a container at the given depth, or a Failure.";
protocolDecodeContainer::usage = "protocolDecodeContainer[bytes, start, end, depth, function] gives function applied to the list of values inside \
a container, or a Failure.";
protocolCompleteValue::usage = "protocolCompleteValue[decoded, codeCount] gives the value of {value, nextPosition} when it used all codeCount \
bytes, and a Failure otherwise.";
protocolBuildFrame::usage = "protocolBuildFrame[channel, token, requestID, payload] gives the frame, a byte array, with the encoded payload text.";
protocolPrefixOverlap::usage = "protocolPrefixOverlap[bytes, prefix] gives the length of the longest end of bytes that is a proper start of prefix.";
protocolFrameField::usage = "protocolFrameField[bytes, start, maximum] reads a header field of at most maximum bytes that a colon ends. It gives \
{field, nextPosition}, Missing[\"Incomplete\"] when the colon may still arrive, or a Failure.";
protocolNextFrameField::usage = "protocolNextFrameField[bytes, {fields, position}, maximum] reads one more header field and gives the fields with \
it and the next position. A Failure or Missing in place of the state is passed on.";
protocolFrameFields::usage = "protocolFrameFields[bytes, start] reads the four header fields after the token: version, channel, request number \
and payload length. It gives {fields, payloadStart}, Missing[\"Incomplete\"] or a Failure.";
protocolIncompleteFrame::usage = "protocolIncompleteFrame[bytes, outputLength] gives the result for a frame that has not arrived in full: the \
first outputLength bytes are output and the rest stays in the buffer.";
protocolFrameError::usage = "protocolFrameError[channel, requestID, version, frameChannel, frameID, payloadLength] gives the reason why a frame \
header does not fit the expected channel and request, or None.";
protocolFramePayload::usage = "protocolFramePayload[frame, payloadBytes] gives the association frame with the decoded \"Payload\", or a Failure.";
protocolReadPayload::usage = "protocolReadPayload[channel, bytes, requestID, start, position, payloadLength] gives the complete frame whose \
payload starts at position, or the incomplete result when the payload has not arrived in full.";
protocolReadFields::usage = "protocolReadFields[channel, bytes, requestID, start, header] gives the result of reading a frame that starts at \
start, given what protocolFrameFields gave for its header.";

(* ::Section:: *)
(*Function Definitions*)

$protocolVersion = 1;
$protocolMaxPayloadBytes = 64 * 1024 ^ 2;
$protocolMaxDepth = 128;
$protocolMaxID = 2 ^ 63 - 1;
$protocolFrameCodes = <|"Request" -> "Q", "Response" -> "R", "ErrorEnd" -> "E"|>;
$protocolChildTag = "GAPLinkProtocolChild";

protocolFailure[reason_String] := gapFailure["GAPProtocolError", "The GAP protocol data is not valid.", <|"Reason" -> reason|>]

(* allow BarePattern: value is any expression that cannot be sent, and only its head is reported *)
unsupportedValue[value_] := gapFailure["GAPUnsupportedValue", "The value cannot be sent to GAP.", <|"Type" -> ToString[Head[value], InputForm]|>]

protocolApply[failure_Failure, _] := failure
protocolApply[value_, function : (_Symbol | _Function)] := function[value]

protocolTokenQ[token_String] := StringMatchQ[token, RegularExpression["[0-9a-f]{32}"]]
protocolTokenQ[___] := False

protocolIDQ[number_Integer] := 1 <= number <= $protocolMaxID
protocolIDQ[___] := False

(* ::Subsection:: *)
(*Encoding*)

protocolNode[tag_String, data_String] :=
	Module[{node},
		node = tag <> IntegerString[StringLength[data]] <> ":" <> data;
		If[StringLength[node] <= $protocolMaxPayloadBytes, node, protocolFailure["ValueTooLarge"]]
	]

protocolHex[bytes_List] := StringJoin[IntegerString[bytes, 16, 2]]

protocolSortKeys[keys_List] := SortBy[keys, ToCharacterCode[#, "UTF-8"] &, LexicographicOrder[#1, #2] === 1 &]

protocolEncodeParts[values_List, depth_Integer] :=
	Module[{parts, failure},
		parts = Map[protocolEncodeNode[#, depth + 1] &, values];
		failure = SelectFirst[parts, FailureQ, None];
		If[FailureQ[failure], failure, StringJoin[parts]]
	]

(* The values inside a container sit one level deeper than the container. *)
protocolEncodeContainer[tag_String, values_List, depth_Integer] :=
	If[values =!= {} && depth >= $protocolMaxDepth,
		protocolFailure["ValueTooDeep"],
		protocolApply[protocolEncodeParts[values, depth], protocolNode[tag, #] &]
	]

protocolNonzeroRealParts[exact : (_Rational | _Integer)] :=
	Module[{numerator, numeratorTwos, mantissa},
		numerator = Numerator[exact];
		numeratorTwos = IntegerExponent[Abs[numerator], 2];
		mantissa = Quotient[numerator, 2 ^ numeratorTwos];
		{mantissa, IntegerLength[Abs[mantissa], 2] + numeratorTwos - IntegerExponent[Denominator[exact], 2]}
	]

protocolMachineRealParts[value_Real] :=
	Module[{exact},
		exact = SetPrecision[value, Infinity];
		If[exact === 0, {0, 0}, protocolNonzeroRealParts[exact]]
	]

protocolRecordParts[record_Association] := Catenate @ Map[Function[key, {key, record[key]}], protocolSortKeys[Keys[record]]]

protocolEncodeNode[value_Integer, _Integer] := protocolNode["i", ToString[value, InputForm]]
protocolEncodeNode[value_Rational, depth_Integer] := protocolEncodeContainer["q", {Numerator[value], Denominator[value]}, depth]
protocolEncodeNode[True, _Integer] := protocolNode["t", ""]
protocolEncodeNode[False, _Integer] := protocolNode["f", ""]
protocolEncodeNode[Null, _Integer] := protocolNode["n", ""]
protocolEncodeNode[Missing["GAPFail"], _Integer] := protocolNode["x", ""]
protocolEncodeNode[value_Real?MachineNumberQ, depth_Integer] := protocolEncodeContainer["d", protocolMachineRealParts[value], depth]
protocolEncodeNode[value_String, _Integer] := protocolNode["s", protocolHex[ToCharacterCode[value, "UTF-8"]]]
protocolEncodeNode[value_ByteArray, _Integer] := protocolNode["b", protocolHex[Normal[value]]]
(* A permutation is sent as its list of images, so the points it moves are limited to 10000. *)
protocolEncodeNode[value_Cycles, depth_Integer] :=
	Module[{images},
		images = If[TrueQ[PermutationCyclesQ[value]] && Max[Append[Flatten[First[value]], 0]] <= 10000,
			Quiet[Check[PermutationList[value], None], {Cycles::reppoint}],
			None
		];
		If[ListQ[images] && PermutationListQ[images], protocolEncodeContainer["p", images, depth], unsupportedValue[value]]
	]
protocolEncodeNode[value_List, depth_Integer] := protocolEncodeContainer["l", value, depth]
protocolEncodeNode[value_Association, depth_Integer] :=
	If[AllTrue[Keys[value], StringQ], protocolEncodeContainer["r", protocolRecordParts[value], depth], unsupportedValue[value]]
protocolEncodeNode[value : gapLinkProtocolObjectReference[objectID_Integer], _Integer] :=
	If[protocolIDQ[objectID], protocolNode["o", IntegerString[objectID]], unsupportedValue[value]]
protocolEncodeNode[value_, _Integer] := unsupportedValue[value]

(* allow BarePattern: any expression may be offered; a value that cannot be sent gives a Failure *)
gapLinkProtocolEncodeValue[value_] := protocolEncodeNode[value, 0]

(* ::Subsection:: *)
(*Decoding*)

protocolDigitQ[byte_Integer] := 48 <= byte <= 57

protocolUnsignedData[data_List, reason_String] :=
	If[data === {} || !AllTrue[data, protocolDigitQ] || (Length[data] > 1 && First[data] === 48),
		protocolFailure[reason],
		FromDigits[data - 48]
	]

protocolIntegerData[data_List] :=
	Module[{negativeQ, magnitude},
		negativeQ = data =!= {} && First[data] === 45;
		magnitude = protocolUnsignedData[If[negativeQ, Rest[data], data], "InvalidInteger"];
		Which[
			FailureQ[magnitude],
				magnitude,
			negativeQ && magnitude === 0,
				protocolFailure["InvalidInteger"],
			negativeQ,
				-magnitude,
			True,
				magnitude
		]
	]

protocolHexDigitQ[byte_Integer] := 48 <= byte <= 57 || 97 <= byte <= 102

(* A digit has the value byte - 48 and a letter the value byte - 87, which is 39 less. *)
protocolHexData[data_List] :=
	Module[{pairs},
		If[OddQ[Length[data]] || !AllTrue[data, protocolHexDigitQ],
			protocolFailure["InvalidHex"],

			pairs = Partition[data - 48 - 39 * UnitStep[data - 97], 2];
			If[pairs === {}, {}, pairs . {16, 1}]
		]
	]

(* Text is accepted only when its bytes are exactly the UTF-8 form of the text they give. *)
gapLinkUTF8Text[codes_List] :=
	Module[{text},
		text = Quiet[Check[FromCharacterCode[codes, "UTF-8"], None], {$CharacterEncoding::utf8}];
		If[StringQ[text] && ToCharacterCode[text, "UTF-8"] === codes, text, None]
	]

protocolTextValue[codes_List] := Replace[gapLinkUTF8Text[codes], None :> protocolFailure["InvalidUTF8"]]

protocolStringData[data_List] := protocolApply[protocolHexData[data], protocolTextValue]

(* The length field is read digit by digit and no further than needed: reading stops at the first byte that is not a
   digit, and as soon as the length passes the limit. The state is {position, dataLength}. *)
protocolLengthStep[bytes_List, {position_Integer, dataLength_Integer}] := {position + 1, 10 * dataLength + bytes[[position]] - 48}

protocolLengthContinuesQ[bytes_List, limit_Integer, {position_Integer, dataLength_Integer}] :=
	position <= limit && protocolDigitQ[bytes[[position]]] && dataLength <= $protocolMaxPayloadBytes

protocolCheckedLength[bytes_List, digitStart_Integer, limit_Integer, {position_Integer, dataLength_Integer}] :=
	Which[
		position === digitStart,
			protocolFailure["InvalidLength"],
		dataLength > $protocolMaxPayloadBytes,
			protocolFailure["ValueTooLarge"],
		position > limit || bytes[[position]] =!= 58,
			protocolFailure["InvalidLength"],
		bytes[[digitStart]] === 48 && position - digitStart > 1,
			protocolFailure["InvalidLength"],
		True,
			{dataLength, position}
	]

protocolLengthField[bytes_List, digitStart_Integer, limit_Integer] :=
	protocolCheckedLength[
		bytes, digitStart, limit,
		NestWhile[protocolLengthStep[bytes, #] &, {digitStart, 0}, protocolLengthContinuesQ[bytes, limit, #] &]
	]

protocolNodeData[bytes_List, dataStart_Integer, dataEnd_Integer] := If[dataEnd < dataStart, {}, Take[bytes, {dataStart, dataEnd}]]

protocolEmptyValue[data_List, value : (True | False | Null | _Missing), reason_String] := If[data === {}, value, protocolFailure[reason]]

protocolRationalValue[{numerator_Integer, denominator_Integer}] :=
	If[numerator === 0 || denominator <= 1 || !CoprimeQ[numerator, denominator], protocolFailure["InvalidRational"], numerator / denominator]
protocolRationalValue[_List] := protocolFailure["InvalidRational"]

(* A machine real is accepted only in the one form that protocolMachineRealParts gives for it. *)
protocolMachineRealValue[{0, exponent_Integer}] := If[exponent === 0, 0., protocolFailure["InvalidMachineReal"]]
protocolMachineRealValue[parts : {mantissa_Integer?OddQ, exponent_Integer}] :=
	Module[{bitLength, exact, value},
		bitLength = IntegerLength[Abs[mantissa], 2];
		exact = mantissa * 2 ^ (exponent - bitLength);
		value = Quiet[N[exact, MachinePrecision], {General::munfl, General::unfl, General::ovfl}];
		If[MatchQ[value, _Real] && Precision[value] === MachinePrecision && protocolMachineRealParts[value] === parts,
			value,
			protocolFailure["InvalidMachineReal"]
		]
	]
protocolMachineRealValue[_List] := protocolFailure["InvalidMachineReal"]

protocolPermutationValue[parts : {___Integer?Positive}] :=
	Module[{cycles},
		cycles = If[PermutationListQ[parts], PermutationCycles[parts], None];
		If[MatchQ[cycles, _Cycles] && PermutationList[cycles] === parts, cycles, protocolFailure["InvalidPermutation"]]
	]
protocolPermutationValue[_List] := protocolFailure["InvalidPermutation"]

protocolRecordValue[parts_List] :=
	Module[{pairs, keys},
		pairs = If[EvenQ[Length[parts]], Partition[parts, 2], None];
		keys = If[ListQ[pairs], Map[First, pairs], None];
		If[ListQ[keys] && AllTrue[keys, StringQ] && DuplicateFreeQ[keys] && keys === protocolSortKeys[keys],
			AssociationThread[keys, Map[Last, pairs]],
			protocolFailure["InvalidRecord"]
		]
	]

protocolObjectReferenceValue[objectID_Integer] := If[protocolIDQ[objectID], gapLinkProtocolObjectReference[objectID], protocolFailure["InvalidObject"]]

protocolObjectValue[data_List] := protocolApply[protocolIntegerData[data], protocolObjectReferenceValue]

protocolNodeValue[tag_String, bytes_List, dataStart_Integer, dataEnd_Integer, depth_Integer] :=
	Switch[tag,
		"i",
			protocolIntegerData[protocolNodeData[bytes, dataStart, dataEnd]],
		"q",
			protocolDecodeContainer[bytes, dataStart, dataEnd, depth, protocolRationalValue],
		"t",
			protocolEmptyValue[protocolNodeData[bytes, dataStart, dataEnd], True, "InvalidTrue"],
		"f",
			protocolEmptyValue[protocolNodeData[bytes, dataStart, dataEnd], False, "InvalidFalse"],
		"n",
			protocolEmptyValue[protocolNodeData[bytes, dataStart, dataEnd], Null, "InvalidNull"],
		"x",
			protocolEmptyValue[protocolNodeData[bytes, dataStart, dataEnd], Missing["GAPFail"], "InvalidFail"],
		"d",
			protocolDecodeContainer[bytes, dataStart, dataEnd, depth, protocolMachineRealValue],
		"s",
			protocolStringData[protocolNodeData[bytes, dataStart, dataEnd]],
		"b",
			protocolApply[protocolHexData[protocolNodeData[bytes, dataStart, dataEnd]], ByteArray],
		"p",
			protocolDecodeContainer[bytes, dataStart, dataEnd, depth, protocolPermutationValue],
		"l",
			protocolDecodeChildren[bytes, dataStart, dataEnd, depth],
		"r",
			protocolDecodeContainer[bytes, dataStart, dataEnd, depth, protocolRecordValue],
		"o",
			protocolObjectValue[protocolNodeData[bytes, dataStart, dataEnd]],
		_,
			protocolFailure["UnknownTag"]
	]

protocolDecodeBody[bytes_List, start_Integer, limit_Integer, depth_Integer, {dataLength_Integer, colonPosition_Integer}] :=
	Module[{dataEnd, value},
		dataEnd = colonPosition + dataLength;
		If[dataEnd > limit,
			protocolFailure["ShortValue"],

			value = protocolNodeValue[FromCharacterCode[bytes[[start]]], bytes, colonPosition + 1, dataEnd, depth];
			If[FailureQ[value], value, {value, dataEnd + 1}]
		]
	]
protocolDecodeBody[_List, _Integer, _Integer, _Integer, failure_Failure] := failure

protocolDecodeNode[bytes_List, start_Integer, limit_Integer, depth_Integer] :=
	Which[
		depth > $protocolMaxDepth,
			protocolFailure["ValueTooDeep"],
		start > limit,
			protocolFailure["MissingValue"],
		True,
			protocolDecodeBody[bytes, start, limit, depth, protocolLengthField[bytes, start + 1, limit]]
	]

(* The values inside a container follow one another, and each says where the next one starts. Each decoded value is
   collected with Sow; a Failure in place of the next position ends the reading. *)
protocolDecodeChild[bytes_List, position_Integer, end_Integer, depth_Integer] :=
	Replace[
		protocolDecodeNode[bytes, position, end, depth + 1],
		{value_, nextPosition_Integer} :> (
			Sow[value, $protocolChildTag];
			nextPosition
		)
	]

protocolDecodeChildren[bytes_List, start_Integer, end_Integer, depth_Integer] :=
	Replace[
		Reap[NestWhile[protocolDecodeChild[bytes, #, end, depth] &, start, IntegerQ[#] && # <= end &], $protocolChildTag],
		{
			{failure_Failure, _} :> failure,
			{_Integer, {}} -> {},
			{_Integer, {children_List}} :> children
		}
	]

protocolDecodeContainer[bytes_List, start_Integer, end_Integer, depth_Integer, function_Symbol] :=
	protocolApply[protocolDecodeChildren[bytes, start, end, depth], function]

protocolCompleteValue[{value_, nextPosition_Integer}, codeCount_Integer] := If[nextPosition === codeCount + 1, value, protocolFailure["TrailingData"]]
protocolCompleteValue[failure_Failure, _Integer] := failure

(* Deeply nested values need more evaluation depth than the default limit gives. *)
gapLinkProtocolDecodeValue[encoded_String] :=
	Block[{$RecursionLimit = Max[$RecursionLimit, 4096]},
		Module[{codes},
			codes = ToCharacterCode[encoded];
			Which[
				Length[codes] > $protocolMaxPayloadBytes || Max[codes, 0] > 127,
					protocolFailure["InvalidValue"],
				codes === {},
					protocolFailure["MissingValue"],
				True,
					protocolCompleteValue[protocolDecodeNode[codes, 1, Length[codes], 0], Length[codes]]
			]
		]
	]
gapLinkProtocolDecodeValue[_] := protocolFailure["InvalidValue"]

(* ::Subsection:: *)
(*Frames*)

protocolBuildFrame[channel_String, token_String, requestID_Integer, payload_String] :=
	Module[{header},
		header = StringRiffle[
			{
				"GAPLINK", token, IntegerString[$protocolVersion], $protocolFrameCodes[channel], IntegerString[requestID],
				IntegerString[StringLength[payload]]
			},
			":"
		];
		ByteArray @ ToCharacterCode[header <> ":" <> payload, "ASCII"]
	]

(* allow BarePattern: payload is any expression; a value that cannot be sent gives a Failure *)
gapLinkProtocolEncodeFrame[channel : ("Request" | "Response"), token_?protocolTokenQ, requestID_?protocolIDQ, payload_] :=
	protocolApply[gapLinkProtocolEncodeValue[payload], protocolBuildFrame[channel, token, requestID, #] &]
gapLinkProtocolEncodeFrame["ErrorEnd", token_?protocolTokenQ, requestID_?protocolIDQ] := protocolBuildFrame["ErrorEnd", token, requestID, ""]
gapLinkProtocolEncodeFrame[___] := protocolFailure["InvalidFrame"]

protocolPrefixOverlap[bytes_List, prefix_List] :=
	SelectFirst[Reverse @ Range[Min[Length[bytes], Length[prefix] - 1]], Take[bytes, -#] === Take[prefix, #] &, 0]

(* A field has from 1 to maximum bytes, so a colon is looked for in the next maximum + 1 bytes only. *)
protocolFrameField[bytes_List, start_Integer, maximum_Integer] :=
	Module[{remaining, colonOffset},
		remaining = Length[bytes] - start + 1;
		colonOffset = FirstPosition[Take[bytes, {start, start + Min[remaining, maximum + 1] - 1}], 58, None, {1}];
		Which[
			MatchQ[colonOffset, {1}],
				protocolFailure["InvalidHeader"],
			ListQ[colonOffset],
				{Take[bytes, {start, start + First[colonOffset] - 2}], start + First[colonOffset]},
			remaining <= maximum,
				Missing["Incomplete"],
			True,
				protocolFailure["InvalidHeader"]
		]
	]

protocolNextFrameField[bytes_List, {fields_List, position_Integer}, maximum_Integer] :=
	Replace[protocolFrameField[bytes, position, maximum], {field_List, nextPosition_Integer} :> {Append[fields, field], nextPosition}]
protocolNextFrameField[_List, stopped : (_Failure | _Missing), _Integer] := stopped

protocolFrameFields[bytes_List, start_Integer] := Fold[protocolNextFrameField[bytes, #1, #2] &, {{}, start}, {3, 1, 19, 8}]

protocolIncompleteFrame[bytes_List, outputLength_Integer] :=
	<|"Status" -> "Incomplete", "Output" -> ByteArray[Take[bytes, outputLength]], "Buffer" -> ByteArray[Drop[bytes, outputLength]]|>

protocolFrameError[channel_String, requestID_Integer, version_Integer, frameChannel_String, frameID_Integer, payloadLength_Integer] :=
	Which[
		version =!= $protocolVersion,
			"UnsupportedVersion",
		frameChannel =!= $protocolFrameCodes[channel],
			"WrongFrameKind",
		frameID =!= requestID,
			"WrongRequestID",
		payloadLength > $protocolMaxPayloadBytes,
			"PayloadTooLarge",
		(channel === "ErrorEnd" && payloadLength =!= 0) || (channel =!= "ErrorEnd" && payloadLength === 0),
			"InvalidPayloadLength",
		True,
			None
	]

protocolFramePayload[frame_Association, payloadBytes_List] :=
	If[Max[payloadBytes, 0] > 127,
		protocolFailure["InvalidPayload"],
		protocolApply[gapLinkProtocolDecodeValue[FromCharacterCode[payloadBytes]], Append[frame, "Payload" -> #] &]
	]

protocolReadPayload[channel_String, bytes_List, requestID_Integer, start_Integer, position_Integer, payloadLength_Integer] :=
	Module[{payloadEnd, frame},
		payloadEnd = position + payloadLength - 1;
		If[payloadEnd > Length[bytes],
			protocolIncompleteFrame[bytes, start - 1],

			frame = <|
				"Status" -> "Complete",
				"Output" -> ByteArray[Take[bytes, start - 1]],
				"Channel" -> channel,
				"RequestID" -> requestID,
				"Rest" -> ByteArray[Drop[bytes, payloadEnd]]
			|>;
			If[channel === "ErrorEnd", frame, protocolFramePayload[frame, Take[bytes, {position, payloadEnd}]]]
		]
	]

protocolReadFields[
	channel_String, bytes_List, requestID_Integer, start_Integer,
	{{versionField_List, channelField_List, requestField_List, lengthField_List}, position_Integer}
] :=
	Module[{version, frameID, payloadLength, frameError},
		version = protocolUnsignedData[versionField, "InvalidHeader"];
		frameID = protocolUnsignedData[requestField, "InvalidHeader"];
		payloadLength = protocolUnsignedData[lengthField, "InvalidHeader"];
		frameError = If[AnyTrue[{version, frameID, payloadLength}, FailureQ],
			"InvalidHeader",
			protocolFrameError[channel, requestID, version, FromCharacterCode[channelField], frameID, payloadLength]
		];
		If[StringQ[frameError],
			protocolFailure[frameError],
			protocolReadPayload[channel, bytes, requestID, start, position, payloadLength]
		]
	]
protocolReadFields[_String, bytes_List, _Integer, start_Integer, _Missing] := protocolIncompleteFrame[bytes, start - 1]
protocolReadFields[_String, _List, _Integer, _Integer, failure_Failure] := failure

(* Output that GAP printed may come before a frame, and a frame may arrive in pieces. Bytes at the end of the buffer
   that could start a frame are kept until more arrive. *)
gapLinkProtocolReadFrame[
	channel : ("Request" | "Response" | "ErrorEnd"), buffer_ByteArray?ByteArrayQ, token_?protocolTokenQ, requestID_?protocolIDQ
] :=
	Module[{bytes, prefix, prefixPositions},
		bytes = Normal[buffer];
		prefix = ToCharacterCode["GAPLINK:" <> token <> ":", "ASCII"];
		prefixPositions = SequencePosition[bytes, prefix, 1];
		Replace[
			prefixPositions,
			{
				{} :> protocolIncompleteFrame[bytes, Length[bytes] - protocolPrefixOverlap[bytes, prefix]],
				{{start_Integer, prefixEnd_Integer}} :> protocolReadFields[channel, bytes, requestID, start, protocolFrameFields[bytes, prefixEnd + 1]]
			}
		]
	]
gapLinkProtocolReadFrame[___] := protocolFailure["InvalidFrame"]
