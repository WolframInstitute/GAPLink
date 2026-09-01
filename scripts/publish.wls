#!/usr/bin/env wolframscript

Get[FileNameJoin[{DirectoryName[$InputFileName], "common.wl"}]];
Needs["PacletTools`"];

setting[name_String] := scriptRequire[
    Environment[name],
    StringQ[#] && StringTrim[#] =!= "" &,
    name, " is not set"
];

publishedCommit[object_CloudObject] := Replace[
    Quiet @ Options[object, MetaInformation],
    {
        {MetaInformation -> data : (_Association | {___Rule})} :>
            Lookup[data, "Commit", None],
        _ -> None
    }
];

Module[
    {
        paclet, archive, version, commit, hash, versioned, latest, objects,
        result, urls
    },
    paclet = PacletObject[File[pacletDirectory]];
    scriptRequire[paclet, PacletObjectQ, "Cannot read source paclet"];
    version = paclet["Version"];
    archive = archivePath[version];
    scriptRequire[FileExistsQ[archive], TrueQ, "Run make build first"];

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
    hash = IntegerString[FileHash[archive, "SHA256"], 16, 64];
    versioned = CloudObject[
        FileNameJoin[{"GAPLink", FileNameTake[archive]}]
    ];
    latest = CloudObject[
        FileNameJoin[{"GAPLink", archivePrefix <> ".paclet"}]
    ];

    If[TrueQ[FileExistsQ[versioned]],
        scriptRequire[
            publishedCommit[versioned],
            SameQ[#, commit] &,
            "Version ", version, " is already published"
        ]
    ];

    objects = {versioned, latest};
    Scan[
        Function[object,
            result = Quiet @ Check[
                CopyFile[archive, object, OverwriteTarget -> True],
                $Failed
            ];
            scriptRequire[result, MatchQ[_CloudObject], "Could not upload paclet"];
            scriptRequire[
                Quiet @ Check[
                    SetOptions[
                        result,
                        Permissions -> "Public",
                        MetaInformation -> <|
                            "Commit" -> commit,
                            "SHA256" -> hash
                        |>
                    ],
                    $Failed
                ],
                # =!= $Failed &,
                "Could not set cloud object options"
            ]
        ],
        objects
    ];

    urls = First /@ objects;
    writeGitHubOutput[
        "archive" -> urls[[1]],
        "latest" -> urls[[2]],
        "sha256" -> hash
    ];
    Print["OK: ", urls[[1]]];
    Print["Install with PacletInstall[\"", urls[[2]], "\"]"]
]
