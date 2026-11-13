(* Integration tests of the transport: large output on both streams and a large reply with text outside ASCII.
   They need GAP; set GAPLINK_GAP to choose one. *)

PacletDirectoryLoad[DirectoryName[$TestFileName, 3]]
Needs["WolframInstitute`GAPLink`"]

gapExecutable = Replace[Environment["GAPLINK_GAP"], Except[_String] | "" -> Automatic];

largeOutputCode = StringJoin[
	"WriteAll(OutputTextUser(), ListWithIdenticalEntries(200000, 'x')); ",
	"WriteAll(OutputTextFile(\"*errout*\", false), ListWithIdenticalEntries(200000, 'e')); 42;"
];

VerificationTest[
	Module[{session, text, captured},
		session = StartGAPSession["Executable" -> gapExecutable];
		text = StringRepeat["GAP \[Lambda] ", 10000];
		If[FailureQ[session],
			{"Start GAP" -> session},

			WithCleanup[
				captured = GAPEvaluate[session, largeOutputCode, "Output" -> "Capture"];
				{
					captured === <|"Result" -> 42, "StandardOutput" -> StringRepeat["x", 200000], "StandardError" -> StringRepeat["e", 200000]|>,
					GAPCall[session, "IdFunc", text] === text,
					GAPCall[session, "Sum", {1, 2, 3}] === 6
				},
				DeleteObject[session]
			]
		]
	],
	{True, True, True},
	TestID -> "Read-Large-Output-And-Unicode-Reply"
]
