Needs["WolframInstitute`GAPLink`"];

{gapCommand, startGAP, validateHello} = Symbol[
    "WolframInstitute`GAPLink`PackageScope`" <> #
] & /@ {"gapLinkGAPCommand", "gapLinkStartGAP", "gapLinkValidateGAPHello"};

windowsRoot = CreateDirectory @ FileNameJoin[{
    $TemporaryDirectory, "GAP Link " <> CreateUUID[]
}];
windowsFile[parts__] := CreateFile[
    FileNameJoin[{windowsRoot, parts}],
    CreateIntermediateDirectories -> True
];
windowsLauncher = windowsFile["gap.bat"];
windowsBash = windowsFile["runtime", "bin", "bash.exe"];
windowsGAP = windowsFile["runtime", "opt", "gap-4.16.1", "gap.exe"];

hello[version_, hpc_: False] := <|
    "Status" -> "OK",
    "Result" -> <|
        "Build" -> version,
        "GAPVersion" -> version,
        "HPC" -> hpc,
        "Packages" -> {"GAPDoc", "primgrp"},
        "Processor" -> "x86_64",
        "ProtocolVersion" -> 1,
        "System" -> "Linux"
    |>
|>;

VerificationTest[
    Module[{command = gapCommand["/set/gap"]},
        ListQ[command] &&
            Most[command] === {
                "/set/gap", "-q", "-n", "-A", "-r", "--nointeract"
            } &&
            FileNameTake[Last[command]] === "startup.g" &&
            FileExistsQ[Last[command]]
    ],
    True,
    TestID -> "Build-GAP-Command"
]

VerificationTest[
    Module[
        {
            command = gapCommand[windowsLauncher], script,
            startup = Last @ gapCommand["/set/gap"]
        },
        If[!ListQ[command], Return[False]];
        script = command[[5]];
        command[[1 ;; 4]] === {windowsBash, "--noprofile", "--norc", "-c"} &&
            command[[6 ;; 8]] === {"GAPLink", windowsGAP, startup} &&
            Take[command, -5] === {"-q", "-n", "-A", "-r", "--nointeract"} &&
            And @@ (StringContainsQ[script, #] & /@
                {"$1", "$2", "$@", "$PATH"}) &&
            StringFreeQ[script, windowsRoot]
    ],
    True,
    TestID -> "Build-Windows-GAP-Command"
]

VerificationTest[
    Module[{failure = gapCommand[FileNameJoin[{windowsRoot, "missing", "gap.bat"}]]},
        FailureQ[failure] && failure["Reason"] === "WindowsLauncherNotFound"
    ],
    True,
    TestID -> "Reject-Incomplete-Windows-GAP"
]

VerificationTest[
    Module[{failure},
        windowsFile["runtime", "opt", "gap-4.15.1", "gap.exe"];
        failure = gapCommand[windowsLauncher];
        FailureQ[failure] && failure["Reason"] === "WindowsLauncherAmbiguous"
    ],
    True,
    TestID -> "Reject-Ambiguous-Windows-GAP"
]

VerificationTest[
    validateHello /@ {hello["4.14.0"], hello["4.16.9"]} //
        Map[Lookup[#, "Tested", False] &],
    {True, True},
    TestID -> "Accept-Supported-GAP"
]

VerificationTest[
    Lookup[validateHello @ hello["4.17.0"], "Tested", True],
    False,
    TestID -> "Mark-New-GAP-Untested"
]

VerificationTest[
    FailureQ /@ {
        validateHello @ hello["4.13.1"],
        validateHello @ hello["5.0.0"],
        validateHello @ hello["4.16.1dev"],
        validateHello @ hello["4.16.1", True],
        validateHello @ <|"Status" -> "OK", "Result" -> <||>|>
    },
    ConstantArray[True, 5],
    TestID -> "Reject-Unsupported-GAP"
]

VerificationTest[
    Module[{failure = startGAP[FileNameJoin[{$TemporaryDirectory, CreateUUID[]}]]},
        FailureQ[failure] && failure["Reason"] === "ExecutableNotFound"
    ],
    True,
    TestID -> "Fail-Before-Starting-Missing-GAP"
]

VerificationTest[
    AllTrue[
        {
            gapCommand["gap.cmd"],
            validateHello @ hello["5.0.0"]
        },
        StringQ[#["MessageTemplate"]] &&
            AssociationQ[#["MessageParameters"]] &
    ],
    True,
    TestID -> "Startup-Failures-Have-Messages"
]

DeleteDirectory[windowsRoot, DeleteContents -> True];
