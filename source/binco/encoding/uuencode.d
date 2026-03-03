/// UUEncoding and XXEncoding implementation.
///
/// Both use the same algorithm (3 bytes -> 4 characters) but differ in
/// their character lookup table.
///
/// Authors: dd86k <dd@dax.moe>
/// Copyright: dd86k <dd@dax.moe>
/// License: BSD-3-Clause-Clear
module binco.encoding.uuencode;

private immutable char[64] uuTable = "`!\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_";
private immutable char[64] xxTable = `+-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz`;

private immutable ubyte[256] uuReverse = buildReverse(uuTable);
private immutable ubyte[256] xxReverse = buildReverse(xxTable);

private ubyte[256] buildReverse(const char[64] table)
{
    ubyte[256] r = 0xFF;
    foreach (i, c; table)
        r[c] = cast(ubyte) i;
    // UU: space and backtick are interchangeable for value 0
    if (table[0] == '`')
        r[' '] = 0;
    else if (table[0] == ' ')
        r['`'] = 0;
    return r;
}

/// Encode a chunk of bytes into a single UU/XX encoded line (with length prefix char).
/// Buffer overload: encode into caller-provided buffer, return filled slice.
char[] uuEncode(const(ubyte)[] data, bool xxVariant, char[] buf)
{
    if (data.length == 0)
        return null;

    immutable table = xxVariant ? xxTable : uuTable;

    // Length character
    buf[0] = table[data.length & 0x3F];

    size_t pos = 1;
    size_t i = 0;
    while (i < data.length)
    {
        ubyte a = data[i];
        ubyte b = (i + 1 < data.length) ? data[i + 1] : 0;
        ubyte c = (i + 2 < data.length) ? data[i + 2] : 0;

        buf[pos++] = table[(a >> 2) & 0x3F];
        buf[pos++] = table[((a << 4) | (b >> 4)) & 0x3F];
        buf[pos++] = table[((b << 2) | (c >> 6)) & 0x3F];
        buf[pos++] = table[c & 0x3F];

        i += 3;
    }

    return buf[0 .. pos];
}

/// Convenience: allocates buffer internally.
char[] uuEncode(const(ubyte)[] data, bool xxVariant = false)
{
    if (data.length == 0)
        return null;

    size_t nGroups = (data.length + 2) / 3;
    return uuEncode(data, xxVariant, new char[1 + nGroups * 4]);
}

/// Decode a single UU/XX encoded line (strips length prefix, uses it for exact byte count).
/// Buffer overload: decode into caller-provided buffer, return filled slice.
ubyte[] uuDecode(const(char)[] line, bool xxVariant, ubyte[] buf)
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

/// Convenience: allocates buffer internally.
ubyte[] uuDecode(const(char)[] line, bool xxVariant = false)
{
    if (line.length == 0)
        return null;

    size_t nGroups = (line.length > 1) ? (line.length - 1) / 4 : 0;
    return uuDecode(line, xxVariant, new ubyte[nGroups * 3]);
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
    
    // uuEncode cannot handle multilines
    // for now, slice into 45 byte chunks
    {
        auto input = cast(const(ubyte)[])(
            `Man is distinguished, not only by his reason, but by this singular passion from `~
            `other animals, which is a lust of the mind, that by a perseverance of delight in `~
            `the continued and indefatigable generation of knowledge, exceeds the short `~
            `vehemence of any carnal pleasure.`);
        assert(uuEncode(input[0 .. 45]) ==
            "M36%N(&ES(&1I<W1I;F=U:7-H960L(&YO=\"!O;FQY(&)Y(&AI<R!R96%S;VXL");
        assert(uuEncode(input[45 .. 90]) ==
            "M(&)U=\"!B>2!T:&ES('-I;F=U;&%R('!A<W-I;VX@9G)O;2!O=&AE<B!A;FEM");
        assert(uuEncode(input[90 .. 135]) ==
            "M86QS+\"!W:&EC:\"!I<R!A(&QU<W0@;V8@=&AE(&UI;F0L('1H870@8GD@82!P");
        assert(uuEncode(input[135 .. 180]) ==
            "M97)S979E<F%N8V4@;V8@9&5L:6=H=\"!I;B!T:&4@8V]N=&EN=65D(&%N9\"!I");
        assert(uuEncode(input[180 .. 225]) ==
            "M;F1E9F%T:6=A8FQE(&=E;F5R871I;VX@;V8@:VYO=VQE9&=E+\"!E>&-E961S");
        assert(uuEncode(input[225 .. $]) ==
            "L('1H92!S:&]R=\"!V96AE;65N8V4@;V8@86YY(&-A<FYA;\"!P;&5A<W5R92X`");
    }
}
