/// Command-line interface and application.
///
/// Authors: dd86k <dd@dax.moe>
/// Copyright: dd86k <dd@dax.moe>
/// License: BSD-3-Clause-Clear
module main;

import binco.encoding;
import core.stdc.stdlib : exit;
import std.base64;
import std.conv : text;
import std.getopt;
import std.stdio;
import std.traits : EnumMembers;

private:

enum Version   = "0.3.1";
enum Copyright = "Copyright (c) 2023-2026 dd86k <dd@dax.moe>";

// Possible future encodings:
//base1024      // https://github.com/shea256/emojicoding
//base2048      // https://github.com/qntm/base2048
//base32768     // https://github.com/qntm/base32768
//base65536     // https://github.com/qntm/base65536
enum EncodingType
{
    array_c,
    array_csharp,
    array_d,
    array_go,
    array_java,
    array_python,
    array_rust,
    ascii85,
    base2,
    base16,
    base32,
    base32h,
    base32z,
    base36,
    base58,
    base64,         // Base64
    base64u,        // Base64 URL no-padding, RFC 4648 and 7515
    base64up,       // Base64 URL with padding
    base91,
    intelhex,
    srecord,
    uuencode,
    xxencode,
    z85,
}
enum ENCODINGS  = EnumMembers!EncodingType.length;
enum NoEncoding = cast(EncodingType)-1;

struct Selection { EncodingType encoding; string[] names; string description; }
immutable Selection[ENCODINGS] selection = [
    {
        EncodingType.array_c,
        [ EncodingType.array_c.stringof ],
        "C array (encoding only)"
    },
    {
        EncodingType.array_csharp,
        [ EncodingType.array_csharp.stringof ],
        "C# array (encoding only)"
    },
    {
        EncodingType.array_d,
        [ EncodingType.array_d.stringof ],
        "D array (encoding only)"
    },
    {
        EncodingType.array_go,
        [ EncodingType.array_go.stringof ],
        "Go array (encoding only)"
    },
    {
        EncodingType.array_java,
        [ EncodingType.array_java.stringof ],
        "Java array (encoding only)"
    },
    {
        EncodingType.array_python,
        [ EncodingType.array_python.stringof ],
        "Python array (encoding only)"
    },
    {
        EncodingType.array_rust,
        [ EncodingType.array_rust.stringof ],
        "Rust array (encoding only)"
    },
    {
        EncodingType.ascii85,
        [ EncodingType.ascii85.stringof ],
        "Ascii85 (Base85)"
    },
    {
        EncodingType.base2,
        // NOTE: "binary" might be confused as raw input/output
        [ EncodingType.base2.stringof ],
        "Binary (Base2)"
    },
    {
        EncodingType.base16,
        [ EncodingType.base16.stringof ],
        "Hexadecimal (Base16)"
    },
    {
        EncodingType.base32,
        [ EncodingType.base32.stringof ],
        "Base32 (RFC 4648)"
    },
    {
        EncodingType.base32h,
        [ EncodingType.base32h.stringof ],
        "Base32 Extended Hex (RFC 4648)"
    },
    {
        EncodingType.base32z,
        [ EncodingType.base32z.stringof, "zbase32" ],
        "Z-Base32"
    },
    {
        EncodingType.base36,
        [ EncodingType.base36.stringof ],
        "Base36"
    },
    {
        EncodingType.base58,
        [ EncodingType.base58.stringof ],
        "Base58 (Bitcoin alphabet)"
    },
    {
        EncodingType.base64,
        [ EncodingType.base64.stringof ],
        "Base64"
    },
    {
        EncodingType.base64u,
        [ EncodingType.base64u.stringof ],
        "Base64 URL without padding, RFC 4648 and 7515"
    },
    {
        EncodingType.base64up,
        [ EncodingType.base64up.stringof ],
        "Base64 URL with padding"
    },
    {
        EncodingType.base91,
        [ EncodingType.base91.stringof ],
        "basE91"
    },
    {
        EncodingType.intelhex,
        [ EncodingType.intelhex.stringof, "ihex" ],
        "Intel HEX"
    },
    {
        EncodingType.srecord,
        [ EncodingType.srecord.stringof, "srec" ],
        "Motorola S-record"
    },
    {
        EncodingType.uuencode,
        [ EncodingType.uuencode.stringof ],
        "UUEncoding"
    },
    {
        EncodingType.xxencode,
        [ EncodingType.xxencode.stringof ],
        "XXEncoding"
    },
    {
        EncodingType.z85,
        [ EncodingType.z85.stringof ],
        "Z85 (ZeroMQ Base85)"
    },
];

