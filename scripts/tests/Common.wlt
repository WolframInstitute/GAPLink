(* Tests of the helpers that the scripts share, of the list of project commands and of two helpers of the sweep. *)

Get[FileNameJoin[{DirectoryName[$TestFileName, 2], "run.wls"}]]["Load"]
Needs["GAPLink`Scripts`"]

runTask = GAPLink`Scripts`PackageScope`RunTask;
requireOrLog = GAPLink`Scripts`PackageScope`RequireOrLog;
quietCheck = GAPLink`Scripts`PackageScope`quietCheck;

VerificationTest[
	RepositoryPath[FileNameJoin[{$RepositoryRoot, "scripts", "common.wl"}]],
	FileNameJoin[{"scripts", "common.wl"}],
	TestID -> "Repository-Path-Strips-The-Root"
]

VerificationTest[
	First @ RepositoryPath[1],
	"InvalidArguments",
	{RepositoryPath::args},
	TestID -> "Repository-Path-Rejects-Other-Arguments"
]

(* A required value that fails its test stops the task and gives its Failure. The script then exits with status 1. *)
VerificationTest[
	Module[{failure},
		failure = runTask[requireOrLog[3, EvenQ]];
		{First[failure], GAPLink`Scripts`PackageScope`taskFailureQ[failure]}
	],
	{"ScriptTaskFailure", True},
	TestID -> "Required-Value-That-Fails-Stops-The-Task"
]

VerificationTest[
	runTask[requireOrLog[4, EvenQ]],
	4,
	TestID -> "Required-Value-That-Passes-Is-Returned"
]

VerificationTest[
	{quietCheck[1 + 1], First @ quietCheck[1 / 0]},
	{2, "MessageFailure"},
	TestID -> "Quiet-Check-Gives-A-Failure-For-A-Message"
]

(* Every project command is a function of the script package. *)
VerificationTest[
	{
		Sort[Keys[GAPLink`Scripts`PackageScope`$projectCommands]],
		AllTrue[Values[GAPLink`Scripts`PackageScope`$projectCommands], MatchQ[DownValues[#], {__}] &]
	},
	{
		{
			"all", "build", "bundle", "check", "check-release", "ci", "lint", "publish", "style", "style-fix", "sweep", "test", "test-gap", "verify",
			"verify-bundle"
		},
		True
	},
	TestID -> "Every-Project-Command-Has-A-Function"
]

VerificationTest[
	First /@ {RunProject[1], CheckPaclet[1], TestPaclet[1], BuildPaclet[1], BuildBundle[1], CheckRelease[1], PublishPaclet[1], RunCoverage[1]},
	ConstantArray["InvalidArguments", 8],
	{RunProject::args, CheckPaclet::args, TestPaclet::args, BuildPaclet::args, BuildBundle::args, CheckRelease::args, PublishPaclet::args, RunCoverage::args},
	TestID -> "Script-Commands-Reject-Other-Arguments"
]

(* The sweep passes a test file whose list of differences is empty, and sets aside one without inputs. *)
VerificationTest[
	Map[
		Apply[GAPLink`Scripts`PackageScope`coverageStatus],
		{{"[  ]", 5}, {"[]", 5}, {"[]", 0}, {"[ [ 1, \"a\", \"b\", \"c\" ] ]", 5}, {Failure["GAPError", <||>], 0}}
	],
	{"Passed", "Passed", "NotApplicable", "Review", "Review"},
	TestID -> "Coverage-Status-Of-A-Test-File"
]

(* A test file that would start a program or quit GAP is left out of the sweep. *)
VerificationTest[
	Map[
		StringContainsQ[#, GAPLink`Scripts`PackageScope`$unsafeTestPattern] &,
		{"gap> Exec(\"ls\");", "gap> QUIT ( );", "gap> Size(SymmetricGroup(4));", "gap> Executable := 1;"}
	],
	{True, True, False, False},
	TestID -> "Coverage-Leaves-Out-Unsafe-Test-Files"
]
