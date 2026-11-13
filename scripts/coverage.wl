(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[RunCoverage];

(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{documentedNames, coverageStatus, $unsafeTestPattern}];

(* ::Section:: *)
(*Usage Messages*)

RunCoverage::usage = "RunCoverage[] checks which documented GAP functions can be called and runs GAP's own test files through GAPLink. It reads \
the GAP source tree that GAPLINK_SOURCE names and uses the GAP that GAPLINK_GAP names. Reports go to the coverage folder of the build directory: \
functions.json, tests.json, summary.json and one case file for each test that needs review. Upstream tests run in temporary directories, and \
nothing is downloaded.";
$documentedNamePattern::usage = "$documentedNamePattern matches the declaration of a function, operation, attribute, property or filter in GAP's \
documentation sources.";
$unsafeTestPattern::usage = "$unsafeTestPattern matches a call in a GAP test file that starts a program, quits GAP, changes files outside the \
test or downloads data. A file with such a call is left out of the sweep.";
$coverageTestCode::usage = "$coverageTestCode is the GAP code that defines GAPLinkCoverageTest, which runs one test file and gives its \
differences and its number of inputs.";
$exclusionReason::usage = "$exclusionReason is the sentence in the summary that says why some test files are left out.";
coverageLauncher::usage = "coverageLauncher[executable, source, output] writes a launcher in the output directory that starts the GAP executable \
with the library of the source tree, and gives its path.";
documentedNames::usage = "documentedNames[source] gives the sorted names that the documentation and library files of the GAP source tree declare.";
writeFunctionCatalog::usage = "writeFunctionCatalog[launcher, names, output] asks GAP which of the names are functions, writes functions.json to \
the output directory, and gives the GAP version.";
upstreamTestFiles::usage = "upstreamTestFiles[source] gives the test files of the GAP source tree that the sweep can run, as an association with \
the keys \"Run\" and \"Excluded\".";
relativePath::usage = "relativePath[file, source] gives the path of a file below the source directory.";
coverageResult::usage = "coverageResult[launcher, file] starts GAP with the launcher, runs one test file through GAPCall and gives the captured \
result, or the Failure of the call.";
coverageStatus::usage = "coverageStatus[differences, inputs] gives \"Passed\" when the differences of a test file are an empty GAP list, \
\"NotApplicable\" when it also had no inputs, and \"Review\" otherwise.";
coverageRow::usage = "coverageRow[run, index, file] runs the test file with the given index and gives its row: an association with the keys \
\"File\", \"Status\" and \"Inputs\". It writes a case file when the test needs review. run is an association with the keys \"Launcher\", \
\"Source\", \"Output\" and \"Total\".";
appendCoverageRow::usage = "appendCoverageRow[rows, {index, file}, run] gives the rows with the row of one more test file, and writes them to \
tests.json.";

(* ::Section:: *)
(*Function Definitions*)

$documentedNamePattern = RegularExpression["<(?:Func|Oper|Attr|Prop|Filt)\\s+Name=[\"']([^\"']+)[\"']"];

(* AtlasGenerators can download data from the optional AtlasRep package. *)
$unsafeTestPattern = RegularExpression[
	"\\b(?:Exec|QUIT|QuitGap|ForceQuitGap|SaveWorkspace|LoadWorkspace|Edit|Pager|RemoveFile|FileString|Process|InputOutputLocalProcess|ChangeDirectoryCurrent|AtlasGenerators)\\s*\\("
];

$coverageTestCode = StringJoin[
	"GAPLinkCoverageTest := function(path) local diffs; diffs := []; ",
	"Test(path, rec(showProgress := false, compareFunction := \"uptowhitespace\", ",
	"reportDiff := function(input, expected, actual, file, line, time) ",
	"Add(diffs, [line, input, expected, actual]); end)); ",
	"return rec(Differences := String(diffs), Inputs := Length(TEST.lastTestData[1])); end;;"
];

$exclusionReason = "Tests that launch programs, quit GAP, manipulate external files, or download AtlasRep data need a separate harness.";

coverageLauncher[executable_String, source_String, output_String] :=
	Module[{launcher, result},
		launcher = FileNameJoin[{output, "gap-coverage"}];
		result = pythonScript["coverage.py", {"--launcher", executable, source, launcher}];
		RequireOrLog[result["ExitCode"], # === 0 &, result["StandardError"]];
		launcher
	]

(* GAP escapes operator names in its documentation, but globals use the operator itself. *)
documentedNames[source_String] :=
	Module[{files, declared},
		files = Catenate @ Map[FileNames[{"*.xml", "*.gd", "*.gi", "*.g"}, FileNameJoin[{source, #}], Infinity] &, {"doc/ref", "lib", "grp"}];
		declared = Sort @ DeleteDuplicates @ Catenate @ Map[StringCases[ReadString[#], $documentedNamePattern -> "$1"] &, files];
		Map[StringReplace[#, {"&lt;" -> "<", "&gt;" -> ">", "&amp;" -> "&", "\\" -> ""}] &, declared]
	]

writeFunctionCatalog[launcher_String, names : {___String}, output_String] :=
	Module[{session, version, checker, checks, callable},
		session = gapLinkFunction["StartGAPSession"]["Executable" -> launcher];
		RequireOrLog[session, !FailureQ[#] &, "Could not start GAP"];
		WithCleanup[
			version = session["Version"];
			checker = gapLinkFunction["GAPEvaluate"][session, "name -> IsFunction(GAPLinkNamedFunction(name));"];
			checks = gapLinkFunction["GAPCall"][session, "List", names, checker];
			RequireOrLog[checks, MatchQ[#, {(True | False) ..}] &, "Could not check documented function names"];
			callable = Pick[names, checks, True];
			Export[
				FileNameJoin[{output, "functions.json"}],
				<|"GAPVersion" -> version, "Documented" -> Length[names], "Callable" -> callable, "Unavailable" -> Pick[names, checks, False]|>,
				"RawJSON"
			],
			DeleteObject[session]
		];
		LogInfo["Documented functions available: ", Length[callable], "/", Length[names]];
		version
	]

upstreamTestFiles[source_String] :=
	Module[{files, excluded},
		files = Sort @ Catenate @ Map[FileNames["*.tst", FileNameJoin[{source, "tst", #}], Infinity] &, {"testinstall", "teststandard"}];
		excluded = Select[files, StringContainsQ[ReadString[#], $unsafeTestPattern] &];
		<|"Run" -> Complement[files, excluded], "Excluded" -> excluded|>
	]

relativePath[file_String, source_String] := FileNameDrop[file, Length[FileNameSplit[source]]]

coverageResult[launcher_String, file_String] :=
	Module[{session},
		session = gapLinkFunction["StartGAPSession"]["Executable" -> launcher];
		RequireOrLog[session, !FailureQ[#] &, "GAP startup failed: ", file];
		WithCleanup[
			gapLinkFunction["GAPEvaluate"][session, $coverageTestCode, "Output" -> "Discard"];
			gapLinkFunction["GAPCall"][session, "GAPLinkCoverageTest", file, "Output" -> "Capture", TimeConstraint -> 60],
			DeleteObject[session]
		]
	]

coverageStatus["[  ]" | "[]", 0] := "NotApplicable"
coverageStatus["[  ]" | "[]", _] := "Passed"
coverageStatus[_, _] := "Review"

coverageRow[run_Association, index_Integer, file_String] :=
	Module[{result, capturedQ, differences, inputs, status, row},
		result = coverageResult[run["Launcher"], file];
		capturedQ = AssociationQ[result] && AssociationQ[result["Result"]];
		differences = If[capturedQ, result["Result"]["Differences"], result];
		inputs = If[capturedQ, result["Result"]["Inputs"], 0];
		status = coverageStatus[differences, inputs];
		If[status === "Review",
			Export[
				FileNameJoin[{run["Output"], "case-" <> ToString[index] <> ".json"}],
				<|
					"File" -> file,
					"Differences" -> If[StringQ[differences], differences, Null],
					"Bridge" -> If[FailureQ[result], ToString[result, InputForm], result]
				|>,
				"RawJSON"
			]
		];
		row = <|"File" -> relativePath[file, run["Source"]], "Status" -> status, "Inputs" -> inputs|>;
		LogInfo[index, "/", run["Total"], " ", status, " ", row["File"]];
		row
	]

appendCoverageRow[rows : {___Association}, {index_Integer, file_String}, run_Association] :=
	Module[{extended},
		extended = Append[rows, coverageRow[run, index, file]];
		Export[FileNameJoin[{run["Output"], "tests.json"}], extended, "RawJSON"];
		extended
	]

RunCoverage[] :=
	Module[{source, executable, output, launcher, version, tests, run, original, scratch, rows},
		source = ExpandFileName[environmentSetting["GAPLINK_SOURCE"]];
		executable = ExpandFileName[environmentSetting["GAPLINK_GAP"]];
		RequireOrLog[FileNameJoin[{source, "tst", "teststandard"}], DirectoryQ, "GAPLINK_SOURCE must point to the matching GAP source tree"];
		output = FileNameJoin[{$BuildDirectory, "coverage"}];
		If[!DirectoryQ[output], CreateDirectory[output, CreateIntermediateDirectories -> True]];
		launcher = coverageLauncher[executable, source, output];
		LoadPaclet[];
		version = writeFunctionCatalog[launcher, documentedNames[source], output];
		tests = upstreamTestFiles[source];
		Export[FileNameJoin[{output, "helper.g"}], $coverageTestCode, "Text"];
		Scan[DeleteFile, FileNames["case-*.json", output]];
		run = <|"Launcher" -> launcher, "Source" -> source, "Output" -> output, "Total" -> Length[tests["Run"]]|>;
		original = Directory[];
		scratch = CreateDirectory[];
		rows = WithCleanup[
			SetDirectory[scratch],
			Fold[appendCoverageRow[#1, #2, run] &, {}, Transpose[{Range[Length[tests["Run"]]], tests["Run"]}]],
			SetDirectory[original];
			DeleteDirectory[scratch, DeleteContents -> True]
		];
		Export[
			FileNameJoin[{output, "summary.json"}],
			<|
				"GAPVersion" -> version,
				"Tests" -> Counts[Lookup[rows, "Status"]],
				"Inputs" -> Total[Lookup[rows, "Inputs"]],
				"Excluded" -> Map[relativePath[#, source] &, tests["Excluded"]],
				"ExclusionReason" -> $exclusionReason
			|>,
			"RawJSON"
		];
		LogInfo[Counts[Lookup[rows, "Status"]]];
		LogInfo["Bridge sweep complete; native comparisons run next."]
	]
RunCoverage[___] := invalidArgumentsFailure[RunCoverage]
