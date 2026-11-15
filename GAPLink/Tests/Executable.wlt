(* Tests for Kernel/Internal/Executable.wl: where GAP is looked for, with files made for the tests. They need no GAP. *)

PacletDirectoryLoad[DirectoryName[$TestFileName, 2]]
Needs["WolframInstitute`GAPLink`"]

findGAP = WolframInstitute`GAPLink`PackageScope`gapLinkFindGAPExecutable;
bundledExecutables = WolframInstitute`GAPLink`PackageScope`gapLinkBundledGAPExecutables;

gapTestRoot = CreateDirectory[];
gapTestFile[parts__String] := CreateFile[FileNameJoin[{gapTestRoot, parts}], CreateIntermediateDirectories -> True]

explicitGAP = gapTestFile["set", "gap"];
bundledGAP = gapTestFile["bundled", "gap"];
pathGAP = gapTestFile["path", If[$OperatingSystem === "Windows", "gap.exe", "gap"]];
commonGAP = gapTestFile["common", "gap"];
windowsGAP = gapTestFile["windows", "gap.bat"];
pathSeparator = If[$OperatingSystem === "Windows", ";", ":"];

(* A paclet whose runtime asset is the folder of bundledGAP. *)
bundledPaclet = PacletObject @ <|
	"Name" -> "WolframInstitute/GAPLink",
	"Version" -> "0.1.0",
	"Location" -> gapTestRoot,
	"Extensions" -> {{"Asset", "Root" -> ".", "Assets" -> {{"GAPRuntime", "bundled"}}}}
|>;

If[$OperatingSystem =!= "Windows",
	Export[bundledGAP, "#!/bin/sh\nexit 0\n", "Text"];
	Export[FileNameJoin[{DirectoryName[bundledGAP], "EXECUTABLES.txt"}], "gap\n", "Text"]
];

VerificationTest[
	findGAP[explicitGAP, {bundledGAP}, DirectoryName[pathGAP], {commonGAP}, $OperatingSystem],
	ExpandFileName[explicitGAP],
	TestID -> "Use-Set-Path"
]

VerificationTest[
	findGAP[
		Automatic, {},
		StringRiffle[{FileNameJoin[{gapTestRoot, "missing"}], DirectoryName[pathGAP]}, pathSeparator],
		{commonGAP},
		$OperatingSystem
	],
	ExpandFileName[pathGAP],
	TestID -> "Find-GAP-On-Path"
]

VerificationTest[
	findGAP[Automatic, {}, "", {commonGAP}, $OperatingSystem],
	ExpandFileName[commonGAP],
	TestID -> "Use-Common-Path"
]

VerificationTest[
	findGAP[Automatic, {}, "\"" <> DirectoryName[windowsGAP] <> "\"", {}, "Windows"],
	ExpandFileName[windowsGAP],
	TestID -> "Find-Windows-GAP-On-Path"
]

VerificationTest[
	findGAP[Automatic, {bundledGAP}, DirectoryName[pathGAP], {commonGAP}, $OperatingSystem],
	ExpandFileName[bundledGAP],
	TestID -> "Use-Bundled-GAP"
]

VerificationTest[
	bundledExecutables[{bundledPaclet}, $OperatingSystem],
	{ExpandFileName[bundledGAP]},
	TestID -> "Read-Bundled-GAP-Path"
]

VerificationTest[
	If[$OperatingSystem === "Windows",
		True,
		RunProcess[{bundledGAP}]["ExitCode"] === 0
	],
	True,
	TestID -> "Restore-Bundled-GAP-Permissions"
]

VerificationTest[
	bundledExecutables[{bundledPaclet}, "Windows"],
	{FileNameJoin[{gapTestRoot, "bundled", "gap.bat"}]},
	TestID -> "Read-Bundled-Windows-GAP-Path"
]

VerificationTest[
	Module[{failure},
		failure = findGAP[FileNameJoin[{gapTestRoot, "missing", "gap"}], {bundledGAP}, DirectoryName[pathGAP], {commonGAP}, $OperatingSystem];
		{
			FailureQ[failure],
			failure["Reason"],
			StringQ[failure["MessageTemplate"]],
			AssociationQ[failure["MessageParameters"]]
		}
	],
	{True, "ExecutableNotFound", True, True},
	TestID -> "Fail-For-Missing-Set-Path"
]

VerificationTest[
	FailureQ @ findGAP[Automatic, {}, "", {}, $OperatingSystem],
	True,
	TestID -> "Fail-When-GAP-Is-Missing"
]

(* PATH can be unset, and then Environment gives $Failed in place of a string. *)
VerificationTest[
	findGAP[Automatic, {}, $Failed, {commonGAP}, $OperatingSystem],
	ExpandFileName[commonGAP],
	TestID -> "Search-Without-PATH"
]

DeleteDirectory[gapTestRoot, DeleteContents -> True];
