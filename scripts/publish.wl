publicCloudFileQ[url_String, type_String] := Module[{response},
    response = Quiet @ Check[RunProcess[{
        "python3", FileNameJoin[{scriptDirectory, "verify-cloud.py"}], url, type
    }], $Failed];
    If[AssociationQ[response] && response["ExitCode"] =!= 0,
        Print[Lookup[response, "StandardError", ""]]
    ];
    MatchQ[response, KeyValuePattern["ExitCode" -> 0]]
];

publishCloudFile[file_String, path_String, metadata_Association, type_String] := Module[{object},
    object = Quiet @ Check[
        CopyFile[file, CloudObject[path, Permissions -> "Public"],
            OverwriteTarget -> True, MIMEType -> type],
        $Failed
    ];
    scriptRequire[object, MatchQ[_CloudObject], "Could not upload ", path];
    scriptRequire[
        Quiet @ Check[SetOptions[object, MetaInformation -> metadata], $Failed],
        MatchQ[{__Rule}], "Could not set metadata for ", path
    ];
    scriptRequire[
        Quiet @ Check[SetPermissions[object, All -> "Read"], $Failed],
        MatchQ[{__Rule}], "Could not set public access for ", path
    ];
    scriptRequire[
        publicCloudFileQ[First[object], type], TrueQ,
        "Anonymous download failed for ", First[object]
    ];
    First[object]
];
