(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{GAPPackageAvailableQ, LoadGAPPackage}];

(* ::Section:: *)
(*Usage Messages*)

GAPPackageAvailableQ::usage = "GAPPackageAvailableQ[session, name] checks whether GAP can load the package with the given name. It gives True or \
False, or a Failure when the name is blank, the session is not valid or GAP cannot be asked.\n\
The options are TimeConstraint -> Infinity and \"Version\" -> Automatic, which accepts any version; a string is a version that GAP must have.";
LoadGAPPackage::usage = "LoadGAPPackage[session, name] loads the GAP package with the given name and returns its name and version as an \
association, or a Failure.\n\
The options are TimeConstraint -> Infinity and \"Version\" -> Automatic, which accepts any version; a string is a version that GAP must have.";
gapPackageNameQ::usage = "gapPackageNameQ[name] gives True when name is a string that is not blank.";
gapPackageNameFailure::usage = "gapPackageNameFailure[] gives the Failure with the tag \"GAPUnsupportedValue\" for a package name that is blank or \
not a string.";
gapCheckedPackageName::usage = "gapCheckedPackageName[name] gives name when it is not blank, and the Failure for a package name otherwise.";
gapCheckedPackageOptions::usage = "gapCheckedPackageOptions[values] gives the list {version, timeConstraint} when both are valid, and the Failure \
for the first that is not. A Failure in place of the list is passed on.";
gapPackageOptions::usage = "gapPackageOptions[function, rules] gives {version, timeConstraint} for a call of function with the given list of \
option rules, or the Failure for the first option that is not valid.";
gapPackageArguments::usage = "gapPackageArguments[name, version] gives the arguments that name a package to GAP: the name, and the version when \
it is a string and not Automatic.";
gapPackageLoadFailure::usage = "gapPackageLoadFailure[name, version, captured] gives the Failure with the tag \"GAPPackageNotAvailable\" for a \
package that GAP did not load. captured is the captured result of the call, whose output goes into the Failure.";
gapLoadedOrFailure::usage = "gapLoadedOrFailure[name, version, captured] gives captured when GAP loaded the package, and the Failure otherwise.";

(* ::Section:: *)
(*Function Definitions*)

Options[GAPPackageAvailableQ] = {
	TimeConstraint -> Infinity,
	"Version" -> Automatic
};
Options[LoadGAPPackage] = Options[GAPPackageAvailableQ];

gapPackageNameQ[name_String] := StringLength[StringTrim[name]] > 0
gapPackageNameQ[___] := False

gapPackageNameFailure[] := gapFailure["GAPUnsupportedValue", "The GAP package name must be a nonempty string."]

gapCheckedPackageName[name_String] := If[gapPackageNameQ[name], name, gapPackageNameFailure[]]

gapCheckedPackageOptions[{version_, timeConstraint_}] :=
	Which[
		!(version === Automatic || gapPackageNameQ[version]),
			gapOptionFailure["Version"],
		!gapTimeConstraintQ[timeConstraint],
			gapOptionFailure[TimeConstraint],
		True,
			{version, timeConstraint}
	]
gapCheckedPackageOptions[failure_Failure] := failure

gapPackageOptions[function_Symbol, rules_List] := gapCheckedPackageOptions[gapLinkOptionValues[function, rules, {"Version", TimeConstraint}]]

gapPackageArguments[name_String, Automatic] := {name}
gapPackageArguments[name_String, version_String] := {name, version}

gapPackageLoadFailure[name_String, version : (_String | Automatic), captured_Association] :=
	gapFailure[
		"GAPPackageNotAvailable", "The GAP package could not be loaded.",
		Join[<|"Package" -> name|>, If[StringQ[version], <|"Version" -> version|>, <||>], KeyTake[captured, {"StandardOutput", "StandardError"}]]
	]

gapLoadedOrFailure[name_String, version : (_String | Automatic), captured_Association] :=
	If[captured["Result"] === True, captured, gapPackageLoadFailure[name, version, captured]]

(* GAP answers the availability test with a path, true or fail. *)
GAPPackageAvailableQ[session_GAPSession, name_String, opts : OptionsPattern[]] :=
	Enclose[
		Module[{version, timeConstraint, availability},
			{version, timeConstraint} = ConfirmMatch[gapPackageOptions[GAPPackageAvailableQ, {opts}], $notFailure];
			ConfirmMatch[gapCheckedPackageName[name], $notFailure];
			availability = GAPCall[
				session, "TestPackageAvailability", Sequence @@ gapPackageArguments[name, version],
				TimeConstraint -> timeConstraint, "Output" -> "Discard"
			];
			Replace[
				availability,
				{
					Missing["GAPFail"] -> False,
					True | _String | _ByteArray -> True,
					Except[_Failure] :> gapFailure["GAPError", "GAP returned an invalid package result.", <|"Package" -> name|>]
				}
			]
		],
		innerFailure
	]
(* These two forms gave a Failure without a message before every function had a catch-all, and projects that use
   GAPLink rely on that: a session followed by anything but a name and options, and a first argument that is not a
   session. *)
GAPPackageAvailableQ[_GAPSession, ___] := gapPackageNameFailure[]
GAPPackageAvailableQ[Except[_GAPSession], ___] := gapInvalidSession[]
GAPPackageAvailableQ[___] := False

LoadGAPPackage[session_GAPSession, name_String, opts : OptionsPattern[]] :=
	Enclose[
		Module[{version, timeConstraint, captured, installedVersion},
			{version, timeConstraint} = ConfirmMatch[gapPackageOptions[LoadGAPPackage, {opts}], $notFailure];
			ConfirmMatch[gapCheckedPackageName[name], $notFailure];
			captured = ConfirmMatch[
				GAPCall[
					session, "LoadPackage", Sequence @@ Append[gapPackageArguments[name, version], False],
					TimeConstraint -> timeConstraint, "Output" -> "Capture"
				],
				$notFailure
			];
			ConfirmMatch[gapLoadedOrFailure[name, version, captured], $notFailure];
			installedVersion = ConfirmMatch[
				GAPCall[session, "InstalledPackageVersion", name, TimeConstraint -> timeConstraint, "Output" -> "Discard"],
				$notFailure
			];
			If[StringQ[installedVersion],
				<|"Name" -> name, "Version" -> installedVersion|>,
				gapFailure["GAPError", "GAP did not return the package version.", <|"Package" -> name|>]
			]
		],
		innerFailure
	]
(* The same two earlier forms as for GAPPackageAvailableQ. *)
LoadGAPPackage[_GAPSession, ___] := gapPackageNameFailure[]
LoadGAPPackage[Except[_GAPSession], ___] := gapInvalidSession[]
LoadGAPPackage[___] := invalidArgumentsFailure[LoadGAPPackage]
