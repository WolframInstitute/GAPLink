(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[RunProject];

(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{$projectCommands}];

(* ::Section:: *)
(*Usage Messages*)

RunProject::usage = "RunProject[] runs the project command named on the command line, such as check, test or build, with the arguments after it. \
With no command it runs all. A command that fails logs an error, and the script then exits with status 1.";
$projectCommands::usage = "$projectCommands gives, for the name of each project command, the function that runs it.";
lintNamedFiles::usage = "lintNamedFiles[] lints the files named on the command line with CodeInspector and checks them against the coding guides.";
runAll::usage = "runAll[] checks the source, runs the tests that do not need GAP, and builds the documentation and the archive.";

(* ::Section:: *)
(*Function Definitions*)

lintNamedFiles[] := LintFiles[resolveStyleFile /@ $ScriptArguments]

runAll[] := (
	CheckPaclet[];
	TestPaclet[];
	BuildPaclet[]
)

$projectCommands = <|
	"check" -> CheckPaclet,
	"test" -> TestPaclet,
	"test-gap" -> TestGAP,
	"sweep" -> RunCoverage,
	"build" -> BuildPaclet,
	"bundle" -> BuildBundle,
	"verify" -> VerifyPaclet,
	"verify-bundle" -> VerifyBundle,
	"check-release" -> CheckRelease,
	"publish" -> PublishPaclet,
	"lint" -> lintNamedFiles,
	"style" -> CheckStyle,
	"style-fix" -> FixStyle,
	"all" -> runAll,
	"ci" -> RunCI
|>;

RunProject[] :=
	RunTask @ Module[{command},
		command = Lookup[$projectCommands, $ScriptCommand, None];
		RequireOrLog[command, # =!= None &, "Unknown command: ", $ScriptCommand];
		command[]
	]
RunProject[___] := invalidArgumentsFailure[RunProject]