EncodingType selectEncoding(string name)
{
    foreach (selected; selection)
    {
        foreach (ename; selected.names)
            if (ename == name)
                return selected.encoding;
    }
    throw new Exception(text("Unknown encoding: ", name));
}

noreturn abort(string func = __FUNCTION__, A...)(int code, string fmt, A args)
{
    stderr.writef("error: (code %d) ", code);
    debug stderr.write("[", func, "] ");
    stderr.writefln(fmt, args);
    exit(code);
}

noreturn abort(int code, Exception ex)
{
    stderr.writef("error: (code %d) ", code);
    debug stderr.writeln(ex);
    else stderr.writeln(ex.message);
    exit(code);
}

int suggestColumns(EncodingType encoding)
{
    final switch (encoding) with (EncodingType) {
    case array_c:
    case array_csharp:
    case array_d:
    case array_go:
    case array_java:
    case array_python:
    case array_rust:
        return 12;
    case ascii85:
    case base16:
    case base32:
    case base32h:
    case base32z:
    case base36:
    case base58:
    case base64:
    case base64u:
    case base64up:
    case base91:
    case z85:
        return 76;
    case base2:
        return 72;
    case intelhex:
    case srecord:
        return 43;
    case uuencode:
    case xxencode:
        return 61;
    }
}

int columnsToChunkSize(EncodingType encoding, int cols)
{
    final switch (encoding) with (EncodingType) {
    case array_c:
    case array_csharp:
    case array_d:
    case array_go:
    case array_java:
    case array_python:
    case array_rust:
        return cols;
    case ascii85:
    case z85:
        return cols / 5 * 4;
    case base2:
        return cols / 8;
    case base16:
        return cols / 2;
    case base32:
    case base32h:
    case base32z:
        return cols / 8 * 5;
    case base64:
    case base64u:
    case base64up:
        return cols / 4 * 3;
    case base36: // base36 expands ~1.55x
        return cols * 100 / 155;
    case base58: // base58 expands ~1.37x
        return cols * 100 / 137;
    case base91: // base91 produces ~16 chars per 13 bytes on avg
        return cols * 13 / 16;
    case intelhex:
        return (cols - 11) / 2;
    case srecord:
        return (cols - 10) / 2;
    case uuencode:
    case xxencode:
        return (cols - 1) / 4 * 3;
    }
}

size_t maxEncodedSize(EncodingType encoding, size_t chunkSize)
{
    final switch (encoding) with (EncodingType) {
    case array_c:
    case array_csharp:
    case array_d:
    case array_go:
    case array_python:
    case array_rust:
        return chunkSize * 6 + 4;
    case array_java:
        return chunkSize * 9 + 4;
    case ascii85:
    case z85:
        return (chunkSize + 3) / 4 * 5;
    case base2:
        return chunkSize * 8;
    case base16:
        return chunkSize * 2;
    case base32:
    case base32h:
    case base32z:
        return (chunkSize + 4) / 5 * 8;
    case base64:
    case base64u:
    case base64up:
        return (chunkSize + 2) / 3 * 4;
    case base36:
        return chunkSize * 155 / 100 + 2;
    case base58:
        return chunkSize * 137 / 100 + 2;
    case base91:
        return chunkSize * 16 / 13 + 2;
    case intelhex:
        return 11 + chunkSize * 2;
    case srecord:
        return 10 + chunkSize * 2;
    case uuencode:
    case xxencode:
        return 1 + (chunkSize + 2) / 3 * 4;
    }
}

