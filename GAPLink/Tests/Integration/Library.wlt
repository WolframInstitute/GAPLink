(* Integration tests of GAP's library through GAPLink: functions as values, records, options, characters, large
   values and the bundled group libraries. They need GAP; set GAPLINK_GAP to choose one. *)

PacletDirectoryLoad[DirectoryName[$TestFileName, 3]]
Needs["WolframInstitute`GAPLink`"]

gapExecutable = Replace[Environment["GAPLINK_GAP"], Except[_String] | "" -> Automatic];

(* Starts GAP, gives body[session] and closes the session. A GAP that does not start gives its Failure, so that the
   test fails and shows why. *)
withLibrarySession[body_Function] :=
	Module[{session},
		session = StartGAPSession["Executable" -> gapExecutable];
		If[FailureQ[session], session, WithCleanup[body[session], DeleteObject[session]]]
	]

VerificationTest[
	withLibrarySession[Function[session, Module[{square, add, group, result},
		square = GAPEvaluate[session, "x -> x^2;"];
		add = GAPEvaluate[session, "\\+;"];
		group = GAPCall[session, "SymmetricGroup", 3];
		result = {
			GAPCall[session, square, 12],
			GAPCall[session, "List", {1, 2, 3}, square],
			GAPCall[session, add, 4, 7],
			MatchQ[GAPCall[session, group], Failure["GAPFunctionNotFound", _]]
		};
		DeleteObject[square];
		Append[result, MatchQ[GAPCall[session, square, 2], Failure["GAPInvalidObject", _]]]
	]]],
	{144, {1, 4, 9}, 11, True, True},
	TestID -> "Call-Returned-Functions"
]

VerificationTest[
	withLibrarySession[Function[session, Module[{input, output, text},
		input = GAPCall[session, "InputTextString", "hello"];
		text = GAPCall[session, "ReadAll", input];
		GAPCall[session, "CloseStream", input];
		output = GAPEvaluate[session,
			"GAPLinkTestBuffer := \"\";; OutputTextString(GAPLinkTestBuffer,true);"];
		GAPCall[session, "PrintTo", output, "written through GAP"];
		GAPCall[session, "CloseStream", output];
		{text, GAPEvaluate[session, "GAPLinkTestBuffer;"]}
	]]],
	{"hello", "written through GAP"},
	TestID -> "Read-And-Write-GAP-Streams"
]

VerificationTest[
	withLibrarySession[Function[session, Module[{module},
		module = GAPEvaluate[session, "GModuleByMats([IdentityMat(2,GF(3))],GF(3));",
			"ReturnType" -> "Object"];
		GAPEvaluate[session, "GAPLinkTestNamespace := rec(inner := rec(f := x -> x+1));;"];
		{
			GAPCall[session, "MTX.Dimension", module],
			GAPCall[session, "MTX.IsIrreducible", module],
			GAPCall[session, "GAPLinkTestNamespace.inner.f", 7],
			GAPCall[session, "+", 4, 7],
			MatchQ[GAPCall[session, "GAPLinkTestNamespace..inner.f", 7],
				Failure["GAPFunctionNotFound", _]],
			MatchQ[GAPCall[session, "Print(123)", 7], Failure["GAPFunctionNotFound", _]]
		}
	]]],
	{2, False, 8, 11, True, True},
	TestID -> "Call-Library-Functions-In-Records"
]

VerificationTest[
	withLibrarySession[Function[session, Module[{reader, broken, group, result},
		reader = GAPEvaluate[session, "function() return [ValueOption(\"flag\"), Size(ValueOption(\"group\"))]; end;"];
		broken = GAPEvaluate[session, "function() Error(\"option test\"); end;"];
		group = GAPCall[session, "SymmetricGroup", 4];
		GAPEvaluate[session, "PushOptions(rec(outer := 7));;"];
		result = GAPCall[session, reader, "GAPOptions" -> <|"flag" -> True, "group" -> group|>];
		{
			result,
			GAPEvaluate[session, "[ValueOption(\"flag\"), ValueOption(\"outer\")];"],
			MatchQ[GAPCall[session, broken, "GAPOptions" -> <|"outer" -> 9|>,
				"Output" -> "Discard"], Failure["GAPError", _]],
			GAPEvaluate[session, "[Length(OptionsStack), ValueOption(\"outer\")];"]
		}
	]]],
	{{True, 24}, {Missing["GAPFail"], 7}, True, {1, 7}},
	TestID -> "GAP-Options-Are-Scoped-Even-After-Errors"
]

