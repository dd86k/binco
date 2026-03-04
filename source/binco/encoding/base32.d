/// Base32 (RFC 4648) implementation.
///
/// Authors: dd86k <dd@dax.moe>
/// Copyright: dd86k <dd@dax.moe>
/// License: BSD-3-Clause-Clear
module binco.encoding.base32;

/// Base32 alphabet set of 32 characters
enum Base32Alphabet
{
    standard,
    extendedHex,
    zbase32,
}

private immutable char[32] stdUpper     = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
private immutable char[32] stdLower     = "abcdefghijklmnopqrstuvwxyz234567";
private immutable char[32] hexUpper     = "0123456789ABCDEFGHIJKLMNOPQRSTUV";
private immutable char[32] hexLower     = "0123456789abcdefghijklmnopqrstuv";
private immutable char[32] zbase32Alpha = "ybndrfg8ejkmcpqxot1uwisza345h769";
private immutable ubyte[128] zbase32Reverse = () {
    ubyte[128] t = 0xFF;
    foreach (ubyte i, char c; zbase32Alpha)
        t[c] = i;
    return t;
}();

/// Encode into caller-provided buffer, return filled slice.
char[] base32Encode(const(ubyte)[] data, bool upper, char[] buf,
    Base32Alphabet alphabet = Base32Alphabet.standard)
{
    immutable(char)[32] table = selectAlphabet(alphabet, upper);

    bool usePadding = alphabet != Base32Alphabet.zbase32;

    size_t len = data.length;
    size_t outIdx;
    size_t i;

    // Process full 5-byte groups
    while (i + 5 <= len)
    {
        buf[outIdx++] = table[(data[i] >> 3)];
        buf[outIdx++] = table[((data[i] & 0x07) << 2) | (data[i+1] >> 6)];
        buf[outIdx++] = table[(data[i+1] >> 1) & 0x1F];
        buf[outIdx++] = table[((data[i+1] & 0x01) << 4) | (data[i+2] >> 4)];
        buf[outIdx++] = table[((data[i+2] & 0x0F) << 1) | (data[i+3] >> 7)];
        buf[outIdx++] = table[(data[i+3] >> 2) & 0x1F];
        buf[outIdx++] = table[((data[i+3] & 0x03) << 3) | (data[i+4] >> 5)];
        buf[outIdx++] = table[data[i+4] & 0x1F];
        i += 5;
    }

    // Handle remaining bytes with padding
    switch (len - i) {
    case 1:
        buf[outIdx++] = table[(data[i] >> 3)];
        buf[outIdx++] = table[((data[i] & 0x07) << 2)];
        if (usePadding) { buf[outIdx++] = '='; buf[outIdx++] = '='; buf[outIdx++] = '=';
            buf[outIdx++] = '='; buf[outIdx++] = '='; buf[outIdx++] = '='; }
        break;
    case 2:
        buf[outIdx++] = table[(data[i] >> 3)];
        buf[outIdx++] = table[((data[i] & 0x07) << 2) | (data[i+1] >> 6)];
        buf[outIdx++] = table[(data[i+1] >> 1) & 0x1F];
        buf[outIdx++] = table[((data[i+1] & 0x01) << 4)];
        if (usePadding) { buf[outIdx++] = '='; buf[outIdx++] = '='; buf[outIdx++] = '=';
            buf[outIdx++] = '='; }
        break;
    case 3:
        buf[outIdx++] = table[(data[i] >> 3)];
        buf[outIdx++] = table[((data[i] & 0x07) << 2) | (data[i+1] >> 6)];
        buf[outIdx++] = table[(data[i+1] >> 1) & 0x1F];
        buf[outIdx++] = table[((data[i+1] & 0x01) << 4) | (data[i+2] >> 4)];
        buf[outIdx++] = table[((data[i+2] & 0x0F) << 1)];
        if (usePadding) { buf[outIdx++] = '='; buf[outIdx++] = '='; buf[outIdx++] = '='; }
        break;
    case 4:
        buf[outIdx++] = table[(data[i] >> 3)];
        buf[outIdx++] = table[((data[i] & 0x07) << 2) | (data[i+1] >> 6)];
        buf[outIdx++] = table[(data[i+1] >> 1) & 0x1F];
        buf[outIdx++] = table[((data[i+1] & 0x01) << 4) | (data[i+2] >> 4)];
        buf[outIdx++] = table[((data[i+2] & 0x0F) << 1) | (data[i+3] >> 7)];
        buf[outIdx++] = table[(data[i+3] >> 2) & 0x1F];
        buf[outIdx++] = table[((data[i+3] & 0x03) << 3)];
        if (usePadding) { buf[outIdx++] = '='; }
        break;
    default:
    }

    return buf[0 .. outIdx];
}

/// Convenience: allocates buffer internally.
char[] base32Encode(const(ubyte)[] data, bool upper = true,
    Base32Alphabet alphabet = Base32Alphabet.standard)
{
    size_t outLen = (data.length + 4) / 5 * 8;
    return base32Encode(data, upper, new char[outLen], alphabet);
}

