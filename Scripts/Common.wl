(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{
    $RepositoryRoot, $PacletName, $PacletDirectory, $BuildDirectory, $GitHubActionsQ,
    LogInfo, LogNotice, LogWarning, LogError, LogGroup, RepositoryPath,
    ErrorCount, FinishScript, RunScript, LoadPaclet, CheckPacletInfoFile,
    WriteGitHubOutput, AppendStepSummary
}];

(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{$ArchivePrefix, ArchivePath, RequireOrLog, RunTask}];

(* ::Section:: *)
(*Usage Messages*)

$RepositoryRoot::usage = "$RepositoryRoot is the repository directory.";
$PacletName::usage = "$PacletName is the full paclet name.";
$PacletDirectory::usage = "$PacletDirectory is the paclet source directory.";
$BuildDirectory::usage = "$BuildDirectory is the build directory.";
$GitHubActionsQ::usage = "$GitHubActionsQ indicates whether GitHub Actions is running.";
$ArchivePrefix::usage = "$ArchivePrefix is the filename prefix used for built paclets.";
ArchivePath::usage = "ArchivePath[version] gives the path of a built paclet version.";
RequireOrLog::usage = "RequireOrLog[value, test, parts] logs and stops a failed script task.";
RunTask::usage = "RunTask[body] evaluates body until a required value fails.";
LogInfo::usage = "LogInfo[parts] prints information.";
LogNotice::usage = "LogNotice[parts] prints a notice.";
LogWarning::usage = "LogWarning[parts] prints a warning.";
LogError::usage = "LogError[parts] prints an error and marks the script as failed.";
LogGroup::usage = "LogGroup[title, body] evaluates body in a log group.";
RepositoryPath::usage = "RepositoryPath[file] gives a repository-relative path.";
ErrorCount::usage = "ErrorCount[] gives the number of logged errors.";
FinishScript::usage = "FinishScript[] exits with a status determined by logged errors.";
RunScript::usage = "RunScript[f] runs f[] and exits with its logged status.";
LoadPaclet::usage = "LoadPaclet[] loads the paclet from source.";
CheckPacletInfoFile::usage = "CheckPacletInfoFile[] checks PacletInfo.wl syntax.";
WriteGitHubOutput::usage = "WriteGitHubOutput[rules] writes GitHub Actions step outputs.";
AppendStepSummary::usage = "AppendStepSummary[markdown] appends to the Actions summary.";

(* ::Section:: *)
(*Function Definitions*)

normalizePath[path_String] := FileNameJoin @ FileNameSplit @ ExpandFileName[path];

$RepositoryRoot = normalizePath @ DirectoryName[ExpandFileName[$InputFileName], 2];
$PacletName = "WolframInstitute/GAPLink";
$PacletDirectory = FileNameJoin[{$RepositoryRoot, "GAPLink"}];
$BuildDirectory = FileNameJoin[{$RepositoryRoot, "build"}];
$GitHubActionsQ = Environment["GITHUB_ACTIONS"] === "true";
$ArchivePrefix = StringReplace[$PacletName, "/" -> "__"];

ArchivePath[version_String] := FileNameJoin[{
    $BuildDirectory,
    $ArchivePrefix <> "-" <> version <> ".paclet"
}];

RepositoryPath[file_String] := Module[
    {rootParts = FileNameSplit[$RepositoryRoot], fileParts = FileNameSplit[normalizePath[file]]},
    FileNameJoin @ Drop[fileParts, Length[rootParts]]
];

$errorCount = 0;

toText[text_String] := text;
toText[expr_] := ToString[expr, InputForm];
joinText[parts___] := StringJoin[toText /@ {parts}];
locationQ[location_] := AssociationQ[location] && KeyExistsQ[location, "File"];

escapeData[text_String] := StringReplace[text, {
    "%" -> "%25", "\r" -> "%0D", "\n" -> "%0A"
}];

escapeProperty[text_String] := StringReplace[text, {
    "%" -> "%25", "\r" -> "%0D", "\n" -> "%0A", ":" -> "%3A", "," -> "%2C"
}];

locationProperties[location_] := StringRiffle[DeleteMissing @ {
    "file=" <> escapeProperty[RepositoryPath[location["File"]]],
    If[IntegerQ[location["Line"]], "line=" <> ToString[location["Line"]], Missing[]],
    If[IntegerQ[location["Column"]], "col=" <> ToString[location["Column"]], Missing[]]
}, ","];

