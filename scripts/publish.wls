#!/usr/bin/env wolframscript

Get[FileNameJoin[{DirectoryName[$InputFileName], "common.wl"}]];
Needs["PacletTools`"];

setting[name_String] := scriptRequire[
    Environment[name],
    StringQ[#] && StringTrim[#] =!= "" &,
    name, " is not set"
];

Module[
    {
        archive, archives, commit, hash, latest, paclet, page, pageFile,
        prefix, result, systems, urls, version
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
            hash = IntegerString[FileHash[file, "SHA256"], 16, 64];
            latest = CloudObject[
                FileNameJoin[{
                    "GAPLink", archivePrefix <> "-" <> system <> ".paclet"
                }]
            ];
            result = Quiet @ Check[
                CopyFile[file, latest, OverwriteTarget -> True],
                $Failed
            ];
            scriptRequire[
                result,
                MatchQ[_CloudObject],
                "Could not upload paclet"
            ];
            scriptRequire[
                Quiet @ Check[
                    SetOptions[
                        result,
                        Permissions -> "Public",
                        MetaInformation -> <|
                            "Commit" -> commit,
                            "SHA256" -> hash,
                            "Version" -> version,
                            "SystemID" -> system
                        |>
                    ],
                    $Failed
                ],
                # =!= $Failed &,
                "Could not set cloud object options"
            ];
            First[result]
        ],
        {archives, systems}
    ];
    pageFile = FileNameJoin[{scriptDirectory, "resource-page.html"}];
    scriptRequire[pageFile, FileExistsQ, "Resource page was not found"];
    page = CloudObject[FileNameJoin[{
        "DeployedResources", "Paclet", "WolframInstitute", "GAPLink"
    }]];
    result = Quiet @ Check[
        CopyFile[
            pageFile, page, OverwriteTarget -> True, MIMEType -> "text/html"
        ],
        $Failed
    ];
    scriptRequire[result, MatchQ[_CloudObject], "Could not upload resource page"];
    scriptRequire[
        Quiet @ Check[
            SetOptions[
                result,
                Permissions -> "Public",
                MetaInformation -> <|"Commit" -> commit, "Version" -> version|>
            ],
            $Failed
        ],
        # =!= $Failed &,
        "Could not set resource page options"
    ];
    prefix = StringReplace[
        First[urls],
        systems[[1]] <> ".paclet" ~~ EndOfString -> ""
    ];
    writeGitHubOutput[
        "archives" -> Length[urls],
        "prefix" -> prefix,
        "page" -> First[result]
    ];
    Scan[Print["OK: ", #] &, urls];
    Print["OK: ", First[result]];
    Print[
        "Install with PacletInstall[\"", prefix,
        "\" <> $SystemID <> \".paclet\"]"
    ]
]
