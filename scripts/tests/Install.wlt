Needs["CloudObject`"];

installExample = First @ StringCases[
    Import[FileNameJoin[{repositoryRoot, "README.md"}], "Text"],
    RegularExpression["(?s)```wolfram\n(.*?)\n```"] -> "$1"
];

VerificationTest[
    Module[{resources, text},
        resources = AssociationMap[
            pacletResourceInfo[PacletObject[File[pacletDirectory]],
                CloudObject["https://www.wolframcloud.com/obj/gaplink-test/" <> # <> ".paclet"], #] &,
            systems
        ];
        text = platformDescription[resources];
        Internal`InheritedBlock[{CloudObject}, Module[{page, description},
            page = CloudObject["https://www.wolframcloud.com/obj/wolframinstitute/DeployedResources/Paclet/WolframInstitute/GAPLink"];
            description = CloudObject["https://www.wolframcloud.com/obj/gaplink-test/platforms.wl"];
            Unprotect[CloudObject];
            With[{p = page, d = description},
                CloudObject /: Verbatim[Options][p, MetaInformation] :=
                    {MetaInformation -> <|"ResourceLocation" -> d|>};
                CloudObject /: CloudGet[d] := ToExpression[
                    StringReplace[text, "$SystemID" -> ToString[system, InputForm]]]
            ];
            (* Load the resource tools before intercepting archive installation. *)
            Block[{system = First[systems]}, ResourceObject[First[page]]];
            And @@ Table[
                Block[{PacletInstall = (Sow[{##}] &)},
                    Last[Reap[ToExpression[installExample]]] === {{
                        {resources[system]["PacletFile"], ForceVersionInstall -> True, "ShowProgress" -> True}
                    }}
                ],
                {system, systems}
            ]
        ]]
    ],
    True,
    TestID -> "Readme-Install-Selects-All-Four-Platforms-With-Progress"
]

ClearAll[installExample];
