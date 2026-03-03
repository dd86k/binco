/// Base16 (hexadecimal) implementation.
///
/// Authors: dd86k <dd@dax.moe>
/// Copyright: dd86k <dd@dax.moe>
/// License: BSD-3-Clause-Clear
module binco.encoding.base16;

/// Encode into caller-provided buffer, return filled slice.
char[] base16Encode(const(ubyte)[] data, bool upper, char[] buf)
{
    immutable char[16] digits = upper ? "0123456789ABCDEF" : "0123456789abcdef";

    foreach (i, b; data)
    {
        buf[i * 2]     = digits[b >> 4];
        buf[i * 2 + 1] = digits[b & 0x0F];
    }

    return buf[0 .. data.length * 2];
}

/// Convenience: allocates buffer internally.
char[] base16Encode(const(ubyte)[] data, bool upper = true)
{
    return base16Encode(data, upper, new char[data.length * 2]);
}

/// Decode into caller-provided buffer, return filled slice.
ubyte[] base16Decode(const(char)[] hex, ubyte[] buf)
{
    if (hex.length % 2 != 0)
        throw new Exception("Invalid base16 input: odd length");

    size_t count = hex.length / 2;

    foreach (i; 0 .. count)
    {
        ubyte hi = hexVal(hex[i * 2]);
        ubyte lo = hexVal(hex[i * 2 + 1]);
        buf[i] = cast(ubyte)((hi << 4) | lo);
    }

    return buf[0 .. count];
}

/// Convenience: allocates buffer internally.
ubyte[] base16Decode(const(char)[] hex)
{
    if (hex.length % 2 != 0)
        throw new Exception("Invalid base16 input: odd length");

    return base16Decode(hex, new ubyte[hex.length / 2]);
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
