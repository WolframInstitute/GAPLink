(* ::Package:: *)

PackageImport["PacletTools`"]

(* ::Section:: *)
(*PackageExported*)

PackageExported[BuildPaclet];

(* ::Section:: *)
(*Usage Messages*)

BuildPaclet::usage = "BuildPaclet[] builds the paclet archive.";

(* ::Section:: *)
(*Function Definitions*)

cleanPreviousOutputs[] := Scan[
    Function[file,
        LogInfo["  removing ", RepositoryPath[file]];
        If[
            DirectoryQ[file],
            DeleteDirectory[file, DeleteContents -> True],
            DeleteFile[file]
        ]
    ],
    If[DirectoryQ[$BuildDirectory], FileNames[$ArchivePrefix ~~ ___, $BuildDirectory], {}]
];

build[] := RunTask @ Module[{paclet, result, archive, directory},
    RequireOrLog[CheckPacletInfoFile[], TrueQ];
    RequireOrLog[
        PacletValidate[$PacletDirectory],
        TrueQ,
        "PacletValidate failed for ", RepositoryPath[$PacletDirectory]
    ];
    paclet = PacletObject[File[$PacletDirectory]];
    RequireOrLog[paclet, PacletObjectQ, "cannot read source paclet"];
    LogInfo["  building ", paclet["Name"], " ", paclet["Version"]];
    cleanPreviousOutputs[];
    result = PacletBuild[$PacletDirectory, $BuildDirectory];
    RequireOrLog[result, MatchQ[_Success], "PacletBuild failed: ", result];
    archive = result["PacletArchive"];
    directory = Replace[result["BuildPacletDirectory"], File[path_] :> path];
    RequireOrLog[
        archive,
        Function[path, StringQ[path] && FileExistsQ[path]],
        "PacletBuild did not produce an archive"
    ];
    If[PacletValidate[directory] =!= True,
        LogError["built paclet directory does not validate: ", directory]
    ];
    LogInfo[
        "  archive: ", RepositoryPath[archive],
        " (", FileByteCount[archive], " bytes)"
    ];
    WriteGitHubOutput[
        "paclet" -> archive,
        "version" -> paclet["Version"],
        "name" -> paclet["Name"]
    ];
    AppendStepSummary @ StringJoin[
        "### Paclet build\n\n| Name | Version | Archive | Size |\n|---|---|---|---:|\n| ",
        paclet["Name"], " | ", paclet["Version"], " | `",
        RepositoryPath[archive], "` | ", ToString[FileByteCount[archive]], " bytes |"
    ]
];

BuildPaclet[] := LogGroup["Build", build[]];
