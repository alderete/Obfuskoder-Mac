# Obfuskoder for macOS

A native Mac app that turns an email address (or an arbitrary HTML snippet)
into an obfuscated HTML+JavaScript snippet you can paste into your own web
page — readable by visitors, opaque to email-harvesting bots.

See [SPECIFICATION.md](SPECIFICATION.md) for the product specification and
[SPECIFICATION-CLI.md](SPECIFICATION-CLI.md) for the command-line tool.

## Command-line tool

Obfuskoder includes `obfuskode`, a command-line edition of the same encoder,
embedded in the app at `Obfuskoder.app/Contents/Helpers/obfuskode`.

To install it, choose **Obfuskoder ▸ Install Command Line Tool…** and pick a
folder (default `/usr/local/bin`). The app creates a symbolic link to the
tool inside the app bundle, so updating the app updates the tool. If the
folder isn't writable, Obfuskoder shows a Terminal command you can copy and
run instead.

Usage:

    obfuskode --email sue@example.com --link-text "Email Sue"
    obfuskode --html '<a href="mailto:sue@example.com">contact</a>'
    pbpaste | obfuskode | pbcopy

The obfuscated snippet is written to standard output. Run `obfuskode --help`
for all options (`--link-title`, `--subject`, `--fallback`). Encoding is
intentionally randomized: the same input produces a different snippet each
run; every snippet decodes identically.
