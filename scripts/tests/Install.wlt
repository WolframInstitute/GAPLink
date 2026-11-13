(* Tests of the install command in README.md: on every system it must install the archive of that system. Nothing is
   downloaded or installed: the cloud objects and PacletInstall are replaced for the test. *)

Get[FileNameJoin[{DirectoryName[$TestFileName, 2], "run.wls"}]]["Load"]
Needs["GAPLink`Scripts`"]
Needs["CloudObject`"]

systems = GAPLink`Scripts`PackageScope`$systems;
pacletResourceInfo = GAPLink`Scripts`PackageScope`pacletResourceInfo;
platformDescription = GAPLink`Scripts`PackageScope`platformDescription;

(* The first Wolfram Language code block of the README is the install command. *)
installExample = First @ StringCases[
	Import[FileNameJoin[{$RepositoryRoot, "README.md"}], "Text"],
	RegularExpression["(?s)```wolfram\n(.*?)\n```"] -> "$1"
];

pageObject = CloudObject["https://www.wolframcloud.com/obj/wolframinstitute/DeployedResources/Paclet/WolframInstitute/GAPLink"];
descriptionObject = CloudObject["https://www.wolframcloud.com/obj/gaplink-test/platforms.wl"];

(* The system that the platform description is read on. A test sets it before it reads the description. *)
installingSystem = $SystemID;

platformResources[] :=
	AssociationMap[
		pacletResourceInfo[PacletObject[File[$PacletDirectory]], CloudObject["https://www.wolframcloud.com/obj/gaplink-test/" <> # <> ".paclet"], #] &,
		systems
	]

(* Makes the resource page point to the platform description, and the description read as it would on installingSystem.
   With puts the two cloud objects into the definitions, whose left-hand sides are held. *)
definePlatformPage[descriptionText_String] :=
	With[{page = pageObject, description = descriptionObject},
		CloudObject /: Verbatim[Options][page, MetaInformation] := {MetaInformation -> <|"ResourceLocation" -> description|>};
		CloudObject /: CloudGet[description] := ToExpression[StringReplace[descriptionText, "$SystemID" -> ToString[installingSystem, InputForm]]]
	]

(* Evaluates body with the definitions that setup adds to CloudObject, and takes them away afterwards. *)
SetAttributes[withCloudObjectDefinitions, HoldAll];
withCloudObjectDefinitions[setup_, body_] :=
	Module[{savedUpValues, protectedQ},
		savedUpValues = UpValues[CloudObject];
		protectedQ = MemberQ[Attributes[CloudObject], Protected];
		WithCleanup[
			Unprotect[CloudObject];
			setup,
			body,
			UpValues[CloudObject] = savedUpValues;
			If[protectedQ, Protect[CloudObject]]
		]
	]

recordInstall[arguments___] := Sow[{arguments}, "Install"]

(* Runs the install command as on the given system and says whether it installs that system's archive, with progress. *)
installsPlatformQ[resources_Association, system_String] := (
	installingSystem = system;
	Block[{PacletInstall = recordInstall},
		MatchQ[
			Reap[ToExpression[installExample], "Install"],
			{_, {{{resources[system]["PacletFile"], ForceVersionInstall -> True, "ShowProgress" -> True}}}}
		]
	]
)

VerificationTest[
	Module[{resources},
		resources = platformResources[];
		withCloudObjectDefinitions[
			definePlatformPage[platformDescription[resources]],
			(* Load the resource tools before PacletInstall is replaced. *)
			installingSystem = First[systems];
			ResourceObject[First[pageObject]];
			Map[installsPlatformQ[resources, #] &, systems]
		]
	],
	{True, True, True, True},
	TestID -> "Readme-Install-Selects-All-Four-Platforms-With-Progress"
]
