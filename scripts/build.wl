(* ::Package:: *)

PackageImport["PacletTools`"]

(* ::Section:: *)
(*PackageExported*)

PackageExported[{BuildPaclet, VerifyPaclet, BuildBundle, VerifyBundle, RunCI}];

(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{loadPublishing, pageCall, withEntitledKernels, checkArchive, bundleArchivePath, $archiveExclusions}];

(* ::Section:: *)
(*Usage Messages*)

BuildPaclet::usage = "BuildPaclet[] builds the documentation and the paclet archive with PacletPage, checks the archive, copies it to the build \
directory and gives its path. The documentation examples are evaluated against GAP.";
VerifyPaclet::usage = "VerifyPaclet[] checks the archive that PacletPage built, without building it again, and gives the result of PacletPage.";
BuildBundle::usage = "BuildBundle[] builds the archive with a GAP runtime for the system that GAPLINK_SYSTEM_ID names, from the runtime directory \
that GAPLINK_RUNTIME names. Without them it uses this system and its runtime in the build directory.\n\
BuildBundle[system, runtime] builds the archive for the system ID from the runtime directory, and gives the path of the archive.";
VerifyBundle::usage = "VerifyBundle[] checks the archive with a GAP runtime for this system: it validates, loads, starts its own GAP and runs a \
call. With GAPLINK_VERIFY_INSTALL set to 1 it installs the archive first.";
RunCI::usage = "RunCI[] runs what continuous integration runs: the checks, the tests without GAP, the tests with each GAP version and with the \
built runtime, the paclet build, the archive of every system, and the installed archive of this system in a fresh kernel.";
$archiveExclusions::usage = "$archiveExclusions lists the file patterns that PacletPage leaves out of an archive.";
loadPublishing::usage = "loadPublishing[] loads the pinned PacletPage tools under .deps and gives the options for a documentation build.";
entitlementQ::usage = "entitlementQ[] gives True when WOLFRAMSCRIPT_ENTITLEMENTID is set, as it is in continuous integration.";
entitledEnvironment::usage = "entitledEnvironment[kernel] gives the environment of the current process with WOLFRAMSCRIPT_KERNELPATH set to the \
kernel.";
kernelLauncherQ::usage = "kernelLauncherQ[command] gives True when the command is a path to a WolframKernel executable.";
entitledRunProcess::usage = "entitledRunProcess[kernel, file, arguments] runs the script file with wolframscript, for the kernel, and gives the \
process result.";
entitledStartProcess::usage = "entitledStartProcess[kernel, file, options] starts the script file with wolframscript, for the kernel, with the \
options.";
$runProcessOverride::usage = "$runProcessOverride is the rule that has RunProcess start a WolframKernel script through wolframscript.";
$startProcessOverride::usage = "$startProcessOverride is the rule that has StartProcess start a WolframKernel script through wolframscript.";
setLauncherDownValues::usage = "setLauncherDownValues[runDownValues, startDownValues] sets the definitions of RunProcess and StartProcess.";
withEntitledKernels::usage = "withEntitledKernels[body] evaluates body with the launch of WolframKernel scripts by RunProcess and StartProcess \
replaced by wolframscript, so that a fresh kernel finds the on-demand entitlement. It restores both functions afterwards.";
pacletPageFunction::usage = "pacletPageFunction[name] gives the PacletPage function of the given name, once PacletPage is loaded.";
pageCall::usage = "pageCall[name, arguments] calls the PacletPage function name with the arguments, through entitled kernels when an entitlement \
is set.";
checkArchive::usage = "checkArchive[result, loadCheckQ] checks the result that PacletPage gave for an archive: its fresh-kernel load check when \
loadCheckQ is True, its documentation, and its contents with verify-runtime.py. It stops the current task when a check fails.";
buildInputFiles::usage = "buildInputFiles[] lists the files that decide whether a build can reuse the documentation cache: the paclet metadata, \
the kernel, the resources, the guide pages and the scripts.";
prepareBuild::usage = "prepareBuild[] loads the paclet, finds GAP and puts it on PATH for the documentation examples. It gives an association \
with the \"Fingerprint\" of the build inputs, the \"Stamp\" file that records it, and whether the build is \"Incremental\".";
replaceDirectory::usage = "replaceDirectory[source, target] copies the directory source to target, in place of any directory that is there.";
stageSource::usage = "stageSource[stage, name] copies the file or directory name of the paclet into the stage directory.";
stageBuild::usage = "stageBuild[stage, path] copies a directory of the paclet's build output, given as a list of path parts, into the stage \
directory.";
bundleInfo::usage = "bundleInfo[system] gives the paclet metadata for the archive of a system, as an association with the runtime asset added.";
bundleArchivePath::usage = "bundleArchivePath[system, version] gives the path of the archive with a GAP runtime for a system and version.";
installedBundle::usage = "installedBundle[archive] installs the archive and gives an association with the \"Paclet\" and its \"Directory\".";
extractedBundle::usage = "extractedBundle[archive, root] extracts the archive into root and gives an association with the \"Paclet\" and its \
\"Directory\".";
verifyBundledSession::usage = "verifyBundledSession[executable, expected] starts GAP from the loaded bundle, checks that it is the GAP at \
executable with the expected version, runs a call and loads a package, and gives the GAP version.";
verifyBundleInFreshKernel::usage = "verifyBundleInFreshKernel[] runs the verify-bundle command in a fresh kernel and stops the current task when \
it fails.";
testGAPVersion::usage = "testGAPVersion[gapRoot, version] runs the tests that need GAP with the GAP version found under gapRoot.";

