Needs["WolframInstitute`GAPLink`"];

{encodeValue, decodeValue, encodeFrame, readFrame, objectReference} =
    Symbol["WolframInstitute`GAPLink`PackageScope`" <> #] & /@ {
        "gapLinkProtocolEncodeValue", "gapLinkProtocolDecodeValue",
        "gapLinkProtocolEncodeFrame", "gapLinkProtocolReadFrame",
        "gapLinkProtocolObjectReference"
    };

token = "0123456789abcdef0123456789abcdef";
otherToken = "fedcba9876543210fedcba9876543210";
asciiBytes[text_String] := ByteArray[ToCharacterCode[text, "ASCII"]];
makeFrame[channel_, id_, payload___] := encodeFrame[channel, token, id, payload];
read[channel_, bytes_, id_] := readFrame[channel, bytes, token, id];
joinBytes[parts__ByteArray] := ByteArray[Join @@ (Normal /@ {parts})];

VerificationTest[
    encodeValue /@ {
        42,
        1/3,
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
            -7/11,
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
        And @@ (SameQ[decodeValue[encodeValue[#]], #] & /@ values)
    ],
    True,
    TestID -> "Roundtrip-Supported-Values"
]

VerificationTest[
    encodeValue[<|"z" -> 1, "a" -> 2|>] ===
        encodeValue[<|"a" -> 2, "z" -> 1|>],
    True,
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
    Module[{wrap},
        wrap[value_, count_] := Nest[
            "l" <> IntegerString[StringLength[#]] <> ":" <> # &,
            value,
            count
        ];
        {
            !FailureQ @ decodeValue @ wrap["n0:", 128],
            FailureQ @ decodeValue @ wrap["n0:", 129]
        }
    ],
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
        result = read["Response", buffer, 9];
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
    Module[{payload, frame, bytes, first, second},
        payload = <|"Result" -> {1, 2, 3}, "Status" -> "OK"|>;
        frame = makeFrame["Response", 11, payload];
        bytes = Normal[frame];
        And @@ Table[
            first = read["Response", ByteArray[Take[bytes, count]], 11];
            If[count === Length[bytes],
                first["Status"] === "Complete" && first["Payload"] === payload,
                second = read[
                    "Response",
                    joinBytes[first["Buffer"], ByteArray[Drop[bytes, count]]],
                    11
                ];
                first["Status"] === "Incomplete" &&
                    second["Status"] === "Complete" &&
                    second["Payload"] === payload
            ],
            {count, 0, Length[bytes]}
        ]
    ],
    True,
    TestID -> "Read-Split-Frame"
]

VerificationTest[
    Module[{result},
        result = read["Response", asciiBytes["textGAPLI"], 1];
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
        result = read["Response", buffer, 13];
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
        result = read["Response", buffer, 15];
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
        FailureQ[read["Response", frame, 17]]
    ],
    True,
    TestID -> "Reject-Protocol-Version"
]

VerificationTest[
    FailureQ @ read[
        "Response", makeFrame["Response", 19, <|"Result" -> 1|>], 20
    ],
    True,
    TestID -> "Reject-Request-ID"
]

VerificationTest[
    FailureQ @ read[
        "Response", makeFrame["Request", 21, <|"Operation" -> "Hello"|>], 21
    ],
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
        FailureQ @ read["Response", asciiBytes[#], 1] &
    ],
    True,
    TestID -> "Reject-Payload-Length"
]

VerificationTest[
    Module[{frame, buffer, result},
        frame = makeFrame["ErrorEnd", 23];
        buffer = joinBytes[asciiBytes["warning"], frame, asciiBytes["rest"]];
        result = read["ErrorEnd", buffer, 23];
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
