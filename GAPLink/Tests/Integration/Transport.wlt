Needs["WolframInstitute`GAPLink`"];

gapExecutable = Replace[
    Quiet @ Environment["GAPLINK_GAP"],
    {path_String /; path =!= "" :> path, _ -> Automatic}
];

VerificationTest[
    Module[{captured, session, text = StringRepeat["GAP \[Lambda] ", 10000]},
        session = StartGAPSession["Executable" -> gapExecutable];
        If[FailureQ[session], Return[False]];
        WithCleanup[
            captured = GAPEvaluate[
                session,
                "WriteAll(OutputTextUser(), ListWithIdenticalEntries(200000, 'x')); " <>
                    "WriteAll(OutputTextFile(\"*errout*\", false), ListWithIdenticalEntries(200000, 'e')); 42;",
                "Output" -> "Capture"
            ];
            captured === <|
                "Result" -> 42,
                "StandardOutput" -> StringRepeat["x", 200000],
                "StandardError" -> StringRepeat["e", 200000]
            |> &&
                GAPCall[session, "IdFunc", text] === text &&
                GAPCall[session, "Sum", {1, 2, 3}] === 6,
            DeleteObject[session]
        ]
    ],
    True,
    TestID -> "Read-Large-Output-And-Unicode-Reply"
]
