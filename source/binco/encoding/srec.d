/// Motorola S-record encoding/decoding implementation.
///
/// S-record is a text format for representing binary data, widely used
/// for firmware/microcontroller programming. Each line is a record with
/// structure S<type>LLAAAA[AA[AA]]DD...DDCC where LL=byte count,
/// AAAA=address (16/24/32-bit), DD=data bytes, CC=checksum.
///
/// Authors: dd86k <dd@dax.moe>
/// Copyright: dd86k <dd@dax.moe>
/// License: BSD-3-Clause-Clear
module binco.encoding.srec;

private immutable char[16] hexDigitsUpper = "0123456789ABCDEF";

/// Encode a chunk of data as an S1 (16-bit address) record.
char[] srecEncode(const(ubyte)[] data, ushort address)
{
    if (data.length == 0)
        return null;
    if (data.length > 255)
        throw new Exception("S-record data too long (max 255 bytes)");

    // S1 LL AAAA DD...DD CC
    // 2 + 2 + 4 + data.length*2 + 2 = 10 + data.length*2
    char[] result = new char[10 + data.length * 2];

    result[0] = 'S';
    result[1] = '1';

    // byte count = address(2) + data + checksum(1)
    ubyte count = cast(ubyte)(data.length + 3);
    hexByte(result[2 .. 4], count);
    hexByte(result[4 .. 6], cast(ubyte)(address >> 8));
    hexByte(result[6 .. 8], cast(ubyte)(address & 0xFF));

    ubyte sum = count;
    sum += cast(ubyte)(address >> 8);
    sum += cast(ubyte)(address & 0xFF);

    foreach (i, b; data)
    {
        hexByte(result[8 + i * 2 .. 10 + i * 2], b);
        sum += b;
    }

    ubyte checksum = cast(ubyte)(~sum); // one's complement
    hexByte(result[$ - 2 .. $], checksum);

    return result;
}

/// Returns the S-record EOF record (S9 with address 0000).
string srecEof()
{
    return "S9030000FC";
}

