/// Base16 (hexadecimal) implementation.
///
/// Authors: dd86k <dd@dax.moe>
/// Copyright: dd86k <dd@dax.moe>
/// License: BSD-3-Clause-Clear
module binco.encoding.base16;

string base16Encode(const(ubyte)[] data, bool upper = true)
{
    immutable char[16] digits = upper ? "0123456789ABCDEF" : "0123456789abcdef";
    char[] result = new char[data.length * 2];

    foreach (i, b; data)
    {
        result[i * 2]     = digits[b >> 4];
        result[i * 2 + 1] = digits[b & 0x0F];
    }

    return cast(string) result;
}

ubyte[] base16Decode(const(char)[] hex)
{
    import std.format : format;

    if (hex.length % 2 != 0)
        throw new Exception("Invalid base16 input: odd length");

    ubyte[] result = new ubyte[hex.length / 2];

    foreach (i; 0 .. result.length)
    {
        ubyte hi = hexVal(hex[i * 2]);
        ubyte lo = hexVal(hex[i * 2 + 1]);
        result[i] = cast(ubyte)((hi << 4) | lo);
    }

    return result;
}

private ubyte hexVal(char c)
{
    if (c >= '0' && c <= '9') return cast(ubyte)(c - '0');
    if (c >= 'A' && c <= 'F') return cast(ubyte)(c - 'A' + 10);
    if (c >= 'a' && c <= 'f') return cast(ubyte)(c - 'a' + 10);
    throw new Exception("Invalid hex character: " ~ c);
}

unittest
{
    // Encode uppercase (default)
    assert(base16Encode(cast(const(ubyte)[])"Hello") == "48656C6C6F");

    // Encode lowercase
    assert(base16Encode(cast(const(ubyte)[])"Hello", false) == "48656c6c6f");

    // Decode uppercase
    assert(base16Decode("48656C6C6F") == cast(ubyte[])"Hello");

    // Decode lowercase
    assert(base16Decode("48656c6c6f") == cast(ubyte[])"Hello");

    // Decode mixed case
    assert(base16Decode("48656C6c6f") == cast(ubyte[])"Hello");

    // Round-trip
    immutable ubyte[] data = [0x00, 0xFF, 0x7F, 0x80, 0x01, 0xFE];
    assert(base16Decode(base16Encode(data)) == data);
    assert(base16Decode(base16Encode(data, false)) == data);

    // Empty input
    assert(base16Encode(null) == "");
    assert(base16Decode("") == null);
}
