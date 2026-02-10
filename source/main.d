/// Command-line interface and application.
///
/// Authors: dd86k <dd@dax.moe>
/// Copyright: dd86k <dd@dax.moe>
/// License: BSD-3-Clause-Clear
module main;

import std.stdio;
import std.getopt;
import core.stdc.stdlib : exit;
import std.base64;
import binco.encoding.base16;

// Possible future encodings:
//base32
//base32z
//base36
//base58
//ascii85
//base91
//base1024     // https://github.com/shea256/emojicoding
//uuencoding
//xxencoding
//bson
//array_c
//array_csharp
//array_d
//intelhex
enum EncodingType
{
    base16,
    base64,         // Base64
    base64u,        // Base64 URL no-padding, RFC 4648 and 7515
    base64up,       // Base64 URL with padding
}
enum NoEncoding = cast(EncodingType)-1;

enum Version   = "0.0.1";
enum Desc      = "binco "~Version~" (built: "~__TIMESTAMP__~")";
enum Copyright = "Copyright (c) 2023 dd86k <dd@dax.moe>";

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
    case base16:
        return 76 / 2;
    case base64:
    case base64u:
    case base64up:
        return 76;
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

ubyte[] decodeData(EncodingType encoding, const(char)[] line)
{
    final switch (encoding) with (EncodingType) {
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

immutable string page_license = q"LICENSE
The Clear BSD License

LICENSE"~Copyright~q"LICENSE

All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted (subject to the limitations in the disclaimer
below) provided that the following conditions are met:

     * Redistributions of source code must retain the above copyright notice,
     this list of conditions and the following disclaimer.

     * Redistributions in binary form must reproduce the above copyright
     notice, this list of conditions and the following disclaimer in the
     documentation and/or other materials provided with the distribution.

     * Neither the name of the copyright holder nor the names of its
     contributors may be used to endorse or promote products derived from this
     software without specific prior written permission.

NO EXPRESS OR IMPLIED LICENSES TO ANY PARTY'S PATENT RIGHTS ARE GRANTED BY
THIS LICENSE. THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
LICENSE";

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
                writeln(member);
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
            foreach (chunk; fileIn.byChunk(ocolumns))
                fileOut.writeln(encodeData(encode, chunk, ouppercase));
        }
        else
        {
            foreach (line; fileIn.byLine())
                fileOut.rawWrite(decodeData(decode, line));
        }
    }
    catch (Exception ex)
    {
        abort(6, ex);
    }
}
