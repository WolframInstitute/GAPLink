(* Upstream tests run in temporary directories. No downloads are made. *)
runCoverage[] := Module[
    {source, executable, output, files, names, catalog, checks, exclusions, unsafe,
     scratch, original, session, checker, code, result, rows = {}, differences, status, i = 0, version, functionNames, launcher},
    source = ExpandFileName[setting["GAPLINK_SOURCE"]];
    executable = ExpandFileName[setting["GAPLINK_GAP"]];
    scriptRequire[FileNameJoin[{source, "tst", "teststandard"}], DirectoryQ,
        "GAPLINK_SOURCE must point to the matching GAP source tree"];
    output = FileNameJoin[{buildDirectory, "coverage"}];
    If[!DirectoryQ[output], CreateDirectory[output, CreateIntermediateDirectories -> True]];
    launcher = FileNameJoin[{output, "gap-coverage"}];
    result = RunProcess[{"python3", FileNameJoin[{scriptDirectory, "coverage.py"}],
        "--launcher", executable, source, launcher}];
    scriptRequire[result["ExitCode"], # === 0 &, result["StandardError"]];
    executable = launcher;
    loadSource[];
    session = WolframInstitute`GAPLink`StartGAPSession["Executable" -> executable];
    scriptRequire[session, !FailureQ[#] &, "Could not start GAP"];
    version = session["Version"];
    files = Flatten[FileNames[{"*.xml", "*.gd", "*.gi", "*.g"}, FileNameJoin[{source, #}], Infinity] & /@
        {"doc/ref", "lib", "grp"}];
    names = Sort @ DeleteDuplicates @ Flatten[
        StringCases[ReadString[#], RegularExpression["<(?:Func|Oper|Attr|Prop|Filt)\\s+Name=[\"']([^\"']+)[\"']"] -> "$1"] & /@ files];
    (* GAP escapes operator names in its documentation, but globals use the operator itself. *)
    names = StringReplace[#, {"&lt;" -> "<", "&gt;" -> ">", "&amp;" -> "&", "\\" -> ""}] & /@ names;
    checker = WolframInstitute`GAPLink`GAPEvaluate[session,
        "name -> IsFunction(GAPLinkNamedFunction(name));"];
    checks = WolframInstitute`GAPLink`GAPCall[session, "List", names, checker];
    scriptRequire[checks, MatchQ[#, { (True | False) ..}] &, "Could not check documented function names"];
    functionNames = Pick[names, checks, True];
    catalog = <|"GAPVersion" -> version, "Documented" -> Length[names],
        "Callable" -> functionNames, "Unavailable" -> Pick[names, checks, False]|>;
    Export[FileNameJoin[{output, "functions.json"}], catalog, "RawJSON"];
    DeleteObject[session];
    Print["Documented functions available: ", Length[functionNames], "/", Length[names]];

    files = Sort @ Flatten[FileNames["*.tst", FileNameJoin[{source, "tst", #}], Infinity] & /@
        {"testinstall", "teststandard"}];
    unsafe = RegularExpression["\\b(?:Exec|QUIT|QuitGap|ForceQuitGap|SaveWorkspace|LoadWorkspace|Edit|Pager|RemoveFile|FileString|Process|InputOutputLocalProcess|ChangeDirectoryCurrent)\\s*\\("];
    exclusions = Select[files, StringContainsQ[ReadString[#], unsafe] &];
    files = Complement[files, exclusions];
    code = "GAPLinkCoverageTest := function(path) local diffs; diffs := []; " <>
        "Test(path, rec(showProgress := false, compareFunction := \"uptowhitespace\", " <>
        "reportDiff := function(input, expected, actual, file, line, time) " <>
        "Add(diffs, [line, input, expected, actual]); end)); " <>
        "return rec(Differences := String(diffs), Inputs := Length(TEST.lastTestData[1])); end;;";
    Export[FileNameJoin[{output, "helper.g"}], code, "Text"];
    Scan[DeleteFile, FileNames["case-*.json", output]];
    original = Directory[];
    scratch = CreateDirectory[];
    WithCleanup[
        SetDirectory[scratch];
        Do[
            i++;
            session = WolframInstitute`GAPLink`StartGAPSession["Executable" -> executable];
            If[FailureQ[session], scriptFail["GAP startup failed: ", file]];
            result = WithCleanup[
                WolframInstitute`GAPLink`GAPEvaluate[session,
                    code,
                    "Output" -> "Discard"];
                WolframInstitute`GAPLink`GAPCall[session, "GAPLinkCoverageTest", file,
                    "Output" -> "Capture", TimeConstraint -> 60],
                DeleteObject[session]
            ];
            differences = If[AssociationQ[result] && AssociationQ[result["Result"]],
                result["Result"]["Differences"], result];
            status = If[MemberQ[{"[  ]", "[]"}, differences], "Passed", "Review"];
            If[status === "Passed" && result["Result"]["Inputs"] === 0, status = "NotApplicable"];
            If[status === "Review",
                Export[FileNameJoin[{output, "case-" <> ToString[i] <> ".json"}],
                    <|"File" -> file, "Differences" -> If[StringQ[differences], differences, Null],
                      "Bridge" -> If[FailureQ[result], ToString[result, InputForm], result]|>, "RawJSON"]
            ];
            AppendTo[rows, <|"File" -> FileNameDrop[file, Length[FileNameSplit[source]]], "Status" -> status,
                "Inputs" -> If[AssociationQ[result] && AssociationQ[result["Result"]], result["Result"]["Inputs"], 0]|>];
            Print[i, "/", Length[files], " ", status, " ", Last[rows]["File"]];
            Export[FileNameJoin[{output, "tests.json"}], rows, "RawJSON"],
            {file, files}
        ],
        SetDirectory[original];
        If[MatchQ[session, _WolframInstitute`GAPLink`GAPSession], DeleteObject[session]];
        DeleteDirectory[scratch, DeleteContents -> True]
    ];
    Export[FileNameJoin[{output, "summary.json"}], <|
        "GAPVersion" -> version, "Tests" -> Counts[Lookup[rows, "Status"]],
        "Inputs" -> Total[Lookup[rows, "Inputs"]],
        "Excluded" -> (FileNameDrop[#, Length[FileNameSplit[source]]] & /@ exclusions),
        "ExclusionReason" -> "Tests that launch programs, quit GAP, or manipulate external files need a separate harness."
    |>, "RawJSON"];
    Print[Counts[Lookup[rows, "Status"]]];
    Print["Bridge sweep complete; native comparisons run next."]
];
