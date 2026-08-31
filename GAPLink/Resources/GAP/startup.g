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

GAPLinkSlice := function(text, first, last)
    if first > last then
        return "";
    fi;
    return text{[first .. last]};
end;

GAPLinkInteger := function(text)
    local char, digits;
    if Length(text) = 0 then
        return fail;
    fi;
    digits := text;
    if text[1] = '-' then
        if Length(text) = 1 then
            return fail;
        fi;
        digits := text{[2 .. Length(text)]};
    fi;
    if (Length(digits) > 1 and digits[1] = '0') or
       (text[1] = '-' and digits = "0") then
        return fail;
    fi;
    for char in digits do
        if not char in "0123456789" then
            return fail;
        fi;
    od;
    return Int(text);
end;

GAPLinkUnhex := function(text)
    local first, i, result, second;
    if Length(text) mod 2 <> 0 then
        return fail;
    fi;
    result := "";
    for i in [1, 3 .. Length(text) - 1] do
        first := Position("0123456789abcdef", text[i]);
        second := Position("0123456789abcdef", text[i + 1]);
        if first = fail or second = fail then
            return fail;
        fi;
        Add(result, CharInt(16 * (first - 1) + second - 1));
    od;
    return result;
end;

GAPLinkBad := function(state)
    state.valid := false;
    return fail;
end;

GAPLinkDecodeNode := fail;

GAPLinkChildren := function(state, last, depth)
    local result, value;
    result := [];
    while state.position <= last do
        value := GAPLinkDecodeNode(state, depth + 1);
        if not state.valid then
            return fail;
        fi;
        Add(result, value);
    od;
    if state.position <> last + 1 then
        return GAPLinkBad(state);
    fi;
    return result;
end;

GAPLinkDecodeNode := function(state, depth)
    local data, dataStart, denominator, exponent, key, last,
          length, lengthStart, mantissa, numerator, parts, previous,
          record, tag, value;

    if depth > 128 or state.position > Length(state.text) then
        return GAPLinkBad(state);
    fi;
    tag := state.text[state.position];
    state.position := state.position + 1;
    lengthStart := state.position;
    while state.position <= Length(state.text) and
          state.text[state.position] in "0123456789" do
        state.position := state.position + 1;
    od;
    if state.position = lengthStart or state.position > Length(state.text) or
       state.text[state.position] <> ':' then
        return GAPLinkBad(state);
    fi;
    length := GAPLinkNatural(
        GAPLinkSlice(state.text, lengthStart, state.position - 1), 67108864
    );
    if length = fail then
        return GAPLinkBad(state);
    fi;
    dataStart := state.position + 1;
    last := dataStart + length - 1;
    if last > Length(state.text) then
        return GAPLinkBad(state);
    fi;
    state.position := dataStart;

    if tag in "qdplr" then
        parts := GAPLinkChildren(state, last, depth);
        if not state.valid then
            return fail;
        fi;
        if tag = 'l' then
            return parts;
        elif tag = 'q' then
            if Length(parts) <> 2 or not IsInt(parts[1]) or
               not IsInt(parts[2]) then
                return GAPLinkBad(state);
            fi;
            numerator := parts[1];
            denominator := parts[2];
            if numerator = 0 or denominator <= 1 or
               GcdInt(AbsInt(numerator), denominator) <> 1 then
                return GAPLinkBad(state);
            fi;
            return numerator / denominator;
        elif tag = 'd' then
            if Length(parts) <> 2 or not IsInt(parts[1]) or
               not IsInt(parts[2]) then
                return GAPLinkBad(state);
            fi;
            mantissa := parts[1];
            exponent := parts[2];
            if mantissa = 0 then
                if exponent = 0 then
                    return 0.0;
                fi;
                return GAPLinkBad(state);
            elif mantissa mod 2 = 0 then
                return GAPLinkBad(state);
            fi;
            value := Float(mantissa) *
                2.0 ^ (exponent - Log2Int(AbsInt(mantissa)) - 1);
            if ExtRepOfObj(value) <> parts then
                return GAPLinkBad(state);
            fi;
            return value;
        elif tag = 'p' then
            if not ForAll(parts, x -> IsInt(x) and x > 0) then
                return GAPLinkBad(state);
            fi;
            value := PermList(parts);
            if value = fail or ListPerm(value) <> parts then
                return GAPLinkBad(state);
            fi;
            return value;
        fi;

        if Length(parts) mod 2 <> 0 then
            return GAPLinkBad(state);
        fi;
        record := rec();
        previous := fail;
        for key in [1, 3 .. Length(parts) - 1] do
            if not IsString(parts[key]) or
               (previous <> fail and not previous < parts[key]) then
                return GAPLinkBad(state);
            fi;
            previous := parts[key];
            record.(previous) := parts[key + 1];
        od;
        return record;
    fi;

    data := GAPLinkSlice(state.text, dataStart, last);
    state.position := last + 1;
    if tag = 'i' then
        value := GAPLinkInteger(data);
        if value = fail then
            return GAPLinkBad(state);
        fi;
        return value;
    elif tag = 't' and length = 0 then
        return true;
    elif tag = 'f' and length = 0 then
        return false;
    elif tag = 'x' and length = 0 then
        return fail;
    elif tag = 's' or tag = 'b' then
        value := GAPLinkUnhex(data);
        if value = fail or (tag = 's' and Unicode(value, "UTF-8") = fail) then
            return GAPLinkBad(state);
        fi;
        return value;
    fi;
    return GAPLinkBad(state);
