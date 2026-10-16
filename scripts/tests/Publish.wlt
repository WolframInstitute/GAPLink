Get[FileNameJoin[{scriptDirectory, "publish.wl"}]];
Needs["CloudObject`"];

SetAttributes[withPublishMocks, HoldAll];
withPublishMocks[body_] := Block[
    {
        CopyFile = Function[Null, Sow["Upload"]; CloudObject["https://example.invalid/obj/test/paclet"]],
        SetOptions = Function[Null, Sow["Metadata"]; {MetaInformation -> <||>}],
        SetPermissions = Function[{object, permissions}, Sow[{"Permissions", permissions}]; {All -> {"Read"}}],
        publicCloudFileQ = Function[Null, Sow["Verify"]; True],
        scriptFail = (Throw[StringJoin[##], "PublishFailure"] &)
    },
    Catch[body, "PublishFailure"]
];

VerificationTest[
    withPublishMocks @ Reap[
        publishCloudFile["file.paclet", "https://example.invalid/obj/test/path", <||>, "application/zip"]
    ],
    {"https://example.invalid/obj/test/paclet", {{"Upload", "Metadata", {"Permissions", All -> "Read"}, "Verify"}}},
    TestID -> "Publish-Set-Public-Access-And-Verify"
]

VerificationTest[
    withPublishMocks @ Block[{CopyFile = ($Failed &)},
        publishCloudFile["file.paclet", "https://example.invalid/obj/test/path", <||>, "application/zip"]
    ],
    "Could not upload https://example.invalid/obj/test/path",
    TestID -> "Publish-Reject-Failed-Upload"
]

VerificationTest[
    withPublishMocks @ Block[{SetOptions = ({$Failed} &)},
        publishCloudFile["file.paclet", "https://example.invalid/obj/test/path", <||>, "application/zip"]
    ],
    "Could not set metadata for https://example.invalid/obj/test/paclet",
    TestID -> "Publish-Reject-Failed-Metadata"
]

VerificationTest[
    withPublishMocks @ Block[{SetPermissions = ($Failed &)},
        publishCloudFile["file.paclet", "https://example.invalid/obj/test/path", <||>, "application/zip"]
    ],
    "Could not set public access for https://example.invalid/obj/test/path",
    TestID -> "Publish-Reject-Failed-Permissions"
]

VerificationTest[
    withPublishMocks @ Block[{publicCloudFileQ = (False &)},
        publishCloudFile["file.paclet", "https://example.invalid/obj/test/path", <||>, "application/zip"]
    ],
    "Anonymous download failed for https://example.invalid/obj/test/paclet",
    TestID -> "Publish-Reject-Private-Download"
]

VerificationTest[
    Table[
        Block[{RunProcess = (<|"ExitCode" -> code|> &)},
            publicCloudFileQ["https://example.invalid/obj/test/paclet", "application/zip"]
        ],
        {code, {0, 1}}
    ],
    {True, False},
    TestID -> "Publish-Check-Anonymous-Request-Result"
]

VerificationTest[
    Module[{paclet, systems, infos},
        paclet = PacletObject[File[pacletDirectory]];
        systems = {"Linux-x86-64", "MacOSX-ARM64", "MacOSX-x86-64", "Windows-x86-64"};
        infos = pacletResourceInfo[paclet,
            CloudObject["https://example.invalid/obj/GAPLink/" <> archivePrefix <> "-" <> # <> ".paclet"], #
        ] & /@ systems;
        {
            Lookup[infos, "SystemID"] === systems,
            And @@ MapThread[
                StringEndsQ[First[#1["PacletFile"]], #2 <> ".paclet"] &,
                {infos, systems}
            ],
            DuplicateFreeQ[Lookup[infos, "UUID"]],
            AllTrue[infos,
                Lookup[#, {"Name", "ResourceType", "Version", "Autoload"}] ===
                    {pacletName, "Paclet", paclet["Version"], True} &
            ],
            FreeQ[infos, paclet["Location"]]
        }
    ],
    {True, True, True, True, True},
    TestID -> "Resource-Platform-Archives"
]

VerificationTest[
    Module[{paclet = PacletObject[File[pacletDirectory]], archive, first, second},
        archive = CloudObject["https://example.invalid/obj/test/paclet"];
        first = pacletResourceInfo[paclet, archive, $SystemID];
        second = pacletResourceInfo[paclet, archive, $SystemID];
        first["UUID"] =!= second["UUID"]
    ],
    True,
    TestID -> "Resource-Republish-Refreshes-Cache-Identity"
]

VerificationTest[
    Module[{directory = CreateDirectory[], result, records, description, info, metadata},
        result = Block[{buildDirectory = directory},
            Reap @ Block[{
                publishCloudFile = Function[{file, path, data, type},
                    Sow[{path, data, type}]; "https://example.invalid/obj/" <> path
                ],
                setCloudMetadata = Function[{object, data}, Sow[{object, MetaInformation -> data}]]
            },
                publishPaclet[FileNameJoin[{pacletDirectory, "PacletInfo.wl"}],
                    "Linux-x86-64", PacletObject[File[pacletDirectory]], "test-commit"]
            ]
        ];
        records = First[Last[result]];
        description = Import[FileNameJoin[{directory, "PacletInfo.wl"}], "Text"];
        info = Block[{ResourceObject}, First[ToExpression[description]]];
        metadata = Last[Last[Last[records]]];
        DeleteDirectory[directory, DeleteContents -> True];
        {
            First[result],
            records[[All, 1]],
            records[[1, 2, "Commit"]],
            records[[1, 2, "Version"]],
            records[[1, 3]], records[[2, 3]],
            metadata["ResourceLocation"],
            info["PacletFile"] === First[Last[records]],
            info["UUID"] === metadata["UUID"],
            info["Autoload"]
        }
    ],
    {
        "https://example.invalid/obj/GAPLink/WolframInstitute__GAPLink-Linux-x86-64.paclet",
        {
            "GAPLink/WolframInstitute__GAPLink-Linux-x86-64.paclet",
            "GAPLink/PacletInfo.wl",
            CloudObject["https://example.invalid/obj/GAPLink/WolframInstitute__GAPLink-Linux-x86-64.paclet"]
        },
        "test-commit", PacletObject[File[pacletDirectory]]["Version"],
        "application/zip", "text/plain",
        CloudObject["https://example.invalid/obj/GAPLink/PacletInfo.wl"],
        True, True, True
    },
    TestID -> "Publish-Resource-Links-To-Existing-Archive"
]

Needs["PacletResource`"];

VerificationTest[
    With[{
        archive = CloudObject["https://www.wolframcloud.com/obj/gaplink-test/test.paclet"],
        description = CloudObject["https://www.wolframcloud.com/obj/gaplink-test/ResourceObject.wl"]
    },
        Internal`InheritedBlock[{CloudObject}, Module[{info, text, resource, reads = 0},
            info = pacletResourceInfo[PacletObject[File[pacletDirectory]], archive, "Linux-x86-64"];
            text = Block[{ResourceObject}, ToString[ResourceObject[info], InputForm]];
            Unprotect[CloudObject];
            CloudObject /: Verbatim[Options][archive, MetaInformation] :=
                {MetaInformation -> <|"ResourceLocation" -> description|>};
            CloudObject /: CloudGet[description] := (reads++; ToExpression[text]);
            resource = ResourceObject[First[archive]];
            {
                Head[resource], reads,
                Lookup[resource[All], {"Name", "ResourceType", "SystemID", "PacletFile"}]
            }
        ]]
    ],
    {
        ResourceObject, 1,
        {pacletName, "Paclet", "Linux-x86-64",
            CloudObject["https://www.wolframcloud.com/obj/gaplink-test/test.paclet"]}
    },
    TestID -> "ResourceObject-Reads-Description-Not-Archive"
]

ClearAll[withPublishMocks];
