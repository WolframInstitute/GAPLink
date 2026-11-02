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
                publishPlatform[FileNameJoin[{pacletDirectory, "PacletInfo.wl"}],
                    "Linux-x86-64", PacletObject[File[pacletDirectory]], "test-commit"]
            ]
        ];
        records = First[Last[result]];
        description = Import[FileNameJoin[{directory, "PacletInfo.wl"}], "Text"];
        info = Block[{ResourceObject}, First[ToExpression[description]]];
        metadata = Last[Last[Last[records]]];
        DeleteDirectory[directory, DeleteContents -> True];
        {
            First[result]["PacletFile"],
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
        CloudObject["https://example.invalid/obj/GAPLink/WolframInstitute__GAPLink-Linux-x86-64.paclet"],
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

VerificationTest[
    Module[{resources, description, results},
        resources = AssociationMap[
            pacletResourceInfo[PacletObject[File[pacletDirectory]],
                CloudObject["https://example.invalid/obj/GAPLink/" <> archivePrefix <> "-" <> # <> ".paclet"], #] &,
            systems
        ];
        description = platformDescription[resources];
        results = Table[
            Block[{ResourceObject}, First[ToExpression[
                StringReplace[description, "$SystemID" -> ToString[system, InputForm]]]]],
            {system, systems}
        ];
        {
            results === Values[resources],
            DuplicateFreeQ[Lookup[results, "UUID"]],
            FailureQ[ToExpression[StringReplace[description, "$SystemID" -> "\"Unsupported\""]]]
        }
    ],
    {True, True, True},
    TestID -> "Resource-Selects-The-Installing-System"
]

VerificationTest[
    Module[{directory = CreateDirectory[], result, metadata},
        metadata = {"PacletVersion" -> "0.3.0", "PacletCommit" -> "commit", "Other" -> 1};
        result = Internal`InheritedBlock[{CloudObject},
            Unprotect[CloudObject];
            CloudObject /: Verbatim[Options][CloudObject["https://example.invalid/obj/resource"], MetaInformation] :=
                {MetaInformation -> metadata};
            Block[{
                buildDirectory = directory,
                publishCloudFile = Function[Null, "https://example.invalid/obj/platforms.wl"],
                setCloudMetadata = Function[{object, info}, info]
            }, attachPlatforms["https://example.invalid/obj/resource", <||>, "0.3.0", "commit"]]
        ];
        DeleteDirectory[directory, DeleteContents -> True];
        result === Append[Association[metadata], "ResourceLocation" -> CloudObject["https://example.invalid/obj/platforms.wl"]]
    ],
    True,
    TestID -> "Platform-Routing-Preserves-PacletPage-Release-Metadata"
]

VerificationTest[
    Block[{scriptFail = (Throw[StringJoin[##], "ReleaseFailure"] &)},
        Module[{environment},
            environment = <|"GITHUB_ACTIONS" -> "true", "GITHUB_EVENT_NAME" -> "push",
                "GITHUB_REF_TYPE" -> "tag", "GITHUB_REF_NAME" -> "v0.3.0", "GITHUB_REF" -> "refs/tags/v0.3.0"|>;
            {
                releaseTag[environment, "0.3.0"],
                Catch[releaseTag[<||>, "0.3.0"], "ReleaseFailure"],
                Catch[releaseTag[environment, "0.3.1"], "ReleaseFailure"],
                Catch[releaseTag[Append[environment, "GITHUB_EVENT_NAME" -> "pull_request"], "0.3.0"], "ReleaseFailure"]
            }
        ]
    ],
    {"v0.3.0", "Publishing requires a release-tag workflow", "The release tag must match PacletInfo.wl",
        "Publishing requires a release-tag workflow"},
    TestID -> "Publish-Only-From-A-Matching-Release-Tag"
]

VerificationTest[
    Block[{
        checkRelease = Function[Null, "commit"], platformArchives = Function[Null, <||>],
        verifyPaclet = Function[Null, Throw["Invalid archive", "ReleaseFailure"]],
        CloudConnect = Function[Null, Throw["Connected too early", "ReleaseFailure"]]
    }, Catch[publish[], "ReleaseFailure"]],
    "Invalid archive",
    TestID -> "Reject-Unverified-Build-Before-Connecting-To-Cloud"
]

VerificationTest[
    Module[{events, calls = {}, resource, pageResult},
        resource = CloudObject["https://example.invalid/obj/platform.paclet"];
        pageResult = <|"Resource" -> <|"Deployed" -> True, "Resource" -> "https://example.invalid/obj/resource"|>,
            "Site" -> <|"Site" -> "https://example.invalid/obj/GAPLink/Documentation"|>, "Check" -> <|"OK" -> True|>|>;
        events = Last @ Reap @ Block[{
            checkRelease = Function[Null, "commit"],
            platformArchives = Function[Null, AssociationMap[# <> ".paclet" &, systems]],
            verifyPaclet = Function[Null, Sow["Verify"]],
            setting = Function[Null, "test"],
            CloudConnect = Function[Null, Sow["Connect"]], $CloudConnected = True,
            pageCall = ((AppendTo[calls, {##}]; Sow["PacletPage"]; pageResult) &),
            publishPlatform = Function[Null, Sow["Platform"]; <|"PacletFile" -> resource|>],
            attachPlatforms = Function[Null, Sow["Route"]],
            ResourceObject = Function[Null, Function[property, Sow["Resolve"]; resource]],
            writeGitHubOutput = Function[Null, Null], Print = Function[Null, Null]
        }, publish[]];
        {
            events,
            First[First[calls]],
            First[calls][[3]],
            Lookup[Association[Drop[First[calls], 3]], "Build"],
            Lookup[Association[Lookup[Association[Drop[First[calls], 3]], "ResourceOptions"]], "Build"]
        }
    ],
    {{{"Verify", "Connect", "PacletPage", "Platform", "Platform", "Platform", "Platform", "Route", "Resolve"}},
        "PublishPacletPage", "GAPLink/Documentation", False, False},
    TestID -> "Publish-Reuses-Verified-Build-And-Routes-The-Resource"
]
