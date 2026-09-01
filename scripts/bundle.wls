#!/usr/bin/env wolframscript

Get[FileNameJoin[{DirectoryName[$InputFileName], "common.wl"}]];
Needs["PacletTools`"];

Module[
    {
        archive, archiveRoot, builtDirectory, executable, extensions,
        info, output, paclet, result, runtime, runtimeTarget, stage,
        systemID, systems, zip
    },
    systemID = Replace[Environment["GAPLINK_SYSTEM_ID"], Except[_String] | "" :> $SystemID];
    systems = {
        "Linux-x86-64", "MacOSX-ARM64", "MacOSX-x86-64",
        "Windows-x86-64"
    };
    scriptRequire[systemID, MemberQ[systems, #] &, "Unsupported system: ", systemID];
    runtime = Replace[
        Environment["GAPLINK_RUNTIME"],
        Except[_String] | "" :> FileNameJoin[{
            buildDirectory, "runtimes", systemID, "runtime"
        }]
    ];
    scriptRequire[runtime, DirectoryQ, "GAP runtime not found: ", runtime];
    runtime = ExpandFileName[runtime];
    executable = If[StringStartsQ[systemID, "Windows"], "gap.bat", "gap"];
    scriptRequire[
        FileNameJoin[{runtime, executable}],
        FileExistsQ,
        "Runtime executable not found: ", executable
    ];

    stage = FileNameJoin[{buildDirectory, "staging", systemID}];
    If[DirectoryQ[stage], DeleteDirectory[stage, DeleteContents -> True]];
    If[!DirectoryQ[DirectoryName[stage]],
        CreateDirectory[DirectoryName[stage], CreateIntermediateDirectories -> True]
    ];
    CopyDirectory[pacletDirectory, stage];
    runtimeTarget = FileNameJoin[{stage, "Resources", "Runtime"}];
    If[DirectoryQ[runtimeTarget], DeleteDirectory[runtimeTarget, DeleteContents -> True]];
    CopyDirectory[runtime, runtimeTarget];

    paclet = PacletObject[File[stage]];
    scriptRequire[paclet, PacletObjectQ, "Cannot read staged paclet"];
    info = KeyDrop[First[paclet], "Location"];
    extensions = Append[
        info["Extensions"],
        {
            "Asset", "Root" -> "Resources",
            "Assets" -> {{"GAPRuntime", "Runtime"}}
        }
    ];
    info = Join[
        info,
        <|
            "Qualifier" -> systemID,
            "SystemID" -> systemID,
            "Extensions" -> extensions
        |>
    ];
    Put[PacletObject[info], FileNameJoin[{stage, "PacletInfo.wl"}]];
    scriptRequire[PacletValidate[stage], TrueQ, "Staged paclet does not validate"];

    output = FileNameJoin[{buildDirectory, "bundles", systemID}];
    If[DirectoryQ[output], DeleteDirectory[output, DeleteContents -> True]];
    CreateDirectory[output, CreateIntermediateDirectories -> True];
    result = PacletBuild[stage, output];
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
    scriptRequire[archive, FileExistsQ, "Archive was not created"];
    scriptRequire[builtDirectory, DirectoryQ, "Built paclet was not created"];

    archiveRoot = FileNameJoin[{output, FileBaseName[archive]}];
    RenameDirectory[builtDirectory, archiveRoot];
    DeleteFile[archive];
    zip = Quiet @ Check[
        RunProcess[
            {
                "zip", "-q", "-r", "-y", "-X", FileNameTake[archive],
                FileNameTake[archiveRoot]
            },
            ProcessDirectory -> output
        ],
        $Failed
    ];
    scriptRequire[
        zip,
        AssociationQ[#] && #["ExitCode"] === 0 &,
        "Could not create the archive with zip"
    ];
    scriptRequire[archive, FileExistsQ, "Archive was not created"];
    Print["OK: ", archive]
]
