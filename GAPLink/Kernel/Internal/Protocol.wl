(* ::Package:: *)

PackageScoped["gapLinkProtocolDecodeValue"]
PackageScoped["gapLinkProtocolEncodeFrame"]
PackageScoped["gapLinkProtocolEncodeValue"]
PackageScoped["gapLinkProtocolObjectReference"]
PackageScoped["gapLinkProtocolReadFrame"]

$protocolVersion = 1;
$protocolMaxPayloadBytes = 64 * 1024^2;
$protocolMaxDepth = 128;
$protocolMaxID = 2^63 - 1;
$protocolFrameCodes = <|"Request" -> "Q", "Response" -> "R", "ErrorEnd" -> "E"|>;
$protocolContainerTags = {"q", "d", "p", "l", "r"};

protocolFailure[reason_String] := Failure[
    "GAPProtocolError",
    <|
        "MessageTemplate" -> "The GAP protocol data is not valid.",
        "Reason" -> reason
    |>
]

unsupportedValue[value_] := Failure[
    "GAPUnsupportedValue",
    <|
        "MessageTemplate" -> "The value cannot be sent to GAP.",
        "Type" -> ToString[Head[value], InputForm]
    |>
]

protocolApply[value_, function_] := If[FailureQ[value], value, function[value]]

protocolTokenQ[token_] := StringQ[token] &&
    StringMatchQ[token, RegularExpression["[0-9a-f]{32}"]]

protocolIDQ[id_] := IntegerQ[id] && 1 <= id <= $protocolMaxID

protocolNode[tag_String, data_String] := Module[{node},
    node = tag <> IntegerString[StringLength[data]] <> ":" <> data;
    If[StringLength[node] <= $protocolMaxPayloadBytes,
        node, protocolFailure["ValueTooLarge"]]
]

