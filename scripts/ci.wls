#!/usr/bin/env wolframscript

Needs["DocumentationBuild`Utils`"];

DocumentationBuild`Utils`SafeNotebookExport =
    Function[{file, notebook, timeout},
        TimeConstrained[
            Quiet @ CheckAbort[
                Check[Export[file, notebook, "NB"]; "Success", $Failed],
                $Failed
            ],
            timeout,
            $Failed
        ]
    ];

Module[
    {bundle, directory, gapRoot, root, runGAP, runtimeRoot, systems, testGAP,
        versions},
    directory = DirectoryName @ ExpandFileName[$InputFileName];
    root = ParentDirectory[directory];
    gapRoot = FileNameJoin[{root, "build", "gap-versions"}];
    runtimeRoot = FileNameJoin[{root, "build", "ci-runtimes"}];
    systems = {
        "Linux-x86-64", "MacOSX-ARM64", "MacOSX-x86-64",
        "Windows-x86-64"
    };
    testGAP = FileNameJoin[{directory, "test-gap.wls"}];

    runGAP[path_, version_] := (
        Print["Testing GAP ", version, "..."];
        SetEnvironment["GAPLINK_GAP" -> path];
        SetEnvironment["GAPLINK_EXPECTED_GAP_VERSION" -> version];
        Get[testGAP]
    );
    bundle[system_] := (
        Print["Building ", system, " paclet..."];
        SetEnvironment[
            "GAPLINK_RUNTIME" -> FileNameJoin[{runtimeRoot, system, "runtime"}]
        ];
        SetEnvironment["GAPLINK_SYSTEM_ID" -> system];
        Get[FileNameJoin[{directory, "bundle.wls"}]]
    );

    Print["Wolfram Engine ", $Version, " | license type: ", $LicenseType];
    Print["Building base paclet..."];
    Get[FileNameJoin[{directory, "build.wls"}]];
    Get[FileNameJoin[{directory, "verify.wls"}]];
    Get[FileNameJoin[{directory, "check.wl"}]];
    runCheck[];
    Get[FileNameJoin[{directory, "test.wls"}]];
    versions = Sort[FileNameTake /@ Select[FileNames[All, gapRoot], DirectoryQ]];
    scriptRequire[versions, # =!= {} &, "No GAP versions found"];
    Scan[runGAP[FileNameJoin[{gapRoot, #, "gap"}], #] &, versions];
    Scan[bundle, systems];

    Print["Testing bundled GAP..."];
    SetEnvironment["GAPLINK_VERIFY_INSTALL" -> "1"];
    SetEnvironment["GAPLINK_EXPECTED_GAP_VERSION" -> Last[versions]];
    Get[FileNameJoin[{directory, "verify-bundle.wls"}]];
    runGAP[
        FileNameJoin[{runtimeRoot, First[systems], "runtime", "gap"}],
        Last[versions]
    ]
]