/// Decode into caller-provided buffer, return filled slice.
ubyte[] base32Decode(const(char)[] text, ubyte[] buf,
    Base32Alphabet alphabet = Base32Alphabet.standard)
{
    // Strip padding
    size_t len = text.length;
    while (len > 0 && text[len - 1] == '=')
        --len;

    size_t outIdx = 0;
    size_t i = 0;

    // Process full 8-character groups
    while (i + 8 <= len)
    {
        ubyte a = b32Val(text[i], alphabet);
        ubyte b = b32Val(text[i+1], alphabet);
        ubyte c = b32Val(text[i+2], alphabet);
        ubyte d = b32Val(text[i+3], alphabet);
        ubyte e = b32Val(text[i+4], alphabet);
        ubyte f = b32Val(text[i+5], alphabet);
        ubyte g = b32Val(text[i+6], alphabet);
        ubyte h = b32Val(text[i+7], alphabet);

        buf[outIdx++] = cast(ubyte)((a << 3) | (b >> 2));
        buf[outIdx++] = cast(ubyte)((b << 6) | (c << 1) | (d >> 4));
        buf[outIdx++] = cast(ubyte)((d << 4) | (e >> 1));
        buf[outIdx++] = cast(ubyte)((e << 7) | (f << 2) | (g >> 3));
        buf[outIdx++] = cast(ubyte)((g << 5) | h);
        i += 8;
    }

    // Handle remaining characters
    size_t charRemaining = len - i;
    if (charRemaining >= 2)
    {
        ubyte a = b32Val(text[i], alphabet);
        ubyte b = b32Val(text[i+1], alphabet);
        buf[outIdx++] = cast(ubyte)((a << 3) | (b >> 2));
    }
    if (charRemaining >= 4)
    {
        ubyte b = b32Val(text[i+1], alphabet);
        ubyte c = b32Val(text[i+2], alphabet);
        ubyte d = b32Val(text[i+3], alphabet);
        buf[outIdx++] = cast(ubyte)((b << 6) | (c << 1) | (d >> 4));
    }
    if (charRemaining >= 5)
    {
        ubyte d = b32Val(text[i+3], alphabet);
        ubyte e = b32Val(text[i+4], alphabet);
        buf[outIdx++] = cast(ubyte)((d << 4) | (e >> 1));
    }
    if (charRemaining >= 7)
    {
        ubyte e = b32Val(text[i+4], alphabet);
        ubyte f = b32Val(text[i+5], alphabet);
        ubyte g = b32Val(text[i+6], alphabet);
        buf[outIdx++] = cast(ubyte)((e << 7) | (f << 2) | (g >> 3));
    }

    return buf[0 .. outIdx];
}

/// Convenience: allocates buffer internally.
ubyte[] base32Decode(const(char)[] text,
    Base32Alphabet alphabet = Base32Alphabet.standard)
{
    size_t outLen = text.length / 8 * 5 + 5;
    return base32Decode(text, new ubyte[outLen], alphabet);
}

// Extended Hex convenience wrappers

char[] base32hEncode(const(ubyte)[] data, bool upper, char[] buf)
{
    return base32Encode(data, upper, buf, Base32Alphabet.extendedHex);
}

char[] base32hEncode(const(ubyte)[] data, bool upper = true)
{
    return base32Encode(data, upper, Base32Alphabet.extendedHex);
}

ubyte[] base32hDecode(const(char)[] text, ubyte[] buf)
{
    return base32Decode(text, buf, Base32Alphabet.extendedHex);
}

ubyte[] base32hDecode(const(char)[] text)
{
    return base32Decode(text, Base32Alphabet.extendedHex);
}

// Z-Base32 convenience wrappers

char[] base32zEncode(const(ubyte)[] data, char[] buf)
{
    return base32Encode(data, false, buf, Base32Alphabet.zbase32);
}

char[] base32zEncode(const(ubyte)[] data)
{
    return base32Encode(data, false, Base32Alphabet.zbase32);
}

ubyte[] base32zDecode(const(char)[] text, ubyte[] buf)
{
    return base32Decode(text, buf, Base32Alphabet.zbase32);
}

ubyte[] base32zDecode(const(char)[] text)
{
    return base32Decode(text, Base32Alphabet.zbase32);
}

private immutable(char)[32] selectAlphabet(Base32Alphabet alphabet, bool upper)
{
    final switch (alphabet) {
    case Base32Alphabet.standard:
        return upper ? stdUpper : stdLower;
    case Base32Alphabet.extendedHex:
        return upper ? hexUpper : hexLower;
    case Base32Alphabet.zbase32:
        return zbase32Alpha;
    }
}

