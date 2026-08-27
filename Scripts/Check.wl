(* ::Package:: *)

PackageImport["PacletTools`"]

(* ::Section:: *)
(*PackageExported*)

PackageExported[CheckPaclet];

(* ::Section:: *)
(*Usage Messages*)

CheckPaclet::usage = "CheckPaclet[] checks paclet metadata, source, and repository metadata.";

(* ::Section:: *)
(*Function Definitions*)

$requiredFields = {
    "Name", "Version", "WolframVersion", "Description", "Creator",
    "License", "PublisherID", "PrimaryContext"
};
$versionPattern = DigitCharacter.. ~~ "." ~~ DigitCharacter.. ~~ "." ~~ DigitCharacter..;
$pacletInfo := FileNameJoin[{$PacletDirectory, "PacletInfo.wl"}];
$infoLocation := <|"File" -> $pacletInfo|>;
$lintFiles := Join[
    FileNames[{"*.wl", "*.m"}, FileNameJoin[{$PacletDirectory, "Kernel"}], Infinity],
    FileNames["*.wlt", FileNameJoin[{$PacletDirectory, "Tests"}], Infinity],
    FileNames[{"*.wl", "*.wls"}, FileNameJoin[{$RepositoryRoot, "Scripts"}]]
];

contextSpecs[options_Association] := Replace[
    Replace[Lookup[options, "Context", {}], context_String :> {context}],
    {
        {context_String, file_String} :> {context, file},
        context_String :> {context, Automatic}
    },
    {1}
];

