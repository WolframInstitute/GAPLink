(* ::Package:: *)

PackageImport["PacletTools`"]

(* ::Section:: *)
(*PackageExported*)

PackageExported[CheckPaclet];

(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{sourceFiles}];

(* ::Section:: *)
(*Usage Messages*)

CheckPaclet::usage = "CheckPaclet[] checks the paclet metadata, lints the source and checks it against the coding guides, loads the paclet, and \
checks that every public symbol is declared in PacletInfo.wl and has a usage message and a reference page.";
sourceFiles::usage = "sourceFiles[] lists the Wolfram Language files that the check reads: the paclet metadata, the kernel, the tests and the \
scripts.";
$requiredFields::usage = "$requiredFields lists the fields that PacletInfo.wl must give, each a non-empty string.";
$versionPattern::usage = "$versionPattern is the pattern of a paclet version, MAJOR.MINOR.PATCH.";
missingFieldQ::usage = "missingFieldQ[paclet, field] gives True when a field of the paclet is missing or empty.";
checkMetadata::usage = "checkMetadata[] checks PacletInfo.wl: that it validates, its required fields, its name and the form of its version. It \
checks that CITATION.cff gives the same version and license, and gives the paclet object.";
symbolName::usage = "symbolName[name] gives the last part of the full name of a symbol.";
usageQ::usage = "usageQ[name] gives True when the symbol with the full name has a usage message.";
checkSymbols::usage = "checkSymbols[paclet] compares the symbols of the loaded paclet with the \"Symbols\" list of PacletInfo.wl, checks that \
each has a usage message, and gives their full names.";
referencePage::usage = "referencePage[name] gives the path of the reference page of the symbol with the full name.";
checkReferencePages::usage = "checkReferencePages[paclet, names] checks that the paclet has one Documentation extension and that each of the \
symbols with the full names has a reference page written from the Symbol template.";

(* ::Section:: *)
(*Function Definitions*)

$requiredFields = {"Name", "Version", "WolframVersion", "Description", "Creator", "License", "PublisherID", "PrimaryContext"};
$versionPattern = DigitCharacter.. ~~ "." ~~ DigitCharacter.. ~~ "." ~~ DigitCharacter..;

sourceFiles[] :=
	Join[
		{FileNameJoin[{$PacletDirectory, "PacletInfo.wl"}]},
		FileNames[{"*.wl", "*.m"}, FileNameJoin[{$PacletDirectory, "Kernel"}], Infinity],
		FileNames["*.wlt", FileNameJoin[{$PacletDirectory, "Tests"}], Infinity],
		FileNames[{"*.wl", "*.wls", "*.wlt"}, $ScriptsDirectory, Infinity]
	]

missingFieldQ[paclet_PacletObject, field_String] := !StringQ[paclet[field]] || StringTrim[paclet[field]] === ""

checkMetadata[] :=
	Module[{paclet, missingFields, citation},
		paclet = quietCheck[PacletObject[File[$PacletDirectory]]];
		RequireOrLog[paclet, PacletObjectQ, "Cannot read PacletInfo.wl"];
		RequireOrLog[PacletValidate[$PacletDirectory], TrueQ, "PacletValidate failed"];
		missingFields = Select[$requiredFields, missingFieldQ[paclet, #] &];
		RequireOrLog[missingFields, # === {} &, "Missing metadata: ", missingFields];
		RequireOrLog[paclet["Name"], # === $PacletName &, "Unexpected paclet name"];
		RequireOrLog[paclet["Version"], StringMatchQ[#, $versionPattern] &, "Version must use MAJOR.MINOR.PATCH"];
		citation = Import[FileNameJoin[{$RepositoryRoot, "CITATION.cff"}], "Text"];
		RequireOrLog[citation, StringContainsQ[#, "version: " <> paclet["Version"]] &, "CITATION.cff has a different version"];
		RequireOrLog[citation, StringContainsQ[#, "license: " <> paclet["License"]] &, "CITATION.cff has a different license"];
		paclet
	]

symbolName[name_String] := Last @ StringSplit[name, "`"]

usageQ[name_String] := StringQ[Quiet[ToExpression[name <> "::usage"], All]]

(* Names gives short names for a context on $ContextPath, so each name is rebuilt from its last part. *)
checkSymbols[paclet_PacletObject] :=
	Module[{context, declaredNames, exportedSymbols, missingUsage},
		context = paclet["PrimaryContext"];
		declaredNames = Flatten[Lookup[Map[Last, PacletExtensions[paclet, "Kernel"]], "Symbols", {}]];
		exportedSymbols = Map[context <> symbolName[#] &, Names[context <> "*"]];
		RequireOrLog[Sort[declaredNames], # === Sort[exportedSymbols] &, "PacletInfo.wl symbol list does not match exported symbols"];
		missingUsage = Select[exportedSymbols, !usageQ[#] &];
		RequireOrLog[missingUsage, # === {} &, "Missing usage messages: ", missingUsage];
		exportedSymbols
	]

referencePage[name_String] := FileNameJoin[{$RepositoryRoot, "docs", "en", "Symbols", symbolName[name] <> ".md"}]

checkReferencePages[paclet_PacletObject, names : {___String}] :=
	Module[{documentationFiles, missingDocumentation, invalidDocumentation},
		RequireOrLog[PacletExtensions[paclet, "Documentation"], Length[#] === 1 &, "PacletInfo.wl must have one Documentation extension"];
		documentationFiles = referencePage /@ names;
		missingDocumentation = Select[documentationFiles, !FileExistsQ[#] &];
		RequireOrLog[missingDocumentation, # === {} &, "Missing reference pages: ", missingDocumentation];
		invalidDocumentation = Select[documentationFiles, !StringContainsQ[ReadString[#], "Template: Symbol"] &];
		RequireOrLog[invalidDocumentation, # === {} &, "Invalid reference pages: ", invalidDocumentation]
	]

CheckPaclet[] :=
	Module[{paclet, exportedSymbols},
		checkMetadata[];
		LintFiles[sourceFiles[]];
		requireNoErrors[];
		paclet = LoadPaclet[];
		exportedSymbols = checkSymbols[paclet];
		checkReferencePages[paclet, exportedSymbols];
		LogInfo["OK: ", paclet["Name"], " ", paclet["Version"]]
	]
CheckPaclet[___] := invalidArgumentsFailure[CheckPaclet]