/// Encode into caller-provided buffer, return filled slice.
char[] encodeData(EncodingType encoding, const(ubyte)[] data, bool uppercase, char[] buf)
{
    final switch (encoding) with (EncodingType) {
    case array_c:
    case array_csharp:
    case array_d:
    case array_go:
    case array_java:
    case array_python:
    case array_rust:
        return arrayEncode(encoding, data, uppercase);
    case ascii85:
        return ascii85Encode(data, buf);
    case z85:
        return z85Encode(data, buf);
    case base2:
        return base2Encode(data, buf);
    case base16:
        return base16Encode(data, uppercase, buf);
    case base32:
        return base32Encode(data, uppercase, buf);
    case base32h:
        return base32hEncode(data, uppercase, buf);
    case base32z:
        return base32zEncode(data, buf);
    case base36:
        return base36Encode(data, buf);
    case base58:
        return base58Encode(data, buf);
    case base64:
        return Base64.encode(data);
    case base64u:
        return Base64URLNoPadding.encode(data);
    case base64up:
        return Base64URL.encode(data);
    case base91:
        return base91Encode(data, buf);
    case intelhex:
        return intelHexEncode(data, 0, buf);
    case srecord:
        return srecEncode(data, 0, buf);
    case uuencode:
        return uuEncode(data, false, buf);
    case xxencode:
        return uuEncode(data, true, buf);
    }
}

/// Convenience: allocates internally.
char[] encodeData(EncodingType encoding, const(ubyte)[] data, bool uppercase)
{
    final switch (encoding) with (EncodingType) {
    case array_c:
    case array_csharp:
    case array_d:
    case array_go:
    case array_java:
    case array_python:
    case array_rust:
        return arrayEncode(encoding, data, uppercase);
    case ascii85:
        return ascii85Encode(data);
    case z85:
        return z85Encode(data);
    case base2:
        return base2Encode(data);
    case base16:
        return base16Encode(data, uppercase);
    case base32:
        return base32Encode(data, uppercase);
    case base32h:
        return base32hEncode(data, uppercase);
    case base32z:
        return base32zEncode(data);
    case base36:
        return base36Encode(data);
    case base58:
        return base58Encode(data);
    case base64:
        return Base64.encode(data);
    case base64u:
        return Base64URLNoPadding.encode(data);
    case base64up:
        return Base64URL.encode(data);
    case base91:
        return base91Encode(data);
    case intelhex:
        return intelHexEncode(data, 0);
    case srecord:
        return srecEncode(data, 0);
    case uuencode:
        return uuEncode(data);
    case xxencode:
        return uuEncode(data, true);
    }
}

char[] arrayEncode(EncodingType encoding, const(ubyte)[] data, bool uppercase)
{
    import std.format : formattedWrite;
    import std.array : Appender, appender;

    Appender!(char[]) buf = appender!(char[]);
    buf.put("    ");
    bool isJava = encoding == EncodingType.array_java;
    string fmt = isJava
        ? (uppercase ? "(byte)0x%02X" : "(byte)0x%02x")
        : (uppercase ? "0x%02X" : "0x%02x");
    foreach (i, b; data)
    {
        if (i) buf.put(", ");
        buf.formattedWrite(fmt, b);
    }
    return buf[];
}

