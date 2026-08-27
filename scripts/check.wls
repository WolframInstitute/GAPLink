#!/usr/bin/env wolframscript

Get[FileNameJoin[{DirectoryName[$InputFileName], "common.wl"}]];
Needs["PacletTools`"];

Module[
    {
        paclet, requiredFields, missingFields, citation, files, context,
        kernelExtensions, declaredSymbols, exportedSymbols, missingUsage
    },
    paclet = Quiet @ Check[PacletObject[File[pacletDirectory]], $Failed];
    scriptRequire[paclet, PacletObjectQ, "Cannot read PacletInfo.wl"];
    scriptRequire[
        PacletValidate[pacletDirectory],
        TrueQ,
        "PacletValidate failed"
    ];

    requiredFields = {
        "Name", "Version", "WolframVersion", "Description", "Creator",
        "License", "PublisherID", "PrimaryContext"
    };
    missingFields = Select[
        requiredFields,
        !StringQ[paclet[#]] || StringTrim[paclet[#]] === "" &
    ];
    If[missingFields =!= {}, scriptFail["Missing metadata: ", missingFields]];
    If[paclet["Name"] =!= pacletName, scriptFail["Unexpected paclet name"]];
    If[
        !StringMatchQ[
            paclet["Version"],
            DigitCharacter.. ~~ "." ~~ DigitCharacter.. ~~ "." ~~ DigitCharacter..
        ],
        scriptFail["Version must use MAJOR.MINOR.PATCH"]
    ];

    citation = Import[FileNameJoin[{repositoryRoot, "CITATION.cff"}], "Text"];
    If[
        !StringContainsQ[citation, "version: " <> paclet["Version"]],
        scriptFail["CITATION.cff has a different version"]
    ];
    If[
        !StringContainsQ[citation, "license: " <> paclet["License"]],
        scriptFail["CITATION.cff has a different license"]
    ];

    files = Join[
        {FileNameJoin[{pacletDirectory, "PacletInfo.wl"}]},
        FileNames[{"*.wl", "*.m"}, FileNameJoin[{pacletDirectory, "Kernel"}], Infinity],
        FileNames["*.wlt", FileNameJoin[{pacletDirectory, "Tests"}], Infinity],
        FileNames[{"*.wl", "*.wls"}, scriptDirectory]
    ];
    lintFiles[files];

    paclet = loadSource[];
    context = paclet["PrimaryContext"];
    kernelExtensions = PacletExtensions[paclet, "Kernel"];
    declaredSymbols = Flatten[Lookup[Last /@ kernelExtensions, "Symbols", {}]];
    exportedSymbols = Select[
        Names[context <> "*"],
        StringCount[#, "`"] === StringCount[context, "`"] &
    ];
    If[
        Sort[declaredSymbols] =!= Sort[exportedSymbols],
        scriptFail["PacletInfo.wl symbol list does not match exported symbols"]
    ];
    missingUsage = Select[
        exportedSymbols,
        !StringQ[Quiet @ ToExpression[# <> "::usage"]] &
    ];
    If[missingUsage =!= {}, scriptFail["Missing usage messages: ", missingUsage]];

    Print["OK: ", paclet["Name"], " ", paclet["Version"]]
]
