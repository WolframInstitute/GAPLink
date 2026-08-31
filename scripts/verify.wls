#!/usr/bin/env wolframscript

Get[FileNameJoin[{DirectoryName[$InputFileName], "common.wl"}]];
Needs["PacletTools`"];

Module[
    {
        source, archive, root, directory, paclet, context, result, loaded,
        symbols, documentationFiles, missingDocumentation,
        invalidDocumentation, page, requiredStyles, styles, uri
    },
    source = PacletObject[File[pacletDirectory]];
    scriptRequire[source, PacletObjectQ, "Cannot read source paclet"];
    archive = archivePath[source["Version"]];
    If[!FileExistsQ[archive], scriptFail["Run make build first"]];

    root = CreateDirectory[];
    WithCleanup[
        ExtractArchive[archive, root];
        directory = SelectFirst[FileNames[All, root], DirectoryQ, $Failed];
        scriptRequire[directory, StringQ, "Could not extract archive"];
        scriptRequire[
            PacletValidate[directory],
            TrueQ,
            "Archive does not contain a valid paclet"
        ];

        paclet = PacletObject[File[directory]];
        context = paclet["PrimaryContext"];
        symbols = Flatten @ Lookup[
            Last /@ PacletExtensions[paclet, "Kernel"], "Symbols", {}
        ];
        documentationFiles = FileNameJoin[{
            directory, "Documentation", "English", "ReferencePages",
            "Symbols", Last[StringSplit[#, "`"]] <> ".nb"
        }] & /@ symbols;
        missingDocumentation = Select[documentationFiles, !FileExistsQ[#] &];
        If[missingDocumentation =!= {},
            scriptFail["Archive is missing reference pages: ", missingDocumentation]
        ];
        requiredStyles = {
            "AnchorBarGrid", "ObjectNameGrid", "Usage", "NotesSection",
            "PrimaryExamplesSection", "SeeAlsoSection"
        };
        invalidDocumentation = Select[
            documentationFiles,
            Function[file,
                page = Quiet @ Check[Get[file], $Failed];
                styles = Cases[
                    page, Cell[_, style_String, ___] :> style, Infinity
                ];
                uri = pacletName <> "/ref/" <> FileBaseName[file];
                !MatchQ[page, _Notebook] ||
                    !ContainsAll[styles, requiredStyles] ||
                    FreeQ[page, "uri" -> uri]
            ]
        ];
        If[invalidDocumentation =!= {},
            scriptFail["Invalid built reference pages: ", invalidDocumentation]
        ];
        PacletDirectoryLoad[directory];
        result = Check[Needs[context], $Failed];
        scriptRequire[result, # =!= $Failed &, "Could not load built paclet"];
        loaded = PacletObject[pacletName];
        If[
            !PacletObjectQ[loaded] || loaded["Version"] =!= source["Version"],
            scriptFail["Loaded paclet does not match the archive"]
        ];
        Print["OK: loaded ", context, " ", loaded["Version"]],
        If[DirectoryQ[root], DeleteDirectory[root, DeleteContents -> True]]
    ]
]
