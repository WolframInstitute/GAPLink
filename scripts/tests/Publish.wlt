(* Tests of the publishing scripts: cloud uploads, resource descriptions, the release tag and the order of a release.
   Nothing is uploaded: the cloud functions are replaced for each test. *)

Get[FileNameJoin[{DirectoryName[$TestFileName, 2], "run.wls"}]]["Load"]
Needs["GAPLink`Scripts`"]
Needs["CloudObject`"]
Needs["PacletResource`"]

systems = GAPLink`Scripts`PackageScope`$systems;
publicCloudFileQ = GAPLink`Scripts`PackageScope`publicCloudFileQ;
publishCloudFile = GAPLink`Scripts`PackageScope`publishCloudFile;
pacletResourceInfo = GAPLink`Scripts`PackageScope`pacletResourceInfo;
publishPlatform = GAPLink`Scripts`PackageScope`publishPlatform;
platformDescription = GAPLink`Scripts`PackageScope`platformDescription;
attachPlatforms = GAPLink`Scripts`PackageScope`attachPlatforms;
releaseTag = GAPLink`Scripts`PackageScope`releaseTag;
siteCheckFailure = GAPLink`Scripts`PackageScope`siteCheckFailure;

sourcePaclet = PacletObject[File[$PacletDirectory]];
uploadedObject = CloudObject["https://example.invalid/obj/test/paclet"];

(* Stand-ins for the cloud functions. Each records its step under the tag "Publish". *)
recordUpload[___] := (
	Sow["Upload", "Publish"];
	uploadedObject
)
recordMetadata[___] := (
	Sow["Metadata", "Publish"];
	{MetaInformation -> <||>}
)
recordPermissions[_, permissions_] := (
	Sow[{"Permissions", permissions}, "Publish"];
	{All -> {"Read"}}
)
recordVerify[___] := (
	Sow["Verify", "Publish"];
	True
)
recordStep[step_String] := Function[Null, Sow[step, "Publish"]]

(* In place of logging an error and stopping the task, a failed requirement gives its message. *)
throwMessage[parts___] := Throw[StringJoin[Map[ToString, {parts}]], "TaskFailure"]

(* Evaluates body with the cloud replaced by the stand-ins. A failed requirement gives its message as the result. *)
SetAttributes[withPublishMocks, HoldAll];
withPublishMocks[body_] :=
	Block[
		{
			CopyFile = recordUpload,
			SetOptions = recordMetadata,
			SetPermissions = recordPermissions,
			GAPLink`Scripts`PackageScope`publicCloudFileQ = recordVerify,
			GAPLink`Scripts`PackageScope`failTask = throwMessage
		},
		Catch[body, "TaskFailure"]
	]

(* Evaluates body with extra definitions for CloudObject and takes them away afterwards. *)
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

platformResources[] :=
	AssociationMap[
		pacletResourceInfo[sourcePaclet, CloudObject["https://example.invalid/obj/GAPLink/" <> $ArchivePrefix <> "-" <> # <> ".paclet"], #] &,
		systems
	]

VerificationTest[
	withPublishMocks @ Reap[publishCloudFile["file.paclet", "https://example.invalid/obj/test/path", <||>, "application/zip"], "Publish"],
	{"https://example.invalid/obj/test/paclet", {{"Upload", "Metadata", {"Permissions", All -> "Read"}, "Verify"}}},
	TestID -> "Publish-Set-Public-Access-And-Verify"
]

VerificationTest[
	withPublishMocks @ Block[{CopyFile = ($Failed &)},
		publishCloudFile["file.paclet", "https://example.invalid/obj/test/path", <||>, "application/zip"]
	],
	"Could not upload https://example.invalid/obj/test/path",
	TestID -> "Publish-Reject-Failed-Upload"
]

VerificationTest[
	withPublishMocks @ Block[{SetOptions = ({$Failed} &)},
		publishCloudFile["file.paclet", "https://example.invalid/obj/test/path", <||>, "application/zip"]
	],
	"Could not set metadata for https://example.invalid/obj/test/paclet",
	TestID -> "Publish-Reject-Failed-Metadata"
]

VerificationTest[
	withPublishMocks @ Block[{SetPermissions = ($Failed &)},
		publishCloudFile["file.paclet", "https://example.invalid/obj/test/path", <||>, "application/zip"]
	],
	"Could not set public access for https://example.invalid/obj/test/path",
	TestID -> "Publish-Reject-Failed-Permissions"
]

VerificationTest[
	withPublishMocks @ Block[{GAPLink`Scripts`PackageScope`publicCloudFileQ = (False &)},
		publishCloudFile["file.paclet", "https://example.invalid/obj/test/path", <||>, "application/zip"]
	],
	"Anonymous download failed for https://example.invalid/obj/test/paclet",
	TestID -> "Publish-Reject-Private-Download"
]

