/// Command-line interface and application.
///
/// Authors: dd86k <dd@dax.moe>
/// Copyright: dd86k <dd@dax.moe>
/// License: BSD-3-Clause-Clear
module main;

import binco.encoding.base16;
import core.stdc.stdlib : exit;
import std.base64;
import std.getopt;
import std.stdio;
import std.traits : EnumMembers;

// Possible future encodings:
//base32        // RFC 4648 Base32 §6 alphabet
//base32h       // RFC 4648 Base32 §7 "extended hex" alphabet
//base32z       // Z-Base32
//base36
//base58
//ascii85
//base91
//base1024      // https://github.com/shea256/emojicoding
//uuencoding
//xxencoding
//array_c (output only)
//array_csharp (output only)
//array_d (output only)
//intelhex
enum EncodingType
{
    array_c,
    array_csharp,
    array_d,
    base16,
    base64,         // Base64
    base64u,        // Base64 URL no-padding, RFC 4648 and 7515
    base64up,       // Base64 URL with padding
}
enum ENCODINGS  = EnumMembers!EncodingType.length;
enum NoEncoding = cast(EncodingType)-1;

immutable string[] descriptions = [
    "C array (encoding only)",
    "C# array (encoding only)",
    "D array (encoding only)",
    "Hexadecimal",
    "Base64",
    "Base64 URL without padding, RFC 4648 and 7515",
    "Base64 URL with padding",
];
static assert(descriptions.length == ENCODINGS, "Missing descriptions");
string description(EncodingType encoding)
{
    size_t i = cast(size_t)encoding;
    return descriptions[i];
}

enum Version   = "0.1.0";
enum Desc      = "binco "~Version~" (built: "~__TIMESTAMP__~")";
enum Copyright = "Copyright (c) 2023-2026 dd86k <dd@dax.moe>";

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
    case base16:
    case base64:
    case base64u:
    case base64up:
        return 76;
    }
}

int columnsToChunkSize(EncodingType encoding, int cols)
{
    final switch (encoding) with (EncodingType) {
    case array_c:
    case array_csharp:
    case array_d:
        return cols;
    case base16:
        return cols / 2;
    case base64:
    case base64u:
    case base64up:
        return cols / 4 * 3;
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
    final switch (encoding) with (EncodingType) {
    case array_c:
    case array_csharp:
    case array_d:
        return arrayEncode(data, uppercase);
    case base16:
        return base16Encode(data, uppercase).dup;
    case base64:
        return Base64.encode(data);
    case base64u:
        return Base64URLNoPadding.encode(data);
    case base64up:
        return Base64URL.encode(data);
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
    import std.conv : text;
    final switch (encoding) with (EncodingType) {
    case array_c:
    case array_csharp:
    case array_d:
        throw new Exception(text("Decoding not supported for ", encoding));
    case base16:
        return base16Decode(line);
    case base64:
        return Base64.decode(line);
    case base64u:
        return Base64URLNoPadding.decode(line);
    case base64up:
        return Base64URL.decode(line);
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

immutable string page_version =
    Desc~"\n"~
    Copyright~"\n"~
    "License: BSD-3-Clause-Clear <https://choosealicense.com/licenses/bsd-3-clause-clear/>\n"~
    "Homepage: <https://github.com/dd86k/binco>";

immutable string page_license = import("LICENSE");

void main(string[] args)
{
    import std.traits : EnumMembers;
    
    string pathIn, pathOut;
    EncodingType encode = NoEncoding;
    EncodingType decode = NoEncoding;
    int ocolumns;       /// Columns before newline
    bool ouppercase;
    
    bool noArgs = args.length <= 1;

    GetoptResult res = void;
    try res = getopt(args, config.caseSensitive,
        "tmp000",   "", { // until easter egg gets a better name
            writeln(page_secret);
            exit(0);
        },
        "cols",     "Line length when encoding", &ocolumns,
        "upper",    "Use uppercase hex digits (base16)", &ouppercase,
        "e|encode", "Select encoding mode and format", &encode,
        "d|decode", "Select decoding mode and format", &decode,
        "i|input",  "File input (default: stdin)", &pathIn,
        "o|output", "File output (default: stdout)", &pathOut,
        "list",     "List available formats", {
            foreach (member; EnumMembers!EncodingType)
                writeln(member, "\t: ", description(member));
            exit(0);
        },
        "version",  "Show software version page", {
            writeln(page_version);
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
        abort(2, "Encoding or decoding base not selected");

    if (ocolumns == int.init && wantEncode)
        ocolumns = suggestColumns(encode);

    File fileIn  = pathIn  ? fileOpen(pathIn,  "rb") : stdin;
    File fileOut = pathOut ? fileOpen(pathOut, "wb") : stdout;

    try
    {
        if (wantEncode && wantDecode)
        {
            // Re-encode: decode from one format, encode to another
            foreach (line; fileIn.byLine())
                fileOut.writeln(encodeData(encode, decodeData(decode, line), ouppercase));
        }
        else if (wantEncode)
        {
            switch (encode) with (EncodingType) {
            case EncodingType.array_c:
                fileOut.writeln("unsigned char data[] = {");
                break;
            case EncodingType.array_csharp:
                fileOut.writeln("static readonly byte[] data = new byte[] {");
                break;
            case EncodingType.array_d:
                fileOut.writeln("ubyte[] data = [");
                break;
            default:
            }

            foreach (chunk; fileIn.byChunk(columnsToChunkSize(encode, ocolumns)))
                fileOut.writeln(encodeData(encode, chunk, ouppercase));

            switch (encode) with (EncodingType) {
            case EncodingType.array_c:
            case EncodingType.array_csharp:
                fileOut.writeln("};");
                break;
            case EncodingType.array_d:
                fileOut.writeln("];");
                break;
            default:
            }
        }
        else
        {
            // TODO: Concern: .byLine grows a buffer until a line is met
            foreach (line; fileIn.byLine())
                fileOut.rawWrite(decodeData(decode, line));
        }
    }
    catch (Exception ex)
    {
        abort(6, ex);
    }
}
