Needs["WolframInstitute`GAPLink`"];

findGAP = Symbol[
    "WolframInstitute`GAPLink`PackageScope`gapLinkFindGAPExecutable"
];
bundledExecutables = Symbol[
    "WolframInstitute`GAPLink`PackageScope`gapLinkBundledGAPExecutables"
];
gapTestRoot = CreateDirectory[];
gapTestFile[parts__] := CreateFile[
    FileNameJoin[{gapTestRoot, parts}],
    CreateIntermediateDirectories -> True
];

explicitGAP = gapTestFile["set", "gap"];
bundledGAP = gapTestFile["bundled", "gap"];
pathGAP = gapTestFile["path", If[$OperatingSystem === "Windows", "gap.exe", "gap"]];
commonGAP = gapTestFile["common", "gap"];
windowsGAP = gapTestFile["windows", "gap.bat"];
pathSeparator = If[$OperatingSystem === "Windows", ";", ":"];

If[$OperatingSystem =!= "Windows",
    Export[bundledGAP, "#!/bin/sh\nexit 0\n", "Text"];
    Export[
        FileNameJoin[{DirectoryName[bundledGAP], "EXECUTABLES.txt"}],
        "gap\n",
        "Text"
    ]
];

VerificationTest[
    findGAP[
        explicitGAP, {bundledGAP}, DirectoryName[pathGAP], {commonGAP},
        $OperatingSystem
    ],
    ExpandFileName[explicitGAP],
    TestID -> "Use-Set-Path"
]

VerificationTest[
    findGAP[
        Automatic, {},
        StringRiffle[{FileNameJoin[{gapTestRoot, "missing"}], DirectoryName[pathGAP]}, pathSeparator],
        {commonGAP},
        $OperatingSystem
    ],
    ExpandFileName[pathGAP],
    TestID -> "Find-GAP-On-Path"
]

VerificationTest[
    findGAP[Automatic, {}, "", {commonGAP}, $OperatingSystem],
    ExpandFileName[commonGAP],
    TestID -> "Use-Common-Path"
]

VerificationTest[
    findGAP[
        Automatic, {}, "\"" <> DirectoryName[windowsGAP] <> "\"", {},
        "Windows"
    ],
    ExpandFileName[windowsGAP],
    TestID -> "Find-Windows-GAP-On-Path"
]

VerificationTest[
    findGAP[
        Automatic, {bundledGAP}, DirectoryName[pathGAP], {commonGAP},
        $OperatingSystem
    ],
    ExpandFileName[bundledGAP],
    TestID -> "Use-Bundled-GAP"
]

VerificationTest[
    bundledExecutables[
        {
            PacletObject @ <|
                "Name" -> "WolframInstitute/GAPLink",
                "Version" -> "0.1.0",
                "Location" -> gapTestRoot,
                "Extensions" -> {{
                    "Asset", "Root" -> ".",
                    "Assets" -> {{"GAPRuntime", "bundled"}}
                }}
            |>
        },
        $OperatingSystem
    ],
    {ExpandFileName[bundledGAP]},
    TestID -> "Read-Bundled-GAP-Path"
]

VerificationTest[
    If[$OperatingSystem === "Windows",
        True,
        RunProcess[{bundledGAP}]["ExitCode"] === 0
    ],
    True,
    TestID -> "Restore-Bundled-GAP-Permissions"
]

VerificationTest[
    bundledExecutables[
        {
            PacletObject @ <|
                "Name" -> "WolframInstitute/GAPLink",
                "Version" -> "0.1.0",
                "Location" -> gapTestRoot,
                "Extensions" -> {{
                    "Asset", "Root" -> ".",
                    "Assets" -> {{"GAPRuntime", "bundled"}}
                }}
            |>
        },
        "Windows"
    ],
    {FileNameJoin[{gapTestRoot, "bundled", "gap.bat"}]},
    TestID -> "Read-Bundled-Windows-GAP-Path"
]

VerificationTest[
    Module[{failure},
        failure = findGAP[
            FileNameJoin[{gapTestRoot, "missing", "gap"}],
            {bundledGAP}, DirectoryName[pathGAP],
            {commonGAP},
            $OperatingSystem
        ];
        FailureQ[failure] &&
            failure["Reason"] === "ExecutableNotFound" &&
            StringQ[failure["MessageTemplate"]] &&
            AssociationQ[failure["MessageParameters"]]
    ],
    True,
    TestID -> "Fail-For-Missing-Set-Path"
]

VerificationTest[
    FailureQ @ findGAP[Automatic, {}, "", {}, $OperatingSystem],
    True,
    TestID -> "Fail-When-GAP-Is-Missing"
]

DeleteDirectory[gapTestRoot, DeleteContents -> True];
