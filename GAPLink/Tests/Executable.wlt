Needs["WolframInstitute`GAPLink`"];

findGAP = Symbol[
    "WolframInstitute`GAPLink`PackageScope`gapLinkFindGAPExecutable"
];
gapTestRoot = CreateDirectory[];
gapTestFile[parts__] := CreateFile[
    FileNameJoin[{gapTestRoot, parts}],
    CreateIntermediateDirectories -> True
];

explicitGAP = gapTestFile["set", "gap"];
pathGAP = gapTestFile["path", If[$OperatingSystem === "Windows", "gap.exe", "gap"]];
commonGAP = gapTestFile["common", "gap"];
windowsGAP = gapTestFile["windows", "gap.bat"];
pathSeparator = If[$OperatingSystem === "Windows", ";", ":"];

VerificationTest[
    findGAP[explicitGAP, DirectoryName[pathGAP], {commonGAP}, $OperatingSystem],
    ExpandFileName[explicitGAP],
    TestID -> "Use-Set-Path"
]

VerificationTest[
    findGAP[
        Automatic,
        StringRiffle[{FileNameJoin[{gapTestRoot, "missing"}], DirectoryName[pathGAP]}, pathSeparator],
        {commonGAP},
        $OperatingSystem
    ],
    ExpandFileName[pathGAP],
    TestID -> "Find-GAP-On-Path"
]

VerificationTest[
    findGAP[Automatic, "", {commonGAP}, $OperatingSystem],
    ExpandFileName[commonGAP],
    TestID -> "Use-Common-Path"
]

VerificationTest[
    findGAP[Automatic, "\"" <> DirectoryName[windowsGAP] <> "\"", {}, "Windows"],
    ExpandFileName[windowsGAP],
    TestID -> "Find-Windows-GAP-On-Path"
]

VerificationTest[
    Module[{failure},
        failure = findGAP[
            FileNameJoin[{gapTestRoot, "missing", "gap"}],
            DirectoryName[pathGAP],
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
    FailureQ @ findGAP[Automatic, "", {}, $OperatingSystem],
    True,
    TestID -> "Fail-When-GAP-Is-Missing"
]

DeleteDirectory[gapTestRoot, DeleteContents -> True];
