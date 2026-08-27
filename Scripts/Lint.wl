(* ::Package:: *)

PackageImport["CodeInspector`"]

(* ::Section:: *)
(*PackageExported*)

PackageExported[{LintFiles, $LintMinimumConfidence}];

(* ::Section:: *)
(*Usage Messages*)

LintFiles::usage = "LintFiles[files] checks Wolfram Language files with CodeInspector.";
$LintMinimumConfidence::usage = "$LintMinimumConfidence is the minimum reported confidence.";

(* ::Section:: *)
(*Function Definitions*)

$LintMinimumConfidence = .75;

plainMessage[message_String] := StringReplace[message, "``" -> ""];
plainMessage[message_] := ToString[message];

issueLocation[file_, data_Association] := Replace[
    Lookup[data, CodeParser`Source, None],
    {
        {{line_Integer, column_Integer}, ___} :>
            <|"File" -> file, "Line" -> line, "Column" -> column|>,
        _ :> <|"File" -> file|>
    }
];

reportIssue[file_, InspectionObject[tag_, message_, severity_, data_Association]] := With[
    {
        location = issueLocation[file, data],
        text = StringJoin[
            ToString[tag], " (", ToString[severity], "): ", plainMessage[message]
        ]
    },
    Switch[severity,
        "Fatal" | "Error", LogError[location, text],
        "Warning" | "Scoping", LogWarning[location, text],
        _, LogInfo[
            "  ", RepositoryPath[file],
            Replace[
                Lookup[location, "Line", None],
                line_Integer :> ":" <> ToString[line],
                _ -> ""
            ],
            ": ", text
        ]
    ]
];

reportIssue[file_, result_] := LogWarning[
    <|"File" -> file|>,
    "unrecognized CodeInspector result: ", result
];

confidentQ[InspectionObject[_, _, _, data_Association]] :=
    Lookup[data, ConfidenceLevel, 1.] >= $LintMinimumConfidence;
confidentQ[_] := True;

lintFile[file_String] := RunTask @ Module[{issues},
    RequireOrLog[FileExistsQ[file], TrueQ, "file not found: ", file];
    issues = CodeInspect[File[file]];
    RequireOrLog[
        issues,
        ListQ,
        <|"File" -> file|>,
        "CodeInspect failed: ", issues
    ];
    issues = Select[issues, confidentQ];
    Scan[reportIssue[file, #] &, issues];
    LogInfo[
        "  ", RepositoryPath[file], ": ", Length[issues],
        " issue(s) at confidence >= ", $LintMinimumConfidence
    ]
];

LintFiles[files_List] := Scan[lintFile, files];
LintFiles[file_String] := LintFiles[{file}];
