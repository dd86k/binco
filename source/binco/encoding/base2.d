/// Base2 (binary) implementation.
///
/// Authors: dd86k <dd@dax.moe>
/// Copyright: dd86k <dd@dax.moe>
/// License: BSD-3-Clause-Clear
module binco.encoding.base2;

/// Encode into caller-provided buffer, return filled slice.
char[] base2Encode(const(ubyte)[] data, char[] buf)
{
    foreach (i, b; data)
    {
        foreach (bit; 0 .. 8)
            buf[i * 8 + bit] = (b >> (7 - bit)) & 1 ? '1' : '0';
    }

    return buf[0 .. data.length * 8];
}

/// Convenience: allocates buffer internally.
char[] base2Encode(const(ubyte)[] data)
{
    return base2Encode(data, new char[data.length * 8]);
}

/// Decode into caller-provided buffer, return filled slice.
ubyte[] base2Decode(const(char)[] bin, ubyte[] buf)
{
    size_t pos;
    ubyte val;
    int bitCount;

    foreach (c; bin)
    {
        if (c != '0' && c != '1')
            continue;
        val = cast(ubyte)((val << 1) | (c - '0'));
        if (++bitCount == 8)
        {
            buf[pos++] = val;
            val = 0;
            bitCount = 0;
        }
    }

    if (bitCount != 0)
        throw new Exception("Invalid base2 input: length not a multiple of 8");

    return pos ? buf[0 .. pos] : null;
}

/// Convenience: allocates buffer internally.
ubyte[] base2Decode(const(char)[] bin)
{
    return base2Decode(bin, new ubyte[bin.length / 8]);
}

unittest
{
    // Encode
    assert(base2Encode(cast(const(ubyte)[])"A") == "01000001");
    assert(base2Encode(cast(const(ubyte)[])"Hi") == "0100100001101001");

    // Decode
    assert(base2Decode("01000001") == cast(ubyte[])"A");
    assert(base2Decode("0100100001101001") == cast(ubyte[])"Hi");

    // Round-trip
    immutable ubyte[] data = [0x00, 0xFF, 0x7F, 0x80, 0x01, 0xFE];
    assert(base2Decode(base2Encode(data)) == data);

    // Empty input
    assert(base2Encode(null) == "");
    assert(base2Decode("") == null);

    // Decode with spaces between bytes
    assert(base2Decode("01001000 01101001") == cast(ubyte[])"Hi");
    assert(base2Decode("01001000  01101001") == cast(ubyte[])"Hi"); // multiple spaces
    assert(base2Decode(" 01001000 01101001 ") == cast(ubyte[])"Hi"); // leading/trailing

    // Decode with other separators (ignored)
    assert(base2Decode("01001000-01101001") == cast(ubyte[])"Hi"); // dashes
    assert(base2Decode("01001000_01101001") == cast(ubyte[])"Hi"); // underscores
    assert(base2Decode("01001000,01101001") == cast(ubyte[])"Hi"); // commas

    // Partial data (not a multiple of 8) should throw
    bool threw;
    try base2Decode("0100");
    catch (Exception) threw = true;
    assert(threw, "Expected exception for partial input");

    threw = false;
    try base2Decode("010000011"); // 9 bits
    catch (Exception) threw = true;
    assert(threw, "Expected exception for 9-bit input");
}
