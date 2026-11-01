Needs["WolframInstitute`GAPLink`"];

withLibrarySession[body_] := Module[{session},
    session = StartGAPSession["Executable" -> Replace[
        Environment["GAPLINK_GAP"], Except[_String] | "" -> Automatic
    ]];
    If[FailureQ[session], Return[session]];
    WithCleanup[body[session], DeleteObject[session]]
];

VerificationTest[
    withLibrarySession[Function[s, Module[{square, add, group, result},
        square = GAPEvaluate[s, "x -> x^2;"];
        add = GAPEvaluate[s, "\\+;"];
        group = GAPCall[s, "SymmetricGroup", 3];
        result = {
            GAPCall[s, square, 12],
            GAPCall[s, "List", {1, 2, 3}, square],
            GAPCall[s, add, 4, 7],
            MatchQ[GAPCall[s, group], Failure["GAPFunctionNotFound", _]]
        };
        DeleteObject[square];
        Append[result, MatchQ[GAPCall[s, square, 2], Failure["GAPInvalidObject", _]]]
    ]]],
    {144, {1, 4, 9}, 11, True, True},
    TestID -> "Call-Returned-Functions"
]

VerificationTest[
    withLibrarySession[Function[s, Module[{input, output, text},
        input = GAPCall[s, "InputTextString", "hello"];
        text = GAPCall[s, "ReadAll", input];
        GAPCall[s, "CloseStream", input];
        output = GAPEvaluate[s,
            "GAPLinkTestBuffer := \"\";; OutputTextString(GAPLinkTestBuffer,true);"];
        GAPCall[s, "PrintTo", output, "written through GAP"];
        GAPCall[s, "CloseStream", output];
        {text, GAPEvaluate[s, "GAPLinkTestBuffer;"]}
    ]]],
    {"hello", "written through GAP"},
    TestID -> "Read-And-Write-GAP-Streams"
]

VerificationTest[
    withLibrarySession[Function[s, Module[{module},
        module = GAPEvaluate[s, "GModuleByMats([IdentityMat(2,GF(3))],GF(3));",
            "ReturnType" -> "Object"];
        GAPEvaluate[s, "GAPLinkTestNamespace := rec(inner := rec(f := x -> x+1));;"];
        {
            GAPCall[s, "MTX.Dimension", module],
            GAPCall[s, "MTX.IsIrreducible", module],
            GAPCall[s, "GAPLinkTestNamespace.inner.f", 7],
            GAPCall[s, "+", 4, 7],
            MatchQ[GAPCall[s, "GAPLinkTestNamespace..inner.f", 7],
                Failure["GAPFunctionNotFound", _]],
            MatchQ[GAPCall[s, "Print(123)", 7], Failure["GAPFunctionNotFound", _]]
        }
    ]]],
    {2, False, 8, 11, True, True},
    TestID -> "Call-Library-Functions-In-Records"
]

VerificationTest[
    withLibrarySession[Function[s, Module[{reader, broken, group, result},
        reader = GAPEvaluate[s, "function() return [ValueOption(\"flag\"), Size(ValueOption(\"group\"))]; end;"];
        broken = GAPEvaluate[s, "function() Error(\"option test\"); end;"];
        group = GAPCall[s, "SymmetricGroup", 4];
        GAPEvaluate[s, "PushOptions(rec(outer := 7));;"];
        result = GAPCall[s, reader, "GAPOptions" -> <|"flag" -> True, "group" -> group|>];
        {
            result,
            GAPEvaluate[s, "[ValueOption(\"flag\"), ValueOption(\"outer\")];"],
            MatchQ[GAPCall[s, broken, "GAPOptions" -> <|"outer" -> 9|>,
                "Output" -> "Discard"], Failure["GAPError", _]],
            GAPEvaluate[s, "[Length(OptionsStack), ValueOption(\"outer\")];"]
        }
    ]]],
    {{True, 24}, {Missing["GAPFail"], 7}, True, {1, 7}},
    TestID -> "GAP-Options-Are-Scoped-Even-After-Errors"
]

