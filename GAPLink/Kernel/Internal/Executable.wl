(* ::Package:: *)

PackageScoped["gapLinkFindGAPExecutable"]

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

gapFirstExecutable[paths_List, requested_] := Replace[
    SelectFirst[
        ExpandFileName /@ DeleteDuplicates @ Select[paths, StringQ[#] && # =!= "" &],
        FileType[#] === File &,
        Missing["NotFound"]
    ],
    _Missing :> gapExecutableFailure[requested]
]

gapLinkFindGAPExecutable[path_: Automatic] := gapLinkFindGAPExecutable[
    path, Environment["PATH"], gapCommonExecutables[$OperatingSystem],
    $OperatingSystem
]

gapLinkFindGAPExecutable[path_String, _, _, _] :=
    gapFirstExecutable[{path}, path]

gapLinkFindGAPExecutable[Automatic, path_, common_List, system_String] :=
    gapFirstExecutable[Join[gapPathExecutables[path, system], common], Automatic]
