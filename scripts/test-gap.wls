#!/usr/bin/env wolframscript

Get[FileNameJoin[{DirectoryName[$InputFileName], "common.wl"}]];

loadSource[];
runTests @ FileNames[
    "*.wlt",
    FileNameJoin[{pacletDirectory, "Tests", "Integration"}]
];
