/// basE91 encoding implementation.
///
/// Binary-to-text encoding using 91 printable ASCII characters,
/// achieving ~23% overhead vs ~33% for base64.
///
/// Authors: dd86k <dd@dax.moe>
/// Copyright: dd86k <dd@dax.moe>
/// License: BSD-3-Clause-Clear
module binco.encoding.base91;

private immutable char[91] enctab =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#$%&()*+,./:;<=>?@[]^_`{|}~\"";

private immutable ubyte[256] dectab = () {
    ubyte[256] t = 255;
    foreach (i, c; enctab)
        t[c] = cast(ubyte) i;
    return t;
}();

/// Encode into caller-provided buffer, return filled slice.
char[] base91Encode(const(ubyte)[] data, char[] buf)
{
    if (data.length == 0)
        return buf[0 .. 0];

    size_t pos = 0;
    uint b = 0; // bit accumulator
    uint n = 0; // number of bits in accumulator

    foreach (byte_; data)
    {
        b |= cast(uint) byte_ << n;
        n += 8;

        if (n > 13)
        {
            uint v = b & 8191; // extract 13 bits
            if (v > 88)
            {
                b >>= 13;
                n -= 13;
            }
            else
            {
                v = b & 16383; // extract 14 bits
                b >>= 14;
                n -= 14;
            }
            buf[pos++] = enctab[v % 91];
            buf[pos++] = enctab[v / 91];
        }
    }

    // Flush remaining bits
    if (n > 0)
    {
        buf[pos++] = enctab[b % 91];
        if (n > 7 || b > 90)
            buf[pos++] = enctab[b / 91];
    }

    return buf[0 .. pos];
}

/// Convenience: allocates buffer internally.
char[] base91Encode(const(ubyte)[] data)
{
    if (data.length == 0)
        return null;

    // Worst case: ~16 chars per 13 bytes + 2 for flush
    return base91Encode(data, new char[data.length * 16 / 13 + 2]);
}

/// Decode into caller-provided buffer, return filled slice.
ubyte[] base91Decode(const(char)[] text, ubyte[] buf)
{
    if (text.length == 0)
        return null;

    size_t pos = 0;
    uint b = 0; // bit accumulator
    uint n = 0; // number of bits in accumulator
    int v = -1; // first value of pair (-1 = waiting for first)

    foreach (c; text)
    {
        ubyte d = dectab[c];
        if (d == 255)
            continue; // skip invalid characters (whitespace etc.)

        if (v == -1)
        {
            v = d;
        }
        else
        {
            v += d * 91;
            b |= v << n;
            n += (v & 8191) > 88 ? 13 : 14;

            while (n >= 8)
            {
                buf[pos++] = cast(ubyte)(b & 255);
                b >>= 8;
                n -= 8;
            }
            v = -1;
        }
    }

    // Flush remaining bits from unpaired final character
    if (v != -1)
    {
        buf[pos++] = cast(ubyte)((b | v << n) & 255);
    }

    return pos ? buf[0 .. pos] : null;
}

/// Convenience: allocates buffer internally.
ubyte[] base91Decode(const(char)[] text)
{
    if (text.length == 0)
        return null;

    // Worst case: ~7/8 byte per char + 1
    return base91Decode(text, new ubyte[text.length]);
}

unittest
{
    // Empty input
    assert(base91Encode(null) == "");
    assert(base91Decode("") is null);

    // Round-trip: "Hello World"
    {
        const(ubyte)[] data = cast(const(ubyte)[]) "Hello World";
        char[] encoded = base91Encode(data);
        assert(encoded.length > 0);
        assert(base91Decode(encoded) == data);
    }

    // Round-trip: single byte
    {
        const(ubyte)[] data = cast(const(ubyte)[]) "A";
        assert(base91Decode(base91Encode(data)) == data);
    }

    // Round-trip: two bytes
    {
        const(ubyte)[] data = cast(const(ubyte)[]) "AB";
        assert(base91Decode(base91Encode(data)) == data);
    }

    // Round-trip: three bytes
    {
        const(ubyte)[] data = cast(const(ubyte)[]) "ABC";
        assert(base91Decode(base91Encode(data)) == data);
    }

    // Round-trip: binary data
    {
        immutable ubyte[] data = [0x00, 0xFF, 0x7F, 0x80, 0x01, 0xFE];
        assert(base91Decode(base91Encode(data)) == data);
    }

    // Round-trip: all byte values
    {
        ubyte[256] data;
        foreach (i, ref b; data)
            b = cast(ubyte) i;
        assert(base91Decode(base91Encode(data[])) == data[]);
    }

    // Round-trip: longer data
    {
        ubyte[60] data;
        foreach (i, ref b; data)
            b = cast(ubyte)(i * 7 + 3);
        assert(base91Decode(base91Encode(data[])) == data[]);
    }

    // Verify encoding is shorter than base64 for non-trivial data
    {
        ubyte[100] data;
        foreach (i, ref b; data)
            b = cast(ubyte)(i * 13 + 5);
        char[] encoded = base91Encode(data[]);
        // basE91 should produce fewer characters than base64 (which would be 136 chars)
        assert(encoded.length < 136);
    }

    // Whitespace/invalid characters ignored during decoding
    {
        const(ubyte)[] data = cast(const(ubyte)[]) "test";
        char[] encoded = base91Encode(data);
        // Insert whitespace into encoded string
        char[] withSpaces;
        foreach (i, c; encoded)
        {
            withSpaces ~= c;
            if (i == 1) withSpaces ~= ' ';
        }
        assert(base91Decode(withSpaces) == data);
    }
    
    assert(base91Encode(cast(ubyte[])(
        `Man is distinguished, not only by his reason, but by this singular passion from `~
        `other animals, which is a lust of the mind, that by a perseverance of delight in `~
        `the continued and indefatigable generation of knowledge, exceeds the short `~
        `vehemence of any carnal pleasure.`)) ==
        "8D$J`/wC4!c.hQ;mT8,<p/&Y/H@$]xlL3oDg<W.0$FW6GFMo_D8=8=}AMf][|LfVd/<P1o/1Z2(.I+LR6t"~
        "QQ0o1a/2/WtN3$3t[x&k)zgZ5=p;LRe.{B[pqa(I.WRT%yxtB92oZB,2,Wzv;Rr#N.cju\"JFXiZBMf<WM"~
        "C&$@+e95p)z01_*UCxT0t88Km=UQJ;WH[#F]4pE>i3o(g7=$e7R2u>xjLxoefB.6Yy#~uex8jEU_1e,MIr"~
        "%!&=EHnLBn2h>M+;Rl3qxcL5)Wfc,HT$F]4pEsofrFK;W&eh#=#},|iKB,2,W]@fVlx,a<m;i=CY<=Hb%}"~
        "+},F");
}