defaultContextFile[root_String, context_String] := With[
    {base = Last @ DeleteCases[StringSplit[context, "`"], ""]},
    SelectFirst[
        FileNameJoin[{root, base <> #}] & /@ {".wl", ".m"},
        FileExistsQ,
        FileNameJoin[{root, base <> ".wl"}]
    ]
];

checkContextSpec[root_][{context_, file_String}] := With[
    {path = FileNameJoin[{root, file}]},
    If[!FileExistsQ[path],
        LogError[
            $infoLocation,
            "context ", context, " maps to a missing file: ", RepositoryPath[path]
        ]
    ]
];

checkContextSpec[root_][{context_, Automatic}] := With[
    {path = defaultContextFile[root, context]},
    If[!FileExistsQ[path],
        LogError[
            $infoLocation,
            "context ", context, " has no loadable default file: ", RepositoryPath[path]
        ]
    ]
];

checkKernelExtension[paclet_, {"Kernel", options_Association}] := RunTask @ Module[
    {
        root = FileNameJoin[{$PacletDirectory, Lookup[options, "Root", "Kernel"]}],
        specs,
        primary
    },
    RequireOrLog[
        DirectoryQ[root],
        TrueQ,
        $infoLocation,
        "Kernel root does not exist: ", RepositoryPath[root]
    ];
    specs = contextSpecs[options];
    RequireOrLog[specs, # =!= {} &, $infoLocation, "Kernel declares no Context"];
    Scan[checkContextSpec[root], specs];
    primary = paclet["PrimaryContext"];
    If[StringQ[primary] && !MemberQ[specs[[All, 1]], primary],
        LogError[
            $infoLocation,
            "PrimaryContext ", primary, " is not declared by the Kernel extension"
        ]
    ]
];

checkKernelExtension[_, extension_] := LogError[
    $infoLocation,
    "unexpected Kernel extension form: ", extension
];

checkMetadata[] := RunTask @ Module[{paclet, extensions, omitted},
    RequireOrLog[CheckPacletInfoFile[], TrueQ];
    RequireOrLog[
        PacletValidate[$PacletDirectory],
        TrueQ,
        $infoLocation,
        "PacletValidate failed for ", RepositoryPath[$PacletDirectory]
    ];
    paclet = PacletObject[File[$PacletDirectory]];
    RequireOrLog[paclet, PacletObjectQ, $infoLocation, "cannot read the paclet"];
    Scan[
        If[!StringQ[paclet[#]] || StringTrim[paclet[#]] === "",
            LogError[$infoLocation, "missing or empty ", #]
        ] &,
        $requiredFields
    ];
    If[paclet["Name"] =!= $PacletName,
        LogError[
            $infoLocation,
            "Name is ", paclet["Name"], "; expected ", $PacletName
        ]
    ];
    If[StringQ[paclet["Version"]] && !StringMatchQ[paclet["Version"], $versionPattern],
        LogError[
            $infoLocation,
            "Version must be MAJOR.MINOR.PATCH; got ", paclet["Version"]
        ]
    ];
    extensions = PacletExtensions[paclet, "Kernel"];
    If[extensions === {},
        LogError[$infoLocation, "no Kernel extension declared"],
        Scan[checkKernelExtension[paclet, #] &, extensions]
    ];
    If[PacletExtensions[paclet, "Test"] === {},
        LogError[$infoLocation, "no Test extension declared"]
    ];
    omitted = PacletOmittedFiles[paclet];
    If[ListQ[omitted] && omitted =!= {},
        LogWarning[
            $infoLocation,
            Length[omitted], " paclet file(s) are not covered by an extension: ",
            StringRiffle[RepositoryPath /@ omitted, ", "]
        ]
    ];
    LogInfo[
        "  ", paclet["Name"], " ", paclet["Version"],
        " (Wolfram ", paclet["WolframVersion"], ")"
    ];
    paclet
];

checkRepositoryMetadata[] := RunTask @ Module[
    {paclet, citation, requiredFiles},
    paclet = PacletObject[File[$PacletDirectory]];
    RequireOrLog[paclet, PacletObjectQ, "cannot read paclet metadata"];
    requiredFiles = FileNameJoin[{$RepositoryRoot, #}] & /@ {
        "README.md", "CONTRIBUTING.md", "CHANGELOG.md", "CITATION.cff",
        "LICENSE", "SECURITY.md", "THIRD_PARTY_NOTICES.md"
    };
    Scan[
        If[!FileExistsQ[#], LogError["missing repository file: ", RepositoryPath[#]]] &,
        requiredFiles
    ];
    citation = Import[FileNameJoin[{$RepositoryRoot, "CITATION.cff"}], "Text"];
    If[!StringContainsQ[citation, "version: " <> paclet["Version"]],
        LogError[
            "CITATION.cff version does not match PacletInfo.wl version ", paclet["Version"]
        ]
    ];
    If[!StringContainsQ[citation, "license: " <> paclet["License"]],
        LogError[
            "CITATION.cff license does not match PacletInfo.wl license ", paclet["License"]
        ]
    ];
    LogInfo["  required repository metadata is present and aligned"]
];

usageQ[name_String] := StringQ @ Quiet @ ToExpression[name <> "::usage"];

exportedSymbols[context_String] := Select[
    Names[context <> "*"],
    StringCount[#, "`"] === StringCount[context, "`"] &
];

checkLoad[] := RunTask @ Module[{paclet, context, declared, exported},
    paclet = LoadPaclet[];
    RequireOrLog[paclet, PacletObjectQ];
    context = paclet["PrimaryContext"];
    LogInfo["  ", context, " loaded"];
    declared = Catenate[
        Lookup[Last[#], "Symbols", {}] & /@ PacletExtensions[paclet, "Kernel"]
    ];
    exported = exportedSymbols[context];
    Scan[
        If[Names[#] === {},
            LogError[$infoLocation, "declared public symbol is not defined: ", #]
        ] &,
        declared
    ];
    Scan[
        LogError[$infoLocation, "exported symbol is not declared in PacletInfo.wl: ", #] &,
        Complement[exported, declared]
    ];
    Scan[
        If[!usageQ[#], LogError["exported symbol has no usage message: ", #]] &,
        exported
    ];
    LogInfo[
        "  ", Length[exported], " exported symbol(s), ",
        Length[declared], " declared in PacletInfo.wl"
    ]
];

CheckPaclet[] := Scan[
    LogGroup[First[#], Last[#][]] &,
    {
        "Paclet metadata" -> checkMetadata,
        "Repository metadata" -> checkRepositoryMetadata,
        "Source lint" -> (LintFiles[$lintFiles] &),
        "Load from source" -> checkLoad
    }
];
