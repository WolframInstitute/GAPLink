#!/usr/bin/env wolframscript

Get[FileNameJoin[{DirectoryName[$InputFileName], "common.wl"}]];

Module[{files, reports, passed, failed, runtimeFailures},
    loadSource[];
    files = FileNames["*.wlt", FileNameJoin[{pacletDirectory, "Tests"}], Infinity];
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
                    Function[result,
                        If[result["Outcome"] =!= "Success",
                            Print["FAIL: ", result["TestID"]]
                        ]
                    ],
                    Values[report["TestResults"]]
                ]
            ],
            reports
        ];
        scriptFail[failed, " failed test(s), ", runtimeFailures, " runtime failure(s)"]
    ];

    Print["OK: ", passed, " tests passed"]
]
