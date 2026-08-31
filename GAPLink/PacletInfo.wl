PacletObject[<|
    "Name" -> "WolframInstitute/GAPLink",
    "PublisherID" -> "WolframInstitute",
    "Version" -> "0.1.0",
    "WolframVersion" -> "15.0+",
    "Description" -> "Low-level Wolfram Language interoperability with GAP",
    "Creator" -> "Wolfram Institute",
    "License" -> "MIT",
    "URL" -> "https://github.com/WolframInstitute/GAPLink",
    "Keywords" -> {
        "GAP", "computational algebra", "group theory", "interoperability"
    },
    "Categories" -> {"Mathematics"},
    "PrimaryContext" -> "WolframInstitute`GAPLink`",
    "Extensions" -> {
        {
            "Kernel",
            "Root" -> "Kernel",
            "Context" -> {
                {"WolframInstitute`GAPLink`", "GAPLink.wl"}
            },
            "Symbols" -> {
                "WolframInstitute`GAPLink`GAPCall",
                "WolframInstitute`GAPLink`GAPEvaluate",
                "WolframInstitute`GAPLink`GAPObject",
                "WolframInstitute`GAPLink`GAPSession",
                "WolframInstitute`GAPLink`StartGAPSession"
            }
        },
        {
            "Resource",
            "Root" -> "Resources",
            "Resources" -> {{"GAPStartup", "GAP/startup.g"}}
        },
        {
            "Test",
            "Root" -> "Tests",
            "Method" -> "Experimental-v1"
        }
    }
|>]
