/// Command-line interface and application.
///
/// Authors: dd86k <dd@dax.moe>
/// Copyright: dd86k <dd@dax.moe>
/// License: BSD-3-Clause-Clear
module binco;

import std.stdio;
import std.getopt;
import core.stdc.stdlib : exit;
import std.base64;
/*static import std.file;
import std.algorithm : chunkBy;
import std.string : lineSplitter;

alias readAll = std.file.read;
alias readAllText = std.file.readText;
alias writeAll = std.file.write;*/

enum Version   = "0.0.1";
enum Desc      = "binco "~Version~" (built: "~__TIMESTAMP__~")";
enum Copyright = "Copyright (c) 2023 dd86k <dd@dax.moe>";

enum Base
{
    none,
    //base16,
    //base32,
    //base32z,
    //base36,
    //base58,
    base64,
    //base64url,
    //ascii85
    //base91
    //bson
}

__gshared int setting_columns = 76;  /// Columns before newline

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
    Base encodeBase, decodeBase;
    
    try
    {
        bool noarg = args.length == 1;
        
        GetoptResult res = getopt(args, config.caseSensitive,
            "tmp000",   "", {
                writeln(page_secret);
                exit(0);
            },
            "cols",     "Line length when encoding", &setting_columns,
            "e|encode", "Select encoding mode and format", &encodeBase,
            "d|decode", "Select decoding mode and format", &decodeBase,
            "i|input",  "File input (default: stdin)", &pathIn,
            "o|output", "File output (default: stdout)", &pathOut,
            "list",     "List available formats", {
                writeln("Formats available:");
                foreach (member; EnumMembers!Base[1..$])
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
        
        if (res.helpWanted || noarg)
        {
            writeln(
            "Binary-Text Encoder/Decoder\n"~
            "\n"~
            "OPTIONS"
            );
            res.options[$-1].help = "Show this help page and quit.";
            foreach (Option opt; res.options[1..$])
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
    }
    catch (Exception ex)
    {
        abort(1, ex);
    }
    
    if (encodeBase == Base.none && decodeBase == Base.none)
    {
        abort(2, "Encoding or decoding base not selected");
    }
    
    bool toencode = encodeBase != Base.none;
    bool todecode = decodeBase != Base.none;
    
    if (toencode && todecode)
    {
        abort(3, "Cannot encode and decode at the same time");
    }
    
    setting_columns = cast(int)(setting_columns / 1.33333f);
    
    File fileIn  = pathIn  ? fileOpen(pathIn,  "rb") : stdin;
    File fileOut = pathOut ? fileOpen(pathOut, "wb") : stdout;
    
    try
    {
        if (toencode)
        {
            foreach (encoded; Base64.encoder(fileIn.byChunk(setting_columns)))
            {
                fileOut.write(encoded);
                //fileOut.write("\r\n");
                fileOut.write('\n');
            }
        }
        else
        {
            foreach (decoded; Base64.decoder(fileIn.byLine()))
            {
                fileOut.rawWrite(decoded);
            }
        }
    }
    catch (Exception ex)
    {
        abort(6, ex);
    }
}