VerificationTest[
	withLibrarySession[Function[session, Module[{characters},
		characters = GAPCall[session, "Irr", GAPCall[session, "SymmetricGroup", 3]];
		{
			MatchQ[characters, {_GAPObject, _GAPObject, _GAPObject}],
			Sort[GAPCall[session, "DegreeOfCharacter", #] & /@ characters],
			GAPCall[session, "ScalarProduct", Last[characters], Last[characters]],
			Sort[GAPCall[session, "ValuesOfClassFunction", SelectFirst[characters,
				GAPCall[session, "DegreeOfCharacter", #] === 2 &]]]
		}
	]]],
	{True, {1, 1, 2}, 1, {-1, 0, 2}},
	TestID -> "Characters-Keep-Their-Character-Table"
]

VerificationTest[
	withLibrarySession[Function[session, Module[{range, nested, permutation},
		range = GAPEvaluate[session, "[1..1000000000];"];
		nested = GAPEvaluate[session, "List([1..101], i -> [1..100]);"];
		permutation = GAPEvaluate[session, "(1,1000000);"];
		{
			MatchQ[range, _GAPObject], GAPCall[session, "Length", range],
			MatchQ[Normal[range], Failure["GAPUnsupportedValue", _]],
			MatchQ[nested, _GAPObject], GAPCall[session, "Length", nested],
			MatchQ[permutation, _GAPObject], GAPCall[session, "Order", permutation]
		}
	]]],
	{True, 1000000000, True, True, 101, True, 2},
	TestID -> "Large-Values-Stay-In-GAP"
]

VerificationTest[
	withLibrarySession[Function[session, {
		GAPCall[session, "Size", GAPCall[session, "GF", 16]],
		GAPCall[session, "Order", GAPCall[session, "Z", 16]],
		GAPCall[session, "Size", GAPEvaluate[session, "GL(2,3);"]],
		GAPCall[session, "Dimension", GAPEvaluate[session, "FullMatrixAlgebra(GF(3),2);"]],
		GAPCall[session, "Dimension", GAPEvaluate[session, "SimpleLieAlgebra(\"A\",2,Rationals);"]],
		GAPCall[session, "Length", GAPCall[session, "Factors", GAPEvaluate[session, "Indeterminate(Rationals)^2-1;"]]],
		GAPCall[session, "DegreeOverPrimeField", GAPEvaluate[session, "Field([E(5)]);"]]
	}]],
	{16, 15, 48, 4, 8, 2, 4},
	TestID -> "Fields-Matrices-Polynomials-And-Algebras"
]

VerificationTest[
	withLibrarySession[Function[session, {
		GAPCall[session, "Size", GAPEvaluate[session, "AutomorphismGroup(CyclicGroup(8));"]],
		GAPCall[session, "Size", GAPEvaluate[session, "DerivedSubgroup(SymmetricGroup(4));"]],
		GAPCall[session, "Size", GAPEvaluate[session, "SylowSubgroup(SymmetricGroup(8),2);"]],
		GAPCall[session, "Size", GAPEvaluate[session, "f:=FreeGroup(\"a\",\"b\");; f/[f.1^4,f.2^2,(f.1*f.2)^2];"]],
		GAPCall[session, "Size", GAPEvaluate[session, "Semigroup([Transformation([2,1,1])]);"]],
		GAPCall[session, "Length", GAPCall[session, "Partitions", 8]],
		GAPCall[session, "Gcd", 120, 84]
	}]],
	{4, 12, 128, 8, 2, 22, 12},
	TestID -> "Groups-Presentations-Semigroups-And-Combinatorics"
]

VerificationTest[
	withLibrarySession[Function[session, {
		GAPCall[session, "IdGroup", GAPCall[session, "SmallGroup", 8, 3]],
		GAPCall[session, "Size", GAPCall[session, "PrimitiveGroup", 5, 1]],
		GAPCall[session, "Size", GAPCall[session, "TransitiveGroup", 5, 1]],
		GAPCall[session, "Size", GAPCall[session, "PerfectGroup", 60, 1]]
	}]],
	{{8, 3}, 5, 5, 60},
	TestID -> "Bundled-Group-Libraries"
]
