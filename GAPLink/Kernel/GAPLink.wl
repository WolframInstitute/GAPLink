(* ::Package:: *)

(* The foundation deliberately exports no symbols. PackageInitialize creates the public
   context and gives future source files Structured Package Format isolation. *)
PackageInitialize["WolframInstitute`GAPLink`",
    <|
        "HiddenImports" -> {},
        "LoadFirstFiles" -> {},
        "LoadLastFiles" -> {}
    |>
]
