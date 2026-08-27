(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[TestPaclet];

(* ::Section:: *)
(*Usage Messages*)

TestPaclet::usage = "TestPaclet[] runs the paclet tests.";

(* ::Section:: *)
(*Function Definitions*)

$testsDirectory := FileNameJoin[{$PacletDirectory, "Tests"}];

show[HoldForm[expr_]] := ToString[Unevaluated[expr], InputForm];
show[expr_] := ToString[expr, InputForm];

testResults[report_] := Replace[
    Replace[
        report["TestResults"],
        result_ /; !AssociationQ[result] && !ListQ[result] :> report["Results"]
    ],
    data_Association :> Values[data]
];

reportFailure[file_, result_] := LogError[
    <|"File" -> file|>,
    "test ", result["TestID"], " failed (", result["Outcome"], ")",
    "\n    input:    ", show[result["Input"]],
    "\n    expected: ", show[result["ExpectedOutput"]],
    "\n    actual:   ", show[result["ActualOutput"]],
    Replace[
        result["ActualMessages"],
        messages_List /; messages =!= {} :> "\n    messages: " <> show[messages],
        _ -> ""
    ]
];

runFile[file_] := RunTask @ Module[{time, report, results, failures, passed},
    {time, report} = AbsoluteTiming[TestReport[file]];
    RequireOrLog[
        report,
        Head[#] === TestReportObject &,
        <|"File" -> file|>,
        "TestReport did not return a report: ", report
    ];
    results = testResults[report];
    RequireOrLog[
        results,
        ListQ,
        <|"File" -> file|>,
        "cannot read test results: ", results
    ];
    RequireOrLog[
        results,
        # =!= {} &,
        <|"File" -> file|>,
        "no tests found in this file"
    ];
    failures = Select[results, #["Outcome"] =!= "Success" &];
    passed = Length[results] - Length[failures];
    If[Length[report["RuntimeFailures"]] > 0,
        LogError[<|"File" -> file|>, "runtime failures: ", report["RuntimeFailures"]]
    ];
    LogInfo[
        "  ", RepositoryPath[file], ": ", passed, "/", Length[results],
        " passed in ", Round[time, .01], " s"
    ];
    Scan[reportFailure[file, #] &, failures];
    {RepositoryPath[file], passed, Length[failures], Round[time, .01]}
];

summaryTable[rows_List] := StringJoin[
    "### Tests (", $Version, ")\n\n",
    "| File | Passed | Failed | Time (s) |\n|---|---:|---:|---:|\n",
    StringRiffle[
        StringJoin[
            "| `", #[[1]], "` | ", ToString[#[[2]]], " | ",
            ToString[#[[3]]], " | ", ToString[#[[4]]], " |"
        ] & /@ rows,
        "\n"
    ]
];

TestPaclet[] := RunTask @ Module[{paclet, files, rows, passed, failed},
    paclet = LogGroup["Load from source", LoadPaclet[]];
    RequireOrLog[paclet, PacletObjectQ];
    files = FileNames["*.wlt", $testsDirectory, Infinity];
    RequireOrLog[
        files,
        # =!= {} &,
        "no *.wlt files found in ", RepositoryPath[$testsDirectory]
    ];
    rows = DeleteCases[LogGroup["Tests", runFile /@ files], $Failed];
    {passed, failed} = Total @ Prepend[{#[[2]], #[[3]]} & /@ rows, {0, 0}];
    LogInfo["\n", passed, " passed, ", failed, " failed in ", Length[files], " file(s)"];
    AppendStepSummary[summaryTable[rows]]
];
