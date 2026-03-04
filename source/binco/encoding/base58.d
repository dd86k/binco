/// Base58 (Bitcoin alphabet) implementation.
///
/// Authors: dd86k <dd@dax.moe>
/// Copyright: dd86k <dd@dax.moe>
/// License: BSD-3-Clause-Clear
module binco.encoding.base58;

private immutable char[58] alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

private immutable ubyte[256] decodeTable = () {
    ubyte[256] t = 0xFF;
    foreach (i, c; alphabet)
        t[c] = cast(ubyte) i;
    return t;
}();

/// Encode into caller-provided buffer, return filled slice.
char[] base58Encode(const(ubyte)[] data, char[] buf)
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

    // Encode by repeated divmod 58
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
            num[i] = cast(ubyte)(digit / 58);
            remainder = digit % 58;

            if (leadingZero && num[i] == 0)
                newStart = i + 1;
            else
                leadingZero = false;
        }

        outIdx--;
        buf[outIdx] = alphabet[remainder];
        start = newStart;
    }

    // Leading '1's for leading zero bytes
    foreach (_; 0 .. zeroCount)
    {
        outIdx--;
        buf[outIdx] = '1';
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
char[] base58Encode(const(ubyte)[] data)
{
    if (data.length == 0)
        return null;

    // Worst case: ~137% expansion + leading zeros
    size_t maxLen = data.length * 137 / 100 + 2;
    return base58Encode(data, new char[maxLen]);
}

/// Decode into caller-provided buffer, return filled slice.
ubyte[] base58Decode(const(char)[] str, ubyte[] buf)
{
    if (str.length == 0)
        return buf[0 .. 0];

    // Count leading '1's (map to 0x00 bytes)
    size_t oneCount = 0;
    while (oneCount < str.length && str[oneCount] == '1')
        oneCount++;

    // Decode by multiply-and-add
    // Use buf from the end, working backwards
    buf[] = 0;
    size_t outIdx = buf.length;

    foreach (i; oneCount .. str.length)
    {
        ubyte val = decodeTable[cast(ubyte) str[i]];
        if (val == 0xFF)
            throw new Exception("Invalid base58 character: " ~ str[i]);

        uint carry = val;
        size_t j = buf.length;
        while (j > outIdx || carry != 0)
        {
            if (j == 0)
                throw new Exception("Base58 decode buffer too small");
            j--;
            uint tmp = cast(uint) buf[j] * 58 + carry;
            buf[j] = cast(ubyte)(tmp & 0xFF);
            carry = tmp >> 8;
        }
        outIdx = j;
    }

    // Build result: leading zeros + decoded bytes
    size_t len = oneCount + (buf.length - outIdx);
    // Shift to beginning
    if (oneCount > 0 || outIdx > 0)
    {
        // Move decoded bytes after leading zeros
        size_t decodedLen = buf.length - outIdx;
        // Copy forward to avoid overlap corruption
        foreach (i; 0 .. decodedLen)
            buf[oneCount + i] = buf[outIdx + i];
        // Fill leading zeros
        foreach (i; 0 .. oneCount)
            buf[i] = 0;
    }

    return buf[0 .. len];
}

/// Convenience: allocates buffer internally.
ubyte[] base58Decode(const(char)[] str)
{
    if (str.length == 0)
        return null;

    // Output is at most as long as input
    return base58Decode(str, new ubyte[str.length]);
}

unittest
{
    // Encode known vectors
    assert(base58Encode(cast(const(ubyte)[])"Hello") == "9Ajdvzr");
    assert(base58Encode(cast(const(ubyte)[])"Hello World") == "JxF12TrwUP45BMd");

    // Decode known vectors
    assert(base58Decode("9Ajdvzr") == cast(ubyte[])"Hello");
    assert(base58Decode("JxF12TrwUP45BMd") == cast(ubyte[])"Hello World");

    // Round-trip
    immutable ubyte[] data = [0x00, 0xFF, 0x7F, 0x80, 0x01, 0xFE];
    assert(base58Decode(base58Encode(data)) == data);

    // Empty input
    assert(base58Encode(null) == null);
    assert(base58Decode("") == null);

    // Leading zeros preserved
    assert(base58Encode([cast(ubyte) 0x00, 0x00, 0x01]) == "112");
    assert(base58Decode("112") == [cast(ubyte) 0x00, 0x00, 0x01]);

    // Single zero byte
    assert(base58Encode([cast(ubyte) 0x00]) == "1");
    assert(base58Decode("1") == [cast(ubyte) 0x00]);
}
