(* ::Package:: *)

(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{gapLinkFindGAPExecutable, gapLinkBundledGAPExecutables}];

(* ::Section:: *)
(*Usage Messages*)

gapLinkFindGAPExecutable::usage = "gapLinkFindGAPExecutable[path] gives the full path of the GAP program at path, or a Failure with the tag \
\"GAPStartFailed\" when no file is there.\n\
gapLinkFindGAPExecutable[Automatic] gives the first GAP program found: the one in an installed GAPLink paclet, then one on PATH, then one in a \
common installation folder.\n\
gapLinkFindGAPExecutable[requested, bundled, searchPath, common, system] looks in the given places only: the list of paths bundled, the value of \
PATH searchPath, the list of paths common, for the operating system named system. requested is a path or Automatic.";
gapLinkBundledGAPExecutables::usage = "gapLinkBundledGAPExecutables[] gives the paths of the GAP programs inside the installed GAPLink paclets.\n\
gapLinkBundledGAPExecutables[paclets, system] gives them for a list of paclet objects and the operating system named system.";
gapExecutableFailure::usage = "gapExecutableFailure[requested] gives the Failure for a GAP program that was not found. requested is the path that \
was asked for, or Automatic.";
gapExecutableNames::usage = "gapExecutableNames[system] gives the file names of a GAP program on the operating system named system.";
gapBundledExecutableName::usage = "gapBundledExecutableName[system] gives the file name of the GAP program in a paclet for the operating system.";
gapPathExecutables::usage = "gapPathExecutables[searchPath, system] gives the paths at which a GAP program may be in the folders of searchPath, \
the value of PATH. Any other value in place of the string gives an empty list.";
gapCommonExecutables::usage = "gapCommonExecutables[system] gives the paths at which GAP is commonly installed on the operating system.";
gapPrepareBundledRuntime::usage = "gapPrepareBundledRuntime[runtime, system] makes the programs of the GAP runtime folder executable, once per \
session, and gives the folder. Paclet installation removes that permission on Linux and macOS; the file EXECUTABLES.txt lists the programs.";
gapBundledExecutable::usage = "gapBundledExecutable[runtime, system] gives the path of the GAP program in a prepared runtime folder.";
gapFirstExecutable::usage = "gapFirstExecutable[paths, requested] gives the full path of the first of the paths that is a file, or the Failure \
for requested when none is.";

(* ::Section:: *)
(*Function Definitions*)

gapExecutableFailure[path_String] := gapStartFailure["ExecutableNotFound", "GAP could not be found.", <|"Path" -> path|>]
gapExecutableFailure[Automatic] := gapStartFailure["ExecutableNotFound", "GAP could not be found."]

gapExecutableNames["Windows"] := {"gap.exe", "gap.bat"}
gapExecutableNames[_String] := {"gap"}

gapBundledExecutableName["Windows"] := "gap.bat"
gapBundledExecutableName[_String] := "gap"

gapPathExecutables[searchPath_String, system_String] :=
	Module[{directories},
		directories = DeleteCases[Map[StringTrim[#, WhitespaceCharacter | "\""] &, StringSplit[searchPath, If[system === "Windows", ";", ":"]]], ""];
		Flatten @ Table[FileNameJoin[{directory, name}], {directory, directories}, {name, gapExecutableNames[system]}]
	]
gapPathExecutables[_, _String] := {}

gapCommonExecutables["Windows"] :=
	FileNames["gap.bat", FileNames["GAP" ~~ ___, Select[Map[Environment, {"LOCALAPPDATA", "ProgramFiles", "ProgramW6432"}], DirectoryQ]]]
gapCommonExecutables["MacOSX"] := {"/opt/homebrew/bin/gap", "/usr/local/bin/gap", "/opt/local/bin/gap", "/usr/bin/gap"}
gapCommonExecutables[_String] := {"/usr/local/bin/gap", "/usr/bin/gap", "/snap/bin/gap"}

(* File and process calls here quiet every message: whatever goes wrong, the runtime is used as it is. *)
gapPrepareBundledRuntime[runtime_String, "Windows"] := runtime
gapPrepareBundledRuntime[runtime_String, system_String] :=
	gapPrepareBundledRuntime[runtime, system] = Module[{manifest, listedFiles, existingFiles},
		manifest = FileNameJoin[{runtime, "EXECUTABLES.txt"}];
		listedFiles = Select[Quiet[Check[Import[manifest, "Lines"], {"gap"}], All], StringQ[#] && # =!= "" &];
		existingFiles = Select[Map[FileNameJoin[{runtime, #}] &, listedFiles], FileExistsQ];
		If[existingFiles =!= {}, Quiet[Check[RunProcess[Join[{"/bin/chmod", "a+x"}, existingFiles]], Null], All]];
		runtime
	]

gapBundledExecutable[runtime_String, system_String] := FileNameJoin[{gapPrepareBundledRuntime[runtime, system], gapBundledExecutableName[system]}]

gapLinkBundledGAPExecutables[paclets_List, system_String] :=
	Map[
		gapBundledExecutable[#, system] &,
		Cases[Quiet[Check[Map[#["AssetLocation", "GAPRuntime"] &, paclets], {}], All], _String]
	]
gapLinkBundledGAPExecutables[] := gapLinkBundledGAPExecutables[Quiet[Check[PacletFind["WolframInstitute/GAPLink"], {}], All], $OperatingSystem]

gapFirstExecutable[paths_List, requested : (_String | Automatic)] :=
	Replace[
		SelectFirst[Map[ExpandFileName, DeleteDuplicates @ Select[paths, StringQ[#] && # =!= "" &]], FileType[#] === File &, None],
		None :> gapExecutableFailure[requested]
	]

gapLinkFindGAPExecutable[path_String, _List, _String | $Failed, _List, _String] := gapFirstExecutable[{path}, path]
gapLinkFindGAPExecutable[Automatic, bundled_List, searchPath : (_String | $Failed), common_List, system_String] :=
	gapFirstExecutable[Join[bundled, gapPathExecutables[searchPath, system], common], Automatic]
gapLinkFindGAPExecutable[path_String] := gapFirstExecutable[{path}, path]
gapLinkFindGAPExecutable[Automatic] :=
	gapLinkFindGAPExecutable[
		Automatic, gapLinkBundledGAPExecutables[], Environment["PATH"], gapCommonExecutables[$OperatingSystem], $OperatingSystem
	]
