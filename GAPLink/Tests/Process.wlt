Needs["WolframInstitute`GAPLink`"];

{gapCommand, startGAP, validateHello} = Symbol[
    "WolframInstitute`GAPLink`PackageScope`" <> #
] & /@ {"gapLinkGAPCommand", "gapLinkStartGAP", "gapLinkValidateGAPHello"};

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
    FailureQ @ gapCommand["gap.bat"],
    True,
    TestID -> "Reject-Batch-Launcher"
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
            gapCommand["gap.bat"],
            validateHello @ hello["5.0.0"]
        },
        StringQ[#["MessageTemplate"]] &&
            AssociationQ[#["MessageParameters"]] &
    ],
    True,
    TestID -> "Startup-Failures-Have-Messages"
]
