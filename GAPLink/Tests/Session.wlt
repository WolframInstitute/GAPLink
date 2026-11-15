(* Tests for Kernel/Session.wl that need no GAP: the options, the properties and a session whose process is gone. *)

PacletDirectoryLoad[DirectoryName[$TestFileName, 2]]
Needs["WolframInstitute`GAPLink`"]

createSession = WolframInstitute`GAPLink`PackageScope`gapLinkCreateSession;

(* The state of a session without a process: it counts as stopped as soon as it is read. *)
fakeState = <|
	"Executable" -> "/test/gap",
	"Process" -> None,
	"Info" -> <|
		"GAPVersion" -> "4.15.1",
		"Packages" -> {"GAPDoc", "primgrp"}
	|>
|>;

VerificationTest[
	Options[StartGAPSession],
	{"Executable" -> Automatic, TimeConstraint -> 30},
	TestID -> "Session-Defaults"
]

VerificationTest[
	MatchQ[
		{
			StartGAPSession["Executable" -> ""],
			StartGAPSession[TimeConstraint -> 0],
			StartGAPSession[TimeConstraint -> -1]
		},
		{Failure["GAPInvalidOption", _] ..}
	],
	True,
	TestID -> "Reject-Session-Options"
]

VerificationTest[
	Module[{failure},
		failure = StartGAPSession[1];
		{First[failure], failure["MessageParameters"]}
	],
	{"InvalidArguments", {StartGAPSession}},
	{StartGAPSession::args},
	TestID -> "Reject-Session-Arguments"
]

VerificationTest[
	Module[{session},
		session = createSession[fakeState];
		{
			MatchQ[session, _GAPSession],
			session["Status"],
			session["Executable"],
			session["Version"],
			session["Packages"],
			session["Backend"],
			session["Properties"],
			session["Other"]
		}
	],
	{
		True,
		"Stopped",
		"/test/gap",
		"4.15.1",
		{"GAPDoc", "primgrp"},
		"Process",
		{
			"Status", "Executable", "Version", "Packages",
			"LoadedPackages", "Backend", "Properties"
		},
		Missing["UnknownProperty", "Other"]
	},
	TestID -> "Read-Session-Properties"
]

VerificationTest[
	FailureQ[GAPSession["missing"]["Status"]],
	True,
	TestID -> "Reject-Unknown-Session"
]

VerificationTest[
	First[GAPSession["missing"][1]],
	"InvalidArguments",
	{GAPSession::args},
	TestID -> "Reject-Property-That-Is-Not-A-Name"
]

VerificationTest[
	Module[{session},
		session = createSession[fakeState];
		MatchQ[session["LoadedPackages"], Failure["GAPInvalidSession", _]]
	],
	True,
	TestID -> "Reject-Loaded-Packages-Without-GAP"
]

VerificationTest[
	Module[{session},
		session = createSession[fakeState];
		DeleteObject[session];
		{session["Status"], DeleteObject[session]}
	],
	{"Closed", Null},
	TestID -> "Delete-Session-Twice"
]