protocolHex[bytes_List] := StringJoin[IntegerString[#, 16, 2] & /@ bytes]

protocolSortKeys[keys_List] := SortBy[keys, ToCharacterCode[#, "UTF-8"] &]

protocolEncodeParts[values_List, depth_Integer] := Module[{parts, failure},
    parts = protocolEncodeNode[#, depth + 1] & /@ values;
    failure = SelectFirst[parts, FailureQ, Missing["NotFound"]];
    If[FailureQ[failure], failure, StringJoin[parts]]
]

protocolEncodeContainer[tag_String, values_List, depth_Integer] := protocolApply[
    protocolEncodeParts[values, depth],
    protocolNode[tag, #] &
]

protocolMachineRealParts[value_Real] := Module[
    {exact, numerator, numeratorTwos, mantissa},
    exact = SetPrecision[value, Infinity];
    If[exact === 0, Return[{0, 0}]];

    numerator = Numerator[exact];
    numeratorTwos = IntegerExponent[Abs[numerator], 2];
    mantissa = Quotient[numerator, 2^numeratorTwos];
    {mantissa,
        IntegerLength[Abs[mantissa], 2] + numeratorTwos -
            IntegerExponent[Denominator[exact], 2]}
]

protocolEncodeNode[value_, depth_Integer] := If[
    depth > $protocolMaxDepth,
    protocolFailure["ValueTooDeep"],
    protocolEncodeData[value, depth]
]

protocolEncodeData[value_Integer, _Integer] :=
    protocolNode["i", ToString[value, InputForm]]

protocolEncodeData[value_Rational, depth_Integer] := protocolEncodeContainer[
    "q", {Numerator[value], Denominator[value]}, depth
]

protocolEncodeData[True, _Integer] := protocolNode["t", ""]
protocolEncodeData[False, _Integer] := protocolNode["f", ""]
protocolEncodeData[Null, _Integer] := protocolNode["n", ""]
protocolEncodeData[Missing["GAPFail"], _Integer] := protocolNode["x", ""]

protocolEncodeData[value_Real?MachineNumberQ, depth_Integer] :=
    protocolEncodeContainer["d", protocolMachineRealParts[value], depth]

protocolEncodeData[value_String, _Integer] :=
    protocolNode["s", protocolHex[ToCharacterCode[value, "UTF-8"]]]

protocolEncodeData[value_ByteArray, _Integer] :=
    protocolNode["b", protocolHex[Normal[value]]]

protocolEncodeData[value_Cycles, depth_Integer] := Module[{images},
    images = Quiet @ Check[PermutationList[value], $Failed];
    If[ListQ[images] && PermutationListQ[images],
        protocolEncodeContainer["p", images, depth],
        unsupportedValue[value]
    ]
]

protocolEncodeData[value_List, depth_Integer] :=
    protocolEncodeContainer["l", value, depth]

protocolEncodeData[value_Association, depth_Integer] := Module[{keys},
    keys = Keys[value];
    If[!AllTrue[keys, StringQ], Return[unsupportedValue[value]]];
    keys = protocolSortKeys[keys];
    protocolEncodeContainer["r", Flatten[{#, value[#]} & /@ keys, 1], depth]
]

protocolEncodeData[value : gapLinkProtocolObjectReference[id_Integer], _Integer] := If[
    protocolIDQ[id],
    protocolNode["o", IntegerString[id]],
    unsupportedValue[value]
]

protocolEncodeData[value_, _Integer] := unsupportedValue[value]

gapLinkProtocolEncodeValue[value_] := protocolEncodeNode[value, 0]

protocolDigitQ[byte_Integer] := 48 <= byte <= 57

protocolUnsignedData[data_List, reason_String] := If[
    data === {} || !AllTrue[data, protocolDigitQ[#] &] ||
        (Length[data] > 1 && First[data] === 48),
    protocolFailure[reason],
    FromDigits[data - 48]
]

protocolIntegerData[data_List] := Module[{negative, value},
    negative = data =!= {} && First[data] === 45;
    value = protocolUnsignedData[If[negative, Rest[data], data], "InvalidInteger"];
    Which[
        FailureQ[value], value,
        negative && value === 0, protocolFailure["InvalidInteger"],
        negative, -value,
        True, value
    ]
]

protocolHexData[data_List] := Module[{nibbles},
    If[OddQ[Length[data]] ||
        !AllTrue[data, (48 <= # <= 57 || 97 <= # <= 102) &],
        Return[protocolFailure["InvalidHex"]]
    ];
    nibbles = data /. byte_Integer :> If[byte <= 57, byte - 48, byte - 87];
    16 * #[[1]] + #[[2]] & /@ Partition[nibbles, 2]
]

protocolStringData[data_List] := Module[{bytes, value},
    bytes = protocolHexData[data];
    If[FailureQ[bytes], Return[bytes]];
    value = Quiet @ Check[FromCharacterCode[bytes, "UTF-8"], $Failed];
    If[!StringQ[value] || ToCharacterCode[value, "UTF-8"] =!= bytes,
        protocolFailure["InvalidUTF8"],
        value
    ]
]

protocolDecodeChildren[bytes_List, start_Integer, end_Integer, depth_Integer] := Module[
    {position = start, result, harvested},
    Catch[
        harvested = Reap[
            While[position <= end,
                result = protocolDecodeNode[bytes, position, end, depth + 1];
                If[FailureQ[result], Throw[result]];
                Sow[result[[1]]];
                position = result[[2]]
            ]
        ][[2]];
        If[harvested === {}, {}, First[harvested]]
    ]
]

protocolDecodeContainer[
    bytes_List, start_Integer, end_Integer, depth_Integer, function_
] := protocolApply[
    protocolDecodeChildren[bytes, start, end, depth],
    function
]

protocolEmptyValue[data_List, value_, reason_String] :=
    If[data === {}, value, protocolFailure[reason]]

protocolRationalValue[parts_List] := Module[{numerator, denominator},
    If[!MatchQ[parts, {_Integer, _Integer}],
        Return[protocolFailure["InvalidRational"]]
    ];
    {numerator, denominator} = parts;
    If[numerator === 0 || denominator <= 1 || !CoprimeQ[numerator, denominator],
        protocolFailure["InvalidRational"],
        numerator / denominator
    ]
]

protocolMachineRealValue[parts_List] := Module[
    {mantissa, exponent, bitLength, exact, value, checkedParts},
    If[!MatchQ[parts, {_Integer, _Integer}],
        Return[protocolFailure["InvalidMachineReal"]]
    ];
    {mantissa, exponent} = parts;
    If[mantissa === 0,
        Return[If[exponent === 0, 0., protocolFailure["InvalidMachineReal"]]]
    ];
    If[EvenQ[mantissa], Return[protocolFailure["InvalidMachineReal"]]];

    bitLength = IntegerLength[Abs[mantissa], 2];
    exact = mantissa * 2^(exponent - bitLength);
    value = Quiet[N[exact, MachinePrecision]];
    If[Head[value] =!= Real || Precision[value] =!= MachinePrecision,
        Return[protocolFailure["InvalidMachineReal"]]
    ];
    checkedParts = protocolMachineRealParts[value];
    If[checkedParts === parts, value, protocolFailure["InvalidMachineReal"]]
]

protocolPermutationValue[parts_List] := Module[{value},
    If[!AllTrue[parts, IntegerQ[#] && Positive[#] &] || !PermutationListQ[parts],
        Return[protocolFailure["InvalidPermutation"]]
    ];
    value = PermutationCycles[parts];
    If[PermutationList[value] === parts,
        value,
        protocolFailure["InvalidPermutation"]
    ]
]

protocolRecordValue[parts_List] := Module[{pairs, keys},
    If[OddQ[Length[parts]], Return[protocolFailure["InvalidRecord"]]];
    pairs = Partition[parts, 2];
    keys = First /@ pairs;
    If[!AllTrue[keys, StringQ] || !DuplicateFreeQ[keys] ||
        keys =!= protocolSortKeys[keys],
        Return[protocolFailure["InvalidRecord"]]
    ];
    AssociationThread[keys, Last /@ pairs]
]

protocolObjectValue[data_List] := protocolApply[
    protocolIntegerData[data],
    If[protocolIDQ[#],
        gapLinkProtocolObjectReference[#],
        protocolFailure["InvalidObject"]
    ] &
]

protocolDecodeNode[bytes_List, start_Integer, limit_Integer, depth_Integer] := Module[
    {tag, position, digitStart, dataLength = 0, dataStart, dataEnd, data, value},
    If[depth > $protocolMaxDepth, Return[protocolFailure["ValueTooDeep"]]];
    If[start > limit, Return[protocolFailure["MissingValue"]]];

    tag = FromCharacterCode[bytes[[start]]];
    position = start + 1;
    digitStart = position;
    If[position > limit || !protocolDigitQ[bytes[[position]]],
        Return[protocolFailure["InvalidLength"]]
    ];
    While[position <= limit && protocolDigitQ[bytes[[position]]],
        dataLength = 10 * dataLength + bytes[[position]] - 48;
        If[dataLength > $protocolMaxPayloadBytes, Break[]];
        position++
    ];
    If[dataLength > $protocolMaxPayloadBytes,
        Return[protocolFailure["ValueTooLarge"]]
    ];
    If[position > limit || bytes[[position]] =!= 58,
        Return[protocolFailure["InvalidLength"]]
    ];
    If[bytes[[digitStart]] === 48 && position - digitStart > 1,
        Return[protocolFailure["InvalidLength"]]
    ];

    dataStart = position + 1;
    dataEnd = dataStart + dataLength - 1;
    If[dataEnd > limit, Return[protocolFailure["ShortValue"]]];
    If[!MemberQ[$protocolContainerTags, tag],
        data = If[dataLength === 0, {}, Take[bytes, {dataStart, dataEnd}]]
    ];

    value = Switch[tag,
        "i", protocolIntegerData[data],
        "q", protocolDecodeContainer[bytes, dataStart, dataEnd, depth,
            protocolRationalValue],
        "t", protocolEmptyValue[data, True, "InvalidTrue"],
        "f", protocolEmptyValue[data, False, "InvalidFalse"],
        "n", protocolEmptyValue[data, Null, "InvalidNull"],
        "x", protocolEmptyValue[data, Missing["GAPFail"], "InvalidFail"],
        "d", protocolDecodeContainer[bytes, dataStart, dataEnd, depth,
            protocolMachineRealValue],
        "s", protocolStringData[data],
        "b", protocolApply[protocolHexData[data], ByteArray],
        "p", protocolDecodeContainer[bytes, dataStart, dataEnd, depth,
            protocolPermutationValue],
        "l", protocolDecodeChildren[bytes, dataStart, dataEnd, depth],
        "r", protocolDecodeContainer[bytes, dataStart, dataEnd, depth,
            protocolRecordValue],
        "o", protocolObjectValue[data],
        _, protocolFailure["UnknownTag"]
    ];
    If[FailureQ[value], value, {value, dataEnd + 1}]
]

gapLinkProtocolDecodeValue[encoded_String] := Block[
    {$RecursionLimit = Max[$RecursionLimit, 4096]},
    Module[{codes, result},
        If[
            StringLength[encoded] > $protocolMaxPayloadBytes ||
                !AllTrue[ToCharacterCode[encoded], # <= 127 &],
            Return[protocolFailure["InvalidValue"]]
        ];
        codes = ToCharacterCode[encoded];
        If[codes === {}, Return[protocolFailure["MissingValue"]]];
        result = protocolDecodeNode[codes, 1, Length[codes], 0];
        protocolApply[result, If[#[[2]] === Length[codes] + 1,
            #[[1]], protocolFailure["TrailingData"]] &]
    ]
]

gapLinkProtocolDecodeValue[_] := protocolFailure["InvalidValue"]

protocolBuildFrame[
    channel_String, token_String, requestID_Integer, payload_String
] := ByteArray @ ToCharacterCode[
    StringRiffle[
        {"GAPLINK", token, IntegerString[$protocolVersion],
            $protocolFrameCodes[channel], IntegerString[requestID],
            IntegerString[StringLength[payload]]},
        ":"
    ] <> ":" <> payload,
    "ASCII"
]

gapLinkProtocolEncodeFrame[
    channel : ("Request" | "Response"),
    token_?protocolTokenQ, requestID_?protocolIDQ, payload_
] := protocolApply[
    gapLinkProtocolEncodeValue[payload],
    protocolBuildFrame[channel, token, requestID, #] &
]

gapLinkProtocolEncodeFrame["ErrorEnd", token_?protocolTokenQ,
    requestID_?protocolIDQ] := protocolBuildFrame["ErrorEnd", token, requestID, ""]

gapLinkProtocolEncodeFrame[___] := protocolFailure["InvalidFrame"]

protocolPrefixOverlap[bytes_List, prefix_List] := SelectFirst[
    Reverse @ Range[Min[Length[bytes], Length[prefix] - 1]],
    Take[bytes, -#] === Take[prefix, #] &,
    0
]

protocolFrameField[bytes_List, start_Integer, maximum_Integer] := Module[
    {end = start, count},
    While[end <= Length[bytes] && bytes[[end]] =!= 58, end++];
    If[end > Length[bytes],
        count = Length[bytes] - start + 1;
        Return[If[count <= maximum, Missing["Incomplete"],
            protocolFailure["InvalidHeader"]]]
    ];
    count = end - start;
    If[count < 1 || count > maximum,
        protocolFailure["InvalidHeader"],
        {Take[bytes, {start, end - 1}], end + 1}
    ]
]

protocolFrameFields[bytes_List, start_Integer] := Module[
    {position = start, result, fields = {}},
    Catch[
        Do[
            result = protocolFrameField[bytes, position, maximum];
            If[FailureQ[result] || MissingQ[result], Throw[result]];
            AppendTo[fields, result[[1]]];
            position = result[[2]],
            {maximum, {3, 1, 19, 8}}
        ];
        {fields, position}
    ]
]

protocolIncompleteFrame[bytes_List, outputLength_Integer] := <|
    "Status" -> "Incomplete",
    "Output" -> ByteArray[Take[bytes, outputLength]],
    "Buffer" -> ByteArray[Drop[bytes, outputLength]]
|>

protocolFrameError[channel_String, requestID_Integer, version_Integer,
    frameChannel_String, frameID_Integer, payloadLength_Integer] := Which[
    version =!= $protocolVersion, "UnsupportedVersion",
    frameChannel =!= $protocolFrameCodes[channel], "WrongFrameKind",
    frameID =!= requestID, "WrongRequestID",
    payloadLength > $protocolMaxPayloadBytes, "PayloadTooLarge",
    channel === "ErrorEnd" && payloadLength =!= 0 ||
        channel =!= "ErrorEnd" && payloadLength === 0, "InvalidPayloadLength",
    True, None
]

gapLinkProtocolReadFrame[
    channel : ("Request" | "Response" | "ErrorEnd"),
    buffer_ByteArray, token_?protocolTokenQ, requestID_?protocolIDQ
] := Module[
    {
        bytes, prefix, positions, start, fieldsResult, fields, position,
        version, frameChannel, frameID, payloadLength, payloadEnd,
        payloadBytes, result, error
    },
    bytes = Normal[buffer];
    prefix = ToCharacterCode["GAPLINK:" <> token <> ":", "ASCII"];
    positions = SequencePosition[bytes, prefix, 1];
    If[positions === {}, Return @ protocolIncompleteFrame[
        bytes,
        Length[bytes] - protocolPrefixOverlap[bytes, prefix]
    ]];

    start = positions[[1, 1]];
    position = positions[[1, 2]] + 1;
    fieldsResult = protocolFrameFields[bytes, position];
    If[MissingQ[fieldsResult],
        Return[protocolIncompleteFrame[bytes, start - 1]]
    ];
    If[FailureQ[fieldsResult], Return[fieldsResult]];
    {fields, position} = fieldsResult;

    version = protocolUnsignedData[fields[[1]], "InvalidHeader"];
    frameID = protocolUnsignedData[fields[[3]], "InvalidHeader"];
    payloadLength = protocolUnsignedData[fields[[4]], "InvalidHeader"];
    If[AnyTrue[{version, frameID, payloadLength}, FailureQ],
        Return[protocolFailure["InvalidHeader"]]
    ];
    frameChannel = FromCharacterCode[fields[[2]]];

    error = protocolFrameError[
        channel, requestID, version, frameChannel, frameID, payloadLength
    ];
    If[StringQ[error], Return[protocolFailure[error]]];

    payloadEnd = position + payloadLength - 1;
    If[payloadEnd > Length[bytes],
        Return[protocolIncompleteFrame[bytes, start - 1]]
    ];
    payloadBytes = If[payloadLength === 0,
        {},
        Take[bytes, {position, payloadEnd}]
    ];

    result = <|
        "Status" -> "Complete",
        "Output" -> ByteArray[Take[bytes, start - 1]],
        "Channel" -> channel,
        "RequestID" -> requestID,
        "Rest" -> ByteArray[Drop[bytes, payloadEnd]]
    |>;
    If[channel === "ErrorEnd", Return[result]];

    If[!AllTrue[payloadBytes, # <= 127 &],
        Return[protocolFailure["InvalidPayload"]]
    ];
    protocolApply[
        gapLinkProtocolDecodeValue[FromCharacterCode[payloadBytes]],
        Append[result, "Payload" -> #] &
    ]
]

gapLinkProtocolReadFrame[___] := protocolFailure["InvalidFrame"]
