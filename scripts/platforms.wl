publicCloudFileQ[url_String, type_String, hash_: None] := Module[{response},
    response = Quiet @ Check[RunProcess[Join[{
        "python3", FileNameJoin[{scriptDirectory, "verify-cloud.py"}], url, type
    }, If[StringQ[hash], {hash}, {}]]], $Failed];
    If[AssociationQ[response] && response["ExitCode"] =!= 0,
        Print[Lookup[response, "StandardError", ""]]
    ];
    MatchQ[response, KeyValuePattern["ExitCode" -> 0]]
];

setCloudMetadata[object_CloudObject, metadata_Association] := scriptRequire[
    Quiet @ Check[SetOptions[object, MetaInformation -> metadata], $Failed],
    MatchQ[{__Rule}], "Could not set metadata for ", First[object]
];

publishCloudFile[file_String, path_String, metadata_Association, type_String] := Module[{object},
    object = Quiet @ Check[
        CopyFile[file, CloudObject[path, Permissions -> "Public"],
            OverwriteTarget -> True, MIMEType -> type],
        $Failed
    ];
    scriptRequire[object, MatchQ[_CloudObject], "Could not upload ", path];
    setCloudMetadata[object, metadata];
    scriptRequire[
        Quiet @ Check[SetPermissions[object, All -> "Read"], $Failed],
        MatchQ[{__Rule}], "Could not set public access for ", path
    ];
    scriptRequire[
        publicCloudFileQ[First[object], type,
            If[type === "text/plain", FileHash[file, "SHA256", "HexString"], None]], TrueQ,
        "Anonymous download failed for ", First[object]
    ];
    First[object]
];

pacletResourceInfo[paclet_PacletObject, archive_CloudObject, system_String] := Join[
    KeyTake[First[paclet], {"Name", "Version", "Description", "PublisherID", "WolframVersion"}],
    <|
        "UUID" -> CreateUUID[],
        "ResourceType" -> "Paclet",
        "SystemID" -> system,
        "PacletFile" -> archive,
        "Autoload" -> True
    |>
];

publishPlatform[file_String, system_String, paclet_PacletObject, commit_String] := Module[
    {metadata, archive, info, description, resource},
    metadata = <|
        "Commit" -> commit,
        "SHA256" -> IntegerString[FileHash[file, "SHA256"], 16, 64],
        "Version" -> paclet["Version"],
        "SystemID" -> system
    |>;
    archive = publishCloudFile[file,
        FileNameJoin[{"GAPLink", archivePrefix <> "-" <> system <> ".paclet"}],
        metadata, "application/zip"
    ];
    info = pacletResourceInfo[paclet, CloudObject[archive], system];
    description = FileNameJoin[{buildDirectory, FileBaseName[file] <> ".wl"}];
    scriptRequire[
        Block[{ResourceObject},
            Export[description, ToString[ResourceObject[info], InputForm], "Text"]
        ],
        StringQ, "Could not write resource description for ", system
    ];
    resource = publishCloudFile[description,
        FileNameJoin[{"GAPLink", FileNameTake[description]}], metadata, "text/plain"
    ];
    setCloudMetadata[CloudObject[archive], Join[
        metadata,
        KeyTake[info, {"Name", "UUID", "ResourceType", "Description"}],
        <|"ResourceLocation" -> CloudObject[resource]|>
    ]];
    info
];

platformArchives[version_String] := AssociationMap[
    Function[system, With[{file = FileNameJoin[{buildDirectory,
        StringRiffle[{archivePrefix, system, version}, "-"] <> ".paclet"}]},
        scriptRequire[file, FileExistsQ, "Missing verified platform archive: ", file]
    ]], systems
];

(* This expression runs on the installing computer, not the publishing runner. *)
platformDescription[resources_Association] := Replace[
    With[{entries = resources}, HoldComplete[
        If[KeyExistsQ[entries, $SystemID],
            ResourceObject[entries[$SystemID]],
            Failure["UnsupportedSystem", <|"MessageTemplate" ->
                "GAPLink has no bundled runtime for `1`.", "MessageParameters" -> {$SystemID}|>]
        ]
    ]],
    HoldComplete[expression_] :> ToString[Unevaluated[expression], InputForm]
];

attachPlatforms[resource_String, resources_Association, version_String, commit_String] := Module[
    {file, description, object = CloudObject[resource], metadata},
    file = FileNameJoin[{buildDirectory, archivePrefix <> "-platforms-" <> version <> ".wl"}];
    scriptRequire[Export[file, platformDescription[resources], "Text"], StringQ,
        "Could not write the platform resource description"];
    description = publishCloudFile[file, "GAPLink/" <> FileNameTake[file],
        <|"Commit" -> commit, "Version" -> version|>, "text/plain"];
    metadata = Quiet @ Check[Association[MetaInformation /. Options[object, MetaInformation]], $Failed];
    scriptRequire[metadata, AssociationQ, "Could not read PacletPage release metadata"];
    setCloudMetadata[object, Append[metadata, "ResourceLocation" -> CloudObject[description]]]
];
