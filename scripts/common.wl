scriptDirectory = DirectoryName[$InputFileName];
repositoryRoot = ParentDirectory[scriptDirectory];
pacletDirectory = FileNameJoin[{repositoryRoot, "GAPLink"}];
buildDirectory = FileNameJoin[{repositoryRoot, "build"}];
pacletName = "WolframInstitute/GAPLink";
archivePrefix = StringReplace[pacletName, "/" -> "__"];

scriptFail[parts___] := (Print["ERROR: ", parts]; Exit[1]);

scriptRequire[value_, test_, parts___] :=
    If[TrueQ[test[value]], value, scriptFail[parts]];

archivePath[version_String] := FileNameJoin[{
    buildDirectory,
    archivePrefix <> "-" <> version <> ".paclet"
}];

loadSource[] := Module[{paclet, context, result},
    paclet = Quiet @ Check[PacletObject[File[pacletDirectory]], $Failed];
    scriptRequire[paclet, PacletObjectQ, "Cannot read ", pacletDirectory];
    PacletDirectoryLoad[pacletDirectory];
    context = paclet["PrimaryContext"];
    result = Check[Needs[context], $Failed];
    scriptRequire[result, # =!= $Failed &, "Cannot load ", context];
    paclet
];

runTests[files_List] := Module[{reports, passed, failed, runtimeFailures},
    If[files === {}, scriptFail["No test files found"]];
    reports = Table[
        With[{report = TestReport[file]},
            scriptRequire[
                report,
                Head[#] === TestReportObject &,
                "Could not run ", file
            ];
            Print[
                "  ", FileNameTake[file], ": ",
                report["TestsSucceededCount"], "/",
                report["TestsSucceededCount"] + report["TestsFailedCount"]
            ];
            report
        ],
        {file, files}
    ];
    passed = Total[#["TestsSucceededCount"] & /@ reports];
    failed = Total[#["TestsFailedCount"] & /@ reports];
    runtimeFailures = Total[Length[#["RuntimeFailures"]] & /@ reports];
    If[failed + runtimeFailures > 0,
        Scan[
            Function[report,
                Scan[
                    If[#["Outcome"] =!= "Success", Print["FAIL: ", #["TestID"]]] &,
                    Values[report["TestResults"]]
                ]
            ],
            reports
        ];
        scriptFail[failed, " failed test(s), ", runtimeFailures, " runtime failure(s)"]
    ];
    Print["OK: ", passed, " tests passed"]
];

lintFiles[files_List] := Module[{issueCount = 0, issues, errors},
    Needs["CodeInspector`"];
    Scan[
        Function[file,
            If[!FileExistsQ[file], scriptFail["File not found: ", file]];
            issues = Quiet @ Check[CodeInspector`CodeInspect[File[file]], $Failed];
            scriptRequire[issues, ListQ, "Could not inspect ", file];
            errors = Cases[
                issues,
                CodeInspector`InspectionObject[_, _, "Fatal" | "Error", _]
            ];
            Scan[Print["ERROR: ", file, ": ", #] &, errors];
            issueCount += Length[errors]
        ],
        files
    ];
    If[issueCount > 0, scriptFail[issueCount, " lint error(s)"]]
];

writeGitHubOutput[rules__Rule] := Module[{file, stream},
    file = Environment["GITHUB_OUTPUT"];
    If[!StringQ[file], Return[Null]];
    stream = OpenAppend[file];
    WriteString[
        stream,
        StringRiffle[(First[#] <> "=" <> ToString[Last[#]]) & /@ {rules}, "\n"],
        "\n"
    ];
    Close[stream]
];
