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
$protocolFrameCodes = <|
    "Request" -> "Q",
    "Response" -> "R",
    "ErrorEnd" -> "E"
|>;


protocolFailure[reason_String] := Failure[
    "GAPProtocolError",
    <|
        "MessageTemplate" -> "The GAP protocol data is not valid.",
        "MessageParameters" -> <||>,
        "Reason" -> reason
    |>
]


unsupportedValue[value_] := Failure[
    "GAPUnsupportedValue",
    <|
        "MessageTemplate" -> "The value cannot be sent to GAP.",
        "MessageParameters" -> <||>,
        "Type" -> ToString[Head[value], InputForm]
    |>
]


protocolTokenQ[token_] := StringQ[token] && StringMatchQ[
    token,
    RegularExpression["[0-9a-f]{32}"]
]


protocolIDQ[id_] := IntegerQ[id] && 1 <= id <= $protocolMaxID


protocolASCIIQ[text_String] := AllTrue[ToCharacterCode[text], # <= 127 &]


protocolNode[tag_String, data_String] := Module[{node},
    node = tag <> IntegerString[StringLength[data]] <> ":" <> data;
    If[StringLength[node] <= $protocolMaxPayloadBytes,
        node,
        protocolFailure["ValueTooLarge"]
    ]
]


protocolHex[bytes_List] := StringJoin[IntegerString[#, 16, 2] & /@ bytes]


protocolSortKeys[keys_List] := SortBy[keys, ToCharacterCode[#, "UTF-8"] &]


protocolIntegerString[value_Integer] := If[
    Negative[value],
    "-" <> IntegerString[-value],
    IntegerString[value]
]


protocolEncodeParts[values_List, depth_Integer] := Module[{parts, failure},
    parts = protocolEncodeNode[#, depth + 1] & /@ values;
    failure = SelectFirst[parts, FailureQ, Missing["NotFound"]];
    If[FailureQ[failure], failure, StringJoin[parts]]
]


protocolMachineRealParts[value_Real] := Module[
    {exact, numerator, denominator, numeratorTwos, denominatorTwos, mantissa},
    exact = SetPrecision[value, Infinity];
    If[exact === 0, Return[{0, 0}]];

    numerator = Numerator[exact];
    denominator = Denominator[exact];
    denominatorTwos = IntegerExponent[denominator, 2];
    If[denominator =!= 2^denominatorTwos,
        Return[protocolFailure["InvalidMachineReal"]]
    ];

    numeratorTwos = IntegerExponent[Abs[numerator], 2];
    mantissa = Quotient[numerator, 2^numeratorTwos];
    {
        mantissa,
        IntegerLength[Abs[mantissa], 2] + numeratorTwos - denominatorTwos
    }
]


protocolEncodeRecord[value_Association, depth_Integer] := Module[
    {keys, parts, failure},
    keys = Keys[value];
    If[!AllTrue[keys, StringQ], Return[unsupportedValue[value]]];
    keys = protocolSortKeys[keys];
    parts = Flatten[
        {protocolEncodeNode[#, depth + 1], protocolEncodeNode[value[#], depth + 1]} & /@ keys,
        1
    ];
    failure = SelectFirst[parts, FailureQ, Missing["NotFound"]];
    If[FailureQ[failure], failure, protocolNode["r", StringJoin[parts]]]
]


protocolEncodePermutation[value_Cycles, depth_Integer] := Module[{images, data},
    images = Quiet @ Check[PermutationList[value], $Failed];
    If[!ListQ[images] || !PermutationListQ[images],
        Return[unsupportedValue[value]]
    ];
    data = protocolEncodeParts[images, depth];
    If[FailureQ[data], data, protocolNode["p", data]]
]


protocolEncodeNode[value_, depth_Integer] := Module[
    {data, parts, numerator, denominator, id},
    If[depth > $protocolMaxDepth, Return[protocolFailure["ValueTooDeep"]]];

    Which[
        IntegerQ[value],
            protocolNode["i", protocolIntegerString[value]],

        Head[value] === Rational,
            numerator = Numerator[value];
            denominator = Denominator[value];
            data = protocolEncodeParts[{numerator, denominator}, depth];
            If[FailureQ[data], data, protocolNode["q", data]],

        value === True,
            protocolNode["t", ""],

        value === False,
            protocolNode["f", ""],

        value === Null,
            protocolNode["n", ""],

        value === Missing["GAPFail"],
            protocolNode["x", ""],

        Head[value] === Real && Precision[value] === MachinePrecision,
            parts = protocolMachineRealParts[value];
            If[FailureQ[parts],
                parts,
                data = protocolEncodeParts[parts, depth];
                If[FailureQ[data], data, protocolNode["d", data]]
            ],

        StringQ[value],
            protocolNode["s", protocolHex[ToCharacterCode[value, "UTF-8"]]],

        Head[value] === ByteArray,
            protocolNode["b", protocolHex[Normal[value]]],

        Head[value] === Cycles,
            protocolEncodePermutation[value, depth],

        ListQ[value],
            data = protocolEncodeParts[value, depth];
            If[FailureQ[data], data, protocolNode["l", data]],

        AssociationQ[value],
            protocolEncodeRecord[value, depth],

        MatchQ[value, gapLinkProtocolObjectReference[_Integer]],
            id = value[[1]];
            If[protocolIDQ[id],
                protocolNode["o", IntegerString[id]],
                unsupportedValue[value]
            ],

        True,
            unsupportedValue[value]
    ]
]


gapLinkProtocolEncodeValue[value_] := protocolEncodeNode[value, 0]


protocolDigitQ[byte_Integer] := 48 <= byte <= 57


protocolIntegerData[data_List] := Module[{text, sign, digits},
    If[data === {} || !AllTrue[data, protocolDigitQ[#] &] && !(
        First[data] === 45 && Length[data] > 1 &&
        AllTrue[Rest[data], protocolDigitQ[#] &]
    ),
        Return[protocolFailure["InvalidInteger"]]
    ];

    text = FromCharacterCode[data];
    If[text === "-0" || (StringLength[text] > 1 && StringStartsQ[text, "0"]) ||
        (StringLength[text] > 2 && StringStartsQ[text, "-0"]),
        Return[protocolFailure["InvalidInteger"]]
    ];

    sign = If[First[data] === 45, -1, 1];
    digits = If[sign === -1, Rest[data], data];
    sign * FromDigits[digits - 48]
]


protocolHexData[data_List] := Module[{nibbles},
    If[OddQ[Length[data]] || !AllTrue[
        data,
        (48 <= # <= 57 || 97 <= # <= 102) &
    ],
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


protocolDecodeChildren[
    bytes_List,
    start_Integer,
    end_Integer,
    depth_Integer
] := Module[{position = start, result, harvested},
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


protocolObjectValue[data_List] := Module[{id},
    id = protocolIntegerData[data];
    If[FailureQ[id], Return[id]];
    If[protocolIDQ[id],
        gapLinkProtocolObjectReference[id],
        protocolFailure["InvalidObject"]
    ]
]


protocolDecodeNode[
    bytes_List,
    start_Integer,
    limit_Integer,
    depth_Integer
] := Module[
    {
        tag, position, digitStart, dataLength = 0, dataStart, dataEnd,
        data, parts, value
    },
    If[depth > $protocolMaxDepth, Return[protocolFailure["ValueTooDeep"]]];
    If[start > limit, Return[protocolFailure["MissingValue"]]];

    tag = bytes[[start]];
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
    If[!MemberQ[{113, 100, 112, 108, 114}, tag],
        data = If[dataLength === 0, {}, Take[bytes, {dataStart, dataEnd}]]
    ];

    value = Switch[tag,
        105,
            protocolIntegerData[data],
        113,
            parts = protocolDecodeChildren[bytes, dataStart, dataEnd, depth];
            If[FailureQ[parts], parts, protocolRationalValue[parts]],
        116,
            If[data === {}, True, protocolFailure["InvalidTrue"]],
        102,
            If[data === {}, False, protocolFailure["InvalidFalse"]],
        110,
            If[data === {}, Null, protocolFailure["InvalidNull"]],
        120,
            If[data === {}, Missing["GAPFail"], protocolFailure["InvalidFail"]],
        100,
            parts = protocolDecodeChildren[bytes, dataStart, dataEnd, depth];
            If[FailureQ[parts], parts, protocolMachineRealValue[parts]],
        115,
            protocolStringData[data],
        98,
            parts = protocolHexData[data];
            If[FailureQ[parts], parts, ByteArray[parts]],
        112,
            parts = protocolDecodeChildren[bytes, dataStart, dataEnd, depth];
            If[FailureQ[parts], parts, protocolPermutationValue[parts]],
        108,
            protocolDecodeChildren[bytes, dataStart, dataEnd, depth],
        114,
            parts = protocolDecodeChildren[bytes, dataStart, dataEnd, depth];
            If[FailureQ[parts], parts, protocolRecordValue[parts]],
        111,
            protocolObjectValue[data],
        _,
            protocolFailure["UnknownTag"]
    ];
    If[FailureQ[value], value, {value, dataEnd + 1}]
]


gapLinkProtocolDecodeValue[encoded_String] := Block[
    {$RecursionLimit = Max[$RecursionLimit, 4096]},
    Module[{codes, result},
        If[
            StringLength[encoded] > $protocolMaxPayloadBytes ||
                !protocolASCIIQ[encoded],
            Return[protocolFailure["InvalidValue"]]
        ];
        codes = ToCharacterCode[encoded];
        If[codes === {}, Return[protocolFailure["MissingValue"]]];
        result = protocolDecodeNode[codes, 1, Length[codes], 0];
        If[FailureQ[result],
            result,
            If[result[[2]] === Length[codes] + 1,
                result[[1]],
                protocolFailure["TrailingData"]
            ]
        ]
    ]
]


gapLinkProtocolDecodeValue[_] := protocolFailure["InvalidValue"]


protocolFrameHeader[
    token_String,
    kind_String,
    requestID_Integer,
    payloadLength_Integer
] := StringRiffle[
    {
        "GAPLINK",
        token,
        IntegerString[$protocolVersion],
        kind,
        IntegerString[requestID],
        IntegerString[payloadLength]
    },
    ":"
] <> ":"


protocolFrameBytes[text_String] := ByteArray[ToCharacterCode[text, "ASCII"]]


gapLinkProtocolEncodeFrame[
    channel : ("Request" | "Response"),
    token_String,
    requestID_Integer,
    payload_
] := Module[{encoded},
    If[!protocolTokenQ[token] || !protocolIDQ[requestID],
        Return[protocolFailure["InvalidFrame"]]
    ];
    encoded = gapLinkProtocolEncodeValue[payload];
    If[FailureQ[encoded], Return[encoded]];
    If[StringLength[encoded] > $protocolMaxPayloadBytes,
        Return[protocolFailure["PayloadTooLarge"]]
    ];
    protocolFrameBytes[
        protocolFrameHeader[
            token,
            $protocolFrameCodes[channel],
            requestID,
            StringLength[encoded]
        ] <> encoded
    ]
]


gapLinkProtocolEncodeFrame[
    "ErrorEnd",
    token_String,
    requestID_Integer
] := If[protocolTokenQ[token] && protocolIDQ[requestID],
    protocolFrameBytes[
        protocolFrameHeader[token, $protocolFrameCodes["ErrorEnd"], requestID, 0]
    ],
    protocolFailure["InvalidFrame"]
]


gapLinkProtocolEncodeFrame[___] := protocolFailure["InvalidFrame"]


protocolPrefixOverlap[bytes_List, prefix_List] := Module[
    {maximum, overlap = 0},
    maximum = Min[Length[bytes], Length[prefix] - 1];
    Do[
        If[Take[bytes, -count] === Take[prefix, count],
            overlap = count;
            Break[]
        ],
        {count, maximum, 1, -1}
    ];
    overlap
]


protocolFrameField[bytes_List, start_Integer, maximum_Integer] := Module[
    {end = start, count},
    While[end <= Length[bytes] && bytes[[end]] =!= 58, end++];
    If[end > Length[bytes],
        count = Length[bytes] - start + 1;
        Return[If[count <= maximum,
            Missing["Incomplete"],
            protocolFailure["InvalidHeader"]
        ]]
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


protocolUnsignedField[data_List] := Module[{value},
    If[data === {} || !AllTrue[data, protocolDigitQ[#] &] ||
        (Length[data] > 1 && First[data] === 48),
        Return[protocolFailure["InvalidHeader"]]
    ];
    value = FromDigits[data - 48];
    value
]


protocolIncompleteFrame[bytes_List, start_Integer] := <|
    "Status" -> "Incomplete",
    "Output" -> ByteArray[Take[bytes, start - 1]],
    "Buffer" -> ByteArray[Drop[bytes, start - 1]]
|>


protocolFrameWithoutMarker[bytes_List, prefix_List] := Module[{overlap, split},
    overlap = protocolPrefixOverlap[bytes, prefix];
    split = Length[bytes] - overlap;
    <|
        "Status" -> "Incomplete",
        "Output" -> ByteArray[Take[bytes, split]],
        "Buffer" -> ByteArray[Drop[bytes, split]]
    |>
]


gapLinkProtocolReadFrame[
    channel_String,
    buffer_ByteArray,
    token_String,
    requestID_Integer
] := Module[
    {
        bytes, prefix, positions, start, fieldsResult, fields, position,
        version, frameChannel, frameID, payloadLength, payloadEnd,
        payloadBytes, payload, result
    },
    If[!KeyExistsQ[$protocolFrameCodes, channel] || !protocolTokenQ[token] ||
        !protocolIDQ[requestID],
        Return[protocolFailure["InvalidFrame"]]
    ];

    bytes = Normal[buffer];
    prefix = ToCharacterCode["GAPLINK:" <> token <> ":", "ASCII"];
    positions = SequencePosition[bytes, prefix, 1];
    If[positions === {}, Return[protocolFrameWithoutMarker[bytes, prefix]]];

    start = positions[[1, 1]];
    position = positions[[1, 2]] + 1;
    fieldsResult = protocolFrameFields[bytes, position];
    If[MissingQ[fieldsResult], Return[protocolIncompleteFrame[bytes, start]]];
    If[FailureQ[fieldsResult], Return[fieldsResult]];
    {fields, position} = fieldsResult;

    version = protocolUnsignedField[fields[[1]]];
    frameID = protocolUnsignedField[fields[[3]]];
    payloadLength = protocolUnsignedField[fields[[4]]];
    If[AnyTrue[{version, frameID, payloadLength}, FailureQ],
        Return[protocolFailure["InvalidHeader"]]
    ];
    frameChannel = FromCharacterCode[fields[[2]]];

    If[version =!= $protocolVersion,
        Return[protocolFailure["UnsupportedVersion"]]
    ];
    If[frameChannel =!= $protocolFrameCodes[channel],
        Return[protocolFailure["WrongFrameKind"]]
    ];
    If[frameID =!= requestID,
        Return[protocolFailure["WrongRequestID"]]
    ];
    If[payloadLength > $protocolMaxPayloadBytes,
        Return[protocolFailure["PayloadTooLarge"]]
    ];
    If[channel === "ErrorEnd" && payloadLength =!= 0 ||
        channel =!= "ErrorEnd" && payloadLength === 0,
        Return[protocolFailure["InvalidPayloadLength"]]
    ];

    payloadEnd = position + payloadLength - 1;
    If[payloadEnd > Length[bytes],
        Return[protocolIncompleteFrame[bytes, start]]
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
    payload = gapLinkProtocolDecodeValue[FromCharacterCode[payloadBytes]];
    If[FailureQ[payload], payload, Append[result, "Payload" -> payload]]
]


gapLinkProtocolReadFrame[___] := protocolFailure["InvalidFrame"]