end;

GAPLinkDecode := function(text)
    local state, value;
    state := rec(text := text, position := 1, valid := true);
    value := GAPLinkDecodeNode(state, 0);
    if not state.valid or state.position <> Length(text) + 1 then
        return fail;
    fi;
    return value;
end;

GAPLinkEncode := fail;

GAPLinkEncodeSequence := function(values, depth)
    local data, encoded, value;
    data := "";
    for value in values do
        encoded := GAPLinkEncode(value, depth + 1);
        if encoded = fail then
            return fail;
        fi;
        data := Concatenation(data, encoded);
    od;
    return data;
end;

GAPLinkEncode := function(value, depth)
    local data, encoded, key, keys, parts;
    if depth > 128 then
        return fail;
    elif IsInt(value) then
        return GAPLinkNode("i", String(value));
    elif IsRat(value) then
        data := Concatenation(
            GAPLinkNode("i", String(NumeratorRat(value))),
            GAPLinkNode("i", String(DenominatorRat(value)))
        );
        return GAPLinkNode("q", data);
    elif IsBool(value) then
        if value = true then
            return "t0:";
        elif value = false then
            return "f0:";
        fi;
        return "x0:";
    elif IsFloat(value) then
        parts := ExtRepOfObj(value);
        if not IsList(parts) or Length(parts) <> 2 or
           not ForAll(parts, IsInt) then
            return fail;
        fi;
        data := GAPLinkEncodeSequence(parts, depth);
        return GAPLinkNode("d", data);
    elif IsString(value) and (Length(value) > 0 or IsStringRep(value)) then
        if Unicode(value, "UTF-8") = fail then
            return GAPLinkNode("b", GAPLinkHex(value));
        fi;
        return GAPLinkString(value);
    elif IsPerm(value) then
        data := GAPLinkEncodeSequence(ListPerm(value), depth);
        return GAPLinkNode("p", data);
    elif IsList(value) then
        if not IsDenseList(value) then
            return fail;
        fi;
        data := GAPLinkEncodeSequence(value, depth);
        if data = fail then
            return fail;
        fi;
        return GAPLinkNode("l", data);
    elif IsRecord(value) then
        data := "";
        keys := SortedList(RecNames(value));
        for key in keys do
            if Unicode(key, "UTF-8") = fail then
                return fail;
            fi;
            encoded := GAPLinkEncode(value.(key), depth + 1);
            if encoded = fail then
                return fail;
            fi;
            data := Concatenation(data, GAPLinkString(key), encoded);
        od;
        return GAPLinkNode("r", data);
    fi;
    return fail;
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
    Print("\c");
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

GAPLinkError := function(status, message)
    return GAPLinkRecord([
        ["Message", GAPLinkString(message)],
        ["Status", GAPLinkString(status)]
    ]);
end;

GAPLinkRequestQ := function(request, names)
    return IsRecord(request) and Set(RecNames(request)) = Set(names);
end;

GAPLinkCall := function(request)
    local caught, encoded, func;
    if not GAPLinkRequestQ(
        request, ["Arguments", "Name", "Operation", "ReturnType"]
    ) or request.Operation <> "Call" or
       not IsString(request.Name) or not IsList(request.Arguments) or
       request.ReturnType <> "Automatic" then
        return fail;
    fi;
    if not IsValidIdentifier(request.Name) or
       not IsBoundGlobal(request.Name) or
       not IsFunction(ValueGlobal(request.Name)) then
        return GAPLinkError(
            "GAPFunctionNotFound", "The GAP function could not be found."
        );
    fi;
    func := ValueGlobal(request.Name);
    caught := CALL_WITH_CATCH(func, request.Arguments);
    if caught[1] = false then
        return GAPLinkError("GAPError", "GAP reported an error.");
    elif Length(caught) = 1 then
        return GAPLinkOK("n0:");
    fi;
    encoded := GAPLinkEncode(caught[2], 0);
    if encoded = fail or Length(encoded) > 67108864 then
        return GAPLinkError(
            "GAPUnsupportedValue", "The GAP result cannot be converted."
        );
    fi;
    return GAPLinkOK(encoded);
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
    local char, decoded, errors, input, next, output, request, response,
          token, valid;

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
    BreakOnError := false;
    next := 1;

    while true do
        request := GAPLinkReadFrame(input, token);
        if request = fail or request[1] <> next then
            ForceQuitGap(1);
        fi;
        decoded := GAPLinkDecode(request[2]);
        if next = 1 and GAPLinkRequestQ(decoded, ["Operation"]) and
           decoded.Operation = "Hello" then
            response := GAPLinkHello();
        elif next > 1 and GAPLinkRequestQ(decoded, ["Operation"]) and
             decoded.Operation = "Close" then
            response := GAPLinkOK("n0:");
        elif next > 1 then
            response := GAPLinkCall(decoded);
        else
            ForceQuitGap(1);
        fi;
        if response = fail then
            ForceQuitGap(1);
        fi;
        if not GAPLinkWriteResponse(output, errors, token, next, response) then
            ForceQuitGap(1);
        fi;
        if decoded.Operation = "Close" then
            ForceQuitGap(0);
        fi;
        next := next + 1;
    od;
end;

GAPLinkMain();
