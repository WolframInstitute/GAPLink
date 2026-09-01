#!/usr/bin/env wolframscript

Get[FileNameJoin[{DirectoryName[$InputFileName], "common.wl"}]];
Needs["PacletTools`"];

Module[
    {
        archive, call, context, directory, executable, expected, loadPackage,
        install, paclet, package, root, runtime, session = None, start
    },
    archive = FileNames[
        "*.paclet",
        FileNameJoin[{buildDirectory, "bundles", $SystemID}]
    ];
    scriptRequire[archive, Length[#] === 1 &, "Expected one bundle for ", $SystemID];
    archive = First[archive];
    expected = Replace[
        Environment["GAPLINK_EXPECTED_GAP_VERSION"],
        Except[_String] | "" -> "4.16.1"
    ];
    install = Environment["GAPLINK_VERIFY_INSTALL"] === "1";
    root = If[install, None, CreateDirectory[]];
    WithCleanup[
        If[install,
            paclet = Quiet @ Check[
                PacletInstall[
                    archive,
                    ForceVersionInstall -> True,
                    ShowProgress -> False
                ],
                $Failed
            ];
            scriptRequire[paclet, PacletObjectQ, "Could not install bundle"];
            directory = paclet["Location"],
            ExtractArchive[archive, root];
            directory = SelectFirst[FileNames[All, root], DirectoryQ, $Failed];
            scriptRequire[directory, StringQ, "Could not extract bundle"];
            paclet = PacletObject[File[directory]]
        ];
        scriptRequire[PacletValidate[directory], TrueQ, "Bundle does not validate"];
        scriptRequire[paclet, PacletObjectQ, "Cannot read bundle"];
        runtime = paclet["AssetLocation", "GAPRuntime"];
        executable = FileNameJoin[{
            runtime,
            If[$OperatingSystem === "Windows", "gap.bat", "gap"]
        }];
        scriptRequire[executable, FileExistsQ, "Bundle is missing GAP"];

        PacletDirectoryLoad[directory];
        context = paclet["PrimaryContext"];
        scriptRequire[Check[Needs[context], $Failed], # =!= $Failed &, "Cannot load bundle"];
        start = Symbol[context <> "StartGAPSession"];
        call = Symbol[context <> "GAPCall"];
        loadPackage = Symbol[context <> "LoadGAPPackage"];
        session = start[];
        scriptRequire[session, !FailureQ[#] &, "Cannot start bundled GAP"];
        scriptRequire[
            session["Executable"],
            ExpandFileName[#] === ExpandFileName[executable] &,
            "GAPLink did not use bundled GAP"
        ];
        scriptRequire[session["Version"], # === expected &, "Wrong GAP version"];
        scriptRequire[call[session, "Sum", Range[10]], # === 55 &, "GAP call failed"];
        package = loadPackage[session, "gapdoc"];
        scriptRequire[package, AssociationQ, "Required GAP package failed"];
        Print["OK: ", FileNameTake[archive], " | GAP ", session["Version"]],
        If[session =!= None && !FailureQ[session], DeleteObject[session]];
        If[DirectoryQ[root], DeleteDirectory[root, DeleteContents -> True]]
    ]
]
