(* ::Package:: *)

PackageImport["PacletTools`"]

(* ::Section:: *)
(*PackageExported*)

PackageExported[VerifyBuild];

(* ::Section:: *)
(*Usage Messages*)

VerifyBuild::usage = "VerifyBuild[] loads the built paclet in a temporary directory.";

(* ::Section:: *)
(*Function Definitions*)

archives[] := If[
    DirectoryQ[$BuildDirectory],
    FileNames[$ArchivePrefix ~~ "-" ~~ __ ~~ ".paclet", $BuildDirectory],
    {}
];

extract[archive_String] := Module[{root = CreateDirectory[], files, directory},
    files = ExtractArchive[archive, root];
    directory = If[
        ListQ[files] && files =!= {},
        SelectFirst[FileNames[All, root], DirectoryQ, $Failed],
        $Failed
    ];
    If[directory === $Failed,
        DeleteDirectory[root, DeleteContents -> True];
        $Failed,
        {directory, root}
    ]
];

verify[] := RunTask @ Module[
    {source, archive, found, extraction, directory, root, paclet, context, expected, loaded, result},
    source = PacletObject[File[$PacletDirectory]];
    RequireOrLog[
        source,
        PacletObjectQ,
        "cannot read source paclet in ", RepositoryPath[$PacletDirectory]
    ];
    archive = ArchivePath[source["Version"]];
    found = archives[];
    RequireOrLog[
        FileExistsQ[archive],
        TrueQ,
        "no ", RepositoryPath[archive], "; run make build first",
        If[
            found === {},
            "",
            " (found: " <> StringRiffle[RepositoryPath /@ found, ", "] <> ")"
        ]
    ];
    LogInfo[
        "  archive: ", RepositoryPath[archive],
        " (", FileByteCount[archive], " bytes)"
    ];
    extraction = extract[archive];
    RequireOrLog[
        extraction,
        MatchQ[{_String, _String}],
        "cannot extract ", RepositoryPath[archive]
    ];
    {directory, root} = extraction;
    WithCleanup[
        RequireOrLog[
            PacletValidate[directory],
            TrueQ,
            "archive content does not validate as a paclet: ", directory
        ];
        paclet = PacletObject[File[directory]];
        context = paclet["PrimaryContext"];
        expected = paclet["Version"];
        PacletDirectoryLoad[directory];
        result = Check[Needs[context], $Failed];
        RequireOrLog[
            result,
            # =!= $Failed &,
            "Needs[\"", context, "\"] generated messages: ", $MessageList
        ];
        RequireOrLog[
            MemberQ[$Packages, context],
            TrueQ,
            "built paclet did not create context ", context
        ];
        loaded = PacletObject[$PacletName];
        If[!PacletObjectQ[loaded] || loaded["Version"] =!= expected,
            LogError[
                "loaded paclet is ", loaded,
                " but the archive version is ", expected
            ]
        ];
        LogInfo[
            "  loaded ", context, " ", expected,
            " from the extracted archive; ",
            Length[Names[context <> "*"]], " exported symbol(s)"
        ],
        If[DirectoryQ[root], DeleteDirectory[root, DeleteContents -> True]]
    ]
];

VerifyBuild[] := LogGroup["Verify built archive", verify[]];
