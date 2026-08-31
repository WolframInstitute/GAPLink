GAPLinkNode := function(tag, data)
    return Concatenation(tag, String(Length(data)), ":", data);
end;

GAPLinkHex := function(text)
    local byte, char, digits, hex;
    digits := "0123456789abcdef";
    hex := "";
    for char in text do
        byte := IntChar(char);
        hex := Concatenation(
            hex,
            digits{[QuoInt(byte, 16) + 1, (byte mod 16) + 1]}
        );
    od;
    return hex;
end;

GAPLinkString := function(text)
    return GAPLinkNode("s", GAPLinkHex(text));
end;

GAPLinkRecord := function(entries)
    local data, entry;
    data := "";
    for entry in entries do
        data := Concatenation(data, GAPLinkString(entry[1]), entry[2]);
    od;
    return GAPLinkNode("r", data);
end;

GAPLinkStringList := function(values)
    local data, value;
    data := "";
    for value in values do
        data := Concatenation(data, GAPLinkString(value));
    od;
    return GAPLinkNode("l", data);
end;

GAPLinkRead := function(stream, count)
    local chunk, result;
    result := "";
    while Length(result) < count do
        chunk := ReadAll(stream, count - Length(result));
        if chunk = fail or Length(chunk) = 0 then
            return fail;
        fi;
        result := Concatenation(result, chunk);
    od;
    return result;
end;

GAPLinkMain := function()
    local build, char, errorEnd, hello, hpc, input, packages, processor,
          request, response, result, system, token, valid;

    if not IsBound(GAPInfo.SystemEnvironment.GAPLINK_TOKEN) then
        ForceQuitGap(1);
    fi;
    token := GAPInfo.SystemEnvironment.GAPLINK_TOKEN;
    valid := Length(token) = 32;
    for char in token do
        valid := valid and char in "0123456789abcdef";
    od;
    if not valid then
        ForceQuitGap(1);
    fi;

    hello := GAPLinkRecord([["Operation", GAPLinkString("Hello")]]);
    request := Concatenation(
        "GAPLINK:", token, ":1:Q:1:", String(Length(hello)), ":", hello
    );
    input := InputTextUser();
    if GAPLinkRead(input, Length(request)) <> request then
        ForceQuitGap(1);
    fi;

    build := GAPInfo.BuildVersion;
    system := GAPInfo.Architecture;
    processor := GAPInfo.Architecture;
    if IsBound(GAPInfo.KernelInfo.uname) then
        if IsBound(GAPInfo.KernelInfo.uname.sysname) then
            system := GAPInfo.KernelInfo.uname.sysname;
        fi;
        if IsBound(GAPInfo.KernelInfo.uname.machine) then
            processor := GAPInfo.KernelInfo.uname.machine;
        fi;
    fi;
    packages := SortedList(RecNames(GAPInfo.PackagesInfo));
    hpc := "f0:";
    if IsBound(GAPInfo.KernelInfo.NUM_CPUS) then
        hpc := "t0:";
    fi;

    result := GAPLinkRecord([
        ["Build", GAPLinkString(build)],
        ["GAPVersion", GAPLinkString(GAPInfo.Version)],
        ["HPC", hpc],
        ["Packages", GAPLinkStringList(packages)],
        ["Processor", GAPLinkString(processor)],
        ["ProtocolVersion", GAPLinkNode("i", "1")],
        ["System", GAPLinkString(system)]
    ]);
    response := GAPLinkRecord([
        ["Result", result],
        ["Status", GAPLinkString("OK")]
    ]);
    WriteAll(
        OutputTextUser(),
        Concatenation(
            "GAPLINK:", token, ":1:R:1:", String(Length(response)), ":",
            response
        )
    );
    errorEnd := Concatenation("GAPLINK:", token, ":1:E:1:0:");
    PrintTo("*errout*", errorEnd);

    if GAPLinkRead(input, 1) <> fail then
        ForceQuitGap(1);
    fi;
    ForceQuitGap(0);
end;

GAPLinkMain();
