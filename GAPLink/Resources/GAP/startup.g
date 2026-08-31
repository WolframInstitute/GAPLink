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

GAPLinkReadField := function(stream, maximum)
    local chunk, result;
    result := "";
    while Length(result) <= maximum do
        chunk := ReadAll(stream, 1);
        if chunk = fail or Length(chunk) = 0 then
            return fail;
        elif chunk = ":" then
            return result;
        fi;
        result := Concatenation(result, chunk);
    od;
    return fail;
end;

GAPLinkNatural := function(text, maximum)
    local char, value;
    if text = fail or Length(text) = 0 or
       (Length(text) > 1 and text[1] = '0') then
        return fail;
    fi;
    for char in text do
        if not char in "0123456789" then
            return fail;
        fi;
    od;
    value := Int(text);
    if value > maximum then
        return fail;
    fi;
    return value;
end;

GAPLinkFrame := function(token, kind, id, payload)
    return Concatenation(
        "GAPLINK:", token, ":1:", kind, ":", String(id), ":",
        String(Length(payload)), ":", payload
    );
end;

GAPLinkReadFrame := function(stream, token)
    local id, length, prefix, text;
    prefix := Concatenation("GAPLINK:", token, ":1:Q:");
    if GAPLinkRead(stream, Length(prefix)) <> prefix then
        return fail;
    fi;
    text := GAPLinkReadField(stream, 19);
    id := GAPLinkNatural(text, 9223372036854775807);
    if id = fail then
        return fail;
    fi;
    text := GAPLinkReadField(stream, 8);
    length := GAPLinkNatural(text, 67108864);
    if length = fail or length = 0 then
        return fail;
    fi;
    text := GAPLinkRead(stream, length);
    if text = fail then
        return fail;
    fi;
    return [id, text];
end;

GAPLinkWriteResponse := function(output, errors, token, id, payload)
    if WriteAll(output, GAPLinkFrame(token, "R", id, payload)) <> true then
        return false;
    fi;
    return WriteAll(errors, GAPLinkFrame(token, "E", id, "")) = true;
end;

GAPLinkOK := function(result)
    return GAPLinkRecord([
        ["Result", result],
        ["Status", GAPLinkString("OK")]
    ]);
end;

GAPLinkHello := function()
    local build, hpc, packages, processor, result, system;

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
    return GAPLinkOK(result);
end;

GAPLinkMain := function()
    local char, close, errors, hello, input, next, output, request,
          response, token, valid;

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

    input := InputTextUser();
    output := OutputTextUser();
    errors := OutputTextFile("*errout*", false);
    hello := GAPLinkRecord([["Operation", GAPLinkString("Hello")]]);
    close := GAPLinkRecord([["Operation", GAPLinkString("Close")]]);
    next := 1;

    while true do
        request := GAPLinkReadFrame(input, token);
        if request = fail or request[1] <> next then
            ForceQuitGap(1);
        fi;
        if next = 1 and request[2] = hello then
            response := GAPLinkHello();
        elif next > 1 and request[2] = close then
            response := GAPLinkOK("n0:");
        else
            ForceQuitGap(1);
        fi;
        if not GAPLinkWriteResponse(output, errors, token, next, response) then
            ForceQuitGap(1);
        fi;
        if request[2] = close then
            ForceQuitGap(0);
        fi;
        next := next + 1;
    od;
end;

GAPLinkMain();
