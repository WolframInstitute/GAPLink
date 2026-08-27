#!/usr/bin/env wolframscript

Get[FileNameJoin[{DirectoryName[$InputFileName], "common.wl"}]];
Get[FileNameJoin[{DirectoryName[$InputFileName], "check.wl"}]];

runCheck[]