VerificationTest[
    withLibrarySession[Function[s, Module[{characters},
        characters = GAPCall[s, "Irr", GAPCall[s, "SymmetricGroup", 3]];
        {
            MatchQ[characters, {_GAPObject, _GAPObject, _GAPObject}],
            Sort[GAPCall[s, "DegreeOfCharacter", #] & /@ characters],
            GAPCall[s, "ScalarProduct", Last[characters], Last[characters]],
            Sort[GAPCall[s, "ValuesOfClassFunction", SelectFirst[characters,
                GAPCall[s, "DegreeOfCharacter", #] === 2 &]]]
        }
    ]]],
    {True, {1, 1, 2}, 1, {-1, 0, 2}},
    TestID -> "Characters-Keep-Their-Character-Table"
]

VerificationTest[
    withLibrarySession[Function[s, Module[{range, nested, permutation},
        range = GAPEvaluate[s, "[1..1000000000];"];
        nested = GAPEvaluate[s, "List([1..101], i -> [1..100]);"];
        permutation = GAPEvaluate[s, "(1,1000000);"];
        {
            MatchQ[range, _GAPObject], GAPCall[s, "Length", range],
            MatchQ[Normal[range], Failure["GAPUnsupportedValue", _]],
            MatchQ[nested, _GAPObject], GAPCall[s, "Length", nested],
            MatchQ[permutation, _GAPObject], GAPCall[s, "Order", permutation]
        }
    ]]],
    {True, 1000000000, True, True, 101, True, 2},
    TestID -> "Large-Values-Stay-In-GAP"
]

VerificationTest[
    withLibrarySession[Function[s, {
        GAPCall[s, "Size", GAPCall[s, "GF", 16]],
        GAPCall[s, "Order", GAPCall[s, "Z", 16]],
        GAPCall[s, "Size", GAPEvaluate[s, "GL(2,3);"]],
        GAPCall[s, "Dimension", GAPEvaluate[s, "FullMatrixAlgebra(GF(3),2);"]],
        GAPCall[s, "Dimension", GAPEvaluate[s, "SimpleLieAlgebra(\"A\",2,Rationals);"]],
        GAPCall[s, "Length", GAPCall[s, "Factors", GAPEvaluate[s, "Indeterminate(Rationals)^2-1;"]]],
        GAPCall[s, "DegreeOverPrimeField", GAPEvaluate[s, "Field([E(5)]);"]]
    }]],
    {16, 15, 48, 4, 8, 2, 4},
    TestID -> "Fields-Matrices-Polynomials-And-Algebras"
]

VerificationTest[
    withLibrarySession[Function[s, {
        GAPCall[s, "Size", GAPEvaluate[s, "AutomorphismGroup(CyclicGroup(8));"]],
        GAPCall[s, "Size", GAPEvaluate[s, "DerivedSubgroup(SymmetricGroup(4));"]],
        GAPCall[s, "Size", GAPEvaluate[s, "SylowSubgroup(SymmetricGroup(8),2);"]],
        GAPCall[s, "Size", GAPEvaluate[s, "f:=FreeGroup(\"a\",\"b\");; f/[f.1^4,f.2^2,(f.1*f.2)^2];"]],
        GAPCall[s, "Size", GAPEvaluate[s, "Semigroup([Transformation([2,1,1])]);"]],
        GAPCall[s, "Length", GAPCall[s, "Partitions", 8]],
        GAPCall[s, "Gcd", 120, 84]
    }]],
    {4, 12, 128, 8, 2, 22, 12},
    TestID -> "Groups-Presentations-Semigroups-And-Combinatorics"
]

VerificationTest[
    withLibrarySession[Function[s, {
        GAPCall[s, "IdGroup", GAPCall[s, "SmallGroup", 8, 3]],
        GAPCall[s, "Size", GAPCall[s, "PrimitiveGroup", 5, 1]],
        GAPCall[s, "Size", GAPCall[s, "TransitiveGroup", 5, 1]],
        GAPCall[s, "Size", GAPCall[s, "PerfectGroup", 60, 1]]
    }]],
    {{8, 3}, 5, 5, 60},
    TestID -> "Bundled-Group-Libraries"
]
