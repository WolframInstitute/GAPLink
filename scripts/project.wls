#!/usr/bin/env wolframscript

Get[FileNameJoin[{DirectoryName[$InputFileName], "common.wl"}]];
Get[FileNameJoin[{scriptDirectory, "check.wl"}]];
Get[FileNameJoin[{scriptDirectory, "platforms.wl"}]];

systems = {"Linux-x86-64", "MacOSX-ARM64", "MacOSX-x86-64", "Windows-x86-64"};

setting[name_String] := scriptRequire[Environment[name],
    StringQ[#] && StringTrim[#] =!= "" &, name, " is not set"];

runOfflineTests[] := (
    scriptRequire[
        RunProcess[{"python3", "-m", "unittest", "discover", "-s", FileNameJoin[{scriptDirectory, "tests"}]}],
        Function[result, Print[result["StandardError"]]; result["ExitCode"] === 0],
        "Python tests failed"
    ];
    loadSource[];
    runTests @ Join[
        FileNames["*.wlt", FileNameJoin[{pacletDirectory, "Tests"}]],
        FileNames["*.wlt", FileNameJoin[{scriptDirectory, "tests"}]]
    ]
);

runGAPTests[] := (
    loadSource[];
    runTests @ FileNames["*.wlt", FileNameJoin[{pacletDirectory, "Tests", "Integration"}]]
);

loadPublishing[] := Module[{page, parser, converter},
    page = FileNameJoin[{repositoryRoot, ".deps", "PacletPage"}];
    parser = FileNameJoin[{repositoryRoot, ".deps", "WolframParser", "Parser"}];
    converter = FileNameJoin[{repositoryRoot, ".deps", "MarkdownToNotebook", "MarkdownToNotebook.wl"}];
    Scan[scriptRequire[#, FileExistsQ, "Run make deps; missing ", #] &,
        {FileNameJoin[{page, "PacletInfo.wl"}], FileNameJoin[{parser, "PacletInfo.wl"}], converter}];
    PacletDirectoryLoad[page];
    PacletDirectoryLoad[parser];
    Needs["Wolfram`Parser`"];
    Needs["WolframInstitute`PacletPage`"];
    {
        "Source" -> FileNameJoin[{repositoryRoot, "docs", "en"}],
        "Definition" -> FileNameJoin[{repositoryRoot, "docs", "ResourceDefinition.md"}],
        "Converter" -> converter, "Dependencies" -> {parser},
        "Parallel" -> False, "TimeConstraint" -> 180, "Prune" -> True
    }
];

(* Child kernels use the entitlement-aware launcher in CI. *)
SetAttributes[withEntitledKernels, HoldFirst];
withEntitledKernels[body_] := Internal`InheritedBlock[{RunProcess, StartProcess},
    Unprotect[RunProcess, StartProcess];
    DownValues[RunProcess] = Prepend[DownValues[RunProcess],
        HoldPattern[RunProcess[{kernel_String, "-noprompt", "-script", file_String}, arguments___] /;
            FileBaseName[kernel] === "WolframKernel"] :>
            RunProcess[{"wolframscript", "-file", file}, arguments,
                ProcessEnvironment -> Append[Association[GetEnvironment[]], "WOLFRAMSCRIPT_KERNELPATH" -> kernel]]];
    DownValues[StartProcess] = Prepend[DownValues[StartProcess],
        HoldPattern[StartProcess[{kernel_String, "-noprompt", "-script", file_String}, options___] /;
            FileBaseName[kernel] === "WolframKernel"] :>
            StartProcess[{"wolframscript", "-file", file}, options,
                ProcessEnvironment -> Append[Association[GetEnvironment[]], "WOLFRAMSCRIPT_KERNELPATH" -> kernel]]];
    Protect[RunProcess, StartProcess];
    body
];

pageCall[name_String, arguments___] := If[
    StringQ[Environment["WOLFRAMSCRIPT_ENTITLEMENTID"]] && Environment["WOLFRAMSCRIPT_ENTITLEMENTID"] =!= "",
    withEntitledKernels[Symbol["WolframInstitute`PacletPage`" <> name][arguments]],
    Symbol["WolframInstitute`PacletPage`" <> name][arguments]
];

checkArchive[result_, load_: True] := (
    scriptRequire[result, AssociationQ, "PacletPage build failed: ", result];
    If[load, scriptRequire[result["Load"]["OK"], TrueQ, "Archive failed its fresh-kernel load check"]];
    scriptRequire[result["Documentation"]["Missing"], # === {} &, "Archive is missing documentation"];
    scriptRequire[result["Documentation"]["Flagged"], # === <||> &, "Archive has invalid documentation"];
    Print["OK: ", result["Pages"], " pages; ", result["Archive"]]
);

prepareBuild[] := Module[{executable, session, files, fingerprint, stamp, cache, incremental},
    loadSource[];
    executable = Replace[Environment["GAPLINK_GAP"], Except[_String] | "" -> Automatic];
    session = WolframInstitute`GAPLink`StartGAPSession["Executable" -> executable];
    scriptRequire[session, !FailureQ[#] &, "GAP is required to evaluate documentation examples: ", session];
    executable = WithCleanup[session["Executable"], DeleteObject[session]];
    (* Documentation examples use StartGAPSession[] in their fresh kernels. *)
    SetEnvironment["PATH" -> DirectoryName[executable] <>
        If[$OperatingSystem === "Windows", ";", ":"] <> Environment["PATH"]];
    files = Sort @ Select[Join[
        {FileNameJoin[{pacletDirectory, "PacletInfo.wl"}], $InputFileName,
         FileNameJoin[{scriptDirectory, "fetch-deps.sh"}]},
        Flatten[FileNames["*", FileNameJoin[{pacletDirectory, #}], Infinity] & /@ {"Kernel", "Resources"}],
        FileNames["*.md", FileNameJoin[{repositoryRoot, "docs", "en", "Guides"}], Infinity]
    ], FileType[#] === File &];
    fingerprint = Hash[{$Version, $SystemID, FileHash[executable, "SHA256"],
        FileHash[#, "SHA256"] & /@ files}, "SHA256", "HexString"];
    stamp = FileNameJoin[{pacletDirectory, "build", "build-context.txt"}];
    incremental = FileExistsQ[stamp] && StringTrim[ReadString[stamp]] === fingerprint;
    cache = FileNameJoin[{pacletDirectory, "build", "cache"}];
    If[!incremental && DirectoryQ[cache], DeleteDirectory[cache, DeleteContents -> True]];
    <|"Fingerprint" -> fingerprint, "Stamp" -> stamp, "Incremental" -> incremental|>
];

buildPaclet[] := Module[{options = loadPublishing[], context, result, archive, destination},
    context = prepareBuild[];
    result = Block[{$CloudConnected = False},
        pageCall["PublishPacletPage", pacletDirectory, "GAPLink", "DryRun" -> True,
            "BuildOptions" -> options,
            "ResourceOptions" -> {"Parallel" -> False, "Incremental" -> context["Incremental"]},
            "Monitor" -> True]
    ];
    scriptRequire[result, AssociationQ, "PacletPage build failed"];
    scriptRequire[result["Build"]["Failed"], # === {} &, "Documentation build failed"];
    scriptRequire[result["Build"]["Unevaluated"], # === <||> &, "Documentation examples did not evaluate"];
    checkArchive[result["Resource"]];
    archive = result["Resource"]["Archive"];
    If[!DirectoryQ[buildDirectory], CreateDirectory[buildDirectory]];
    destination = archivePath[PacletObject[File[pacletDirectory]]["Version"]];
    CopyFile[archive, destination, OverwriteTarget -> True];
    Export[context["Stamp"], context["Fingerprint"], "Text"];
    writeGitHubOutput["version" -> PacletObject[File[pacletDirectory]]["Version"]];
    destination
];

verifyPaclet[] := Module[{result},
    loadPublishing[];
    result = Block[{$CloudConnected = False},
        pageCall["DeployPacletResource", pacletDirectory, "DryRun" -> True,
            "Build" -> False, "Parallel" -> False]];
    checkArchive[result];
    result
];

releaseTag[environment_Association, version_String] := Module[{tag},
    tag = Lookup[environment, "GITHUB_REF_NAME", ""];
    scriptRequire[Lookup[environment, {"GITHUB_ACTIONS", "GITHUB_EVENT_NAME", "GITHUB_REF_TYPE"}],
        # === {"true", "push", "tag"} &, "Publishing requires a release-tag workflow"];
    scriptRequire[tag, StringMatchQ[#, RegularExpression["v(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)"]] &&
        # === "v" <> version && Lookup[environment, "GITHUB_REF"] === "refs/tags/" <> # &,
        "The release tag must match PacletInfo.wl"]
];

gitText[arguments__String] := Module[{result},
    result = RunProcess[{"git", "-C", repositoryRoot, arguments}];
    scriptRequire[result["ExitCode"], # === 0 &, "Git could not verify the release checkout"];
    StringTrim[result["StandardOutput"]]
];

checkRelease[environment_Association : Association[GetEnvironment[]]] := Module[{tag, commit},
    tag = releaseTag[environment, PacletObject[File[pacletDirectory]]["Version"]];
    commit = gitText["rev-parse", "HEAD"];
    scriptRequire[gitText["rev-parse", "refs/tags/" <> tag <> "^{commit}"], # === commit &,
        "The tag does not point to HEAD"];
    scriptRequire[Lookup[environment, "GITHUB_SHA"], StringQ, "The workflow commit is missing"];
    scriptRequire[gitText["rev-parse", environment["GITHUB_SHA"] <> "^{commit}"], # === commit &,
        "The checkout differs from the workflow commit"];
    scriptRequire[RunProcess[{"git", "-C", repositoryRoot, "merge-base", "--is-ancestor", "HEAD", "origin/main"}]["ExitCode"],
        # === 0 &, "The release commit is not on main"];
    scriptRequire[gitText["status", "--porcelain"], # === "" &, "The release checkout has uncommitted changes"];
    commit
];

publish[] := Module[{commit, account, password, paclet, archives, result, resources},
    commit = checkRelease[];
    paclet = PacletObject[File[pacletDirectory]];
    archives = platformArchives[paclet["Version"]];
    verifyPaclet[];
    account = setting["WOLFRAM_CLOUD_USER"];
    password = setting["WOLFRAM_CLOUD_PASSWORD"];
    scriptRequire[Quiet @ Check[CloudConnect[account, password], $Failed], # =!= $Failed &,
        "Could not connect to Wolfram Cloud"];
    scriptRequire[$CloudConnected, TrueQ, "Could not connect to Wolfram Cloud"];
    result = pageCall["PublishPacletPage", pacletDirectory, "GAPLink", "Account" -> account,
        "Build" -> False, "ResourceOptions" -> {"Build" -> False, "Parallel" -> False, "Commit" -> commit},
        "Monitor" -> True];
    scriptRequire[result, AssociationQ, "PacletPage publication failed"];
    scriptRequire[result["Resource"]["Deployed"], TrueQ, "PacletPage resource was not published"];
    scriptRequire[result["Check"]["OK"], TrueQ, "Published documentation did not pass its checks"];
    resources = Association @ KeyValueMap[#1 -> publishPlatform[#2, #1, paclet, commit] &, archives];
    attachPlatforms[result["Resource"]["Resource"], resources, paclet["Version"], commit];
    scriptRequire[Quiet @ Check[ResourceObject[result["Resource"]["Resource"]]["PacletFile"], $Failed],
        # === resources[$SystemID]["PacletFile"] &, "The resource did not select the matching platform archive"];
    writeGitHubOutput["archives" -> Length[archives], "page" -> result["Resource"]["Resource"],
        "site" -> result["Site"]["Site"]];
    Print["OK: ", result["Resource"]["Resource"]];
    Print["OK: ", result["Site"]["Site"]]
];

buildBundle[system_String, runtime_String] := Module[{stage, source, target, info, result, archive},
    scriptRequire[system, MemberQ[systems, #] &, "Unsupported system: ", system];
    scriptRequire[FileNameJoin[{runtime, If[StringStartsQ[system, "Windows"], "gap.bat", "gap"]}],
        FileExistsQ, "Runtime executable not found: ", runtime];
    loadPublishing[];
    stage = FileNameJoin[{buildDirectory, "bundles", system, "source"}];
    If[!DirectoryQ[stage], CreateDirectory[stage, CreateIntermediateDirectories -> True]];
    Scan[Function[name,
        source = FileNameJoin[{pacletDirectory, name}];
        target = FileNameJoin[{stage, name}];
        scriptRequire[source, FileExistsQ, "Run make build first; missing ", source];
        If[DirectoryQ[source],
            If[DirectoryQ[target], DeleteDirectory[target, DeleteContents -> True]];
            CopyDirectory[source, target],
            CopyFile[source, target, OverwriteTarget -> True]
        ]
    ], {"Kernel", "Resources", "Documentation", "Tests", "ResourceDefinition.nb"}];
    info = KeyDrop[First[PacletObject[File[pacletDirectory]]], "Location"];
    info = Join[info, <|"Qualifier" -> system, "SystemID" -> system,
        "Extensions" -> Append[info["Extensions"],
            {"Asset", "Root" -> "Resources", "Assets" -> {{"GAPRuntime", "Runtime"}}}]|>];
    Put[PacletObject[info], FileNameJoin[{stage, "PacletInfo.wl"}]];
    scriptRequire[CopyDirectory[runtime, FileNameJoin[{stage, "Resources", "Runtime"}]],
        StringQ, "Could not copy runtime: ", runtime];
    (* Reuse the verified documentation build for every platform. PacletPage
       still checks its hashes, creates the manifest, and packs each archive. *)
    Scan[Function[path,
        source = FileNameJoin[Join[{pacletDirectory, "build"}, path]];
        target = FileNameJoin[Join[{stage, "build"}, path]];
        scriptRequire[source, DirectoryQ, "Run make build first; missing ", source];
        If[DirectoryQ[target], DeleteDirectory[target, DeleteContents -> True]];
        If[!DirectoryQ[DirectoryName[target]],
            CreateDirectory[DirectoryName[target], CreateIntermediateDirectories -> True]];
        CopyDirectory[source, target]
    ], {{archivePrefix, "Documentation"}, {"incremental", archivePrefix}}];
    result = Block[{$CloudConnected = False},
        pageCall["DeployPacletResource", stage, "DryRun" -> True,
            "LoadCheck" -> (system === $SystemID), "Parallel" -> False,
            "Incremental" -> True, "Monitor" -> True]];
    checkArchive[result, system === $SystemID];
    archive = FileNameJoin[{DirectoryName[stage],
        StringRiffle[{archivePrefix, system, info["Version"]}, "-"] <> ".paclet"}];
    CopyFile[result["Archive"], archive, OverwriteTarget -> True];
    result = RunProcess[{"python3", FileNameJoin[{scriptDirectory, "verify-runtime.py"}], archive, runtime}];
    Print[result["StandardOutput"]];
    scriptRequire[result["ExitCode"], # === 0 &, result["StandardError"]];
    Print["OK: ", archive];
    archive
];

verifyBundle[] := Module[
    {
        archive, call, context, directory, executable, expected, loadPackage,
        install, paclet, package, root, runtime, session = None, start
    },
    archive = FileNameJoin[{buildDirectory, "bundles", $SystemID,
        StringRiffle[{archivePrefix, $SystemID,
            PacletObject[File[pacletDirectory]]["Version"]}, "-"] <> ".paclet"}];
    scriptRequire[archive, FileExistsQ, "Run make bundle first"];
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
];

verifyBundleInFreshKernel[] := Module[{result},
    result = RunProcess[{"wolframscript", "-file",
        FileNameJoin[{scriptDirectory, "project.wls"}], "verify-bundle"}];
    Print[result["StandardOutput"]];
    scriptRequire[result["ExitCode"], # === 0 &, result["StandardError"], "Bundle verification failed"]
];

runCI[] := Module[{gapRoot, runtimeRoot, versions},
    gapRoot = FileNameJoin[{buildDirectory, "gap-versions"}];
    runtimeRoot = FileNameJoin[{buildDirectory, "ci-runtimes"}];
    SetEnvironment["GAPLINK_GAP" -> FileNameJoin[{runtimeRoot, $SystemID, "runtime", "gap"}]];
    runCheck[];
    runOfflineTests[];
    versions = Sort[FileNameTake /@ Select[FileNames[All, gapRoot], DirectoryQ]];
    scriptRequire[versions, # =!= {} &, "No GAP versions found"];
    Scan[Function[version,
        SetEnvironment[{"GAPLINK_GAP" -> FileNameJoin[{gapRoot, version, "gap"}],
            "GAPLINK_EXPECTED_GAP_VERSION" -> version}];
        runGAPTests[]
    ], versions];
    SetEnvironment[{"GAPLINK_GAP" -> FileNameJoin[{runtimeRoot, $SystemID, "runtime", "gap"}],
        "GAPLINK_EXPECTED_GAP_VERSION" -> Last[versions]}];
    runGAPTests[];
    buildPaclet[];
    Scan[buildBundle[#, FileNameJoin[{runtimeRoot, #, "runtime"}]] &, systems];
    SetEnvironment["GAPLINK_VERIFY_INSTALL" -> "1"];
    verifyBundleInFreshKernel[]
];

command = If[Length[$ScriptCommandLine] > 1, $ScriptCommandLine[[2]], "all"];
Switch[command,
    "check", runCheck[],
    "test", runOfflineTests[],
    "test-gap", runGAPTests[],
    "sweep", Get[FileNameJoin[{scriptDirectory, "coverage.wl"}]]; runCoverage[],
    "build", buildPaclet[],
    "bundle", buildBundle[
        Replace[Environment["GAPLINK_SYSTEM_ID"], Except[_String] | "" -> $SystemID],
        Replace[Environment["GAPLINK_RUNTIME"], Except[_String] | "" :>
            FileNameJoin[{buildDirectory, "runtimes", $SystemID, "runtime"}]]],
    "verify", verifyPaclet[],
    "verify-bundle", verifyBundle[],
    "check-release", checkRelease[],
    "publish", publish[],
    "lint", lintFiles[Drop[$ScriptCommandLine, 2]],
    "all", runCheck[]; runOfflineTests[]; buildPaclet[],
    "ci", runCI[],
    _, scriptFail["Unknown command: ", command]
];