locationText[location_] := StringJoin[
    RepositoryPath[location["File"]],
    If[IntegerQ[location["Line"]], ":" <> ToString[location["Line"]], ""],
    If[IntegerQ[location["Column"]], ":" <> ToString[location["Column"]], ""],
    ": "
];

emit[command_String, label_String, location_, parts___] := Print @ If[
    $GitHubActionsQ,
    StringJoin[
        "::", command,
        If[locationQ[location], " " <> locationProperties[location], ""],
        "::", escapeData[joinText[parts]]
    ],
    StringJoin[
        label, ": ",
        If[locationQ[location], locationText[location], ""],
        joinText[parts]
    ]
];

log[command_String, label_String, location_?locationQ, parts___] :=
    emit[command, label, location, parts];
log[command_String, label_String, parts___] := emit[command, label, None, parts];

LogInfo[parts___] := Print[joinText[parts]];
LogNotice[parts___] := log["notice", "NOTICE", parts];
LogWarning[parts___] := log["warning", "WARNING", parts];
LogError[parts___] := ($errorCount++; log["error", "ERROR", parts]);

SetAttributes[LogGroup, HoldRest];
LogGroup[title_String, body_] := (
    If[$GitHubActionsQ, Print["::group::", title], Print["\n== ", title, " =="]];
    WithCleanup[body, If[$GitHubActionsQ, Print["::endgroup::"]]]
);

RequireOrLog[value_, test_, parts___] := If[
    TrueQ[test[value]],
    value,
    If[{parts} =!= {}, LogError[parts]];
    Throw[$Failed, "ScriptTaskFailure"]
];

SetAttributes[RunTask, HoldFirst];
RunTask[body_] := Catch[body, "ScriptTaskFailure"];

ErrorCount[] := $errorCount;

FinishScript[] := If[
    $errorCount > 0,
    Print["\nFAILED: ", $errorCount, " error(s)."]; Exit[1],
    Print["\nOK."]; Exit[0]
];

RunScript[f_] := (f[]; FinishScript[]);

CheckPacletInfoFile[] := Module[
    {file = FileNameJoin[{$PacletDirectory, "PacletInfo.wl"}], expressions},
    If[!FileExistsQ[file],
        LogError["PacletInfo.wl is missing from ", RepositoryPath[$PacletDirectory]];
        Return[False]
    ];
    expressions = Quiet @ Check[ReadList[file, Hold[Expression]], $Failed];
    Which[
        expressions === $Failed || MemberQ[expressions, $Failed],
            LogError[<|"File" -> file|>, "PacletInfo.wl has a syntax error"];
            False,
        !MatchQ[expressions, {Hold[_PacletObject]}],
            LogError[
                <|"File" -> file|>,
                "PacletInfo.wl must contain one PacletObject expression; found ",
                Length[expressions]
            ];
            False,
        True,
            True
    ]
];

LoadPaclet[] := RunTask @ Module[{paclet, resolved, context, loaded},
    paclet = PacletObject[File[$PacletDirectory]];
    RequireOrLog[
        paclet,
        PacletObjectQ,
        "cannot read a paclet from ", $PacletDirectory, ": ", paclet
    ];
    PacletDirectoryLoad[$PacletDirectory];
    resolved = PacletObject[$PacletName];
    If[
        PacletObjectQ[resolved] && StringQ[resolved["Location"]] &&
            normalizePath[resolved["Location"]] =!= normalizePath[$PacletDirectory],
        LogWarning[
            $PacletName, " resolves to ", resolved["Location"],
            " instead of this checkout; uninstall the installed copy to test the checkout"
        ]
    ];
    context = paclet["PrimaryContext"];
    RequireOrLog[context, StringQ, "PacletInfo.wl does not declare PrimaryContext"];
    loaded = Check[Needs[context], $Failed];
    RequireOrLog[
        loaded,
        # =!= $Failed &,
        "Needs[\"", context, "\"] generated messages: ", $MessageList
    ];
    paclet
];

appendToFile[variable_String, lines_List] := With[{file = Environment[variable]},
    If[StringQ[file],
        With[{stream = OpenAppend[file]},
            WithCleanup[
                WriteString[stream, StringRiffle[lines, "\n"], "\n"],
                Close[stream]
            ]
        ]
    ]
];

WriteGitHubOutput[rules__Rule] := appendToFile[
    "GITHUB_OUTPUT",
    (First[#] <> "=" <> toText[Last[#]]) & /@ {rules}
];

AppendStepSummary[markdown_String] := appendToFile["GITHUB_STEP_SUMMARY", {markdown}];
