Needs["PacletTools`"];

runCheck[] := Module[
    {
        paclet, requiredFields, missingFields, citation, files, context,
        kernelExtensions, declaredSymbols, exportedSymbols, missingUsage,
        documentationFiles, missingDocumentation, invalidDocumentation
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
    exportedSymbols = context <> # & /@ Names[context <> "*"];
    If[
        Sort[declaredSymbols] =!= Sort[exportedSymbols],
        scriptFail["PacletInfo.wl symbol list does not match exported symbols"]
    ];
    missingUsage = Select[
        exportedSymbols,
        !StringQ[Quiet @ ToExpression[# <> "::usage"]] &
    ];
    If[missingUsage =!= {}, scriptFail["Missing usage messages: ", missingUsage]];

    scriptRequire[
        PacletExtensions[paclet, "Documentation"],
        Length[#] === 1 &,
        "PacletInfo.wl must have one Documentation extension"
    ];
    documentationFiles = FileNameJoin[{
        pacletDirectory, "Documentation", "English", "ReferencePages",
        "Symbols", Last[StringSplit[#, "`"]] <> ".nb"
    }] & /@ exportedSymbols;
    missingDocumentation = Select[documentationFiles, !FileExistsQ[#] &];
    If[missingDocumentation =!= {},
        scriptFail["Missing reference pages: ", missingDocumentation]
    ];
    invalidDocumentation = Select[
        documentationFiles,
        !MatchQ[Quiet @ Check[Get[#], $Failed], _Notebook] &
    ];
    If[invalidDocumentation =!= {},
        scriptFail["Invalid reference pages: ", invalidDocumentation]
    ];

    Print["OK: ", paclet["Name"], " ", paclet["Version"]]
]
