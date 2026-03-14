/// Integration tests for the binco CLI.
///
/// These tests invoke the compiled binary via std.process and verify
/// end-to-end encoding/decoding behavior, flag handling, and error cases.
///
/// Run: dub build first, then dub test -c integration
module integration;

import std.algorithm : canFind, startsWith, endsWith;
import std.array : join;
import std.conv : text;
import std.file : exists, remove, readText, write;
import std.process : execute, pipeProcess, Redirect, wait;
import std.string : strip, splitLines, indexOf;

private:

/// Path to the binco binary.
version (Windows)
    enum string binco = "binco.exe";
else
    enum string binco = "./binco";

/// Run binco with given arguments, feeding `input` to stdin.
/// Returns tuple of (exit status, stdout+stderr output).
struct Result
{
    int status;
    string output;
}

Result run(string[] args, string input = null)
{
    string[] cmd = [binco] ~ args;
    auto pipes = pipeProcess(cmd, Redirect.stdout | Redirect.stderr | Redirect.stdin);
    if (input !is null)
    {
        pipes.stdin.write(input);
        pipes.stdin.flush();
        pipes.stdin.close();
    }
    else
    {
        pipes.stdin.close();
    }
    int status = wait(pipes.pid);
    string stdout = pipes.stdout.readAll();
    string stderr = pipes.stderr.readAll();
    return Result(status, stdout ~ stderr);
}

string readAll(P)(P pipe)
{
    string result;
    foreach (line; pipe.byLine())
    {
        if (result.length > 0)
            result ~= "\n";
        result ~= line;
    }
    return result;
}

void assertEqual(string actual, string expected, string msg = "")
{
    if (actual != expected)
    {
        string detail = text("Expected: [", expected, "]\nActual:   [", actual, "]");
        if (msg.length > 0)
            detail = msg ~ "\n" ~ detail;
        assert(false, detail);
    }
}

// ---------------------------------------------------------------------------
// Roundtrip tests: encode then decode, verify original data is recovered.
// ---------------------------------------------------------------------------

/// Encodings that support both encode and decode.
immutable string[][] roundtripEncodings = [
    ["ascii85"],
    ["base2"],
    ["base16"],
    ["base32"],
    ["base32h"],
    ["base32z"],
    ["base36"],
    ["base58"],
    ["base64"],
    ["base64u"],
    ["base64up"],
    ["base91"],
    ["z85"],
];

unittest
{
    foreach (enc; roundtripEncodings)
    {
        string name = enc[0];
        // Encode
        Result encoded = run(["-e", name], "Hello, World!");
        assert(encoded.status == 0, text(name, " encode failed: ", encoded.output));
        string encodedText = encoded.output.strip();
        assert(encodedText.length > 0, text(name, " encode produced empty output"));

        // Decode
        Result decoded = run(["-d", name], encodedText ~ "\n");
        assert(decoded.status == 0, text(name, " decode failed: ", decoded.output));
        assertEqual(decoded.output, "Hello, World!", text(name, " roundtrip failed"));
    }
}

// ---------------------------------------------------------------------------
// Known-value encoding tests
// ---------------------------------------------------------------------------

unittest
{
    // base64
    Result r = run(["-e", "base64"], "Hello");
    assertEqual(r.output.strip(), "SGVsbG8=", "base64 encode");

    // base16 lowercase (default)
    r = run(["-e", "base16"], "Hi");
    assertEqual(r.output.strip(), "4869", "base16 encode lowercase");

    // base16 uppercase
    r = run(["-e", "base16", "--upper"], "Hi");
    assertEqual(r.output.strip(), "4869".toUpper(), "base16 encode uppercase");

    // base64url no-padding
    r = run(["-e", "base64u"], "Hello");
    assertEqual(r.output.strip(), "SGVsbG8", "base64u encode");

    // base64url with padding
    r = run(["-e", "base64up"], "Hello");
    assertEqual(r.output.strip(), "SGVsbG8=", "base64up encode");
}

string toUpper(string s)
{
    char[] result = new char[s.length];
    foreach (i, char c; s)
    {
        if (c >= 'a' && c <= 'f')
            result[i] = cast(char)(c - 32);
        else
            result[i] = c;
    }
    return cast(string) result;
}

// ---------------------------------------------------------------------------
// Prefix/suffix tests
// ---------------------------------------------------------------------------