/// Decode into caller-provided buffer, return filled slice.
ubyte[] decodeData(EncodingType encoding, const(char)[] line, ubyte[] buf)
{
    final switch (encoding) with (EncodingType) {
    case array_c:
    case array_csharp:
    case array_d:
    case array_go:
    case array_java:
    case array_python:
    case array_rust:
        throw new Exception(text("Decoding not supported for ", encoding));
    case ascii85:
        return ascii85Decode(line, buf);
    case z85:
        return z85Decode(line, buf);
    case base2:
        return base2Decode(line, buf);
    case base16:
        return base16Decode(line, buf);
    case base32:
        return base32Decode(line, buf);
    case base32h:
        return base32hDecode(line, buf);
    case base32z:
        return base32zDecode(line, buf);
    case base36:
        return base36Decode(line, buf);
    case base58:
        return base58Decode(line, buf);
    case base64:
        return Base64.decode(line);
    case base64u:
        return Base64URLNoPadding.decode(line);
    case base64up:
        return Base64URL.decode(line);
    case base91:
        return base91Decode(line, buf);
    case intelhex:
        return intelHexDecode(line, buf);
    case srecord:
        return srecDecode(line, buf);
    case uuencode:
        return uuDecode(line, false, buf);
    case xxencode:
        return uuDecode(line, true, buf);
    }
}

/// Convenience: allocates internally.
ubyte[] decodeData(EncodingType encoding, const(char)[] line)
{
    final switch (encoding) with (EncodingType) {
    case array_c:
    case array_csharp:
    case array_d:
    case array_go:
    case array_java:
    case array_python:
    case array_rust:
        throw new Exception(text("Decoding not supported for ", encoding));
    case ascii85:
        return ascii85Decode(line);
    case z85:
        return z85Decode(line);
    case base2:
        return base2Decode(line);
    case base16:
        return base16Decode(line);
    case base32:
        return base32Decode(line);
    case base32h:
        return base32hDecode(line);
    case base32z:
        return base32zDecode(line);
    case base36:
        return base36Decode(line);
    case base58:
        return base58Decode(line);
    case base64:
        return Base64.decode(line);
    case base64u:
        return Base64URLNoPadding.decode(line);
    case base64up:
        return Base64URL.decode(line);
    case base91:
        return base91Decode(line);
    case intelhex:
        return intelHexDecode(line);
    case srecord:
        return srecDecode(line);
    case uuencode:
        return uuDecode(line);
    case xxencode:
        return uuDecode(line, true);
    }
}

bool shouldSkipLine(EncodingType encoding, const(char)[] line)
{
    import std.algorithm : startsWith;
    switch (encoding) with (EncodingType) {
    case uuencode:
    case xxencode:
        return line.startsWith("begin ") || line == "end" || line == "`";
    case ascii85:
        return line == "<~" || line == "~>";
    default:
        return false;
    }
}

void encodingPrefix(EncodingType encoding, ref File file)
{
    switch (encoding) with (EncodingType) {
    case EncodingType.array_c:
        file.writeln("unsigned char data[] = {");
        break;
    case EncodingType.array_csharp:
        file.writeln("static readonly byte[] data = new byte[] {");
        break;
    case EncodingType.array_d:
        file.writeln("ubyte[] data = [");
        break;
    case EncodingType.array_go:
        file.writeln("var data = []byte{");
        break;
    case EncodingType.array_java:
        file.writeln("byte[] data = {");
        break;
    case EncodingType.array_python:
        file.writeln("data = bytes([");
        break;
    case EncodingType.array_rust:
        file.writeln("let data: &[u8] = &[");
        break;
    case EncodingType.ascii85:
        file.write("<~");
        break;
    case EncodingType.uuencode:
    case EncodingType.xxencode:
        file.writeln("begin 644 data");
        break;
    default:
    }
}