/// Decode a single S-record line.
/// Returns data bytes for S1/S2/S3 (data) records, null for other types.
ubyte[] srecDecode(const(char)[] line)
{
    if (line.length == 0)
        return null;
    if (line[0] != 'S')
        throw new Exception("S-record must start with 'S'");
    if (line.length < 10)
        throw new Exception("S-record too short");
    if (line.length % 2 != 0)
        throw new Exception("S-record has odd hex length");

    char type = line[1];

    ubyte count = parseHexByte(line[2 .. 4]);

    // Expected total line length: 'S' + type + count*2 + 2 (for count field itself)
    size_t expectedLen = 4 + count * 2;
    if (line.length != expectedLen)
        throw new Exception("S-record length mismatch");

    // Validate checksum: one's complement of sum of all bytes after 'S<type>'
    ubyte sum;
    for (size_t i = 2; i + 1 < line.length; i += 2)
        sum += parseHexByte(line[i .. i + 2]);
    if (sum != 0xFF)
        throw new Exception("S-record checksum error");

    // Determine address size by record type
    int addrBytes;
    switch (type)
    {
    case '0':           // header
    case '5':           // record count
    case '9':           // end (16-bit)
        return null;
    case '7':           // end (32-bit)
    case '8':           // end (24-bit)
        return null;
    case '1':
        addrBytes = 2;
        break;
    case '2':
        addrBytes = 3;
        break;
    case '3':
        addrBytes = 4;
        break;
    default:
        throw new Exception("Unknown S-record type: S" ~ type);
    }

    // data bytes = count - address_bytes - checksum(1)
    int dataLen = count - addrBytes - 1;
    if (dataLen < 0)
        throw new Exception("S-record byte count too small for address size");

    size_t dataStart = 4 + addrBytes * 2;
    ubyte[] data = new ubyte[dataLen];
    foreach (i; 0 .. dataLen)
        data[i] = parseHexByte(line[dataStart + i * 2 .. dataStart + i * 2 + 2]);
    return data;
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
        auto encoded = srecEncode(cast(const(ubyte)[])"Hello", 0);
        // count = 5+3 = 08, addr = 0000, data = 48656C6C6F
        // sum = 08+00+00+48+65+6C+6C+6F = 1FC -> FC, checksum = ~FC = 03
        assert(encoded == "S108000048656C6C6F03", "Got: " ~ encoded);
    }

    // Single byte at address 0
    {
        auto encoded = srecEncode([cast(ubyte) 0xFF], 0);
        // count = 1+3 = 04, addr = 0000, data = FF
        // sum = 04+00+00+FF = 103 -> 03, checksum = ~03 = FC
        assert(encoded == "S1040000FFFC", "Got: " ~ encoded);
    }

    // Data at non-zero address
    {
        auto encoded = srecEncode([cast(ubyte) 0xAB], 0x1234);
        // count = 04, addr = 1234, data = AB
        // sum = 04+12+34+AB = F5, checksum = ~F5 = 0A
        assert(encoded == "S1041234AB0A", "Got: " ~ encoded);
    }

    // Empty input
    assert(srecEncode(null, 0) is null);

    // --- EOF record ---
    assert(srecEof() == "S9030000FC");

    // --- Decode tests ---

    // Decode "Hello"
    {
        auto decoded = srecDecode("S108000048656C6C6F03");
        assert(decoded == cast(ubyte[])"Hello");
    }

    // Decode single byte
    {
        auto decoded = srecDecode("S1040000FFFC");
        assert(decoded == [cast(ubyte) 0xFF]);
    }

    // Decode EOF record returns null (non-data)
    assert(srecDecode("S9030000FC") is null);

    // Decode S0 header returns null
    assert(srecDecode("S0030000FC") is null);

    // --- S2 (24-bit address) decode ---
    {
        // S2, count=06 (3 addr + 2 data + 1 checksum), addr=123456, data=AABB
        // sum = 06+12+34+56+AA+BB = 207 -> 07, checksum = ~07 = F8
        auto decoded = srecDecode("S206123456AABBF8");
        assert(decoded == [cast(ubyte) 0xAA, cast(ubyte) 0xBB], "S2 decode failed");
    }

    // --- S3 (32-bit address) decode ---
    {
        // S3, count=07 (4 addr + 2 data + 1 checksum), addr=12345678, data=AABB
        // sum = 07+12+34+56+78+AA+BB = 280 -> 80, checksum = ~80 = 7F
        auto decoded = srecDecode("S30712345678AABB7F");
        assert(decoded == [cast(ubyte) 0xAA, cast(ubyte) 0xBB], "S3 decode failed");
    }

    // --- Round-trip tests ---

    // Round-trip: text data
    {
        auto data = cast(const(ubyte)[])"Hello, World!";
        auto encoded = srecEncode(data, 0);
        auto decoded = srecDecode(encoded);
        assert(decoded == data);
    }

    // Round-trip: binary data with edge values
    {
        immutable ubyte[] data = [0x00, 0xFF, 0x7F, 0x80, 0x01, 0xFE];
        auto encoded = srecEncode(data, 0);
        auto decoded = srecDecode(encoded);
        assert(decoded == data);
    }

    // Round-trip: 16 bytes (typical full record)
    {
        ubyte[16] data;
        foreach (i, ref b; data)
            b = cast(ubyte)(i * 17 + 5);
        auto encoded = srecEncode(data[], 0x0100);
        auto decoded = srecDecode(encoded);
        assert(decoded == data[]);
    }

    //
    // Error cases
    //

    // Missing S prefix
    {
        try
        {
            srecDecode("108000048656C6C6F03");
            assert(false);
        }
        catch (Exception) {}
    }

    // Bad checksum
    {
        try
        {
            srecDecode("S108000048656C6C6FFF");
            assert(false);
        }
        catch (Exception) {}
    }

    // Too short
    {
        try
        {
            srecDecode("S104");
            assert(false);
        }
        catch (Exception) {}
    }

    // Empty line returns null
    assert(srecDecode("") is null);

    // Lowercase hex decode
    {
        auto decoded = srecDecode("S108000048656c6c6f03");
        assert(decoded == cast(ubyte[])"Hello");
    }
}
