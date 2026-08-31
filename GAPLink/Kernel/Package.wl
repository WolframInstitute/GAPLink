(* ::Package:: *)

PackageExported[GAPPackageAvailableQ]
PackageExported[LoadGAPPackage]

GAPPackageAvailableQ::usage = "GAPPackageAvailableQ[session, name] checks whether GAP can load a package."
LoadGAPPackage::usage = "LoadGAPPackage[session, name] loads a GAP package and returns its name and version."

Options[GAPPackageAvailableQ] = {
    TimeConstraint -> Infinity,
    "Version" -> Automatic
};
Options[LoadGAPPackage] = Options[GAPPackageAvailableQ];

gapPackageStringQ[value_] := StringQ[value] &&
    StringLength[StringTrim[value]] > 0

gapPackageOptions[head_, rules_] := Module[{time, values, version},
    values = gapLinkOptionValues[head, rules, {"Version", TimeConstraint}];
    If[FailureQ[values], Return[values]];
    {version, time} = values;
    Which[
        !(version === Automatic || gapPackageStringQ[version]),
            gapOptionFailure["Version"],
        !gapTimeConstraintQ[time], gapOptionFailure[TimeConstraint],
        True, values
    ]
]

gapPackageArguments[name_, Automatic] := {name}
gapPackageArguments[name_, version_] := {name, version}

gapPackageNameFailure[] := gapSessionFailure[
    "GAPUnsupportedValue", "The GAP package name must be a nonempty string."
]

gapPackageLoadFailure[name_, version_, captured_] := gapSessionFailure[
    "GAPPackageNotAvailable", "The GAP package could not be loaded.",
    Join[
        <|"Package" -> name|>,
        If[StringQ[version], <|"Version" -> version|>, <||>],
        KeyTake[captured, {"StandardOutput", "StandardError"}]
    ]
]

GAPPackageAvailableQ[
    session_GAPSession, name_String, opts : OptionsPattern[]
] := Module[{options, result, time, version},
    options = gapPackageOptions[GAPPackageAvailableQ, {opts}];
    If[FailureQ[options], Return[options]];
    If[!gapPackageStringQ[name], Return[gapPackageNameFailure[]]];
    {version, time} = options;
    result = GAPCall[
        session, "TestPackageAvailability",
        Sequence @@ gapPackageArguments[name, version],
        TimeConstraint -> time, "Output" -> "Discard"
    ];
    Which[
        FailureQ[result], result,
        result === Missing["GAPFail"], False,
        TrueQ[result] || StringQ[result] || Head[result] === ByteArray, True,
        True, gapSessionFailure[
            "GAPError", "GAP returned an invalid package result.",
            <|"Package" -> name|>
        ]
    ]
]

LoadGAPPackage[
    session_GAPSession, name_String, opts : OptionsPattern[]
] := Module[{captured, options, result, time, version},
    options = gapPackageOptions[LoadGAPPackage, {opts}];
    If[FailureQ[options], Return[options]];
    If[!gapPackageStringQ[name], Return[gapPackageNameFailure[]]];
    {version, time} = options;
    captured = GAPCall[
        session, "LoadPackage",
        Sequence @@ Append[gapPackageArguments[name, version], False],
        TimeConstraint -> time, "Output" -> "Capture"
    ];
    If[FailureQ[captured], Return[captured]];
    If[captured["Result"] =!= True,
        Return[gapPackageLoadFailure[name, version, captured]]
    ];
    result = GAPCall[
        session, "InstalledPackageVersion", name,
        TimeConstraint -> time, "Output" -> "Discard"
    ];
    If[FailureQ[result], Return[result]];
    If[StringQ[result],
        <|"Name" -> name, "Version" -> result|>,
        gapSessionFailure[
            "GAPError", "GAP did not return the package version.",
            <|"Package" -> name|>
        ]
    ]
]

GAPPackageAvailableQ[_GAPSession, ___] := gapPackageNameFailure[]
GAPPackageAvailableQ[_, ___] := gapInvalidSession[]
LoadGAPPackage[_GAPSession, ___] := gapPackageNameFailure[]
LoadGAPPackage[_, ___] := gapInvalidSession[]
