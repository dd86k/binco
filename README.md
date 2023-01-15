# Binco: Binary Encoder/Decoder

Something I made quick for myself.

# Usage

First, you need to specify `-e|--encode` or `-d|--decode` to select an
operation mode, then add the format to use (e.g., `-e base64`).

By default, stdin and stdout streams are used for input and output.

To specify a file input, use `-i|--input`. And file output, use `-o|--output`.

Encode file and show result to stdout:
```text
$ binco -e base64 -i dub.sdl
bmFtZSAiYmluY28iCmRlc2NyaXB0aW9uICJCaW5hcnkgRW5jb2Rlci9EZWNvZGVyIgphdXRob3Jz
ICJkZDg2ayA8ZGRAZGF4Lm1vZT4iCmNvcHlyaWdodCAiQ29weXJpZ2h0IMKpIDIwMjMsIGRkODZr
IDxkZEBkYXgubW9lPiIKbGljZW5zZSAiQlNELTMtQ2xhdXNlIgoKdGFyZ2V0VHlwZSAiZXhlY3V0
YWJsZSI=
```

Encode stream to base64:
```text
$ echo 123 | binco -e base64
MTIzIA0K
```

Decode file to another file:
```text
$ binco -d base64 -i example.txt -o example.exe
```

# Limitations

## Only Base64 (for now)

I need to create a wrapper for encoders/decoders before adding other binary
formats.

## Newlines

Currently, due to a limitation to `File.byLine`, only the `\n` line terminator
is understood by the decoder.