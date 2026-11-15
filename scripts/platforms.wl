(* ::Package:: *)

(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{
	publicCloudFileQ, setCloudMetadata, publishCloudFile, pacletResourceInfo, publishPlatform, platformArchives, platformDescription, attachPlatforms
}];

(* ::Section:: *)
(*Usage Messages*)

publicCloudFileQ::usage = "publicCloudFileQ[url, type] gives True when the file at url can be downloaded without an account and has the MIME type.\n\
publicCloudFileQ[url, type, hash] also requires the SHA-256 hash, a hexadecimal string. With None in place of the hash it checks the type only.";
setCloudMetadata::usage = "setCloudMetadata[object, metadata] sets the meta information of a cloud object to the association metadata, and stops \
the current task when the cloud refuses.";
publishCloudFile::usage = "publishCloudFile[file, path, metadata, type] uploads the file to the cloud path with the MIME type, sets its metadata, \
makes it public and checks that it can be downloaded without an account. It gives the URL of the cloud object.";
pacletResourceInfo::usage = "pacletResourceInfo[paclet, archive, system] gives the description of the paclet resource of one system, an \
association that names the cloud object archive as its paclet file. Each call gives a new UUID.";
publishPlatform::usage = "publishPlatform[file, system, paclet, commit] uploads the archive file of a system with its resource description, links \
the archive to the description, and gives the description as an association.";
platformArchive::usage = "platformArchive[version, system] gives the path of the verified archive of a system, and stops the current task when it \
is missing.";
platformArchives::usage = "platformArchives[version] gives an association from each system ID to the path of its verified archive.";
platformDescription::usage = "platformDescription[resources] gives the text of an expression that picks, on the computer that installs, the \
resource of its own system from the association resources, or gives a Failure for a system without a runtime.";
attachPlatforms::usage = "attachPlatforms[resource, resources, version, commit] publishes the platform description of the association resources \
and links the cloud object at the URL resource to it, keeping the release metadata that PacletPage wrote.";

(* ::Section:: *)
(*Function Definitions*)

publicCloudFileQ[url_String, type_String, hash : (_String | None)] :=
	Module[{response},
		response = quietCheck[pythonScript["verify-cloud.py", Join[{url, type}, If[StringQ[hash], {hash}, {}]]]];
		If[AssociationQ[response] && response["ExitCode"] =!= 0, LogInfo[Lookup[response, "StandardError", ""]]];
		MatchQ[response, KeyValuePattern["ExitCode" -> 0]]
	]
publicCloudFileQ[url_String, type_String] := publicCloudFileQ[url, type, None]
publicCloudFileQ[___] := False

setCloudMetadata[object_CloudObject, metadata_Association] :=
	RequireOrLog[quietCheck[SetOptions[object, MetaInformation -> metadata]], MatchQ[{__Rule}], "Could not set metadata for ", First[object]]

publishCloudFile[file_String, path_String, metadata_Association, type_String] :=
	Module[{object, expectedHash},
		object = quietCheck[CopyFile[file, CloudObject[path, Permissions -> "Public"], OverwriteTarget -> True, "MIMEType" -> type]];
		RequireOrLog[object, MatchQ[_CloudObject], "Could not upload ", path];
		setCloudMetadata[object, metadata];
		RequireOrLog[quietCheck[SetPermissions[object, All -> "Read"]], MatchQ[{__Rule}], "Could not set public access for ", path];
		expectedHash = If[type === "text/plain", FileHash[file, "SHA256", "HexString"], None];
		RequireOrLog[publicCloudFileQ[First[object], type, expectedHash], TrueQ, "Anonymous download failed for ", First[object]];
		First[object]
	]

pacletResourceInfo[paclet_PacletObject, archive_CloudObject, system_String] :=
	Join[
		KeyTake[First[paclet], {"Name", "Version", "Description", "PublisherID", "WolframVersion"}],
		<|"UUID" -> CreateUUID[], "ResourceType" -> "Paclet", "SystemID" -> system, "PacletFile" -> archive, "Autoload" -> True|>
	]

publishPlatform[file_String, system_String, paclet_PacletObject, commit_String] :=
	Module[{metadata, archive, info, description, written, resource},
		metadata = <|
			"Commit" -> commit,
			"SHA256" -> IntegerString[FileHash[file, "SHA256"], 16, 64],
			"Version" -> paclet["Version"],
			"SystemID" -> system
		|>;
		archive = publishCloudFile[file, FileNameJoin[{"GAPLink", $ArchivePrefix <> "-" <> system <> ".paclet"}], metadata, "application/zip"];
		info = pacletResourceInfo[paclet, CloudObject[archive], system];
		description = FileNameJoin[{$BuildDirectory, FileBaseName[file] <> ".wl"}];
		written = Block[{ResourceObject}, Export[description, ToString[ResourceObject[info], InputForm], "Text"]];
		RequireOrLog[written, StringQ, "Could not write resource description for ", system];
		resource = publishCloudFile[description, FileNameJoin[{"GAPLink", FileNameTake[description]}], metadata, "text/plain"];
		setCloudMetadata[
			CloudObject[archive],
			Join[metadata, KeyTake[info, {"Name", "UUID", "ResourceType", "Description"}], <|"ResourceLocation" -> CloudObject[resource]|>]
		];
		info
	]

platformArchive[version_String, system_String] :=
	Module[{file},
		file = FileNameJoin[{$BuildDirectory, StringRiffle[{$ArchivePrefix, system, version}, "-"] <> ".paclet"}];
		RequireOrLog[file, FileExistsQ, "Missing verified platform archive: ", file]
	]

platformArchives[version_String] := AssociationMap[platformArchive[version, #] &, $systems]

(* This expression runs on the installing computer, not the publishing runner. With puts the resources into the held code. *)
platformDescription[resources_Association] :=
	Replace[
		With[{entries = resources},
			HoldComplete[
				If[KeyExistsQ[entries, $SystemID],
					ResourceObject[entries[$SystemID]],
					Failure["UnsupportedSystem", <|"MessageTemplate" -> "GAPLink has no bundled runtime for `1`.", "MessageParameters" -> {$SystemID}|>]
				]
			]
		],
		HoldComplete[expression_] :> ToString[Unevaluated[expression], InputForm]
	]

attachPlatforms[resource_String, resources_Association, version_String, commit_String] :=
	Module[{file, written, description, object, metadata},
		file = FileNameJoin[{$BuildDirectory, $ArchivePrefix <> "-platforms-" <> version <> ".wl"}];
		written = Export[file, platformDescription[resources], "Text"];
		RequireOrLog[written, StringQ, "Could not write the platform resource description"];
		description = publishCloudFile[file, "GAPLink/" <> FileNameTake[file], <|"Commit" -> commit, "Version" -> version|>, "text/plain"];
		object = CloudObject[resource];
		metadata = quietCheck[Association[Lookup[Options[object, MetaInformation], MetaInformation]]];
		RequireOrLog[metadata, AssociationQ, "Could not read PacletPage release metadata"];
		setCloudMetadata[object, Append[metadata, "ResourceLocation" -> CloudObject[description]]]
	]