unittest
{
    // ascii85 has <~ prefix and ~> suffix
    Result r = run(["-e", "ascii85"], "Test");
    string[] lines = r.output.strip().splitLines();
    assert(lines.length >= 3, "ascii85 should have prefix and suffix lines");
    assertEqual(lines[0], "<~", "ascii85 prefix");
    assertEqual(lines[$ - 1], "~>", "ascii85 suffix");

    // -P suppresses prefix
    r = run(["-e", "ascii85", "-P"], "Test");
    lines = r.output.strip().splitLines();
    assert(!lines[0].canFind("<~"), "ascii85 -P should suppress prefix");

    // -S suppresses suffix
    r = run(["-e", "ascii85", "-S"], "Test");
    lines = r.output.strip().splitLines();
    assert(!lines[$ - 1].canFind("~>"), "ascii85 -S should suppress suffix");

    // -P -S suppresses both
    r = run(["-e", "ascii85", "-P", "-S"], "Test");
    lines = r.output.strip().splitLines();
    assert(lines.length == 1, "ascii85 -P -S should have only data line");
}

// ---------------------------------------------------------------------------
// UUEncode/XXEncode prefix/suffix
// ---------------------------------------------------------------------------

unittest
{
    Result r = run(["-e", "uuencode"], "Test");
    string[] lines = r.output.strip().splitLines();
    assert(lines[0].startsWith("begin "), "uuencode should start with 'begin'");
    assertEqual(lines[$ - 1], "end", "uuencode should end with 'end'");

    r = run(["-e", "xxencode"], "Test");
    lines = r.output.strip().splitLines();
    assert(lines[0].startsWith("begin "), "xxencode should start with 'begin'");
    assertEqual(lines[$ - 1], "end", "xxencode should end with 'end'");
}

// ---------------------------------------------------------------------------
// Array encoding tests (encode-only formats)
// ---------------------------------------------------------------------------

unittest
{
    // C array
    Result r = run(["-e", "array_c"], "AB");
    string output = r.output;
    assert(output.canFind("unsigned char data[]"), "C array header");
    assert(output.canFind("0x41"), "C array should contain 0x41 for 'A'");
    assert(output.canFind("};"), "C array footer");

    // D array
    r = run(["-e", "array_d"], "AB");
    output = r.output;
    assert(output.canFind("ubyte[] data"), "D array header");
    assert(output.canFind("];"), "D array footer");

    // Python array
    r = run(["-e", "array_python"], "AB");
    output = r.output;
    assert(output.canFind("data = bytes(["), "Python array header");
    assert(output.canFind("])"), "Python array footer");

    // Go array
    r = run(["-e", "array_go"], "AB");
    output = r.output;
    assert(output.canFind("var data = []byte{"), "Go array header");

    // Rust array
    r = run(["-e", "array_rust"], "AB");
    output = r.output;
    assert(output.canFind("let data: &[u8] = &["), "Rust array header");
    assert(output.canFind("];"), "Rust array footer");

    // Java array with (byte) cast
    r = run(["-e", "array_java"], "A");
    output = r.output;
    assert(output.canFind("(byte)0x41"), "Java array should cast bytes");

    // C# array
    r = run(["-e", "array_csharp"], "A");
    output = r.output;
    assert(output.canFind("static readonly byte[] data"), "C# array header");
}

// ---------------------------------------------------------------------------
// File I/O tests (-i / -o)
// ---------------------------------------------------------------------------

unittest
{
    enum string tmpIn = "/tmp/binco_test_input.bin";
    enum string tmpOut = "/tmp/binco_test_output.txt";
    enum string tmpDec = "/tmp/binco_test_decoded.bin";

    // Cleanup from prior runs
    scope(exit)
    {
        if (tmpIn.exists) remove(tmpIn);
        if (tmpOut.exists) remove(tmpOut);
        if (tmpDec.exists) remove(tmpDec);
    }

    // Write test input
    write(tmpIn, "FileIOTest");

    // Encode with file I/O
    Result r = run(["-e", "base64", "-i", tmpIn, "-o", tmpOut]);
    assert(r.status == 0, text("file encode failed: ", r.output));
    string encoded = readText(tmpOut).strip();
    assertEqual(encoded, "RmlsZUlPVGVzdA==", "file I/O base64 encode");

    // Decode with file I/O
    r = run(["-d", "base64", "-i", tmpOut, "-o", tmpDec]);
    assert(r.status == 0, text("file decode failed: ", r.output));
    string decoded = readText(tmpDec);
    assertEqual(decoded, "FileIOTest", "file I/O base64 decode");
}

// ---------------------------------------------------------------------------
// Re-encoding tests (both -e and -d)
// ---------------------------------------------------------------------------

