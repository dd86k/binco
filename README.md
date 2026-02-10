# Binco: Binary-Text Encoder-Decoder

binco is a CLI-oriented binary-text encoder and decoder.

Currently supports:
- `array_c`: C array (encoding only)
- `array_csharp`: C# array (encoding only)
- `array_d`: D array (encoding only)
- `base16`: Hexadecimal
- `base64`: Base64
- `base64u`: Base64 URL without padding, RFC 4648 and 7515
- `base64up`: Base64 URL with padding

# Usage

An encoding (using `-e`) or decoding (`-d`) scheme needs to be specified.

By default, stdin and stdout streams are used for input and output.

To specify a file input, use `-i|--input`. For file output, use `-o|--output`.

Encode file and show result to stdout:
```sh
$ binco -e base64 -i dub.sdl
bmFtZSAiYmluY28iCmRlc2NyaXB0aW9uICJCaW5hcnkgRW5jb2Rlci9EZWNvZGVyIgphdXRob3Jz
ICJkZDg2ayA8ZGRAZGF4Lm1vZT4iCmNvcHlyaWdodCAiQ29weXJpZ2h0IMKpIDIwMjMsIGRkODZr
IDxkZEBkYXgubW9lPiIKbGljZW5zZSAiQlNELTMtQ2xhdXNlLUNsZWFyIgoKdGFyZ2V0VHlwZSAi
ZXhlY3V0YWJsZSIKCnN0cmluZ0ltcG9ydFBhdGhzICIuIg==
```

Encode stream to base64:
```sh
$ echo 123 | binco -e base64
MTIzIA0K
```

Encode file as a C array:
```sh
$ binco -i bin -e array_c
```

Decode file to another file:
```sh
$ binco -i example.txt -d base64 -o example.exe
```

Transcode a file to another encoding:
```sh
$ binco -i a.txt -d base16 -e base64 -o b.txt
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
