(* ::Package:: *)

(* ::Section:: *)
(*PackageExported*)

PackageExported[{CheckRelease, PublishPaclet}];

(* ::Section:: *)
(*PackageScoped*)

PackageScoped[{releaseTag, gitText, siteCheckFailure}];

(* ::Section:: *)
(*Usage Messages*)

CheckRelease::usage = "CheckRelease[] checks that this is a release-tag workflow whose tag matches PacletInfo.wl, points to HEAD, is on main and \
has no uncommitted changes. It gives the commit hash, and stops the current task when a check fails.\n\
CheckRelease[environment] reads the workflow variables from the association environment and not from the process.";
PublishPaclet::usage = "PublishPaclet[] publishes the verified build of a release: the paclet resource and the documentation site with \
PacletPage, then the archive of each system, and links the resource to them. It connects to the Wolfram Cloud with WOLFRAM_CLOUD_USER and \
WOLFRAM_CLOUD_PASSWORD.";
$releaseTagPattern::usage = "$releaseTagPattern is the pattern of a release tag: v, then MAJOR.MINOR.PATCH without leading zeros.";
matchingTagQ::usage = "matchingTagQ[tag, environment, version] gives True when tag is a release tag for the version and the workflow of the \
association environment runs for that tag.";
releaseTag::usage = "releaseTag[environment, version] gives the tag of the release-tag workflow that the association environment describes, and \
stops the current task when the workflow is not one or its tag does not match the version.";
gitText::usage = "gitText[arguments] gives the output of the git command with the given string arguments, and stops the current task when git fails.";
$siteCheckWait::usage = "$siteCheckWait is the number of seconds that the check of the published site gives a failed check to pass. The cloud \
renders the pages of a site some time after they are published.";
failedCheckLine::usage = "failedCheckLine[result] gives the line that describes the failed check result: its name, the reason and the URL.";
siteCheckFailure::usage = "siteCheckFailure[check] gives the error for published documentation that did not pass its checks, with a line for \
each check that failed in check, the association that the site check of PacletPage gives.";

(* ::Section:: *)
(*Function Definitions*)

$releaseTagPattern = RegularExpression["v(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)"];

matchingTagQ[tag_String, environment_Association, version_String] :=
	And[
		StringMatchQ[tag, $releaseTagPattern],
		tag === "v" <> version,
		Lookup[environment, "GITHUB_REF"] === "refs/tags/" <> tag
	]
matchingTagQ[___] := False

releaseTag[environment_Association, version_String] :=
	Module[{tag},
		tag = Lookup[environment, "GITHUB_REF_NAME", ""];
		RequireOrLog[
			Lookup[environment, {"GITHUB_ACTIONS", "GITHUB_EVENT_NAME", "GITHUB_REF_TYPE"}],
			# === {"true", "push", "tag"} &,
			"Publishing requires a release-tag workflow"
		];
		RequireOrLog[tag, matchingTagQ[#, environment, version] &, "The release tag must match PacletInfo.wl"]
	]

gitText[arguments__String] :=
	Module[{result},
		result = RunProcess[{"git", "-C", $RepositoryRoot, arguments}];
		RequireOrLog[result["ExitCode"], # === 0 &, "Git could not verify the release checkout"];
		StringTrim[result["StandardOutput"]]
	]

CheckRelease[environment_Association] :=
	Module[{tag, commit, ancestorCheck},
		tag = releaseTag[environment, PacletObject[File[$PacletDirectory]]["Version"]];
		commit = gitText["rev-parse", "HEAD"];
		RequireOrLog[gitText["rev-parse", "refs/tags/" <> tag <> "^{commit}"], # === commit &, "The tag does not point to HEAD"];
		RequireOrLog[Lookup[environment, "GITHUB_SHA"], StringQ, "The workflow commit is missing"];
		RequireOrLog[gitText["rev-parse", environment["GITHUB_SHA"] <> "^{commit}"], # === commit &, "The checkout differs from the workflow commit"];
		ancestorCheck = RunProcess[{"git", "-C", $RepositoryRoot, "merge-base", "--is-ancestor", "HEAD", "origin/main"}];
		RequireOrLog[ancestorCheck["ExitCode"], # === 0 &, "The release commit is not on main"];
		RequireOrLog[gitText["status", "--porcelain"], # === "" &, "The release checkout has uncommitted changes"];
		commit
	]
CheckRelease[] := CheckRelease[Association[GetEnvironment[]]]
CheckRelease[___] := invalidArgumentsFailure[CheckRelease]

$siteCheckWait = 600;

failedCheckLine[checkResult_Association] :=
	StringJoin[
		TextString[Lookup[checkResult, "Check", "A check"]],
		": ",
		TextString[Lookup[checkResult, "Detail", "failed"]],
		" (",
		TextString[Lookup[checkResult, "URL", "no URL"]],
		")"
	]

siteCheckFailure[check_Association] :=
	Module[{lines},
		lines = Map[failedCheckLine, Cases[Lookup[check, "Failed", {}], _Association]];
		StringRiffle[Prepend[lines, "Published documentation did not pass its checks" <> If[lines === {}, "", ":"]], "\n"]
	]
siteCheckFailure[___] := "Published documentation did not pass its checks"

(* CloudConnect can print a message and still connect, so its messages go to the log and only the connection is
   required. *)
PublishPaclet[] :=
	Module[{commit, paclet, archives, account, password, connection, result, resource, resources},
		commit = CheckRelease[];
		paclet = PacletObject[File[$PacletDirectory]];
		archives = platformArchives[paclet["Version"]];
		VerifyPaclet[];
		account = environmentSetting["WOLFRAM_CLOUD_USER"];
		password = environmentSetting["WOLFRAM_CLOUD_PASSWORD"];
		connection = CloudConnect[account, password];
		RequireOrLog[$CloudConnected, TrueQ, "Could not connect to Wolfram Cloud: ", connection];
		result = pageCall[
			"PublishPacletPage", $PacletDirectory, "GAPLink/Documentation",
			"Account" -> account,
			"Build" -> False,
			"ResourceOptions" -> {"Build" -> False, "Parallel" -> False, "Commit" -> commit, "Exclude" -> $archiveExclusions},
			"CheckOptions" -> {"Wait" -> $siteCheckWait},
			"Monitor" -> True
		];
		RequireOrLog[result, AssociationQ, "PacletPage publication failed"];
		RequireOrLog[result["Resource"]["Deployed"], TrueQ, "PacletPage resource was not published"];
		RequireOrLog[result["Check"]["OK"], TrueQ, siteCheckFailure[result["Check"]]];
		resource = result["Resource"]["Resource"];
		resources = Association @ KeyValueMap[#1 -> publishPlatform[#2, #1, paclet, commit] &, archives];
		attachPlatforms[resource, resources, paclet["Version"], commit];
		RequireOrLog[
			quietCheck[ResourceObject[resource]["PacletFile"]],
			# === resources[$SystemID]["PacletFile"] &,
			"The resource did not select the matching platform archive"
		];
		WriteGitHubOutput["archives" -> Length[archives], "page" -> resource, "site" -> result["Site"]["Site"]];
		LogInfo["OK: ", resource];
		LogInfo["OK: ", result["Site"]["Site"]]
	]
PublishPaclet[___] := invalidArgumentsFailure[PublishPaclet]
