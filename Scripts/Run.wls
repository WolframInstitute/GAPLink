(* ::Package:: *)

Function[command,
    Module[{context = "GAPLink`Scripts`"},
        If[!NameQ["System`PackageInitialize"],
            Print[
                "ERROR: development scripts require Wolfram Language 15.0 or later; this kernel is ",
                $Version
            ];
            Exit[1]
        ];
        PackageInitialize[context, <|"LoadFirstFiles" -> {"Common.wl"}|>];
        If[command === "LintFiles",
            Symbol[context <> command][Rest[$ScriptCommandLine]];
            Symbol[context <> "FinishScript"][],
            Symbol[context <> "RunScript"][Symbol[context <> command]]
        ]
    ]
]
