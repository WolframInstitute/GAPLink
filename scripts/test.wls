#!/usr/bin/env wolframscript

Get[FileNameJoin[{DirectoryName[$InputFileName], "common.wl"}]];

scriptRequire[
    RunProcess[{"python3", "-m", "unittest", "discover", "-s", FileNameJoin[{scriptDirectory, "tests"}]}],
    Function[result, Print[result["StandardError"]]; result["ExitCode"] === 0],
    "Cloud download tests failed"
];
loadSource[];
runTests @ Join[
    FileNames["*.wlt", FileNameJoin[{pacletDirectory, "Tests"}]],
    FileNames["*.wlt", FileNameJoin[{scriptDirectory, "tests"}]]
];
