#!/usr/bin/env wolframscript

Get[FileNameJoin[{DirectoryName[$InputFileName], "common.wl"}]];
Needs["PacletTools`"];

Module[
    {
        archive, archiveRoot, base, executable, files, info, manifest,
        output, paclet, runtime, runtimeTarget, systemID, systems, zip
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

    base = FileNameJoin[{buildDirectory, archivePrefix}];
    scriptRequire[base, DirectoryQ, "Run make build first"];
    paclet = PacletObject[File[base]];
    scriptRequire[paclet, PacletObjectQ, "Cannot read built paclet"];
    info = KeyDrop[First[paclet], "Location"];
    info = Join[
        info,
        <|
            "Qualifier" -> systemID,
            "SystemID" -> systemID,
            "Extensions" -> Append[
                info["Extensions"],
                {
                    "Asset", "Root" -> "Resources",
                    "Assets" -> {{"GAPRuntime", "Runtime"}}
                }
            ]
        |>
    ];

    output = FileNameJoin[{buildDirectory, "bundles", systemID}];
    If[DirectoryQ[output], DeleteDirectory[output, DeleteContents -> True]];
    CreateDirectory[output, CreateIntermediateDirectories -> True];
    archive = FileNameJoin[{
        output,
        StringRiffle[{archivePrefix, systemID, paclet["Version"]}, "-"] <> ".paclet"
    }];
    archiveRoot = FileNameJoin[{output, FileBaseName[archive]}];
    CopyDirectory[base, archiveRoot];
    runtimeTarget = FileNameJoin[{archiveRoot, "Resources", "Runtime"}];
    CopyDirectory[runtime, runtimeTarget];
    Put[PacletObject[info], FileNameJoin[{archiveRoot, "PacletInfo.wl"}]];

    files = PacletExtensionFiles[
        File[archiveRoot],
        "Relative" -> True,
        SystemID -> All
    ];
    scriptRequire[files, AssociationQ, "Cannot list paclet files"];
    files = DeleteDuplicates @ Flatten @ DeleteMissing @ Values[files];
    manifest = <|"Files" -> Map[
        <|
            "File" -> File[#],
            "Hash" -> FileHash[
                FileNameJoin[{archiveRoot, #}],
                "SHA256",
                "HexString"
            ]
        |> &,
        files
    ]|>;
    Put[manifest, FileNameJoin[{archiveRoot, "PacletManifest.wl"}]];
    scriptRequire[
        PacletValidate[archiveRoot],
        TrueQ,
        "Platform paclet does not validate"
    ];
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
