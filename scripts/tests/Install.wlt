Needs["CloudObject`"];

installExamples = {
    First @ StringCases[
        Import[FileNameJoin[{repositoryRoot, "README.md"}], "Text"],
        RegularExpression["(?s)```wolfram\n(.*?)\n```"] -> "$1"
    ],
    StringReplace[
        First @ StringCases[
            Import[FileNameJoin[{scriptDirectory, "resource-page.html"}], "Text"],
            RegularExpression["(?s)<pre><code>(.*?)</code></pre>"] -> "$1"
        ],
        {"&lt;" -> "<", "&gt;" -> ">"}
    ]
};

VerificationTest[
    SameQ @@ (ToExpression[#, InputForm, HoldComplete] & /@ installExamples),
    True,
    TestID -> "Install-Examples-Match"
]

VerificationTest[
    And @@ Table[
        Block[{
            ResourceObject = Function[url, Function[property,
                If[property === "PacletFile", CloudObject[url], $Failed]
            ]],
            PacletInstall = (Sow[{##}] &)
        },
            Last[Reap[ToExpression[StringReplace[
                First[installExamples], "$SystemID" -> ToString[system, InputForm]
            ]]]] === {{
                {CloudObject["https://www.wolframcloud.com/obj/wolframinstitute/GAPLink/" <>
                    "WolframInstitute__GAPLink-" <> system <> ".paclet"],
                    ForceVersionInstall -> True, "ShowProgress" -> True}
            }}
        ],
        {system, {"Linux-x86-64", "MacOSX-ARM64", "MacOSX-x86-64", "Windows-x86-64"}}
    ],
    True,
    TestID -> "Install-Archive-With-Progress-On-Each-System"
]

ClearAll[installExamples];
