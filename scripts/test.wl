(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{TestPaclet, TestGAP}];

(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{runTests}];

(* ::Section:: *)
(*Usage Messages*)

TestPaclet::usage = "TestPaclet[] runs the tests that do not need GAP: the Python tests, the paclet tests and the script tests. With test files \
named on the command line it runs only those files.";
TestGAP::usage = "TestGAP[] runs the tests that need GAP, the files of GAPLink/Tests/Integration, and prints which GAP they use. GAPLINK_GAP \
names the GAP program; without it GAPLink finds one.";
logGAPVersion::usage = "logGAPVersion[] starts the GAP that the tests will use, prints its version and its path, and closes it. It stops the \
current task when GAP does not start.";
runTests::usage = "runTests[files] runs the test files, a list of paths, and prints the number of tests that passed in each. It stops the current \
task when no file is given, a file has no tests or a test fails.";
runPythonTests::usage = "runPythonTests[] runs the Python tests under scripts/tests and stops the current task when one fails.";
offlineTestFiles::usage = "offlineTestFiles[] lists the paclet and script test files that do not need GAP.";
show::usage = "show[expression] gives the InputForm text of an expression, without evaluating it when it is wrapped in HoldForm.";
testResults::usage = "testResults[report] gives the list of test results of a test report.";
testFileReport::usage = "testFileReport[file] runs the tests of one file, prints the number that passed, and gives the test report.";
reportFailure::usage = "reportFailure[result] prints the test ID, the actual output, the expected output and the messages of a failed test result.";
reportFailures::usage = "reportFailures[report] prints each failed test of a test report.";

(* ::Section:: *)
(*Function Definitions*)

runPythonTests[] :=
	Module[{result},
		result = RunProcess[{"python3", "-m", "unittest", "discover", "-s", FileNameJoin[{$ScriptsDirectory, "tests"}]}];
		LogInfo[result["StandardError"]];
		RequireOrLog[result["ExitCode"], # === 0 &, "Python tests failed"]
	]

offlineTestFiles[] := Join[FileNames["*.wlt", FileNameJoin[{$PacletDirectory, "Tests"}]], FileNames["*.wlt", FileNameJoin[{$ScriptsDirectory, "tests"}]]]

show[HoldForm[expression_]] := ToString[Unevaluated[expression], InputForm]
show[expression_] := ToString[expression, InputForm]

testResults[report_TestReportObject] := Replace[report["TestResults"], results_Association :> Values[results]]

testFileReport[file_String] :=
	Module[{report},
		RequireOrLog[file, FileExistsQ, "Test file not found: ", file];
		report = TestReport[file];
		RequireOrLog[report, MatchQ[#, _TestReportObject] &, "Could not run ", file];
		RequireOrLog[testResults[report], MatchQ[#, {__}] &, "No tests found in ", file];
		LogInfo["  ", FileNameTake[file], ": ", report["TestsSucceededCount"], "/", report["TestsSucceededCount"] + report["TestsFailedCount"]];
		report
	]

reportFailure[result_TestResultObject] :=
	LogInfo[
		"FAIL: ", result["TestID"],
		"\n  Actual: ", show[result["ActualOutput"]],
		"\n  Expected: ", show[result["ExpectedOutput"]],
		Replace[result["ActualMessages"], {messages : {__} :> "\n  Messages: " <> show[messages], _ -> ""}]
	]

reportFailures[report_TestReportObject] := Scan[reportFailure, Select[testResults[report], #["Outcome"] =!= "Success" &]]

runTests[files : {___String}] :=
	Module[{reports, passed, failed, runtimeFailures},
		RequireOrLog[files, # =!= {} &, "No test files found"];
		reports = testFileReport /@ files;
		passed = Total[Map[#["TestsSucceededCount"] &, reports]];
		failed = Total[Map[#["TestsFailedCount"] &, reports]];
		runtimeFailures = Total[Map[Length[#["RuntimeFailures"]] &, reports]];
		If[failed + runtimeFailures > 0,
			Scan[reportFailures, reports];
			failTask[failed, " failed test(s), ", runtimeFailures, " runtime failure(s)"]
		];
		LogInfo["OK: ", passed, " tests passed"]
	]

TestPaclet[] :=
	If[$ScriptArguments === {},
		runPythonTests[];
		LoadPaclet[];
		runTests[offlineTestFiles[]],

		LoadPaclet[];
		runTests[resolveStyleFile /@ $ScriptArguments]
	]
TestPaclet[___] := invalidArgumentsFailure[TestPaclet]

logGAPVersion[] :=
	Module[{requested, session},
		requested = Replace[Environment["GAPLINK_GAP"], Except[_String] | "" -> Automatic];
		session = gapLinkFunction["StartGAPSession"]["Executable" -> requested];
		RequireOrLog[session, !FailureQ[#] &, "GAP is required for these tests: ", session];
		WithCleanup[
			LogInfo["  GAP ", session["Version"], " | ", session["Executable"]],
			DeleteObject[session]
		]
	]

TestGAP[] := (
	LoadPaclet[];
	logGAPVersion[];
	runTests[FileNames["*.wlt", FileNameJoin[{$PacletDirectory, "Tests", "Integration"}]]]
)
TestGAP[___] := invalidArgumentsFailure[TestGAP]
