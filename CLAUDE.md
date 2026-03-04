# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Binco is a binary-to-text encoder/decoder CLI tool written in the D programming language. It supports Base64 (standard, URL no-padding, URL padded), Base16, Ascii85, basE91, Intel HEX, Motorola S-Record, UUEncode, and XXEncode. It reads from stdin or a file and writes to stdout or a file.

## Build Commands

```bash
dub build          # Build the executable
dub run -- <args>  # Build and run with arguments
dub test           # Run unittests
```

## Architecture

- **`source/main.d`** — CLI entry point. Parses command-line options (`-e`/`-d` for encode/decode, `-i`/`-o` for file I/O) and dispatches to the appropriate encoder/decoder. Uses `std.base64` directly from Phobos for Base64 support.
- **`source/binco/encoding/ascii85.d`** — Ascii85 implementation.
- **`source/binco/encoding/base16.d`** — Base16 implementation.
- **`source/binco/encoding/base36.d`** — Base36 implementation.
- **`source/binco/encoding/base58.d`** — Base58 (Bitcoin alphabet) implementation.
- **`source/binco/encoding/base91.d`** — basE91 implementation.
- **`source/binco/encoding/intelhex.d`** — Intel Hex implementation.
- **`source/binco/encoding/package.d`** — Public package import.
- **`source/binco/encoding/srec.d`** — Motorola S-Record implementation.
- **`source/binco/encoding/uuencode.d`** — UUEncode and XXEncode implementation.
- **`source/binco/encoding/z85.d`** — Z85 (ZeroMQ Base85) implementation.

## D Language Notes

- Build system: **DUB** (configured via `dub.sdl`)
- Uses Phobos standard library (`std.base64`, `std.getopt`, `std.stdio`)
- Module paths follow directory structure: `source/binco/encoding/base16.d` → `binco.encoding.base16`
- Do not use the `auto` keyword
