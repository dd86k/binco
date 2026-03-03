/// Intel HEX encoding/decoding implementation.
///
/// Intel HEX is a text format for representing binary data, widely used
/// for firmware/microcontroller programming. Each line is a record with
/// structure :LLAAAATT[DD...]CC where LL=byte count, AAAA=16-bit address,
/// TT=record type (00=data, 01=EOF), DD=data bytes, CC=checksum.
///
/// Authors: dd86k <dd@dax.moe>
/// Copyright: dd86k <dd@dax.moe>
/// License: BSD-3-Clause-Clear
module binco.encoding.intelhex;

private immutable char[16] hexDigitsUpper = "0123456789ABCDEF";

/// Encode a chunk of data as an Intel HEX type 00 (data) record.
/// Buffer overload: encode into caller-provided buffer, return filled slice.
char[] intelHexEncode(const(ubyte)[] data, ushort address, char[] buf)
{
    if (data.length == 0)
        return null;
    if (data.length > 255)
        throw new Exception("Intel HEX record data too long (max 255 bytes)");

    ubyte count = cast(ubyte) data.length;
    size_t len = 11 + data.length * 2;

    buf[0] = ':';
    hexByte(buf[1 .. 3], count);
    hexByte(buf[3 .. 5], cast(ubyte)(address >> 8));
    hexByte(buf[5 .. 7], cast(ubyte)(address & 0xFF));
    hexByte(buf[7 .. 9], 0x00); // type 00 = data

    ubyte checksum = count;
    checksum += cast(ubyte)(address >> 8);
    checksum += cast(ubyte)(address & 0xFF);
    // type 00 adds 0

    foreach (i, b; data)
    {
        hexByte(buf[9 + i * 2 .. 11 + i * 2], b);
        checksum += b;
    }

    checksum = cast(ubyte)(~checksum + 1); // two's complement
    hexByte(buf[len - 2 .. len], checksum);

    return buf[0 .. len];
}

/// Convenience: allocates buffer internally.
char[] intelHexEncode(const(ubyte)[] data, ushort address)
{
    if (data.length == 0)
        return null;

    return intelHexEncode(data, address, new char[11 + data.length * 2]);
}

/// Returns the Intel HEX EOF record.
string intelHexEof()
{
    return ":00000001FF";
}

/// Decode a single Intel HEX record line.
/// Buffer overload: decode into caller-provided buffer, return filled slice.
/// Returns data bytes for type 00 records, null for other record types.
ubyte[] intelHexDecode(const(char)[] line, ubyte[] buf)
{
    if (line.length == 0)
        return null;
    if (line[0] != ':')
        throw new Exception("Intel HEX record must start with ':'");
    if (line.length < 11)
        throw new Exception("Intel HEX record too short");
    if ((line.length - 1) % 2 != 0) // @suppress(dscanner.suspicious.length_subtraction)
        throw new Exception("Intel HEX record has odd hex length");

    ubyte count = parseHexByte(line[1 .. 3]);
    ubyte type  = parseHexByte(line[7 .. 9]); // hi:3..5, lo:5..7

    size_t expectedLen = 11 + count * 2;
    if (line.length != expectedLen)
        throw new Exception("Intel HEX record length mismatch");

    // Validate checksum: sum of all bytes (count, addr, type, data, checksum) == 0
    ubyte sum;
    for (size_t i = 1; i + 1 < line.length; i += 2)
        sum += parseHexByte(line[i .. i + 2]);
    if (sum)
        throw new Exception("Intel HEX checksum error");

    // Only return data for type 00 (data) records
    if (type != 0x00)
        return null;

    foreach (i; 0 .. count)
        buf[i] = parseHexByte(line[9 + i * 2 .. 11 + i * 2]);
    return buf[0 .. count];
}

/// Convenience: allocates buffer internally.
ubyte[] intelHexDecode(const(char)[] line)
{
    size_t bufLen = line.length > 11 ? (line.length - 11) / 2 : 0;
    return intelHexDecode(line, new ubyte[bufLen]);
}

private void hexByte(char[] dst, ubyte b)
{
    dst[0] = hexDigitsUpper[b >> 4];
    dst[1] = hexDigitsUpper[b & 0x0F];
}

private ubyte parseHexByte(const(char)[] s)
{
    return cast(ubyte)((hexVal(s[0]) << 4) | hexVal(s[1]));
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
    // --- Encode tests ---

    // Known test vector: "Hello" at address 0
    {
        auto encoded = intelHexEncode(cast(const(ubyte)[])"Hello", 0);
        assert(encoded == ":0500000048656C6C6F07", "Got: " ~ encoded);
    }

    // Single byte at address 0
    {
        auto encoded = intelHexEncode([cast(ubyte) 0xFF], 0);
        assert(encoded == ":01000000FF00");
    }

    // Data at non-zero address
    {
        auto encoded = intelHexEncode([cast(ubyte) 0xAB], 0x1234);
        // count=01, addr=1234, type=00, data=AB
        // checksum = ~(01+12+34+00+AB)+1 = ~F2+1 = 0E
        assert(encoded == ":01123400AB0E", "Got: " ~ encoded);
    }

    // Empty input
    assert(intelHexEncode(null, 0) is null);

    // --- EOF record ---
    assert(intelHexEof() == ":00000001FF");

    // --- Decode tests ---

    // Decode "Hello"
    {
        auto decoded = intelHexDecode(":0500000048656C6C6F07");
        assert(decoded == cast(ubyte[])"Hello");
    }

    // Decode single byte
    {
        auto decoded = intelHexDecode(":01000000FF00");
        assert(decoded == [cast(ubyte) 0xFF]);
    }

    // Decode EOF record returns null (non-data)
    assert(intelHexDecode(":00000001FF") is null);

    // --- Round-trip tests ---

    // Round-trip: text data
    {
        auto data = cast(const(ubyte)[])"Hello, World!";
        auto encoded = intelHexEncode(data, 0);
        auto decoded = intelHexDecode(encoded);
        assert(decoded == data);
    }

    // Round-trip: binary data with edge values
    {
        immutable ubyte[] data = [0x00, 0xFF, 0x7F, 0x80, 0x01, 0xFE];
        auto encoded = intelHexEncode(data, 0);
        auto decoded = intelHexDecode(encoded);
        assert(decoded == data);
    }

    // Round-trip: 16 bytes (typical full record)
    {
        ubyte[16] data;
        foreach (i, ref b; data)
            b = cast(ubyte)(i * 17 + 5);
        auto encoded = intelHexEncode(data[], 0x0100);
        auto decoded = intelHexDecode(encoded);
        assert(decoded == data[]);
    }

    //
    // Error cases
    //

    // Missing colon
    {
        try
        {
            intelHexDecode("0500000048656C6C6F3C");
            assert(false);
        }
        catch (Exception) {}
    }

    // Bad checksum
    {
        try
        {
            intelHexDecode(":0500000048656C6C6FFF");
            assert(false);
        }
        catch (Exception) {}
    }

    // Too short
    {
        try
        {
            intelHexDecode(":0100");
            assert(false);
        }
        catch (Exception) {}
    }

    // Empty line returns null
    assert(intelHexDecode("") is null);

    // Lowercase hex decode
    {
        auto decoded = intelHexDecode(":0500000048656c6c6f07");
        assert(decoded == cast(ubyte[])"Hello");
    }
}
