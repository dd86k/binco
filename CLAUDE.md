# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Binco is a binary-to-text encoder/decoder CLI tool written in the D programming language. It supports base64 (standard, URL no-padding, URL padded) and base16. It reads from stdin or a file and writes to stdout or a file.

## Build Commands

```bash
dub build          # Build the executable
dub run -- <args>  # Build and run with arguments
dub test           # Run unittests
```

## Architecture

- **`source/main.d`** — CLI entry point. Parses command-line options (`-e`/`-d` for encode/decode, `-i`/`-o` for file I/O) and dispatches to the appropriate encoder/decoder. Currently base64 variants use `std.base64` directly from Phobos.
- **`source/binco/encoding/base16.d`** — Base16 implementation.

## D Language Notes

- Build system: **DUB** (configured via `dub.sdl`)
- Uses Phobos standard library (`std.base64`, `std.getopt`, `std.stdio`)
- Module paths follow directory structure: `source/binco/encoding/base16.d` → `binco.encoding.base16`
