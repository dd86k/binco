/// Z85 (ZeroMQ Base85) encoding implementation.
///
/// Uses the Z85 alphabet: 0-9a-zA-Z.-:+=^!/*?&<>()[]{}@%$#
///
/// Authors: dd86k <dd@dax.moe>
/// Copyright: dd86k <dd@dax.moe>
/// License: BSD-3-Clause-Clear
module binco.encoding.z85;

private immutable char[85] z85Alphabet =
    "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ.-:+=^!/*?&<>()[]{}@%$#";
private immutable ubyte[256] z85Reverse = () {
    ubyte[256] table = 0xFF;
    foreach (i, c; z85Alphabet)
        table[c] = cast(ubyte) i;
    return table;
}();

/// Encode into caller-provided buffer, return filled slice.
char[] z85Encode(const(ubyte)[] data, char[] buf)
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

            char[5] encoded = void;
            for (int j = 4; j >= 0; j--)
            {
                encoded[j] = z85Alphabet[val % 85];
                val /= 85;
            }
            buf[pos .. pos + 5] = encoded[];
            pos += 5;
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
                encoded[j] = z85Alphabet[val % 85];
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
char[] z85Encode(const(ubyte)[] data)
{
    if (data.length == 0)
        return null;

    return z85Encode(data, new char[(data.length + 3) / 4 * 5]);
}

/// Decode into caller-provided buffer, return filled slice.
ubyte[] z85Decode(const(char)[] text, ubyte[] buf)
{
    if (text.length == 0)
        return null;

    // Filter out whitespace
    size_t pos = 0;
    char[5] group = void;
    size_t groupLen = 0;

    foreach (c; text)
    {
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r')
            continue;

        ubyte val = z85Reverse[c];
        if (val == 0xFF)
            throw new Exception("Invalid Z85 character");

        group[groupLen++] = c;
        if (groupLen == 5)
        {
            uint acc = 0;
            foreach (j; 0 .. 5)
                acc = acc * 85 + z85Reverse[group[j]];

            buf[pos++] = cast(ubyte)(acc >> 24);
            buf[pos++] = cast(ubyte)(acc >> 16);
            buf[pos++] = cast(ubyte)(acc >> 8);
            buf[pos++] = cast(ubyte)(acc);
            groupLen = 0;
        }
    }

    // Handle partial trailing group
    if (groupLen > 0)
    {
        if (groupLen < 2)
            throw new Exception("Invalid Z85: trailing single character");

        // Pad with last char in alphabet ('#' = 84)
        foreach (j; groupLen .. 5)
            group[j] = '#';

        uint acc = 0;
        foreach (j; 0 .. 5)
            acc = acc * 85 + z85Reverse[group[j]];

        foreach (j; 0 .. groupLen - 1)
            buf[pos++] = cast(ubyte)(acc >> (24 - j * 8));
    }

    return pos ? buf[0 .. pos] : null;
}

/// Convenience: allocates buffer internally.
ubyte[] z85Decode(const(char)[] text)
{
    if (text.length == 0)
        return null;

    return z85Decode(text, new ubyte[text.length]);
}

unittest
{
    // Empty input
    assert(z85Encode(null) == "");
    assert(z85Decode("") is null);

    // RFC 23 test vector: 0x86 0x4F 0xD2 0x6F 0xB5 0x59 0xF7 0x5B → "HelloWorld"
    assert(z85Encode([cast(ubyte) 0x86, 0x4F, 0xD2, 0x6F, 0xB5, 0x59, 0xF7, 0x5B]) == "HelloWorld");
    assert(z85Decode("HelloWorld") == [cast(ubyte) 0x86, 0x4F, 0xD2, 0x6F, 0xB5, 0x59, 0xF7, 0x5B]);

    // Round-trip: single byte
    {
        const(ubyte)[] data = cast(const(ubyte)[])"A";
        assert(z85Decode(z85Encode(data)) == data);
    }

    // Round-trip: two bytes
    {
        const(ubyte)[] data = cast(const(ubyte)[])"AB";
        assert(z85Decode(z85Encode(data)) == data);
    }

    // Round-trip: three bytes
    {
        const(ubyte)[] data = cast(const(ubyte)[])"ABC";
        assert(z85Decode(z85Encode(data)) == data);
    }

    // Round-trip: four bytes (exact group)
    {
        const(ubyte)[] data = cast(const(ubyte)[])"ABCD";
        assert(z85Decode(z85Encode(data)) == data);
    }

    // Round-trip: binary data
    {
        immutable ubyte[] data = [0x00, 0xFF, 0x7F, 0x80, 0x01, 0xFE];
        assert(z85Decode(z85Encode(data)) == data);
    }

    // All zeros
    assert(z85Encode([cast(ubyte) 0, 0, 0, 0]) == "00000");
    assert(z85Decode("00000") == [cast(ubyte) 0, 0, 0, 0]);

    // Round-trip: longer data
    {
        ubyte[60] data;
        foreach (i, ref b; data)
            b = cast(ubyte)(i * 7 + 3);
        assert(z85Decode(z85Encode(data[])) == data[]);
    }
}