private ubyte b32Val(char c, Base32Alphabet alphabet = Base32Alphabet.standard)
{
    final switch (alphabet) {
    case Base32Alphabet.standard:
        if (c >= 'A' && c <= 'Z') return cast(ubyte)(c - 'A');
        if (c >= 'a' && c <= 'z') return cast(ubyte)(c - 'a');
        if (c >= '2' && c <= '7') return cast(ubyte)(c - '2' + 26);
        break;
    case Base32Alphabet.extendedHex:
        if (c >= '0' && c <= '9') return cast(ubyte)(c - '0');
        if (c >= 'A' && c <= 'V') return cast(ubyte)(c - 'A' + 10);
        if (c >= 'a' && c <= 'v') return cast(ubyte)(c - 'a' + 10);
        break;
    case Base32Alphabet.zbase32:
        if (c >= 128 || zbase32Reverse[c] == 0xFF) break;
        return zbase32Reverse[c];
    }
    throw new Exception("Invalid base32 character: " ~ c);
}

unittest
{
    // RFC 4648 test vectors (standard)
    assert(base32Encode(cast(const(ubyte)[])"") == "");
    assert(base32Encode(cast(const(ubyte)[])"f") == "MY======");
    assert(base32Encode(cast(const(ubyte)[])"fo") == "MZXQ====");
    assert(base32Encode(cast(const(ubyte)[])"foo") == "MZXW6===");
    assert(base32Encode(cast(const(ubyte)[])"foob") == "MZXW6YQ=");
    assert(base32Encode(cast(const(ubyte)[])"fooba") == "MZXW6YTB");
    assert(base32Encode(cast(const(ubyte)[])"foobar") == "MZXW6YTBOI======");

    // Lowercase encoding
    assert(base32Encode(cast(const(ubyte)[])"foobar", false) == "mzxw6ytboi======");

    // Decode RFC 4648 test vectors
    assert(base32Decode("MY======") == cast(ubyte[])"f");
    assert(base32Decode("MZXQ====") == cast(ubyte[])"fo");
    assert(base32Decode("MZXW6===") == cast(ubyte[])"foo");
    assert(base32Decode("MZXW6YQ=") == cast(ubyte[])"foob");
    assert(base32Decode("MZXW6YTB") == cast(ubyte[])"fooba");
    assert(base32Decode("MZXW6YTBOI======") == cast(ubyte[])"foobar");

    // Round-trip
    immutable ubyte[] data = [0x00, 0xFF, 0x7F, 0x80, 0x01, 0xFE];
    assert(base32Decode(base32Encode(data)) == data);
    assert(base32Decode(base32Encode(data, false)) == data);

    // Empty input
    assert(base32Encode(null) == "");
    assert(base32Decode("") == null);

    // RFC 4648 §7 Extended Hex test vectors
    assert(base32hEncode(cast(const(ubyte)[])"") == "");
    assert(base32hEncode(cast(const(ubyte)[])"f") == "CO======");
    assert(base32hEncode(cast(const(ubyte)[])"fo") == "CPNG====");
    assert(base32hEncode(cast(const(ubyte)[])"foo") == "CPNMU===");
    assert(base32hEncode(cast(const(ubyte)[])"foob") == "CPNMUOG=");
    assert(base32hEncode(cast(const(ubyte)[])"fooba") == "CPNMUOJ1");
    assert(base32hEncode(cast(const(ubyte)[])"foobar") == "CPNMUOJ1E8======");

    // Lowercase base32h
    assert(base32hEncode(cast(const(ubyte)[])"foobar", false) == "cpnmuoj1e8======");

    // Decode base32h
    assert(base32hDecode("CO======") == cast(ubyte[])"f");
    assert(base32hDecode("CPNG====") == cast(ubyte[])"fo");
    assert(base32hDecode("CPNMU===") == cast(ubyte[])"foo");
    assert(base32hDecode("CPNMUOG=") == cast(ubyte[])"foob");
    assert(base32hDecode("CPNMUOJ1") == cast(ubyte[])"fooba");
    assert(base32hDecode("CPNMUOJ1E8======") == cast(ubyte[])"foobar");

    // Lowercase decode base32h
    assert(base32hDecode("cpnmuoj1e8======") == cast(ubyte[])"foobar");

    // Round-trip base32h
    assert(base32hDecode(base32hEncode(data)) == data);
    assert(base32hDecode(base32hEncode(data, false)) == data);

    // Z-Base32 test vectors
    assert(base32zEncode(cast(const(ubyte)[])"f") == "ca");
    assert(base32zEncode(cast(const(ubyte)[])"foo") == "c3zs6");
    assert(base32zEncode(cast(const(ubyte)[])"foobar") == "c3zs6aubqe");

    // Decode Z-Base32
    assert(base32zDecode("ca") == cast(ubyte[])"f");
    assert(base32zDecode("c3zs6") == cast(ubyte[])"foo");
    assert(base32zDecode("c3zs6aubqe") == cast(ubyte[])"foobar");

    // Z-Base32 strips padding if present
    assert(base32zDecode("ca======") == cast(ubyte[])"f");

    // Round-trip Z-Base32
    assert(base32zDecode(base32zEncode(data)) == data);
}
