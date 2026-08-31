#!/usr/bin/env wolframscript

Get[FileNameJoin[{DirectoryName[$InputFileName], "common.wl"}]];
Needs["PacletTools`"];

Module[{paclet, oldOutputs, result, archive, builtDirectory},
    scriptRequire[
        PacletValidate[pacletDirectory],
        TrueQ,
        "PacletValidate failed"
    ];
    paclet = PacletObject[File[pacletDirectory]];

    If[!DirectoryQ[buildDirectory], CreateDirectory[buildDirectory]];
    oldOutputs = FileNames[archivePrefix ~~ ___, buildDirectory];
    Scan[
        If[
            DirectoryQ[#],
            DeleteDirectory[#, DeleteContents -> True],
            DeleteFile[#]
        ] &,
        oldOutputs
    ];

    result = PacletBuild[pacletDirectory, buildDirectory];
    scriptRequire[result, MatchQ[_Success], "PacletBuild failed"];
    scriptRequire[
        result["DocumentationBuildResults"],
        Function[results,
            results =!= {} && AllTrue[
                results,
                MatchQ[#, _Success] && TrueQ[#["FailedFilesCount"] === 0] &
            ]
        ],
        "Documentation build failed"
    ];
    archive = result["PacletArchive"];
    builtDirectory = Replace[result["BuildPacletDirectory"], File[path_] :> path];
    scriptRequire[
        FileExistsQ[archive],
        TrueQ,
        "PacletBuild did not create an archive"
    ];
    scriptRequire[
        PacletValidate[builtDirectory],
        TrueQ,
        "Built paclet does not validate"
    ];

    writeGitHubOutput[
        "paclet" -> archive,
        "version" -> paclet["Version"],
        "name" -> paclet["Name"]
    ];
    Print["OK: ", archive, " (", FileByteCount[archive], " bytes)"]
]
