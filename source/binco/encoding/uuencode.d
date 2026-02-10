/// UUEncoding and XXEncoding implementation.
///
/// Both use the same algorithm (3 bytes -> 4 characters) but differ in
/// their character lookup table.
///
/// Authors: dd86k <dd@dax.moe>
/// Copyright: dd86k <dd@dax.moe>
/// License: BSD-3-Clause-Clear
module binco.encoding.uuencode;

private immutable char[64] uuTable = ` !"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`;
private immutable char[64] xxTable = `+-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz`;

private immutable ubyte[256] uuReverse = buildReverse(uuTable);
private immutable ubyte[256] xxReverse = buildReverse(xxTable);

private ubyte[256] buildReverse(const char[64] table)
{
    ubyte[256] r = 0xFF;
    foreach (i, c; table)
        r[c] = cast(ubyte) i;
    // UU: backtick (96) is used as alternate for space (value 0)
    //     We might want to make an option for this, though
    if (table[0] == ' ')
        r['`'] = 0;
    return r;
}

/// Encode a chunk of bytes into a single UU/XX encoded line (with length prefix char).
char[] uuEncode(const(ubyte)[] data, bool xxVariant = false)
{
    if (data.length == 0)
        return null;

    immutable table = xxVariant ? xxTable : uuTable;
    size_t nGroups = (data.length + 2) / 3;
    char[] result = new char[1 + nGroups * 4];

    // Length character
    result[0] = table[data.length & 0x3F];

    size_t pos = 1;
    size_t i = 0;
    while (i < data.length)
    {
        ubyte a = data[i];
        ubyte b = (i + 1 < data.length) ? data[i + 1] : 0;
        ubyte c = (i + 2 < data.length) ? data[i + 2] : 0;

        result[pos++] = table[(a >> 2) & 0x3F];
        result[pos++] = table[((a << 4) | (b >> 4)) & 0x3F];
        result[pos++] = table[((b << 2) | (c >> 6)) & 0x3F];
        result[pos++] = table[c & 0x3F];

        i += 3;
    }

    return result;
}

/// Decode a single UU/XX encoded line (strips length prefix, uses it for exact byte count).
ubyte[] uuDecode(const(char)[] line, bool xxVariant = false)
{
    if (line.length == 0)
        return null;

    immutable reverse = xxVariant ? xxReverse : uuReverse;

    ubyte lenVal = reverse[line[0]];
    if (lenVal == 0xFF)
        throw new Exception("Invalid UU/XX length character");
    if (lenVal == 0)
        return null;

    const(char)[] encoded = line[1 .. $];
    size_t nGroups = (encoded.length) / 4;
    ubyte[] buf = new ubyte[nGroups * 3];

    size_t pos = 0;
    for (size_t i = 0; i + 3 < encoded.length; i += 4)
    {
        ubyte a = reverse[encoded[i]];
        ubyte b = reverse[encoded[i + 1]];
        ubyte c = reverse[encoded[i + 2]];
        ubyte d = reverse[encoded[i + 3]];

        if (a == 0xFF || b == 0xFF || c == 0xFF || d == 0xFF)
            throw new Exception("Invalid character in UU/XX encoded data");

        buf[pos++] = cast(ubyte)((a << 2) | (b >> 4));
        buf[pos++] = cast(ubyte)((b << 4) | (c >> 2));
        buf[pos++] = cast(ubyte)((c << 6) | d);
    }

    return buf[0 .. lenVal];
}

unittest
{
    // --- UU encoding tests ---

    // Known test vector: "Cat" in UUEncoding
    // "Cat" = [0x43, 0x61, 0x74]
    {
        auto encoded = uuEncode(cast(const(ubyte)[])"Cat");
        assert(encoded.length == 5); // 1 length + 4 encoded
        auto decoded = uuDecode(encoded);
        assert(decoded == cast(ubyte[])"Cat");
    }

    // Round-trip: "Hello"
    {
        auto data = cast(const(ubyte)[])"Hello";
        auto encoded = uuEncode(data);
        auto decoded = uuDecode(encoded);
        assert(decoded == data);
    }

    // Round-trip: single byte (partial group of 1)
    {
        auto data = cast(const(ubyte)[])"A";
        auto encoded = uuEncode(data);
        auto decoded = uuDecode(encoded);
        assert(decoded == data);
    }

    // Round-trip: two bytes (partial group of 2)
    {
        auto data = cast(const(ubyte)[])"AB";
        auto encoded = uuEncode(data);
        auto decoded = uuDecode(encoded);
        assert(decoded == data);
    }

    // Empty input
    assert(uuEncode(null) is null);
    assert(uuDecode("") is null);

    // Binary data round-trip
    {
        immutable ubyte[] data = [0x00, 0xFF, 0x7F, 0x80, 0x01, 0xFE];
        auto encoded = uuEncode(data);
        auto decoded = uuDecode(encoded);
        assert(decoded == data);
    }

    // --- XX encoding tests ---

    // Round-trip: "Hello" with XX
    {
        auto data = cast(const(ubyte)[])"Hello";
        auto encoded = uuEncode(data, true);
        auto decoded = uuDecode(encoded, true);
        assert(decoded == data);
    }

    // XX: single byte
    {
        auto data = cast(const(ubyte)[])"X";
        auto encoded = uuEncode(data, true);
        auto decoded = uuDecode(encoded, true);
        assert(decoded == data);
    }

    // XX: two bytes
    {
        auto data = cast(const(ubyte)[])"XY";
        auto encoded = uuEncode(data, true);
        auto decoded = uuDecode(encoded, true);
        assert(decoded == data);
    }

    // XX: empty
    assert(uuEncode(null, true) is null);
    assert(uuDecode("", true) is null);

    // XX: binary data
    {
        immutable ubyte[] data = [0x00, 0xFF, 0x7F, 0x80, 0x01, 0xFE];
        auto encoded = uuEncode(data, true);
        auto decoded = uuDecode(encoded, true);
        assert(decoded == data);
    }

    // UU and XX produce different output for same input
    {
        auto data = cast(const(ubyte)[])"Test";
        auto uu = uuEncode(data);
        auto xx = uuEncode(data, true);
        assert(uu != xx);
    }

    // Longer data (45 bytes, typical full UU line)
    {
        ubyte[45] data;
        foreach (i, ref b; data)
            b = cast(ubyte)(i * 7 + 3);
        auto encoded = uuEncode(data[]);
        auto decoded = uuDecode(encoded);
        assert(decoded == data[]);

        // Same for XX
        auto xxEncoded = uuEncode(data[], true);
        auto xxDecoded = uuDecode(xxEncoded, true);
        assert(xxDecoded == data[]);
    }
}
