#!/usr/bin/env wolframscript

Get[FileNameJoin[{DirectoryName[$InputFileName], "common.wl"}]];

files = Rest[$ScriptCommandLine];
If[files === {}, scriptFail["Pass one or more files to lint"]];
lintFiles[files];
Print["OK: ", Length[files], " file(s) linted"]
