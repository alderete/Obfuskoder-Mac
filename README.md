# Obfuskoder for macOS

Obfuskoder is a Mac app that turns an email address (or any arbitrary text) into an obfuscated HTML+JavaScript snippet you can paste into your own web page — readable by visitors, opaque to email-harvesting bots.

Obfuskoder lets you publish your email address on the Internet without it becoming a target for spam. In Advanced mode, you can obfuscate an arbitrary chunk of text or HTML to make it more challenging for non-humans to read the text.

This protection is imperfect. All that's required is for the obfuskoded text to be run through a JavaScript runtime. That's trivial for one-off access, which is why it should rarely be a problem for normal visitors to your site. At scale, though, it's a bit more computationally expensive, which hopefully makes it opaque for most email- or content-harvesting bots.

## Mac App

Normal use is straightforward. Fill in a form with the content you want protected, and then copy out the obfuskoded snippet. Paste that snippet into an HTML page, or a context where raw HTML is supported.

[screenshots]

Basic mode is optimized for email addresses. Advanced mode lets you obfuskode anything. There's help in the app with more details.

## Command Line Tool

For automation, integration, and other non-UI-based operations, Obfuskoder includes `obfuskode`, a command line version of the same encoder, embedded in the app.

To install it, choose **Obfuskoder ▸ Install Command Line Tool…** and pick a folder (default `/usr/local/bin`). The app creates a symbolic link to the tool inside the app bundle, so updating the app updates the tool. If the folder isn't writable, Obfuskoder shows a Terminal command you can copy and run instead.

Example usage:

```bash
obfuskode --email sue@example.com --link-text "Email Sue"
obfuskode --html '<a href="mailto:sue@example.com">contact</a>'
pbpaste | obfuskode | pbcopy
```

The obfuscated snippet is written to standard output. Run `obfuskode --help` for all options (`--link-title`, `--subject`, `--fallback`). 

## Additional Obfuskoder Tools

For really simple use, there's [Obfuskoder-JS](https://github.com/alderete/Obfuskoder-JS), which is a single page, self-contained web app, which you can run by downloading and opening the local file in any browser. 

For a maybe interesting example of using the command line version, [obfuskode-Quarto](https://github.com/alderete/obfuskode-Quarto) is a shortcode for obscuring email addresses in Quarto Markdown (`.qmd`) documents. Basic use looks like this:

```markdown
{{< obfuskode email=sue@example.com >}}
```

## Development Notes

Obfuskoder for macOS is an open source project. All of the code is here, and you should find it trivial to download and compile yourself with Xcode, should you wish. There's no complex setup, scripts to run, or other steps that more advanced Xcode projects require. 

You can also see a lot of artifacts from the development process. Obfuskoder was mostly written by Claude Code, with constant guidance from me to refine the UI and behavior. It's intended to be a [Mac-assed Mac app](/docs/MAC-ASSED-MAC-APPS.md), and if you find ways in which it isn't, please create an issue!

The other artifacts might or might not be interesting for insight into how a Claude-driven project moves forward on more than just "vibes". See [SPECIFICATION.md](docs/SPECIFICATION.md) for the product specification and [SPECIFICATION-CLI.md](docs/SPECIFICATION-CLI.md) for the command-line tool. Many other artifacts are also in the [docs](docs/) directory.

