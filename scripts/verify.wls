#!/usr/bin/env wolframscript

Get[FileNameJoin[{DirectoryName[$InputFileName], "common.wl"}]];
Needs["PacletTools`"];

Module[
    {source, archive, root, directory, paclet, context, result, loaded},
    source = PacletObject[File[pacletDirectory]];
    scriptRequire[source, PacletObjectQ, "Cannot read source paclet"];
    archive = archivePath[source["Version"]];
    If[!FileExistsQ[archive], scriptFail["Run make build first"]];

    root = CreateDirectory[];
    WithCleanup[
        ExtractArchive[archive, root];
        directory = SelectFirst[FileNames[All, root], DirectoryQ, $Failed];
        scriptRequire[directory, StringQ, "Could not extract archive"];
        scriptRequire[
            PacletValidate[directory],
            TrueQ,
            "Archive does not contain a valid paclet"
        ];

        paclet = PacletObject[File[directory]];
        context = paclet["PrimaryContext"];
        PacletDirectoryLoad[directory];
        result = Check[Needs[context], $Failed];
        scriptRequire[result, # =!= $Failed &, "Could not load built paclet"];
        loaded = PacletObject[pacletName];
        If[
            !PacletObjectQ[loaded] || loaded["Version"] =!= source["Version"],
            scriptFail["Loaded paclet does not match the archive"]
        ];
        Print["OK: loaded ", context, " ", loaded["Version"]],
        If[DirectoryQ[root], DeleteDirectory[root, DeleteContents -> True]]
    ]
]