(* ::Section:: *)
(*Function Definitions*)

$archiveExclusions = {"Tests", "Tests/*"};

loadPublishing[] :=
	Module[{page, parser, converter},
		page = FileNameJoin[{$RepositoryRoot, ".deps", "PacletPage"}];
		parser = FileNameJoin[{$RepositoryRoot, ".deps", "WolframParser", "Parser"}];
		converter = FileNameJoin[{$RepositoryRoot, ".deps", "MarkdownToNotebook", "MarkdownToNotebook.wl"}];
		Scan[
			RequireOrLog[#, FileExistsQ, "Run make deps; missing ", #] &,
			{FileNameJoin[{page, "PacletInfo.wl"}], FileNameJoin[{parser, "PacletInfo.wl"}], converter}
		];
		PacletDirectoryLoad[page];
		PacletDirectoryLoad[parser];
		Needs["Wolfram`Parser`"];
		Needs["WolframInstitute`PacletPage`"];
		{
			"Source" -> FileNameJoin[{$RepositoryRoot, "docs", "en"}],
			"Definition" -> FileNameJoin[{$RepositoryRoot, "docs", "ResourceDefinition.md"}],
			"Converter" -> converter,
			"Dependencies" -> {parser},
			"Parallel" -> False,
			"TimeConstraint" -> 180,
			"Prune" -> True
		}
	]

entitlementQ[] := StringQ[Environment["WOLFRAMSCRIPT_ENTITLEMENTID"]] && Environment["WOLFRAMSCRIPT_ENTITLEMENTID"] =!= ""

(* PacletPage starts its build and archive checks with WolframKernel -script. An on-demand entitlement belongs to
   wolframscript, so in continuous integration those processes must use that launcher. *)
kernelLauncherQ[command_String] := FileBaseName[command] === "WolframKernel"

entitledEnvironment[kernel_String] := Append[Association[GetEnvironment[]], "WOLFRAMSCRIPT_KERNELPATH" -> kernel]

entitledRunProcess[kernel_String, file_String, arguments___] :=
	RunProcess[{"wolframscript", "-file", file}, arguments, ProcessEnvironment -> entitledEnvironment[kernel]]

entitledStartProcess[kernel_String, file_String, options___] :=
	StartProcess[{"wolframscript", "-file", file}, options, ProcessEnvironment -> entitledEnvironment[kernel]]

$runProcessOverride = HoldPattern[RunProcess[{kernel_String, "-noprompt", "-script", file_String}, arguments___] /; kernelLauncherQ[kernel]] :> entitledRunProcess[kernel, file, arguments];

$startProcessOverride = HoldPattern[StartProcess[{kernel_String, "-noprompt", "-script", file_String}, options___] /; kernelLauncherQ[kernel]] :> entitledStartProcess[kernel, file, options];

setLauncherDownValues[runDownValues_List, startDownValues_List] := (
	Unprotect[RunProcess, StartProcess];
	DownValues[RunProcess] = runDownValues;
	DownValues[StartProcess] = startDownValues;
	Protect[RunProcess, StartProcess]
)

SetAttributes[withEntitledKernels, HoldFirst];
(* allow BarePattern: body is any expression, held until the overrides are in place *)
withEntitledKernels[body_] :=
	Module[{savedRunProcess, savedStartProcess},
		savedRunProcess = DownValues[RunProcess];
		savedStartProcess = DownValues[StartProcess];
		WithCleanup[
			setLauncherDownValues[Prepend[savedRunProcess, $runProcessOverride], Prepend[savedStartProcess, $startProcessOverride]],
			body,
			setLauncherDownValues[savedRunProcess, savedStartProcess]
		]
	]

pacletPageFunction[name_String] := Symbol["WolframInstitute`PacletPage`" <> name]

pageCall[name_String, arguments___] :=
	If[entitlementQ[],
		withEntitledKernels[pacletPageFunction[name][arguments]],

		pacletPageFunction[name][arguments]
	]

checkArchive[result_Association, loadCheckQ : (True | False)] :=
	Module[{contentCheck},
		If[loadCheckQ, RequireOrLog[result["Load"]["OK"], TrueQ, "Archive failed its fresh-kernel load check"]];
		RequireOrLog[result["Documentation"]["Missing"], # === {} &, "Archive is missing documentation"];
		RequireOrLog[result["Documentation"]["Flagged"], # === <||> &, "Archive has invalid documentation"];
		contentCheck = pythonScript["verify-runtime.py", {"--archive", result["Archive"]}];
		RequireOrLog[contentCheck["ExitCode"], # === 0 &, contentCheck["StandardError"]];
		LogInfo["OK: ", result["Pages"], " pages; ", result["Archive"]]
	]
checkArchive[result_, (True | False)] := failTask["PacletPage build failed: ", result]

buildInputFiles[] :=
	Sort @ Select[
		Join[
			{FileNameJoin[{$PacletDirectory, "PacletInfo.wl"}], FileNameJoin[{$ScriptsDirectory, "fetch-deps.sh"}]},
			FileNames[{"*.wl", "*.wls"}, $ScriptsDirectory],
			FileNames["*", FileNameJoin[{$PacletDirectory, "Kernel"}], Infinity],
			FileNames["*", FileNameJoin[{$PacletDirectory, "Resources"}], Infinity],
			FileNames["*.md", FileNameJoin[{$RepositoryRoot, "docs", "en", "Guides"}], Infinity]
		],
		FileType[#] === File &
	]

prepareBuild[] :=
	Module[{requested, session, executable, files, fingerprint, stamp, incrementalQ, cache},
		LoadPaclet[];
		requested = Replace[Environment["GAPLINK_GAP"], Except[_String] | "" -> Automatic];
		session = gapLinkFunction["StartGAPSession"]["Executable" -> requested];
		RequireOrLog[session, !FailureQ[#] &, "GAP is required to evaluate documentation examples: ", session];
		executable = WithCleanup[session["Executable"], DeleteObject[session]];
		(* Documentation examples use StartGAPSession[] in their fresh kernels. *)
		SetEnvironment["PATH" -> DirectoryName[executable] <> If[$OperatingSystem === "Windows", ";", ":"] <> Environment["PATH"]];
		files = buildInputFiles[];
		fingerprint = Hash[{$Version, $SystemID, FileHash[executable, "SHA256"], Map[FileHash[#, "SHA256"] &, files]}, "SHA256", "HexString"];
		stamp = FileNameJoin[{$PacletDirectory, "build", "build-context.txt"}];
		incrementalQ = FileExistsQ[stamp] && StringTrim[ReadString[stamp]] === fingerprint;
		cache = FileNameJoin[{$PacletDirectory, "build", "cache"}];
		If[!incrementalQ && DirectoryQ[cache], DeleteDirectory[cache, DeleteContents -> True]];
		<|"Fingerprint" -> fingerprint, "Stamp" -> stamp, "Incremental" -> incrementalQ|>
	]

BuildPaclet[] :=
	Module[{options, buildContext, result, version, destination},
		options = loadPublishing[];
		buildContext = prepareBuild[];
		result = Block[{$CloudConnected = False},
			pageCall[
				"PublishPacletPage", $PacletDirectory, "GAPLink",
				"DryRun" -> True,
				"BuildOptions" -> options,
				"ResourceOptions" -> {"Parallel" -> False, "Incremental" -> buildContext["Incremental"], "Exclude" -> $archiveExclusions},
				"Monitor" -> True
			]
		];
		RequireOrLog[result, AssociationQ, "PacletPage build failed"];
		RequireOrLog[result["Build"]["Failed"], # === {} &, "Documentation build failed"];
		RequireOrLog[result["Build"]["Unevaluated"], # === <||> &, "Documentation examples did not evaluate"];
		checkArchive[result["Resource"], True];
		If[!DirectoryQ[$BuildDirectory], CreateDirectory[$BuildDirectory]];
		version = PacletObject[File[$PacletDirectory]]["Version"];
		destination = archivePath[version];
		CopyFile[result["Resource"]["Archive"], destination, OverwriteTarget -> True];
		Export[buildContext["Stamp"], buildContext["Fingerprint"], "Text"];
		WriteGitHubOutput["version" -> version];
		destination
	]
BuildPaclet[___] := invalidArgumentsFailure[BuildPaclet]

VerifyPaclet[] :=
	Module[{result},
		loadPublishing[];
		result = Block[{$CloudConnected = False},
			pageCall["DeployPacletResource", $PacletDirectory, "DryRun" -> True, "Build" -> False, "Parallel" -> False, "Exclude" -> $archiveExclusions]
		];
		checkArchive[result, True];
		result
	]
VerifyPaclet[___] := invalidArgumentsFailure[VerifyPaclet]

replaceDirectory[source_String, target_String] := (
	If[DirectoryQ[target], DeleteDirectory[target, DeleteContents -> True]];
	If[!DirectoryQ[DirectoryName[target]], CreateDirectory[DirectoryName[target], CreateIntermediateDirectories -> True]];
	CopyDirectory[source, target]
)

stageSource[stage_String, name_String] :=
	Module[{source, target},
		source = FileNameJoin[{$PacletDirectory, name}];
		target = FileNameJoin[{stage, name}];
		RequireOrLog[source, FileExistsQ, "Run make build first; missing ", source];
		If[DirectoryQ[source], replaceDirectory[source, target], CopyFile[source, target, OverwriteTarget -> True]]
	]

stageBuild[stage_String, path : {__String}] :=
	Module[{source, target},
		source = FileNameJoin[Join[{$PacletDirectory, "build"}, path]];
		target = FileNameJoin[Join[{stage, "build"}, path]];
		RequireOrLog[source, DirectoryQ, "Run make build first; missing ", source];
		replaceDirectory[source, target]
	]

bundleInfo[system_String] :=
	Module[{sourceInfo, runtimeAsset},
		sourceInfo = KeyDrop[First[PacletObject[File[$PacletDirectory]]], "Location"];
		runtimeAsset = {"Asset", "Root" -> "Resources", "Assets" -> {{"GAPRuntime", "Runtime"}}};
		Join[sourceInfo, <|"Qualifier" -> system, "SystemID" -> system, "Extensions" -> Append[sourceInfo["Extensions"], runtimeAsset]|>]
	]

bundleArchivePath[system_String, version_String] :=
	FileNameJoin[{$BuildDirectory, "bundles", system, StringRiffle[{$ArchivePrefix, system, version}, "-"] <> ".paclet"}]

BuildBundle[system_String, runtime_String] :=
	Module[{stage, staleTests, info, staged, result, archive, runtimeCheck},
		RequireOrLog[system, MemberQ[$systems, #] &, "Unsupported system: ", system];
		RequireOrLog[
			FileNameJoin[{runtime, If[StringStartsQ[system, "Windows"], "gap.bat", "gap"]}],
			FileExistsQ,
			"Runtime executable not found: ", runtime
		];
		loadPublishing[];
		stage = FileNameJoin[{$BuildDirectory, "bundles", system, "source"}];
		If[!DirectoryQ[stage], CreateDirectory[stage, CreateIntermediateDirectories -> True]];
		staleTests = FileNameJoin[{stage, "Tests"}];
		If[DirectoryQ[staleTests], DeleteDirectory[staleTests, DeleteContents -> True]];
		Scan[stageSource[stage, #] &, {"Kernel", "Resources", "Documentation", "ResourceDefinition.nb"}];
		info = bundleInfo[system];
		Put[PacletObject[info], FileNameJoin[{stage, "PacletInfo.wl"}]];
		staged = pythonScript["verify-runtime.py", {"--stage", runtime, FileNameJoin[{stage, "Resources", "Runtime"}]}];
		RequireOrLog[staged["ExitCode"], # === 0 &, staged["StandardError"]];
		(* Reuse the verified documentation build for every platform. PacletPage
		   still checks its hashes, creates the manifest, and packs each archive. *)
		Scan[stageBuild[stage, #] &, {{$ArchivePrefix, "Documentation"}, {"incremental", $ArchivePrefix}}];
		result = Block[{$CloudConnected = False},
			pageCall[
				"DeployPacletResource", stage,
				"DryRun" -> True,
				"LoadCheck" -> (system === $SystemID),
				"Parallel" -> False,
				"Incremental" -> True,
				"Monitor" -> True
			]
		];
		checkArchive[result, system === $SystemID];
		archive = bundleArchivePath[system, info["Version"]];
		CopyFile[result["Archive"], archive, OverwriteTarget -> True];
		runtimeCheck = pythonScript["verify-runtime.py", {archive, runtime}];
		LogInfo[runtimeCheck["StandardOutput"]];
		RequireOrLog[runtimeCheck["ExitCode"], # === 0 &, runtimeCheck["StandardError"]];
		LogInfo["OK: ", archive];
		archive
	]
BuildBundle[] :=
	BuildBundle[
		Replace[Environment["GAPLINK_SYSTEM_ID"], Except[_String] | "" -> $SystemID],
		Replace[Environment["GAPLINK_RUNTIME"], Except[_String] | "" :> FileNameJoin[{$BuildDirectory, "runtimes", $SystemID, "runtime"}]]
	]
BuildBundle[___] := invalidArgumentsFailure[BuildBundle]

installedBundle[archive_String] :=
	Module[{paclet},
		paclet = quietCheck[PacletInstall[archive, ForceVersionInstall -> True, "ShowProgress" -> False]];
		RequireOrLog[paclet, PacletObjectQ, "Could not install bundle"];
		<|"Paclet" -> paclet, "Directory" -> paclet["Location"]|>
	]

extractedBundle[archive_String, root_String] :=
	Module[{directory},
		ExtractArchive[archive, root];
		directory = SelectFirst[FileNames[All, root], DirectoryQ, None];
		RequireOrLog[directory, StringQ, "Could not extract bundle"];
		<|"Paclet" -> PacletObject[File[directory]], "Directory" -> directory|>
	]

verifyBundledSession[executable_String, expected_String] :=
	Module[{session},
		session = gapLinkFunction["StartGAPSession"][];
		RequireOrLog[session, !FailureQ[#] &, "Cannot start bundled GAP"];
		WithCleanup[
			RequireOrLog[session["Executable"], ExpandFileName[#] === ExpandFileName[executable] &, "GAPLink did not use bundled GAP"];
			RequireOrLog[session["Version"], # === expected &, "Wrong GAP version"];
			RequireOrLog[gapLinkFunction["GAPCall"][session, "Sum", Range[10]], # === 55 &, "GAP call failed"];
			RequireOrLog[gapLinkFunction["LoadGAPPackage"][session, "gapdoc"], AssociationQ, "Required GAP package failed"];
			session["Version"],
			DeleteObject[session]
		]
	]

VerifyBundle[] :=
	Module[{archive, expected, installQ, root, bundle, paclet, directory, executable, loaded, version},
		archive = bundleArchivePath[$SystemID, PacletObject[File[$PacletDirectory]]["Version"]];
		RequireOrLog[archive, FileExistsQ, "Run make bundle first"];
		expected = Replace[Environment["GAPLINK_EXPECTED_GAP_VERSION"], Except[_String] | "" -> "4.16.1"];
		installQ = Environment["GAPLINK_VERIFY_INSTALL"] === "1";
		root = If[installQ, None, CreateDirectory[]];
		WithCleanup[
			bundle = If[installQ, installedBundle[archive], extractedBundle[archive, root]];
			paclet = bundle["Paclet"];
			directory = bundle["Directory"];
			RequireOrLog[PacletValidate[directory], TrueQ, "Bundle does not validate"];
			RequireOrLog[paclet, PacletObjectQ, "Cannot read bundle"];
			executable = FileNameJoin[{paclet["AssetLocation", "GAPRuntime"], If[$OperatingSystem === "Windows", "gap.bat", "gap"]}];
			RequireOrLog[executable, FileExistsQ, "Bundle is missing GAP"];
			PacletDirectoryLoad[directory];
			loaded = Check[Needs[paclet["PrimaryContext"]], Failure["NeedsFailure", <|"MessageTemplate" -> "Needs generated messages."|>]];
			RequireOrLog[loaded, !FailureQ[#] &, "Cannot load bundle"];
			version = verifyBundledSession[executable, expected];
			LogInfo["OK: ", FileNameTake[archive], " | GAP ", version],
			If[StringQ[root] && DirectoryQ[root], DeleteDirectory[root, DeleteContents -> True]]
		]
	]
VerifyBundle[___] := invalidArgumentsFailure[VerifyBundle]

verifyBundleInFreshKernel[] :=
	Module[{result},
		result = RunProcess[{"wolframscript", "-file", FileNameJoin[{$ScriptsDirectory, "project.wls"}], "verify-bundle"}];
		LogInfo[result["StandardOutput"]];
		RequireOrLog[result["ExitCode"], # === 0 &, result["StandardError"], "Bundle verification failed"]
	]

testGAPVersion[gapRoot_String, version_String] := (
	SetEnvironment[{"GAPLINK_GAP" -> FileNameJoin[{gapRoot, version, "gap"}], "GAPLINK_EXPECTED_GAP_VERSION" -> version}];
	TestGAP[]
)

RunCI[] :=
	Module[{gapRoot, runtimeRoot, builtGAP, versions},
		gapRoot = FileNameJoin[{$BuildDirectory, "gap-versions"}];
		runtimeRoot = FileNameJoin[{$BuildDirectory, "ci-runtimes"}];
		builtGAP = FileNameJoin[{runtimeRoot, $SystemID, "runtime", "gap"}];
		SetEnvironment["GAPLINK_GAP" -> builtGAP];
		CheckPaclet[];
		TestPaclet[];
		versions = Sort[FileNameTake /@ Select[FileNames[All, gapRoot], DirectoryQ]];
		RequireOrLog[versions, # =!= {} &, "No GAP versions found"];
		Scan[testGAPVersion[gapRoot, #] &, versions];
		SetEnvironment[{"GAPLINK_GAP" -> builtGAP, "GAPLINK_EXPECTED_GAP_VERSION" -> Last[versions]}];
		TestGAP[];
		BuildPaclet[];
		Scan[BuildBundle[#, FileNameJoin[{runtimeRoot, #, "runtime"}]] &, $systems];
		SetEnvironment["GAPLINK_VERIFY_INSTALL" -> "1"];
		verifyBundleInFreshKernel[]
	]
RunCI[___] := invalidArgumentsFailure[RunCI]
