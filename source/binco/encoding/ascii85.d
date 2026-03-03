/// Ascii85 (Base85) encoding implementation.
///
/// Adobe variant with z-shortcut for all-zero groups.
///
/// Authors: dd86k <dd@dax.moe>
/// Copyright: dd86k <dd@dax.moe>
/// License: BSD-3-Clause-Clear
module binco.encoding.ascii85;

/// Encode into caller-provided buffer, return filled slice.
char[] ascii85Encode(const(ubyte)[] data, char[] buf)
{
    if (data.length == 0)
        return buf[0 .. 0];

    size_t pos = 0;
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
                buf[pos++] = 'z';
            }
            else
            {
                char[5] encoded = void;
                for (int j = 4; j >= 0; j--)
                {
                    encoded[j] = cast(char)(val % 85 + '!');
                    val /= 85;
                }
                buf[pos .. pos + 5] = encoded[];
                pos += 5;
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
            buf[pos .. pos + remaining + 1] = encoded[0 .. remaining + 1];
            pos += remaining + 1;
            i += remaining;
        }
    }

    return buf[0 .. pos];
}

/// Convenience: allocates buffer internally.
char[] ascii85Encode(const(ubyte)[] data)
{
    if (data.length == 0)
        return null;

    // Worst case: 5 chars per 4 bytes (no z-shortcuts)
    return ascii85Encode(data, new char[(data.length + 3) / 4 * 5]);
}

/// Decode into caller-provided buffer, return filled slice.
ubyte[] ascii85Decode(const(char)[] text, ubyte[] buf)
{
    if (text.length == 0)
        return null;

    // Strip <~ prefix and ~> suffix if present
    const(char)[] input = text;
    if (input.length >= 2 && input[0 .. 2] == "<~")
        input = input[2 .. $];
    if (input.length >= 2 && input[$ - 2 .. $] == "~>")
        input = input[0 .. $ - 2];

    if (input.length == 0)
        return null;

    size_t pos = 0;
    char[5] group = void;
    size_t groupLen = 0;

    foreach (c; input)
    {
        if (c == 'z')
        {
            buf[pos .. pos + 4] = 0;
            pos += 4;
        }
        else if (c >= '!' && c <= 'u')
        {
            group[groupLen++] = c;
            if (groupLen == 5)
            {
                uint val = 0;
                foreach (j; 0 .. 5)
                    val = val * 85 + (group[j] - '!');

                buf[pos++] = cast(ubyte)(val >> 24);
                buf[pos++] = cast(ubyte)(val >> 16);
                buf[pos++] = cast(ubyte)(val >> 8);
                buf[pos++] = cast(ubyte)(val);
                groupLen = 0;
            }
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

    // Handle partial trailing group
    if (groupLen > 0)
    {
        if (groupLen < 2)
            throw new Exception("Invalid Ascii85: trailing single character");

        // Pad with 'u' (value 84)
        foreach (j; groupLen .. 5)
            group[j] = 'u';

        uint val = 0;
        foreach (j; 0 .. 5)
            val = val * 85 + (group[j] - '!');

        foreach (j; 0 .. groupLen - 1)
            buf[pos++] = cast(ubyte)(val >> (24 - j * 8));
    }

    return pos ? buf[0 .. pos] : null;
}

/// Convenience: allocates buffer internally.
ubyte[] ascii85Decode(const(char)[] text)
{
    if (text.length == 0)
        return null;

    // Worst case: each 'z' produces 4 bytes
    return ascii85Decode(text, new ubyte[text.length * 4]);
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
