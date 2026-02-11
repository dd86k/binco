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

// Possible future encodings:
//base32        // RFC 4648 Base32 §6 alphabet
//base32h       // RFC 4648 Base32 §7 "extended hex" alphabet
//base32z       // Z-Base32
//base36
//base58
//base91
//base1024      // https://github.com/shea256/emojicoding
enum EncodingType
{
    array_c,
    array_csharp,
    array_d,
    ascii85,
    base16,
    base64,         // Base64
    base64u,        // Base64 URL no-padding, RFC 4648 and 7515
    base64up,       // Base64 URL with padding
    base91,
    intelhex,
    srecord,
    uuencode,
    xxencode,
}
enum ENCODINGS  = EnumMembers!EncodingType.length;
enum NoEncoding = cast(EncodingType)-1;

immutable string[] descriptions = [
    "C array (encoding only)",
    "C# array (encoding only)",
    "D array (encoding only)",
    "Ascii85 (Base85)",
    "Hexadecimal",
    "Base64",
    "Base64 URL without padding, RFC 4648 and 7515",
    "Base64 URL with padding",
    "basE91",
    "Intel HEX",
    "Motorola S-record",
    "UUEncoding",
    "XXEncoding",
];
static assert(descriptions.length == ENCODINGS, "Missing descriptions");
string description(EncodingType encoding)
{
    size_t i = cast(size_t)encoding;
    return descriptions[i];
}

