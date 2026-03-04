# Binco: Binary-Text Encoder-Decoder

binco is a CLI-oriented binary-text encoder and decoder.

Currently supports:
- `array_c`: C array (encoding only)
- `array_csharp`: C# array (encoding only)
- `array_d`: D array (encoding only)
- `ascii85`: Ascii85
- `base16`: Hexadecimal
- `base36`: Base36
- `base58`: Base58
- `base64`: Base64
- `base64u`: Base64 URL without padding, RFC 4648 and 7515
- `base64up`: Base64 URL with padding
- `base91`: basE91
- `intelhex`, `ihex`: Intel HEX (entry types `00` and `01` only)
- `srecord`, `srec`: Motorola S-Record
- `uuencode`: UUEncoding
- `xxencode`: XXEncoding

Why? Well, I want to stop using random websites for this sort of thing.

# Usage

An encoding (using `-e`) or decoding (`-d`) scheme needs to be specified.

By default, stdin and stdout streams are used for input and output.

To specify a file input, use `-i|--input`. For file output, use `-o|--output`.

Encode file and show result to stdout:
```text
$ binco -e base64 -i dub.sdl
bmFtZSAiYmluY28iCmRlc2NyaXB0aW9uICJCaW5hcnkgRW5jb2Rlci9EZWNvZGVyIgphdXRob3Jz
ICJkZDg2ayA8ZGRAZGF4Lm1vZT4iCmNvcHlyaWdodCAiQ29weXJpZ2h0IMKpIDIwMjMsIGRkODZr
IDxkZEBkYXgubW9lPiIKbGljZW5zZSAiQlNELTMtQ2xhdXNlLUNsZWFyIgoKdGFyZ2V0VHlwZSAi
ZXhlY3V0YWJsZSIKCnN0cmluZ0ltcG9ydFBhdGhzICIuIg==
```

Encode stream to base64:
```text
$ echo 123 | binco -e base64
MTIzIA0K
```

Encode file as a C array:
```text
$ binco -i bin -e array_c
unsigned char data[] = {
    0x68, 0x65, 0x6c, 0x6c, 0x6f, 0x20, 0x77, 0x6f, 0x72, 0x6c, 0x64, 0x21
    0x0a
};
```

Decode Intel HEX to S-Record on-screen:
```text
$ binco -d ihex -i bin -e srec
S11300005361646C792C206A7573742061206D656A
S1130010616E696E676C657373206578616D706C71
S11300206520696E20746578742C20736F72727900
S1050030210A9F
S9030000FC
```

Decode base64-encoded file to another file:
```text
$ binco -d base64 -i example.txt -o example.exe
```

Transcode a file to another encoding:
```text
$ binco -d base16 -i a.txt -e base64 -o b.txt
```

# Limitations

## Newlines

Currently, due to a limitation to `File.byLine`, only the `\n` line terminator
is understood by the decoder.

# Building

To build binco, you'll need any D compiler (dmd, gdc, ldc) and dub.

Tests: `dub test`

Debug build: `dub build`

Release build: `dub build -b release`

With LDC: `dub build -b release --compiler=ldc2`
