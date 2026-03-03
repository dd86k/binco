/// Ascii85 (Base85) encoding implementation.
///
/// Adobe variant with z-shortcut for all-zero groups.
///
/// Authors: dd86k <dd@dax.moe>
/// Copyright: dd86k <dd@dax.moe>
/// License: BSD-3-Clause-Clear
module binco.encoding.ascii85;

string ascii85Encode(const(ubyte)[] data)
{
    if (data.length == 0)
        return "";

    import std.array : appender;

    auto buf = appender!(char[]);

    size_t i = 0;
    while (i < data.length)
    {
        size_t remaining = data.length - i;
        if (remaining >= 4)
        {
            uint val = (cast(uint) data[i] << 24) |
                       (cast(uint) data[i + 1] << 16) |
                       (cast(uint) data[i + 2] << 8) |
                       cast(uint) data[i + 3];

            if (val == 0)
            {
                buf.put('z');
            }
            else
            {
                char[5] encoded = void;
                for (int j = 4; j >= 0; j--)
                {
                    encoded[j] = cast(char)(val % 85 + '!');
                    val /= 85;
                }
                buf.put(encoded[]);
            }
            i += 4;
        }
        else
        {
            // Partial trailing group: pad with zero bytes
            ubyte[4] padded = 0;
            foreach (j; 0 .. remaining)
                padded[j] = data[i + j];

            uint val = (cast(uint) padded[0] << 24) |
                       (cast(uint) padded[1] << 16) |
                       (cast(uint) padded[2] << 8) |
                       cast(uint) padded[3];

            char[5] encoded = void;
            for (int j = 4; j >= 0; j--)
            {
                encoded[j] = cast(char)(val % 85 + '!');
                val /= 85;
            }
            buf.put(encoded[0 .. remaining + 1]);
            i += remaining;
        }
    }

    return cast(string) buf[];
}

ubyte[] ascii85Decode(const(char)[] text)
{
    if (text.length == 0)
        return null;

    import std.array : appender;

    // Strip <~ prefix and ~> suffix if present
    const(char)[] input = text;
    if (input.length >= 2 && input[0 .. 2] == "<~")
        input = input[2 .. $];
    if (input.length >= 2 && input[$ - 2 .. $] == "~>")
        input = input[0 .. $ - 2];

    if (input.length == 0)
        return null;

    // Collect valid characters, expanding z shortcut
    auto chars = appender!(char[]);
    foreach (c; input)
    {
        if (c == 'z')
        {
            chars.put("!!!!!");
        }
        else if (c >= '!' && c <= 'u')
        {
            chars.put(c);
        }
        else if (c == ' ' || c == '\t' || c == '\n' || c == '\r')
        {
            // skip whitespace
        }
        else
        {
            throw new Exception("Invalid Ascii85 character");
        }
    }

    auto decoded = chars[];
    if (decoded.length == 0)
        return null;

    auto buf = appender!(ubyte[]);

    size_t i = 0;
    while (i < decoded.length)
    {
        size_t remaining = decoded.length - i;
        if (remaining >= 5)
        {
            uint val = 0;
            foreach (j; 0 .. 5)
                val = val * 85 + (decoded[i + j] - '!');

            buf.put(cast(ubyte)(val >> 24));
            buf.put(cast(ubyte)(val >> 16));
            buf.put(cast(ubyte)(val >> 8));
            buf.put(cast(ubyte)(val));
            i += 5;
        }
        else
        {
            if (remaining < 2)
                throw new Exception("Invalid Ascii85: trailing single character");

            uint val = 0;
            foreach (j; 0 .. 5)
            {
                if (j < remaining)
                    val = val * 85 + (decoded[i + j] - '!');
                else
                    val = val * 85 + 84; // pad with 'u'
            }

            foreach (j; 0 .. remaining - 1)
                buf.put(cast(ubyte)(val >> (24 - j * 8)));

            i += remaining;
        }
    }

    return buf[];
}

unittest
{
    // Empty input
    assert(ascii85Encode(null) == "");
    assert(ascii85Decode("") is null);

    // Known vector: "Man " → "9jqo^"
    assert(ascii85Encode(cast(const(ubyte)[])"Man ") == "9jqo^");
    assert(ascii85Decode("9jqo^") == cast(ubyte[])"Man ");

    // Known vector: "Hello" → "87cURDZ"
    assert(ascii85Encode(cast(const(ubyte)[])"Hello") == "87cURDZ");
    assert(ascii85Decode("87cURDZ") == cast(ubyte[])"Hello");

    // All zeros → "z"
    assert(ascii85Encode([cast(ubyte) 0, 0, 0, 0]) == "z");
    assert(ascii85Decode("z") == [cast(ubyte) 0, 0, 0, 0]);

    // Eight zeros → "zz"
    assert(ascii85Encode([cast(ubyte) 0, 0, 0, 0, 0, 0, 0, 0]) == "zz");
    assert(ascii85Decode("zz") == [cast(ubyte) 0, 0, 0, 0, 0, 0, 0, 0]);

    // Round-trip: single byte
    {
        auto data = cast(const(ubyte)[])"A";
        assert(ascii85Decode(ascii85Encode(data)) == data);
    }

    // Round-trip: two bytes
    {
        auto data = cast(const(ubyte)[])"AB";
        assert(ascii85Decode(ascii85Encode(data)) == data);
    }

    // Round-trip: three bytes
    {
        auto data = cast(const(ubyte)[])"ABC";
        assert(ascii85Decode(ascii85Encode(data)) == data);
    }

    // Round-trip: binary data
    {
        immutable ubyte[] data = [0x00, 0xFF, 0x7F, 0x80, 0x01, 0xFE];
        assert(ascii85Decode(ascii85Encode(data)) == data);
    }

    // Whitespace ignored during decoding
    assert(ascii85Decode("87cUR\nDZ") == cast(ubyte[])"Hello");

    // Delimiter stripping
    assert(ascii85Decode("<~87cURDZ~>") == cast(ubyte[])"Hello");
    assert(ascii85Decode("<~") is null);
    assert(ascii85Decode("~>") is null);

    // Round-trip: longer data
    {
        ubyte[60] data;
        foreach (i, ref b; data)
            b = cast(ubyte)(i * 7 + 3);
        assert(ascii85Decode(ascii85Encode(data[])) == data[]);
    }
    
    assert(ascii85Encode(cast(ubyte[])(
        `Man is distinguished, not only by his reason, but by this singular passion from `~
        `other animals, which is a lust of the mind, that by a perseverance of delight in `~
        `the continued and indefatigable generation of knowledge, exceeds the short `~
        `vehemence of any carnal pleasure.`)) ==
        "9jqo^BlbD-BleB1DJ+*+F(f,q/0JhKF<GL>Cj@.4Gp$d7F!,L7@<6@)/0JDEF<G%<+EV:2F!,O<DJ+*."~
        "@<*K0@<6L(Df-\\0Ec5e;DffZ(EZee.Bl.9pF\"AGXBPCsi+DGm>@3BB/F*&OCAfu2/AKYi(DIb:@FD,*"~
        ")+C]U=@3BN#EcYf8ATD3s@q?d$AftVqCh[NqF<G:8+EV:.+Cf>-FD5W8ARlolDIal(DId<j@<?3r@:F%"~
        "a+D58'ATD4$Bl@l3De:,-DJs`8ARoFb/0JMK@qB4^F!,R<AKZ&-DfTqBG%G>uD.RTpAKYo'+CT/5+Cei"~
        "#DII?(E,9)oF*2M7/c");        
}