unittest
{
    // Encode to base64, then re-encode base64 -> base16
    Result encoded = run(["-e", "base64"], "Hello");
    string b64 = encoded.output.strip();

    Result reencoded = run(["-d", "base64", "-e", "base16"], b64 ~ "\n");
    assert(reencoded.status == 0, text("re-encode failed: ", reencoded.output));
    // "Hello" in hex is 48656c6c6f
    assertEqual(reencoded.output.strip(), "48656c6c6f", "re-encode base64->base16");
}

// ---------------------------------------------------------------------------
// Intel HEX and S-Record roundtrip
// ---------------------------------------------------------------------------

unittest
{
    // Intel HEX
    Result encoded = run(["-e", "intelhex"], "Hello");
    assert(encoded.status == 0, text("intelhex encode failed: ", encoded.output));
    string[] lines = encoded.output.strip().splitLines();
    // Intel HEX lines start with ':'
    assert(lines[0].startsWith(":"), "intelhex line should start with ':'");
    // Last line should be EOF record
    assertEqual(lines[$ - 1], ":00000001FF", "intelhex EOF record");

    // Decode back
    Result decoded = run(["-d", "intelhex"], encoded.output);
    assert(decoded.status == 0, text("intelhex decode failed: ", decoded.output));
    assertEqual(decoded.output, "Hello", "intelhex roundtrip");

    // S-Record
    encoded = run(["-e", "srecord"], "Hello");
    assert(encoded.status == 0, text("srecord encode failed: ", encoded.output));
    lines = encoded.output.strip().splitLines();
    assert(lines[0].startsWith("S"), "srecord line should start with 'S'");

    decoded = run(["-d", "srecord"], encoded.output);
    assert(decoded.status == 0, text("srecord decode failed: ", decoded.output));
    assertEqual(decoded.output, "Hello", "srecord roundtrip");
}

// ---------------------------------------------------------------------------
// CLI flag tests
// ---------------------------------------------------------------------------

unittest
{
    // --list should show available formats
    Result r = run(["--list"]);
    assert(r.status == 0, "--list failed");
    assert(r.output.canFind("base64"), "--list should include base64");
    assert(r.output.canFind("ascii85"), "--list should include ascii85");
    assert(r.output.canFind("intelhex"), "--list should include intelhex");

    // --ver should show version string
    r = run(["--ver"]);
    assert(r.status == 0, "--ver failed");
    string ver = r.output.strip();
    // Version string should match X.Y.Z pattern
    assert(ver.indexOf(".") > 0, text("--ver output doesn't look like a version: ", ver));

    // -h should show help
    r = run(["-h"]);
    assert(r.status == 0, "-h failed");
    assert(r.output.canFind("OPTIONS"), "-h should show OPTIONS");
    assert(r.output.canFind("--encode"), "-h should mention --encode");
    assert(r.output.canFind("--decode"), "-h should mention --decode");
}

// ---------------------------------------------------------------------------
// Error handling tests
// ---------------------------------------------------------------------------

unittest
{
    // No arguments should show help (exit 0)
    Result r = run([]);
    assert(r.status == 0, "no args should show help");

    // Invalid encoding name
    r = run(["-e", "nonexistent"], "test");
    assert(r.status != 0, "invalid encoding should fail");

    // Neither encode nor decode selected (just flags)
    r = run(["--upper"], "test");
    assert(r.status != 0, "no encode/decode should fail");
}

// ---------------------------------------------------------------------------
// Empty input tests
// ---------------------------------------------------------------------------

unittest
{
    // Empty input should produce minimal output
    Result r = run(["-e", "base64"], "");
    assert(r.status == 0, "empty input encode should succeed");

    r = run(["-e", "base16"], "");
    assert(r.status == 0, "empty base16 encode should succeed");
}

// ---------------------------------------------------------------------------
// Encoding alias tests
// ---------------------------------------------------------------------------

unittest
{
    // ihex is alias for intelhex
    Result r1 = run(["-e", "intelhex"], "Test");
    Result r2 = run(["-e", "ihex"], "Test");
    assertEqual(r1.output, r2.output, "ihex alias should match intelhex");

    // srec is alias for srecord
    r1 = run(["-e", "srecord"], "Test");
    r2 = run(["-e", "srec"], "Test");
    assertEqual(r1.output, r2.output, "srec alias should match srecord");

    // zbase32 is alias for base32z
    r1 = run(["-e", "base32z"], "Test");
    r2 = run(["-e", "zbase32"], "Test");
    assertEqual(r1.output, r2.output, "zbase32 alias should match base32z");
}
