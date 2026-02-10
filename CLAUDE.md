# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Binco is a binary-to-text encoder/decoder CLI tool written in the D programming language. It supports base64 (standard, URL no-padding, URL padded) and has a work-in-progress base16 implementation. It reads from stdin or files and writes to stdout or files.

## Build Commands

```bash
dub build          # Build the executable
dub run -- <args>  # Build and run with arguments
dub test           # Run unittests
```

## Architecture

- **`source/main.d`** — CLI entry point. Parses command-line options (`-e`/`-d` for encode/decode, `-i`/`-o` for file I/O) and dispatches to the appropriate encoder/decoder. Currently base64 variants use `std.base64` directly from Phobos.
- **`source/modem.d`** — Defines `EncodingType` enum (the registry of supported formats) and `NoEncoding` sentinel. Contains a `Modem` class intended to be a unified range-based wrapper but currently incomplete.
- **`source/binco/wrapper.d`** — `Encoding` interface and `EncodingWrapper` template class that adapts any D input range into a common `Encoding` interface (type erasure pattern).
- **`source/binco/encoding/base64.d`** — Aliases for base64 encoder/decoder using `EncodingWrapper` (currently commented out).
- **`source/binco/encoding/base16.d`** — Stub `Base16` struct and aliases; not yet implemented.

The intended design is to have each encoding implement a range-based struct, wrap it via `EncodingWrapper` for type erasure through the `Encoding` interface, and dispatch through `Modem`. Currently only base64 works, using `std.base64` directly in `main.d` rather than going through the wrapper system.

## D Language Notes

- Build system: **DUB** (configured via `dub.sdl`)
- Uses Phobos standard library (`std.base64`, `std.getopt`, `std.stdio`)
- Module paths follow directory structure: `source/binco/encoding/base16.d` → `binco.encoding.base16`
