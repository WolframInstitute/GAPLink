(* ::Package:: *)

PackageScoped["gapLinkFindGAPExecutable"]
PackageScoped["gapLinkBundledGAPExecutables"]

gapExecutableFailure[path_] := Failure[
    "GAPStartFailed",
    Join[
        <|
            "MessageTemplate" -> "GAP could not be found.",
            "MessageParameters" -> <||>,
            "Reason" -> "ExecutableNotFound"
        |>,
        If[StringQ[path], <|"Path" -> path|>, <||>]
    ]
]

gapExecutableNames["Windows"] := {"gap.exe", "gap.bat"}
gapExecutableNames[_] := {"gap"}

gapBundledExecutableName["Windows"] := "gap.bat"
gapBundledExecutableName[_] := "gap"

gapPathExecutables[path_String, system_String] := Module[{directories},
    directories = DeleteCases[
        StringTrim[#, WhitespaceCharacter | "\""] & /@
            StringSplit[path, If[system === "Windows", ";", ":"]],
        ""
    ];
    Flatten @ Table[
        FileNameJoin[{directory, name}],
        {directory, directories},
        {name, gapExecutableNames[system]}
    ]
]
gapPathExecutables[_, _] := {}

gapCommonExecutables["Windows"] := FileNames[
    "gap.bat",
    FileNames[
        "GAP" ~~ ___,
        Select[
            Environment /@ {"LOCALAPPDATA", "ProgramFiles", "ProgramW6432"},
            DirectoryQ
        ]
    ]
]
gapCommonExecutables["MacOSX"] := {
    "/opt/homebrew/bin/gap", "/usr/local/bin/gap", "/opt/local/bin/gap",
    "/usr/bin/gap"
}
gapCommonExecutables[_] := {
    "/usr/local/bin/gap", "/usr/bin/gap", "/snap/bin/gap"
}

gapPrepareBundledRuntime[runtime_String, "Windows"] := runtime

gapPrepareBundledRuntime[runtime_String, system_String] :=
    gapPrepareBundledRuntime[runtime, system] = Module[{files, manifest},
        manifest = FileNameJoin[{runtime, "EXECUTABLES.txt"}];
        files = Select[
            Quiet @ Check[Import[manifest, "Lines"], {"gap"}],
            StringQ[#] && # =!= "" &
        ];
        files = Select[FileNameJoin[{runtime, #}] & /@ files, FileExistsQ];
        If[files =!= {}, Quiet @ Check[
            RunProcess[Join[{"/bin/chmod", "a+x"}, files]],
            Null
        ]];
        runtime
    ]

gapLinkBundledGAPExecutables[] := gapLinkBundledGAPExecutables[
    Quiet @ Check[PacletFind["WolframInstitute/GAPLink"], {}],
    $OperatingSystem
]

gapLinkBundledGAPExecutables[paclets_List, system_String] :=
    FileNameJoin[{
        gapPrepareBundledRuntime[#, system], gapBundledExecutableName[system]
    }] & /@ Cases[
        Quiet @ Check[#["AssetLocation", "GAPRuntime"] & /@ paclets, {}],
        _String
    ]

gapFirstExecutable[paths_List, requested_] := Replace[
    SelectFirst[
        ExpandFileName /@ DeleteDuplicates @ Select[paths, StringQ[#] && # =!= "" &],
        FileType[#] === File &,
        Missing["NotFound"]
    ],
    _Missing :> gapExecutableFailure[requested]
]

gapLinkFindGAPExecutable[path_String] := gapFirstExecutable[{path}, path]

gapLinkFindGAPExecutable[Automatic] := gapLinkFindGAPExecutable[
    Automatic, gapLinkBundledGAPExecutables[], Environment["PATH"],
    gapCommonExecutables[$OperatingSystem], $OperatingSystem
]

gapLinkFindGAPExecutable[path_String, _, _, _, _] :=
    gapFirstExecutable[{path}, path]

gapLinkFindGAPExecutable[
    Automatic, bundled_List, path_, common_List, system_String
] := gapFirstExecutable[
    Join[bundled, gapPathExecutables[path, system], common], Automatic
]
