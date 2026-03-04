/// Base36 implementation.
///
/// Authors: dd86k <dd@dax.moe>
/// Copyright: dd86k <dd@dax.moe>
/// License: BSD-3-Clause-Clear
module binco.encoding.base36;

private immutable char[36] alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";

private immutable ubyte[256] decodeTable = () {
    ubyte[256] t = 0xFF;
    foreach (i, c; alphabet)
        t[c] = cast(ubyte) i;
    // Also accept lowercase
    foreach (i, c; cast(immutable(ubyte)[36]) "0123456789abcdefghijklmnopqrstuvwxyz")
        t[c] = cast(ubyte) i;
    return t;
}();

/// Encode into caller-provided buffer, return filled slice.
char[] base36Encode(const(ubyte)[] data, char[] buf)
{
    if (data.length == 0)
        return buf[0 .. 0];

    // Count leading zeros
    size_t zeroCount = 0;
    while (zeroCount < data.length && data[zeroCount] == 0)
        zeroCount++;

    // Work on a mutable copy for divmod
    ubyte[] num = new ubyte[data.length];
    num[] = data[];

    // Encode by repeated divmod 36
    size_t outIdx = buf.length;
    size_t start = zeroCount;

    while (start < num.length)
    {
        uint remainder = 0;
        size_t newStart = start;
        bool leadingZero = true;

        foreach (i; start .. num.length)
        {
            uint digit = remainder * 256 + num[i];
            num[i] = cast(ubyte)(digit / 36);
            remainder = digit % 36;

            if (leadingZero && num[i] == 0)
                newStart = i + 1;
            else
                leadingZero = false;
        }

        outIdx--;
        buf[outIdx] = alphabet[remainder];
        start = newStart;
    }

    // Leading '0's for leading zero bytes
    foreach (_; 0 .. zeroCount)
    {
        outIdx--;
        buf[outIdx] = '0';
    }

    // Shift result to beginning of buffer
    size_t len = buf.length - outIdx;
    if (outIdx > 0)
    {
        foreach (i; 0 .. len)
            buf[i] = buf[outIdx + i];
    }
    return buf[0 .. len];
}

/// Convenience: allocates buffer internally.
char[] base36Encode(const(ubyte)[] data)
{
    if (data.length == 0)
        return null;

    // Worst case: ~155% expansion + leading zeros (log(256)/log(36) ≈ 1.55)
    size_t maxLen = data.length * 155 / 100 + 2;
    return base36Encode(data, new char[maxLen]);
}

/// Decode into caller-provided buffer, return filled slice.
ubyte[] base36Decode(const(char)[] str, ubyte[] buf)
{
    if (str.length == 0)
        return buf[0 .. 0];

    // Count leading '0's (map to 0x00 bytes)
    size_t zeroCount = 0;
    while (zeroCount < str.length && str[zeroCount] == '0')
        zeroCount++;

    // Decode by multiply-and-add
    buf[] = 0;
    size_t outIdx = buf.length;

    foreach (i; zeroCount .. str.length)
    {
        ubyte val = decodeTable[cast(ubyte) str[i]];
        if (val == 0xFF)
            throw new Exception("Invalid base36 character: " ~ str[i]);

        uint carry = val;
        size_t j = buf.length;
        while (j > outIdx || carry != 0)
        {
            if (j == 0)
                throw new Exception("Base36 decode buffer too small");
            j--;
            uint tmp = cast(uint) buf[j] * 36 + carry;
            buf[j] = cast(ubyte)(tmp & 0xFF);
            carry = tmp >> 8;
        }
        outIdx = j;
    }

    // Build result: leading zeros + decoded bytes
    size_t len = zeroCount + (buf.length - outIdx);
    if (zeroCount > 0 || outIdx > 0)
    {
        size_t decodedLen = buf.length - outIdx;
        foreach (i; 0 .. decodedLen)
            buf[zeroCount + i] = buf[outIdx + i];
        foreach (i; 0 .. zeroCount)
            buf[i] = 0;
    }

    return buf[0 .. len];
}

/// Convenience: allocates buffer internally.
ubyte[] base36Decode(const(char)[] str)
{
    if (str.length == 0)
        return null;

    return base36Decode(str, new ubyte[str.length]);
}

unittest
{
    // Encode known vectors
    assert(base36Encode(cast(const(ubyte)[])"Hello") == "3YUD78MN");
    assert(base36Encode(cast(const(ubyte)[])"Hello World") == "AZW5BZ2XP56M4QYCK");

    // Decode known vectors
    assert(base36Decode("3YUD78MN") == cast(ubyte[])"Hello");
    assert(base36Decode("AZW5BZ2XP56M4QYCK") == cast(ubyte[])"Hello World");

    // Case-insensitive decode
    assert(base36Decode("3yud78mn") == cast(ubyte[])"Hello");

    // Round-trip
    immutable ubyte[] data = [0x00, 0xFF, 0x7F, 0x80, 0x01, 0xFE];
    assert(base36Decode(base36Encode(data)) == data);

    // Empty input
    assert(base36Encode(null) == null);
    assert(base36Decode("") == null);

    // Leading zeros preserved
    assert(base36Encode([cast(ubyte) 0x00, 0x00, 0x01]) == "001");
    assert(base36Decode("001") == [cast(ubyte) 0x00, 0x00, 0x01]);

    // Single zero byte
    assert(base36Encode([cast(ubyte) 0x00]) == "0");
    assert(base36Decode("0") == [cast(ubyte) 0x00]);
}