EncodingType selectEncoding(string name)
{
    switch (name) {
    case "array_c":
        return EncodingType.array_c;
    case "array_csharp":
        return EncodingType.array_csharp;
    case "array_d":
        return EncodingType.array_d;
    case "ascii85":
        return EncodingType.ascii85;
    case "base16":
        return EncodingType.base16;
    case "base64":
        return EncodingType.base64;
    case "base64u":
        return EncodingType.base64u;
    case "base64up":
        return EncodingType.base64up;
    case "base91":
        return EncodingType.base91;
    case "intelhex":
    case "ihex":
        return EncodingType.intelhex;
    case "srecord":
    case "srec":
        return EncodingType.srecord;
    case "uuencode":
        return EncodingType.uuencode;
    case "xxencode":
        return EncodingType.xxencode;
    default:
        throw new Exception(text("Unknown encoding: ", name));
    }
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
        return 12;
    case ascii85:
    case base16:
    case base64:
    case base64u:
    case base64up:
    case base91:
        return 76;
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
        return cols;
    case ascii85:
        return cols / 5 * 4;
    case base16:
        return cols / 2;
    case base64:
    case base64u:
    case base64up:
        return cols / 4 * 3;
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

File fileOpen(string path, string mode)
{
    File file;
    
    try
    {
        file.open(path, mode);
    }
    catch (Exception ex)
    {
        abort(5, ex);
    }
    
    return file;
}

char[] encodeData(EncodingType encoding, const(ubyte)[] data, bool uppercase)
{
    // TODO: Concern: .dup doesn't re-use gc buffer but creates a new one every time
    final switch (encoding) with (EncodingType) {
    case array_c:
    case array_csharp:
    case array_d:
        return arrayEncode(data, uppercase);
    case ascii85:
        return ascii85Encode(data).dup;
    case base16:
        return base16Encode(data, uppercase).dup;
    case base64:
        return Base64.encode(data);
    case base64u:
        return Base64URLNoPadding.encode(data);
    case base64up:
        return Base64URL.encode(data);
    case base91:
        return base91Encode(data).dup;
    case intelhex:
        return intelHexEncode(data, 0).dup;
    case srecord:
        return srecEncode(data, 0).dup;
    case uuencode:
        return uuEncode(data).dup;
    case xxencode:
        return uuEncode(data, true).dup;
    }
}

char[] arrayEncode(const(ubyte)[] data, bool uppercase)
{
    import std.format : formattedWrite;
    import std.array : Appender, appender;

    Appender!(char[]) buf = appender!(char[]);
    buf.put("    ");
    string fmt = uppercase ? "0x%02X" : "0x%02x";
    foreach (i, b; data)
    {
        if (i) buf.put(", ");
        buf.formattedWrite(fmt, b);
    }
    return buf[];
}

ubyte[] decodeData(EncodingType encoding, const(char)[] line)
{
    final switch (encoding) with (EncodingType) {
    case array_c:
    case array_csharp:
    case array_d:
        throw new Exception(text("Decoding not supported for ", encoding));
    case ascii85:
        return ascii85Decode(line);
    case base16:
        return base16Decode(line);
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
    case EncodingType.ascii85:
        file.writeln("<~");
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
        file.writeln("};");
        break;
    case EncodingType.array_d:
        file.writeln("];");
        break;
    case EncodingType.ascii85:
        file.writeln("~>");
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
    enum PADDING = -12;
    writefln("%*s%s", PADDING, field, value);
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

    // TODO: EncodingType selectEncoding(string) for aliases
    GetoptResult res = void;
    try res = getopt(args, config.caseSensitive,
        "tmp000",   "", { // until easter egg gets a better name
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
            foreach (member; EnumMembers!EncodingType)
                writeln(member, "\t: ", description(member));
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
        abort(1, ex);
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

    File fileIn  = pathIn  ? fileOpen(pathIn,  "rb") : stdin;
    File fileOut = pathOut ? fileOpen(pathOut, "wb") : stdout;

    try
    {
        if (wantEncode && onoprefix == false)
            encodingPrefix(encode, fileOut);
        
        if (wantEncode && wantDecode) // re-encode
        {
            // Re-encode loop with address tracking for Intel HEX / S-record
            ushort ihexAddr;
            foreach (line; fileIn.byLine())
            {
                ubyte[] decoded = decodeData(decode, line);
                // Intel HEX / S-record lines can be non-data types
                // In that case, disregard line (silently)
                if (decoded is null)
                    continue;
                if (encode == EncodingType.intelhex)
                {
                    fileOut.writeln(intelHexEncode(decoded, ihexAddr));
                    ihexAddr += cast(ushort) decoded.length;
                }
                else if (encode == EncodingType.srecord)
                {
                    fileOut.writeln(srecEncode(decoded, ihexAddr));
                    ihexAddr += cast(ushort) decoded.length;
                }
                else
                    fileOut.writeln(encodeData(encode, decoded, ouppercase));
            }
        }
        else if (wantEncode)
        {
            switch (encode) with (EncodingType) {
            case intelhex:
                ushort addr;
                foreach (chunk; fileIn.byChunk(columnsToChunkSize(encode, ocolumns)))
                {
                    fileOut.writeln(intelHexEncode(chunk, addr));
                    addr += cast(ushort) chunk.length;
                }
                break;
            case srecord:
                ushort saddr;
                foreach (chunk; fileIn.byChunk(columnsToChunkSize(encode, ocolumns)))
                {
                    fileOut.writeln(srecEncode(chunk, saddr));
                    saddr += cast(ushort) chunk.length;
                }
                break;
            default:
                foreach (chunk; fileIn.byChunk(columnsToChunkSize(encode, ocolumns)))
                    fileOut.writeln(encodeData(encode, chunk, ouppercase));
            }
        }
        else
        {
            bool isUUXX = (decode == EncodingType.uuencode || decode == EncodingType.xxencode);
            bool isIntelHex = (decode == EncodingType.intelhex);
            bool isSrec = (decode == EncodingType.srecord);
            bool isAscii85 = (decode == EncodingType.ascii85);
            // TODO: Concern: .byLine grows a buffer until a line is met
            foreach (line; fileIn.byLine())
            {
                if (isUUXX)
                {
                    import std.algorithm : startsWith;
                    if (line.startsWith("begin ") || line == "end" || line == "`")
                        continue;
                }
                
                if (isIntelHex)
                {
                    ubyte[] data = intelHexDecode(line);
                    if (data is null)
                        continue;
                    fileOut.rawWrite(data);
                }
                else if (isSrec)
                {
                    ubyte[] data = srecDecode(line);
                    if (data is null)
                        continue;
                    fileOut.rawWrite(data);
                }
                else if (isAscii85)
                {
                    ubyte[] data = ascii85Decode(line);
                    if (data is null)
                        continue;
                    fileOut.rawWrite(data);
                }
                else
                    fileOut.rawWrite(decodeData(decode, line));
            }
        }
        
        if (wantEncode && onosuffix == false)
            encodingSuffix(encode, fileOut);
    }
    catch (Exception ex)
    {
        abort(2, ex);
    }
}