void encodingSuffix(EncodingType encoding, ref File file)
{
    switch (encoding) with (EncodingType) {
    case EncodingType.array_c:
    case EncodingType.array_csharp:
    case EncodingType.array_java:
        file.writeln("};");
        break;
    case EncodingType.array_d:
    case EncodingType.array_rust:
        file.writeln("];");
        break;
    case EncodingType.array_go:
        file.writeln("}");
        break;
    case EncodingType.array_python:
        file.writeln("])");
        break;
    case EncodingType.ascii85:
        file.write("~>");
        break;
    case EncodingType.intelhex:
        file.writeln(intelHexEof());
        break;
    case EncodingType.srecord:
        file.writeln(srecEof());
        break;
    case EncodingType.uuencode:
    case EncodingType.xxencode:
        file.writeln("`");
        file.writeln("end");
        break;
    default:
    }
}

immutable string page_secret = q"SECRET
The year is 2032,

    And you received your DNA results.

       +- The part that enjoys ASCII art.
       v
 oo   OO   oo   OO   oo
 ||o O||O o||o O||O o||
 |||O||||O||||O||||O|||
 ||O o||o O||O o||o O||
 OO   oo   OO   oo   OO
SECRET";

immutable string page_license = import("LICENSE");

void versionline(string field, string value)
{
    enum PADDING = -11;
    writefln("%*s %s", PADDING, field, value);
}