VerificationTest[
	Table[
		Block[{RunProcess = (<|"ExitCode" -> code|> &)},
			publicCloudFileQ["https://example.invalid/obj/test/paclet", "application/zip"]
		],
		{code, {0, 1}}
	],
	{True, False},
	TestID -> "Publish-Check-Anonymous-Request-Result"
]

VerificationTest[
	publicCloudFileQ[1, 2],
	False,
	TestID -> "Publish-Check-Is-False-For-Other-Arguments"
]

VerificationTest[
	Module[{infos},
		infos = Values[platformResources[]];
		{
			Lookup[infos, "SystemID"] === systems,
			AllTrue[infos, StringEndsQ[First[#["PacletFile"]], #["SystemID"] <> ".paclet"] &],
			DuplicateFreeQ[Lookup[infos, "UUID"]],
			AllTrue[infos, Lookup[#, {"Name", "ResourceType", "Version", "Autoload"}] === {$PacletName, "Paclet", sourcePaclet["Version"], True} &],
			FreeQ[infos, sourcePaclet["Location"]]
		}
	],
	{True, True, True, True, True},
	TestID -> "Resource-Platform-Archives"
]

VerificationTest[
	Module[{first, second},
		first = pacletResourceInfo[sourcePaclet, uploadedObject, $SystemID];
		second = pacletResourceInfo[sourcePaclet, uploadedObject, $SystemID];
		first["UUID"] =!= second["UUID"]
	],
	True,
	TestID -> "Resource-Republish-Refreshes-Cache-Identity"
]

(* A stand-in for publishCloudFile that records the cloud path, the metadata and the type, and gives a URL. *)
recordCloudFile[_, path_String, metadata_Association, type_String] := (
	Sow[{path, metadata, type}, "Publish"];
	"https://example.invalid/obj/" <> path
)
recordCloudMetadata[object_CloudObject, metadata_Association] := Sow[{object, MetaInformation -> metadata}, "Publish"]

(* Publishes one platform into a temporary build directory, with the uploads recorded. It gives the description that
   publishPlatform returned ("Info"), the recorded uploads and metadata ("Records") and the text of the description file. *)
publishedPlatform[] :=
	Module[{directory, reaped},
		directory = CreateDirectory[];
		WithCleanup[
			reaped = Block[
				{
					$BuildDirectory = directory,
					GAPLink`Scripts`PackageScope`publishCloudFile = recordCloudFile,
					GAPLink`Scripts`PackageScope`setCloudMetadata = recordCloudMetadata
				},
				Reap[publishPlatform[FileNameJoin[{$PacletDirectory, "PacletInfo.wl"}], "Linux-x86-64", sourcePaclet, "test-commit"], "Publish"]
			];
			Replace[
				reaped,
				{info_, {records_List}} :> <|"Info" -> info, "Records" -> records, "Description" -> Import[FileNameJoin[{directory, "PacletInfo.wl"}], "Text"]|>
			],
			DeleteDirectory[directory, DeleteContents -> True]
		]
	]

VerificationTest[
	Replace[
		publishedPlatform[],
		KeyValuePattern[{
			"Info" -> info_Association,
			"Records" -> {
				{archivePath_String, archiveData_Association, archiveType_String},
				{descriptionPath_String, _, descriptionType_String},
				{linked_CloudObject, MetaInformation -> linkedData_Association}
			},
			"Description" -> description_String
		}] :> Module[{described},
			described = Block[{ResourceObject}, First[ToExpression[description]]];
			{
				info["PacletFile"],
				{archivePath, descriptionPath, linked},
				archiveData["Commit"],
				archiveData["Version"],
				archiveType,
				descriptionType,
				linkedData["ResourceLocation"],
				described["PacletFile"] === linked,
				described["UUID"] === linkedData["UUID"],
				described["Autoload"]
			}
		]
	],
	{
		CloudObject["https://example.invalid/obj/GAPLink/WolframInstitute__GAPLink-Linux-x86-64.paclet"],
		{
			"GAPLink/WolframInstitute__GAPLink-Linux-x86-64.paclet",
			"GAPLink/PacletInfo.wl",
			CloudObject["https://example.invalid/obj/GAPLink/WolframInstitute__GAPLink-Linux-x86-64.paclet"]
		},
		"test-commit",
		sourcePaclet["Version"],
		"application/zip",
		"text/plain",
		CloudObject["https://example.invalid/obj/GAPLink/PacletInfo.wl"],
		True,
		True,
		True
	},
	TestID -> "Publish-Resource-Links-To-Existing-Archive"
]

(* A resource object made from the URL of an archive reads the small description file, not the archive. *)
archiveObject = CloudObject["https://www.wolframcloud.com/obj/gaplink-test/test.paclet"];
resourceDescriptionObject = CloudObject["https://www.wolframcloud.com/obj/gaplink-test/ResourceObject.wl"];
descriptionReads = 0;

defineArchiveDescription[descriptionText_String] :=
	With[{archive = archiveObject, description = resourceDescriptionObject},
		CloudObject /: Verbatim[Options][archive, MetaInformation] := {MetaInformation -> <|"ResourceLocation" -> description|>};
		CloudObject /: CloudGet[description] := (
			descriptionReads++;
			ToExpression[descriptionText]
		)
	]

VerificationTest[
	Module[{info, text, resource},
		info = pacletResourceInfo[sourcePaclet, archiveObject, "Linux-x86-64"];
		text = Block[{ResourceObject}, ToString[ResourceObject[info], InputForm]];
		descriptionReads = 0;
		withCloudObjectDefinitions[
			defineArchiveDescription[text],
			resource = ResourceObject[First[archiveObject]];
			{MatchQ[resource, _ResourceObject], descriptionReads, Lookup[resource[All], {"Name", "ResourceType", "SystemID", "PacletFile"}]}
		]
	],
	{True, 1, {$PacletName, "Paclet", "Linux-x86-64", CloudObject["https://www.wolframcloud.com/obj/gaplink-test/test.paclet"]}},
	TestID -> "ResourceObject-Reads-Description-Not-Archive"
]

(* The platform description as it reads on the system with the given ID: the description of the resource it picks,
   or what it gives for a system without an archive. ResourceObject is kept from evaluating. *)
descriptionOn[description_String, system_String] :=
	Block[{ResourceObject},
		Replace[ToExpression[StringReplace[description, "$SystemID" -> ToString[system, InputForm]]], ResourceObject[info_] :> info]
	]

VerificationTest[
	Module[{resources, description, results},
		resources = platformResources[];
		description = platformDescription[resources];
		results = Map[descriptionOn[description, #] &, systems];
		{
			results === Values[resources],
			DuplicateFreeQ[Lookup[results, "UUID"]],
			FailureQ[descriptionOn[description, "Unsupported"]]
		}
	],
	{True, True, True},
	TestID -> "Resource-Selects-The-Installing-System"
]

releaseMetadata = {"PacletVersion" -> "0.3.0", "PacletCommit" -> "commit", "Other" -> 1};
releaseResourceObject = CloudObject["https://example.invalid/obj/resource"];

defineReleaseMetadata[] :=
	With[{resource = releaseResourceObject, metadata = releaseMetadata},
		CloudObject /: Verbatim[Options][resource, MetaInformation] := {MetaInformation -> metadata}
	]

giveDescriptionURL[___] := "https://example.invalid/obj/platforms.wl"
giveMetadata[_CloudObject, metadata_Association] := metadata

VerificationTest[
	Module[{directory},
		directory = CreateDirectory[];
		WithCleanup[
			withCloudObjectDefinitions[
				defineReleaseMetadata[],
				Block[
					{
						$BuildDirectory = directory,
						GAPLink`Scripts`PackageScope`publishCloudFile = giveDescriptionURL,
						GAPLink`Scripts`PackageScope`setCloudMetadata = giveMetadata
					},
					attachPlatforms["https://example.invalid/obj/resource", <||>, "0.3.0", "commit"]
				]
			],
			DeleteDirectory[directory, DeleteContents -> True]
		]
	],
	Append[Association[releaseMetadata], "ResourceLocation" -> CloudObject["https://example.invalid/obj/platforms.wl"]],
	TestID -> "Platform-Routing-Preserves-PacletPage-Release-Metadata"
]

releaseEnvironment = <|
	"GITHUB_ACTIONS" -> "true",
	"GITHUB_EVENT_NAME" -> "push",
	"GITHUB_REF_TYPE" -> "tag",
	"GITHUB_REF_NAME" -> "v0.3.0",
	"GITHUB_REF" -> "refs/tags/v0.3.0"
|>;

(* The release tag, or the message of the requirement that failed. *)
checkedReleaseTag[environment_Association, version_String] :=
	Block[{GAPLink`Scripts`PackageScope`failTask = throwMessage}, Catch[releaseTag[environment, version], "TaskFailure"]]

VerificationTest[
	{
		checkedReleaseTag[releaseEnvironment, "0.3.0"],
		checkedReleaseTag[<||>, "0.3.0"],
		checkedReleaseTag[releaseEnvironment, "0.3.1"],
		checkedReleaseTag[Append[releaseEnvironment, "GITHUB_EVENT_NAME" -> "pull_request"], "0.3.0"],
		checkedReleaseTag[Append[releaseEnvironment, "GITHUB_REF" -> "refs/heads/v0.3.0"], "0.3.0"]
	},
	{
		"v0.3.0",
		"Publishing requires a release-tag workflow",
		"The release tag must match PacletInfo.wl",
		"Publishing requires a release-tag workflow",
		"The release tag must match PacletInfo.wl"
	},
	TestID -> "Publish-Only-From-A-Matching-Release-Tag"
]

giveCommit[___] := "commit"
throwInvalidArchive[___] := Throw["Invalid archive", "ReleaseFailure"]
throwConnectedTooEarly[___] := Throw["Connected too early", "ReleaseFailure"]

VerificationTest[
	Block[
		{
			CheckRelease = giveCommit,
			GAPLink`Scripts`PackageScope`platformArchives = Function[Null, <||>],
			VerifyPaclet = throwInvalidArchive,
			CloudConnect = throwConnectedTooEarly
		},
		Catch[PublishPaclet[], "ReleaseFailure"]
	],
	"Invalid archive",
	TestID -> "Reject-Unverified-Build-Before-Connecting-To-Cloud"
]

platformResourceObject = CloudObject["https://example.invalid/obj/platform.paclet"];
pageResult = <|
	"Resource" -> <|"Deployed" -> True, "Resource" -> "https://example.invalid/obj/resource"|>,
	"Site" -> <|"Site" -> "https://example.invalid/obj/GAPLink/Documentation"|>,
	"Check" -> <|"OK" -> True|>
|>;

recordPageCall[arguments___] := (
	Sow[{arguments}, "PageCall"];
	Sow["PacletPage", "Publish"];
	pageResult
)
recordPlatform[___] := (
	Sow["Platform", "Publish"];
	<|"PacletFile" -> platformResourceObject|>
)
resolvedProperty[___] := (
	Sow["Resolve", "Publish"];
	platformResourceObject
)
recordResolve[___] := resolvedProperty
verifiedArchives[___] := AssociationMap[# <> ".paclet" &, systems]

(* Runs PublishPaclet with every outside step replaced. It gives the recorded steps and the arguments of the call
   of PacletPage. *)
publishedRelease[] :=
	Block[
		{
			CheckRelease = giveCommit,
			GAPLink`Scripts`PackageScope`platformArchives = verifiedArchives,
			VerifyPaclet = recordStep["Verify"],
			GAPLink`Scripts`PackageScope`environmentSetting = Function[Null, "test"],
			CloudConnect = recordStep["Connect"],
			$CloudConnected = True,
			GAPLink`Scripts`PackageScope`pageCall = recordPageCall,
			GAPLink`Scripts`PackageScope`publishPlatform = recordPlatform,
			GAPLink`Scripts`PackageScope`attachPlatforms = recordStep["Route"],
			ResourceObject = recordResolve,
			WriteGitHubOutput = Function[Null, Null],
			LogInfo = Function[Null, Null]
		},
		Reap[Reap[PublishPaclet[], "Publish"], "PageCall"]
	]

(* A CloudConnect that prints a message and connects, and one that fails. *)
connectWithNotice::notice = "The cloud printed a notice.";
connectWithNotice[___] := (
	Message[connectWithNotice::notice];
	Sow["Connect", "Publish"]
)
failToConnect[___] := $Failed

(* The steps of a release in which CloudConnect does what connect does and leaves $CloudConnected as connectedQ, and
   pacletPageCall stands in for the call of PacletPage, or the message of the requirement that failed. *)
releaseSteps[connect_Symbol, connectedQ : (True | False), pacletPageCall : (_Symbol | _Function)] :=
	Block[
		{
			CheckRelease = giveCommit,
			GAPLink`Scripts`PackageScope`platformArchives = verifiedArchives,
			VerifyPaclet = recordStep["Verify"],
			GAPLink`Scripts`PackageScope`environmentSetting = Function[Null, "test"],
			CloudConnect = connect,
			$CloudConnected = connectedQ,
			GAPLink`Scripts`PackageScope`failTask = throwMessage,
			GAPLink`Scripts`PackageScope`pageCall = pacletPageCall,
			GAPLink`Scripts`PackageScope`publishPlatform = recordPlatform,
			GAPLink`Scripts`PackageScope`attachPlatforms = recordStep["Route"],
			ResourceObject = recordResolve,
			WriteGitHubOutput = Function[Null, Null],
			LogInfo = Function[Null, Null]
		},
		Catch[First @ Last @ Reap[PublishPaclet[], "Publish"], "TaskFailure"]
	]
releaseSteps[connect_Symbol, connectedQ : (True | False)] := releaseSteps[connect, connectedQ, recordPageCall]

VerificationTest[
	releaseSteps[connectWithNotice, True],
	{"Verify", "Connect", "PacletPage", "Platform", "Platform", "Platform", "Platform", "Route", "Resolve"},
	{connectWithNotice::notice},
	TestID -> "Publish-Goes-On-When-CloudConnect-Prints-A-Message-And-Connects"
]

VerificationTest[
	releaseSteps[failToConnect, False],
	"Could not connect to Wolfram Cloud: $Failed",
	TestID -> "Publish-Stops-When-CloudConnect-Does-Not-Connect"
]

(* A CloudConnect that connects without a message. *)
connectQuietly[___] := Sow["Connect", "Publish"]

(* A stand-in for the call of PacletPage that records the call, as recordPageCall does, and gives result. *)
pageCallGiving[result_Association] :=
	Function[Null,
		Sow[{##}, "PageCall"];
		Sow["PacletPage", "Publish"];
		result
	]

(* The steps of a release in which the check of the published site gives check, or the message of the requirement
   that failed. *)
releaseWithCheck[check_Association] := releaseSteps[connectQuietly, True, pageCallGiving[Append[pageResult, "Check" -> check]]]

VerificationTest[
	releaseWithCheck[
		<|
			"OK" -> False,
			"Failed" -> {
				<|"Check" -> "Page ref/GAPCall", "URL" -> "https://example.invalid/obj/ref/GAPCall.nb", "OK" -> False, "Detail" -> "HTTP 503"|>,
				<|"Check" -> "Feedback Me", "URL" -> "https://example.invalid/obj/Feedback/Me", "OK" -> False, "Detail" -> "not readable anonymously"|>
			}
		|>
	],
	StringRiffle[
		{
			"Published documentation did not pass its checks:",
			"Page ref/GAPCall: HTTP 503 (https://example.invalid/obj/ref/GAPCall.nb)",
			"Feedback Me: not readable anonymously (https://example.invalid/obj/Feedback/Me)"
		},
		"\n"
	],
	TestID -> "Publish-Stops-And-Names-Each-Failed-Site-Check"
]

VerificationTest[
	{siteCheckFailure[<|"OK" -> False|>], siteCheckFailure[None]},
	ConstantArray["Published documentation did not pass its checks", 2],
	TestID -> "Publish-Site-Check-Error-Reads-The-Same-Without-Details"
]

(* The cloud renders the pages of a new site some time after they are published. *)
VerificationTest[
	Replace[publishedRelease[], {_, {{{_String, _, _String, options___Rule}}}} :> Lookup[{options}, "CheckOptions"]],
	{"Wait" -> 600},
	TestID -> "Publish-Gives-A-Failed-Site-Check-Ten-Minutes"
]

VerificationTest[
	Replace[
		publishedRelease[],
		{{_, {steps_List}}, {{{function_String, _, target_String, options___Rule}}}} :> {
			steps,
			function,
			target,
			Lookup[{options}, "Build"],
			Lookup[Lookup[{options}, "ResourceOptions"], "Build"]
		}
	],
	{
		{"Verify", "Connect", "PacletPage", "Platform", "Platform", "Platform", "Platform", "Route", "Resolve"},
		"PublishPacletPage",
		"GAPLink/Documentation",
		False,
		False
	},
	TestID -> "Publish-Reuses-Verified-Build-And-Routes-The-Resource"
]
