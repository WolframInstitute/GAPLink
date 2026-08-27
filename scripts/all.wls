#!/usr/bin/env wolframscript

Print["Wolfram Engine ", $Version, " | license type: ", $LicenseType];

Module[{directory = DirectoryName[$InputFileName]},
    Get[FileNameJoin[{directory, "build.wls"}]];
    Get[FileNameJoin[{directory, "verify.wls"}]];
    Get[FileNameJoin[{directory, "check.wl"}]];
    runCheck[];
    Get[FileNameJoin[{directory, "test.wls"}]]
]