void main(string[] args)
{
    import std.traits : EnumMembers;
    
    string pathIn, pathOut;
    EncodingType encode = NoEncoding;
    EncodingType decode = NoEncoding;
    int ocolumns;       /// Columns before newline
    bool ouppercase;
    bool onoprefix;     /// If set, do not print prefix
    bool onosuffix;     /// If set, do not print suffix
    
    bool noArgs = args.length <= 1;
    
    GetoptResult res = void;
    try res = getopt(args, config.caseSensitive,
        "dna",      "", {
            writeln(page_secret);
            exit(0);
        },
        "cols",     "Line length when encoding", &ocolumns,
        "upper",    "Use uppercase hex digits (base16)", &ouppercase,
        "e|encode", "Select encoding mode and format", (string _, string val) {
            encode = selectEncoding(val);
        },
        "d|decode", "Select decoding mode and format", (string _, string val) {
            decode = selectEncoding(val);
        },
        "i|input",  "File input (default: stdin)", &pathIn,
        "o|output", "File output (default: stdout)", &pathOut,
        config.bundling,
        "P|no-prefix", "If set, do not print prefix", &onoprefix,
        config.bundling,
        "S|no-suffix", "If set, do not print suffix", &onosuffix,
        "list",     "List available formats", {
            foreach (selected; selection)
            {
                // print names/aliases
                enum int BASE = 20;
                int printed;
                foreach (i, ename; selected.names)
                {
                    if (i)
                    {
                        static immutable string sep = ", ";
                        write(sep);
                        printed += sep.length;
                    }
                    write(ename);
                    printed += ename.length;
                }
                
                // print spacer and description
                writefln("%*s : %s", BASE - printed, "", selected.description);
            }
            exit(0);
        },
        "version",  "Show software version page", {
            import std.format : format;
            static immutable string line_build = "Built: "~__TIMESTAMP__;
            static immutable string line_compiler = format(__VENDOR__~" v%d.%d", __VERSION__/1000, __VERSION__%1000);
            versionline("binco", Version);
            versionline("", line_build);
            versionline("", "<https://github.com/dd86k/binco>");
            versionline("License", "BSD-3-Clause-Clear");
            versionline("", Copyright);
            versionline("Compiler", line_compiler);
            exit(0);
        },
        "ver",      "Show software version", {
            writeln(Version);
            exit(0);
        },
        "license",  "Show software license", {
            writeln(page_license);
            exit(0);
        },
    );
    catch (Exception ex)
    {
        abort(1, ex.msg);
    }
    
    if (res.helpWanted || noArgs)
    {
        writeln(
        "Binary-Text Encoder/Decoder\n"~
        "\n"~
        "OPTIONS"
        );
        res.options[$-1].help = "Show this help page and quit.";
        foreach (Option opt; res.options[1..$]) // first is easter egg
        {
            with (opt)
            if (optShort)
                writefln("%s, %-12s  %s", optShort, optLong, help);
            else
                writefln("    %-12s  %s", optLong, help);
        }
        writeln("\nThis program has a DNA scanner.");
        exit(0);
    }
    
    bool wantEncode = encode != NoEncoding;
    bool wantDecode = decode != NoEncoding;
    
    if (!wantEncode && !wantDecode)
        abort(1, "Encoding or decoding base not selected");
    
    if (ocolumns == int.init && wantEncode)
        ocolumns = suggestColumns(encode);
    
    // NOTE: On Windows, opening a file in Byte Mode disables special treatment of \r
    File fileIn  = pathIn  ? File(pathIn,  wantDecode ? "r" : "rb") : stdin;
    File fileOut = pathOut ? File(pathOut, "wb") : stdout;
    
    if (wantEncode && onoprefix == false)
        encodingPrefix(encode, fileOut);
    
    if (wantEncode && wantDecode) // re-encode
    {
        // Re-encode loop with address tracking for Intel HEX / S-record
        ushort ihexAddr;
        int decChunkSize = columnsToChunkSize(decode, suggestColumns(decode));
        ubyte[] decodeBuf = new ubyte[decChunkSize];
        char[] encodeBuf = new char[maxEncodedSize(encode, decChunkSize)];
        foreach (line; fileIn.byLine())
        {
            if (shouldSkipLine(decode, line))
                continue;
            if (decodeBuf.length < line.length)
                decodeBuf = new ubyte[line.length];
            ubyte[] decoded = decodeData(decode, line, decodeBuf);
            // Intel HEX / S-record lines can be non-data types
            // In that case, disregard line (silently)
            if (decoded is null)
                continue;
            size_t needed = maxEncodedSize(encode, decoded.length);
            if (encodeBuf.length < needed)
                encodeBuf = new char[needed];
            if (encode == EncodingType.intelhex)
            {
                fileOut.writeln(intelHexEncode(decoded, ihexAddr, encodeBuf));
                ihexAddr += cast(ushort) decoded.length;
            }
            else if (encode == EncodingType.srecord)
            {
                fileOut.writeln(srecEncode(decoded, ihexAddr, encodeBuf));
                ihexAddr += cast(ushort) decoded.length;
            }
            else
                fileOut.writeln(encodeData(encode, decoded, ouppercase, encodeBuf));
        }
    }
    else if (wantEncode)
    {
        int chunkSize = columnsToChunkSize(encode, ocolumns);
        char[] encodeBuf = new char[maxEncodedSize(encode, chunkSize)];
        switch (encode) with (EncodingType) {
        case intelhex:
            ushort addr;
            foreach (chunk; fileIn.byChunk(chunkSize))
            {
                fileOut.writeln(intelHexEncode(chunk, addr, encodeBuf));
                addr += cast(ushort) chunk.length;
            }
            break;
        case srecord:
            ushort saddr;
            foreach (chunk; fileIn.byChunk(chunkSize))
            {
                fileOut.writeln(srecEncode(chunk, saddr, encodeBuf));
                saddr += cast(ushort) chunk.length;
            }
            break;
        default:
            foreach (chunk; fileIn.byChunk(chunkSize))
                fileOut.writeln(encodeData(encode, chunk, ouppercase, encodeBuf));
        }
    }
    else // decode only
    {
        ubyte[] decodeBuf = new ubyte[4096];
        foreach (line; fileIn.byLine())
        {
            if (shouldSkipLine(decode, line))
                continue;

            if (decodeBuf.length < line.length)
                decodeBuf.length = line.length;

            ubyte[] data = decodeData(decode, line, decodeBuf);
            if (data is null)
                continue;
            fileOut.rawWrite(data);
        }
    }
    
    if (wantEncode && onosuffix == false)
        encodingSuffix(encode, fileOut);
}
