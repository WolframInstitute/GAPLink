(* Tests for Kernel/Internal/Process.wl that need no GAP: the command that starts GAP, its environment and the check of
   the first response. *)

PacletDirectoryLoad[DirectoryName[$TestFileName, 2]]
Needs["WolframInstitute`GAPLink`"]

gapCommand = WolframInstitute`GAPLink`PackageScope`gapLinkGAPCommand;
gapEnvironment = WolframInstitute`GAPLink`PackageScope`gapLinkGAPEnvironment;
startGAP = WolframInstitute`GAPLink`PackageScope`gapLinkStartGAP;
validateHello = WolframInstitute`GAPLink`PackageScope`gapLinkValidateGAPHello;

(* The files of a Windows installation of GAP, in a folder whose name has a space. *)
windowsRoot = CreateDirectory @ FileNameJoin[{$TemporaryDirectory, "GAP Link " <> CreateUUID[]}];
windowsFile[parts__String] := CreateFile[FileNameJoin[{windowsRoot, parts}], CreateIntermediateDirectories -> True]
windowsLauncher = windowsFile["gap.bat"];
windowsBash = windowsFile["runtime", "bin", "bash.exe"];
windowsGAP = windowsFile["runtime", "opt", "gap-4.16.1", "gap.exe"];

(* The parts of a Windows command that the tests look at, or None for a command of another form. *)
windowsCommandParts[{bash_String, "--noprofile", "--norc", "-c", script_String, "GAPLink", gap_String, startup_String, arguments___String}] :=
	<|"Bash" -> bash, "Script" -> script, "GAP" -> gap, "Startup" -> startup, "Arguments" -> {arguments}|>
windowsCommandParts[_] := None

(* The payload of the first response of a GAP of the given version. *)
hello[version_String, hpcQ : (True | False)] :=
	<|
		"Status" -> "OK",
		"Result" -> <|
			"Build" -> version,
			"GAPVersion" -> version,
			"HPC" -> hpcQ,
			"Packages" -> {"GAPDoc", "primgrp"},
			"Processor" -> "x86_64",
			"ProtocolVersion" -> 1,
			"System" -> "Linux"
		|>
	|>
hello[version_String] := hello[version, False]

VerificationTest[
	Replace[
		gapCommand["/set/gap"],
		{
			{"/set/gap", "-q", "-n", "-A", "-r", "--nointeract", startup_String} :> {FileNameTake[startup], FileExistsQ[startup]},
			_ -> None
		}
	],
	{"startup.g", True},
	TestID -> "Build-GAP-Command"
]

VerificationTest[
	Module[{parts},
		parts = windowsCommandParts[gapCommand[windowsLauncher]];
		{
			KeyTake[parts, {"Bash", "GAP", "Startup", "Arguments"}],
			AllTrue[{"$1", "$2", "$@", "$PATH"}, StringContainsQ[parts["Script"], #] &],
			StringFreeQ[parts["Script"], windowsRoot]
		}
	],
	{
		<|"Bash" -> windowsBash, "GAP" -> windowsGAP, "Startup" -> Last @ gapCommand["/set/gap"], "Arguments" -> {"-q", "-n", "-A", "-r", "--nointeract"}|>,
		True,
		True
	},
	TestID -> "Build-Windows-GAP-Command"
]

VerificationTest[
	Module[{failure},
		failure = gapCommand[FileNameJoin[{windowsRoot, "missing", "gap.bat"}]];
		{FailureQ[failure], failure["Reason"]}
	],
	{True, "WindowsLauncherNotFound"},
	TestID -> "Reject-Incomplete-Windows-GAP"
]

VerificationTest[
	Module[{failure},
		windowsFile["runtime", "opt", "gap-4.15.1", "gap.exe"];
		failure = gapCommand[windowsLauncher];
		{FailureQ[failure], failure["Reason"]}
	],
	{True, "WindowsLauncherAmbiguous"},
	TestID -> "Reject-Ambiguous-Windows-GAP"
]

(* Bash must not read startup files when it starts GAP on Windows. Any other GAP gets the environment as it is. *)
VerificationTest[
	gapEnvironment["C:\\GAP\\gap.bat", <|"PATH" -> "C:\\Windows", "TERM" -> "xterm"|>],
	<|"PATH" -> "C:\\Windows", "TERM" -> "", "BASH_ENV" -> "", "ENV" -> ""|>,
	TestID -> "Environment-For-Windows-Launcher"
]

VerificationTest[
	gapEnvironment["/usr/bin/gap", <|"PATH" -> "/usr/bin", "TERM" -> "xterm"|>],
	<|"PATH" -> "/usr/bin", "TERM" -> "xterm"|>,
	TestID -> "Environment-For-Other-GAP"
]

VerificationTest[
	Map[Lookup[validateHello[hello[#]], "Tested", False] &, {"4.14.0", "4.16.9"}],
	{True, True},
	TestID -> "Accept-Supported-GAP"
]

VerificationTest[
	Lookup[validateHello @ hello["4.17.0"], "Tested", True],
	False,
	TestID -> "Mark-New-GAP-Untested"
]

VerificationTest[
	Map[
		#["Reason"] &,
		{
			validateHello @ hello["4.13.1"],
			validateHello @ hello["5.0.0"],
			validateHello @ hello["4.16.1dev"],
			validateHello @ hello["4.16.1", True],
			validateHello @ <|"Status" -> "OK", "Result" -> <||>|>,
			validateHello @ <|"Status" -> "GAPError", "Message" -> "no"|>,
			validateHello["text"]
		}
	],
	{"UnsupportedVersion", "UnsupportedVersion", "UnsupportedVersion", "UnsupportedGAP", "InvalidHello", "HelloFailed", "InvalidHello"},
	TestID -> "Reject-Unsupported-GAP"
]

VerificationTest[
	Module[{failure},
		failure = startGAP[FileNameJoin[{$TemporaryDirectory, CreateUUID[]}]];
		{FailureQ[failure], failure["Reason"]}
	],
	{True, "ExecutableNotFound"},
	TestID -> "Fail-Before-Starting-Missing-GAP"
]

VerificationTest[
	AllTrue[
		{gapCommand["gap.cmd"], validateHello @ hello["5.0.0"]},
		StringQ[#["MessageTemplate"]] && AssociationQ[#["MessageParameters"]] &
	],
	True,
	TestID -> "Startup-Failures-Have-Messages"
]

DeleteDirectory[windowsRoot, DeleteContents -> True];
