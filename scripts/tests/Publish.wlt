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
    "Could not set metadata for https://example.invalid/obj/test/path",
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

ClearAll[withPublishMocks];
