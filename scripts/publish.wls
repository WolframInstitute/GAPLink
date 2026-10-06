#!/usr/bin/env wolframscript

Get[FileNameJoin[{DirectoryName[$InputFileName], "common.wl"}]];
Get[FileNameJoin[{DirectoryName[$InputFileName], "publish.wl"}]];
Needs["PacletTools`"];

setting[name_String] := scriptRequire[
    Environment[name],
    StringQ[#] && StringTrim[#] =!= "" &,
    name, " is not set"
];

Module[
    {
        archive, archives, commit, paclet, page, pageFile,
        prefix, systems, urls, version
    },
    paclet = PacletObject[File[pacletDirectory]];
    scriptRequire[paclet, PacletObjectQ, "Cannot read source paclet"];
    version = paclet["Version"];
    systems = {
        "Linux-x86-64", "MacOSX-ARM64", "MacOSX-x86-64",
        "Windows-x86-64"
    };
    archives = FileNames["*.paclet", buildDirectory];
    archives = Table[
        archive = Select[
            archives,
            FileNameTake[#] === StringRiffle[
                {archivePrefix, system, version}, "-"
            ] <> ".paclet" &
        ];
        scriptRequire[
            archive,
            Length[#] === 1 &,
            "Expected one paclet for ", system
        ];
        First[archive],
        {system, systems}
    ];

    scriptRequire[
        Quiet @ Check[
            CloudConnect[
                setting["WOLFRAM_CLOUD_USER"],
                setting["WOLFRAM_CLOUD_PASSWORD"]
            ],
            $Failed
        ],
        # =!= $Failed &,
        "Could not connect to Wolfram Cloud"
    ];
    scriptRequire[$CloudConnected, TrueQ, "Could not connect to Wolfram Cloud"];

    commit = setting["RELEASE_COMMIT"];
    urls = MapThread[
        Function[{file, system},
            publishCloudFile[file,
                FileNameJoin[{
                    "GAPLink", archivePrefix <> "-" <> system <> ".paclet"
                }],
                <|
                    "Commit" -> commit,
                    "SHA256" -> IntegerString[FileHash[file, "SHA256"], 16, 64],
                    "Version" -> version,
                    "SystemID" -> system
                |>,
                "application/zip"
            ]
        ],
        {archives, systems}
    ];
    pageFile = FileNameJoin[{scriptDirectory, "resource-page.html"}];
    scriptRequire[pageFile, FileExistsQ, "Resource page was not found"];
    page = publishCloudFile[pageFile,
        FileNameJoin[{"DeployedResources", "Paclet", "WolframInstitute", "GAPLink"}],
        <|"Commit" -> commit, "Version" -> version|>,
        "text/html"
    ];
    prefix = StringReplace[
        First[urls],
        systems[[1]] <> ".paclet" ~~ EndOfString -> ""
    ];
    writeGitHubOutput[
        "archives" -> Length[urls],
        "prefix" -> prefix,
        "page" -> page
    ];
    Scan[Print["OK: ", #] &, urls];
    Print["OK: ", page];
    Print[
        "Install with PacletInstall[\"", prefix,
        "\" <> $SystemID <> \".paclet\"]"
    ]
]
