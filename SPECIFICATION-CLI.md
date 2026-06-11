# Obfuskoder for macOS — `obfuskode` Command-Line Tool Specification

**Status:** Draft v0.1
**Owner:** Michael A. Alderete, [Aldosoft](https://aldosoft.com/)
**Date:** 2026-06-10
**Companion documents:** [SPECIFICATION.md](SPECIFICATION.md) (the app this
tool ships inside; its §7 encoder contract applies unchanged),
[MAC-ASSED-MAC-APPS.md](MAC-ASSED-MAC-APPS.md).

---

## 1. Overview

`obfuskode` is a command-line edition of Obfuskoder: a single binary, embedded
inside the Obfuskoder.app bundle, that performs the same encode the app does —
same engine (`ObfuskodeEngine`), same self-check, same output contract (§7 of
the main spec) — and writes the verified snippet to **standard output**, so it
composes with shells, pipelines, build scripts, and static-site generators.

The app gains one menu item, **Obfuskoder ▸ Install Command Line Tool…**,
which creates a **symbolic link** to the embedded binary in a folder of the
user's choice (default `/usr/local/bin`). The app bundle remains the single
unit of distribution: there is no separate CLI download, and updating the app
updates the tool (the symlink continues to point into the bundle).

Two deliverables, specified here:

1. **The `obfuskode` tool** (§5): argument surface, I/O contract, exit codes,
   validation.
2. **The install flow** (§6): menu item, folder chooser, symlink semantics,
   and every failure path — including the ones the App Sandbox and stock
   `/usr/local/bin` permissions make common.
3. **Brief documentation** (§11): a README “Command-line tool” section and a
   Help-menu entry.

## 2. Goals

- Let a scripting-comfortable user produce an obfuskoded snippet from the
  shell, non-interactively, with the **identical output contract and
  encode-time self-check** as the app (ENC-1…ENC-7, §7 of the main spec).
- Compose well with Unix: snippet to stdout, diagnostics to stderr,
  meaningful exit codes, stdin accepted for the Advanced (arbitrary-HTML)
  mode.
- Ship inside the app — one download, one signature, one notarization, one
  version number.
- Make installation a one-menu-item affair, with graceful, Mac-assed handling
  of the cases where the chosen folder isn't writable.

## 3. Non-goals

- **Batch encoding** — one invocation encodes one input. (Loop in the shell.)
- **File-path arguments** — shell redirection (`< file.html`) covers reading
  files; an output flag is unnecessary (`> out.html`). Keeps the tool's
  security surface trivial.
- **Reading the app's Settings or saved presets.** The CLI is stateless and
  self-contained; its defaults are the built-in `AppConfig` constants. (The
  app's settings live in its sandbox container; reaching into it from an
  unsandboxed tool would be fragile and surprising in scripts. A
  `--preset <name>` flag is parked, §13.)
- **A man page, shell completions, or separate Homebrew/MacPorts
  distribution** (v1). `--help` is the tool's built-in documentation; the
  brief README and in-app Help coverage in §11 are in scope.
  (ArgumentParser's generated completions are a free future nicety, §13.)
- **An Uninstall menu item.** Uninstalling is `rm <link>`; not worth UI (§13).
- **GUI behaviors**: no debounce (one shot), no preview, no pasteboard.

## 4. User stories

| #     | As a…              | I want to…                                                  | So that…                                                |
|-------|--------------------|--------------------------------------------------------------|----------------------------------------------------------|
| CL-1  | static-site builder| run `obfuskode -e me@example.com -t "Email me"` in a script  | my build regenerates obfuscated contact links            |
| CL-2  | developer          | pipe HTML through the tool (`pbpaste \| obfuskode \| pbcopy`)| I can obfuscate arbitrary markup without opening the app  |
| CL-3  | script author      | get non-zero exit codes and stderr diagnostics on bad input  | my scripts fail loudly instead of publishing garbage      |
| CL-4  | app user           | install the tool from a menu item                            | I never have to find the binary inside the bundle myself  |
| CL-5  | Homebrew user      | choose `/opt/homebrew/bin` (or any folder) at install time   | the tool lands somewhere already on my `PATH`             |

## 5. The `obfuskode` command

### 5.1 Name, location, invocation

- **CLI-1** The binary is named **`obfuskode`** and ships at
  **`Obfuskoder.app/Contents/Helpers/obfuskode`** (Apple's standard location
  for embedded helper tools).
- **CLI-2** It is a **universal binary** (Apple silicon + Intel), deployment
  target macOS 14, exactly like the app.
- **CLI-3** It runs correctly when invoked by absolute path, via a symlink
  from any directory, or with any working directory. It must not assume it is
  inside the bundle (no lookups relative to the app), and it requires no
  environment variables.

### 5.2 Synopsis

```
obfuskode --email <address> --link-text <text> [--link-title <text>] [--subject <text>] [--fallback <message>]
obfuskode --html <html> [--fallback <message>]
obfuskode [--fallback <message>] < input.html
obfuskode --version
obfuskode --help
```

### 5.3 Input modes

Exactly **one** input source per invocation. The three sources mirror the
app's two form modes:

| Mode             | Source                  | Canonical input handed to the engine                              |
|------------------|-------------------------|--------------------------------------------------------------------|
| Basic            | `--email` (+ companions)| `BasicFields.canonicalHTML()` — identical `<a href="mailto:…">` construction as the app (§6.3 of the main spec) |
| Advanced, inline | `--html <html>`         | the argument, trimmed of surrounding whitespace, verbatim (§6.4)   |
| Advanced, stdin  | piped/redirected stdin  | stdin read to EOF as UTF-8, trimmed of surrounding whitespace, verbatim |

Mode-selection rules:

- **CLI-4** `--email` and `--html` are **mutually exclusive** → usage error
  (exit 64) when both are given.
- **CLI-5** `--link-text`, `--link-title`, and `--subject` are valid **only
  with `--email`** → usage error (exit 64) if any appears without it.
- **CLI-6** `--email` **requires** `--link-text` → usage error (exit 64)
  when missing (the two required Basic fields, per §6.3 of the main spec).
- **CLI-7** When neither `--email` nor `--html` is given: if **stdin is not a
  TTY** (piped or redirected; test with `isatty(STDIN_FILENO)`), read it as
  the Advanced input. If stdin **is** a TTY, do **not** sit waiting for
  input — print a usage error directing the user to `--help` and exit 64.
- **CLI-8** When `--email` or `--html` is given, stdin is **ignored** (never
  read).
- **CLI-9** In Basic mode, the email address is also passed to the engine as
  the leak-check address (the `email:` parameter of
  `ObfuskodeEngine.encode`), exactly as the app does via
  `FormState.emailForSelfCheck`. In Advanced/stdin mode it is `nil`.

### 5.4 Options

| Option         | Short | Value      | Default                              | Description                                                                 |
|----------------|-------|------------|--------------------------------------|-----------------------------------------------------------------------------|
| `--email`      | `-e`  | address    | —                                    | Basic mode. The email address to be obfuskoded. Validated per CLI-10.        |
| `--link-text`  | `-t`  | text       | —                                    | Basic mode, required with `--email`. The visible, clickable link text.       |
| `--link-title` |       | text       | (omitted)                            | Basic mode, optional. Becomes the `title=` attribute.                        |
| `--subject`    |       | text       | (omitted)                            | Basic mode, optional. URL-encoded into the `mailto:` href as `?subject=`.    |
| `--html`       |       | html       | —                                    | Advanced mode. Arbitrary HTML to obfuskode verbatim (after trim).            |
| `--fallback`   |       | message    | `Enable JavaScript to view email` (`AppConfig.defaultFallbackMessage`) | The text non-JavaScript visitors see. Validated per CLI-12. |
| `--version`    |       | —          | —                                    | Print the version (§7.4) to stdout and exit 0.                               |
| `--help`       | `-h`  | —          | —                                    | Print usage (generated by ArgumentParser) and exit 0.                        |

No other flags in v1. (Parked candidates in §13.)

### 5.5 Validation

Validation mirrors the app's rules exactly — same code paths where possible:

- **CLI-10** `--email` is trimmed and validated with the kit's
  `EmailValidator` (the web edition's pattern `^[^\s@]+@[^\s@]+\.[^\s@]+$`).
  Invalid → data error (exit 65):
  `obfuskode: '<value>' is not a valid email address`.
- **CLI-11** `--link-text` must be non-empty after trimming → data error
  (exit 65): `obfuskode: the link text must not be empty`.
  (A *missing* `--link-text` flag is a usage error, CLI-6; a *blank value* is
  a data error.)
- **CLI-12** `--fallback` must not contain the `@` character (ENC-3 makes
  such a snippet unverifiable — every encode attempt would fail) → data error
  (exit 65):
  `obfuskode: the fallback message must not contain the '@' character`.
  An **empty** fallback is allowed (the sentinel span simply has no text).
- **CLI-13** An Advanced input that is empty after trimming (blank `--html`,
  or empty/whitespace-only stdin) → data error (exit 65):
  `obfuskode: no HTML to obfuskode (input is empty)`.
- **CLI-14** Stdin that is not valid UTF-8 → data error (exit 65):
  `obfuskode: standard input is not valid UTF-8`.

After validation, the canonical input is encoded with
`ObfuskodeEngine(fallbackMessage:).encode(_:email:)` — which runs the full
encode-time self-check (ENC-1/2/3, up to 8 attempts) before any output
exists. **The tool never prints an unverified snippet.**

### 5.6 Output contract

- **CLI-15** On success, the snippet — built by the exact same engine path as
  the app's Copy action, satisfying the identical §7 contract — is written to
  **stdout**, followed by exactly **one trailing newline**. Nothing else is
  ever written to stdout (except `--version`/`--help` output).
- **CLI-16** All diagnostics go to **stderr**. Data/internal errors are
  one-line messages prefixed `obfuskode: ` (exact strings in §5.5/§5.8);
  usage errors use ArgumentParser's generated format (message + usage block).
- **CLI-17** Output is UTF-8.
- **CLI-18** Per ENC-6, two runs with identical input produce **different**
  snippets. This is correct behavior; document it in `--help`'s discussion
  text so script authors don't diff successive runs.

### 5.7 Exit codes

BSD `sysexits(3)` values, so failures are distinguishable in scripts:

| Code | Name          | Meaning                                                                |
|------|---------------|------------------------------------------------------------------------|
| 0    | OK            | Snippet written to stdout (or `--help`/`--version`).                   |
| 64   | `EX_USAGE`    | Bad invocation: unknown/conflicting/missing flags (CLI-4…CLI-7).        |
| 65   | `EX_DATAERR`  | Flags were well-formed but a *value* was unusable (CLI-10…CLI-14).      |
| 70   | `EX_SOFTWARE` | The encode-time self-check failed all attempts (§5.8).                  |

*Implementation note:* ArgumentParser exits 64 for `ValidationError`
automatically. For 65/70, print the message to stderr, then throw
`ExitCode(65)` / `ExitCode(70)`.

### 5.8 Internal-error path

If `ObfuskodeEngine.encode` exhausts its attempts
(`ObfuskodeError.selfCheckFailedRepeatedly`), exit 70 with:

```
obfuskode: the encoded snippet failed its self-check repeatedly.
This can happen when the fallback message contains the input text
(the snippet would leak it). Otherwise, please report this bug.
```

(Rationale: ENC-2's static-leak check rejects any snippet whose fallback
contains the whole input, so every attempt fails. The `@` case is already
pre-validated by CLI-12; containment of the input text is the remaining way a
user-supplied fallback makes encoding impossible, and the message must say so
rather than presenting a bare "internal error".)

### 5.9 Settings independence

- **CLI-19** The tool reads **no** UserDefaults, no app container, no config
  files, and no environment variables. The `--fallback` default is the
  compiled-in `AppConfig.defaultFallbackMessage`, **not** the app's Settings
  value. Behavior is fully determined by the command line (plus stdin) —
  scripts behave identically on every Mac.

### 5.10 Examples (these appear in `--help`'s discussion text)

```sh
# Basic: a ready-to-paste obfuscated mailto link
obfuskode --email sue@example.com --link-text "Email Sue"

# Basic with all fields, short flags
obfuskode -e sue@example.com -t "Email Sue" --link-title "Send Sue a message" --subject "Hello"

# Advanced: arbitrary HTML, inline
obfuskode --html '<a href="mailto:sue@example.com">contact</a>'

# Advanced: via stdin / pipeline
obfuskode < snippet.html > obfuscated.html
pbpaste | obfuskode | pbcopy

# Custom fallback for non-JavaScript visitors
obfuskode -e sue@example.com -t "Email Sue" --fallback "JavaScript required"
```

## 6. The Install Command Line Tool menu item

### 6.1 Placement & title

- **INST-1** Menu item **“Install Command Line Tool…”** in the **Obfuskoder
  (app) menu**, directly below **Settings…** (SwiftUI
  `CommandGroup(after: .appSettings)` in `AppCommands`). The ellipsis is
  required — the command always opens a dialog.
- **INST-2** The item is **always enabled** and the flow is **stateless**:
  the app keeps no record of installs. Running it again re-installs
  (idempotently, INST-7); installing to several folders is allowed.
- **INST-3** All user-facing strings live in the String Catalog via
  `UIStrings` (§6.7), like every other string in the app.

### 6.2 Preflight: is the app somewhere a symlink can point to?

A symlink into the bundle is only durable if the bundle path is durable.
Before showing any chooser:

- **INST-4** If the app is **translocated** (bundle path contains
  `/AppTranslocation/`) or running from a **disk image or removable volume**
  (bundle path begins with `/Volumes/`), show an informational alert instead
  of proceeding:

  > **Move Obfuskoder to your Applications folder first.**
  > Obfuskoder is running from a temporary location. A command-line tool
  > installed now would stop working. Move Obfuskoder to your Applications
  > folder, then choose Install Command Line Tool again.

  (Single **OK** button. Detection is by path inspection — no private API.)
- **INST-5** The link **source** is resolved at install time as
  `Bundle.main.bundleURL` + `Contents/Helpers/obfuskode`, standardized
  (symlinks in the bundle path resolved). If that file unexpectedly does not
  exist, show the generic failure alert (INST-10) — never create a dangling
  link.

### 6.3 Choosing the destination

The App Sandbox means the app can write **only** to folders the user
explicitly grants via the open panel (the powerbox) — even `/usr/local/bin`
requires this. So the chooser is not optional UI; it *is* the permission
grant:

- **INST-6** An `NSOpenPanel` configured: directories only
  (`canChooseDirectories = true`, `canChooseFiles = false`),
  `canCreateDirectories = true`, prompt button **“Install”**, and message:

  > Choose where to install the `obfuskode` command-line tool. A symbolic
  > link to the tool inside Obfuskoder will be created in this folder.

  The panel's initial directory is the first of these that exists:
  `/usr/local/bin`, then `/opt/homebrew/bin`, then the user's home folder.
  Cancel ends the flow silently.

### 6.4 Creating the symlink

Let `target` = *chosen folder*`/obfuskode` and `source` = the resolved helper
path (INST-5). Decide by what already exists at `target` (this decision table
is a pure function — keep it testable, §10):

| State at `target`                                  | Action                                                            |
|----------------------------------------------------|-------------------------------------------------------------------|
| **INST-7** nothing                                 | create the symlink → success alert (INST-11)                       |
| **INST-8** a symlink already pointing to `source`  | nothing to do → success alert variant “already installed” (INST-11)|
| **INST-9** any other symlink, or a regular file    | confirmation alert: *“An item named ‘obfuskode’ already exists in this folder. Replace it?”* with **Replace** (destructive) / **Cancel**. On Replace: remove, then create the symlink. |
| a directory                                        | failure alert (INST-10) — never remove a directory                  |

Symlink creation uses
`FileManager.createSymbolicLink(at:withDestinationURL:)` with the absolute
`source` path.

### 6.5 Failure handling — the permission path is the *common* path

On stock macOS, `/usr/local/bin` is root-owned (and on Apple silicon often
does not exist at all); the powerbox grants sandbox access but does **not**
bypass POSIX permissions. So a write failure is expected, not exceptional:

- **INST-10** If creating (or replacing) the link fails — permission denied,
  read-only volume, a directory at the target (§6.4), anything — show an
  alert that states the underlying reason and hands the user a working escape
  hatch:

  > **Obfuskoder couldn't install the command-line tool there.**
  > *<one sentence naming the actual problem — e.g. “You don't have
  > permission to write to <folder>.” from the thrown error>* You can
  > install it yourself by running this command in Terminal:
  >
  > `sudo mkdir -p '<folder>' && sudo ln -sf '<source>' '<folder>/obfuskode'`

  Buttons: **Copy Command** (writes the exact command, with the real resolved
  paths substituted, to the general pasteboard, then dismisses) and
  **Cancel**. The app **never runs privileged commands itself** — the user
  copies, reads, and runs it in Terminal. Failures are never silent.

### 6.6 Success feedback

- **INST-11** A success alert:

  > **The obfuskode command-line tool was installed.**
  > A link was created at *<folder>/obfuskode*. *(or: “…is already installed
  > at <folder>/obfuskode.” for INST-8)*

  If the chosen folder is **not** one of `/usr/local/bin`, `/usr/bin`,
  `/bin`, `/usr/sbin`, `/sbin` (the `/etc/paths` defaults), or
  `/opt/homebrew/bin`, append:

  > If *<folder>* isn't in your shell's PATH, add it to run `obfuskode` by
  > name.

### 6.7 Strings (String Catalog additions)

All of the following are `UIStrings` entries; wording above is the working
copy (final wording is a content edit, per §9.5 of the main spec):
menu title; translocation alert title/body; panel message + prompt;
replace-confirmation title/body + button; failure alert title/body +
**Copy Command** button; success alert title/body (+ already-installed
variant); the PATH hint sentence.

### 6.8 Accessibility & conventions

- **INST-12** Standard `NSOpenPanel`/`NSAlert` (or SwiftUI equivalents) only —
  keyboard operability and VoiceOver come from the system. The destructive
  **Replace** action must not be the default button.

## 7. Architecture & build integration

The principle of the main spec's §8 — pure, testable core; thin presentation —
extends to the CLI: **all CLI logic lives in the package** where `swift test`
reaches it; the Xcode tool target is a three-line shim.

### 7.1 Package changes (`ObfuskoderKit/Package.swift`)

- **BLD-1** Add the project's first external dependency:
  `https://github.com/apple/swift-argument-parser`, `from: "1.3.0"`
  (decided by owner, 2026-06-10 — see §14). Build-time only; nothing about
  the app's no-network runtime posture changes.
- **BLD-2** New **library target `ObfuskodeCLI`**, depending on
  `ObfuskoderKit` and `ArgumentParser`, `swiftLanguageMode(.v6)` like the
  existing targets. It contains:
  - `ObfuskodeCommand: ParsableCommand` — the full flag surface (§5.4),
    `validate()` for the mode rules (CLI-4…CLI-7), and a `run()` that
    delegates to a testable core.
  - The core function takes the parsed values plus injected seams for
    **stdin** (`() -> Data?` or equivalent) and **stdout/stderr** writers, and
    returns/throws so tests never spawn a process. `ObfuskodeEngine` is used
    as-is; `BasicFields` builds the canonical HTML (CLI-10/11 produce their
    specific messages *before* calling `canonicalHTML()`, which is then
    guaranteed non-nil).
  - `ArgumentParser` is **not** exposed from `ObfuskoderKit` itself — the
    core kit stays dependency-free.
- **BLD-3** New **sibling test target `ObfuskodeCLITests`** covering §10
  (decided by owner, 2026-06-10). A separate target keeps the dependency
  graph honest: only the CLI targets touch ArgumentParser.

### 7.2 Xcode tool target

- **BLD-4** New **Command Line Tool target `obfuskode`** in
  `Obfuskoder.xcodeproj`. Its only source is a `main.swift` that calls
  `ObfuskodeCommand.main()`. It links the `ObfuskodeCLI` package product.
- **BLD-5** Build settings: `SWIFT_VERSION = 6.0`,
  `MACOSX_DEPLOYMENT_TARGET = 14.0`, universal architectures,
  `ENABLE_HARDENED_RUNTIME = YES` (required for notarization),
  **`ENABLE_APP_SANDBOX = NO`** (rationale §8), same `MARKETING_VERSION` as
  the app (set at project level so they cannot drift).
- **BLD-6** Version identity: embed an Info.plist section in the binary
  (`CREATE_INFOPLIST_SECTION_IN_BINARY = YES`) carrying
  `CFBundleIdentifier = com.aldosoft.Obfuskoder.obfuskode` and
  `CFBundleShortVersionString = $(MARKETING_VERSION)`. `--version` prints
  `CFBundleShortVersionString` via `Bundle.main` (fallback `0.0` if absent),
  wired through `CommandConfiguration(version:)`.
- **BLD-7** JavaScriptCore note: the self-check's `JSContext` runs in
  interpreter mode under the hardened runtime without a JIT entitlement —
  same as the app today. **Do not add** `com.apple.security.cs.allow-jit`.

### 7.3 Embedding in the app

- **BLD-8** The app target gains a dependency on the `obfuskode` target and a
  **Copy Files** phase — destination **Wrapper**, subpath
  **`Contents/Helpers`**, with **Code Sign on Copy** — producing
  `Obfuskoder.app/Contents/Helpers/obfuskode`, correctly nested-signed for
  notarization.

### 7.4 App-side install flow

- **BLD-9** The app target gains the **user-selected file access (read/write)
  entitlement** (`ENABLE_USER_SELECTED_FILES = readwrite`, i.e.
  `com.apple.security.files.user-selected.read-write`) — required for the
  powerbox-granted symlink write (§6.3). **This amends SPECIFICATION.md
  §9.1**, which currently reads “no user-selected file access”; when
  implementing, update that bullet to:

  > - **`com.apple.security.files.user-selected.read-write`** — declared so
  >   the *Install Command Line Tool* flow (SPECIFICATION-CLI.md §6) can
  >   create its symlink in the folder the user picks in the open panel.
  >   Presets and settings still live in the app's own container; the app
  >   opens no other user files.

- **BLD-10** New app-side unit: an installer controller (e.g.
  `CLIToolInstaller`) owning the §6 flow, with the INST-4 preflight check and
  the §6.4 decision table implemented as pure, unit-testable functions
  separate from the AppKit panel/alert presentation.

## 8. Security & privacy

- **SEC-1** The tool makes **no network connections** of any kind (and its
  output is self-contained per ENC-4). The project's no-network promise
  (§9.2 of the main spec) extends to the CLI verbatim.
- **SEC-2** The tool is **not sandboxed**. It is a helper run from the user's
  shell that reads argv/stdin and writes stdout — it opens no files, so the
  sandbox would protect nothing, and sandboxed CLI tools acquire confusing
  per-tool containers. It is signed, hardened-runtime, and notarized inside
  the app. *MAS note:* Mac App Store submission requires every executable to
  be sandboxed; if the MAS door (main spec §9.1) is ever exercised, revisit —
  sandboxing this tool is feasible precisely because it touches no files.
- **SEC-3** Privilege escalation is **never performed by the app**. The only
  `sudo` in this design is a command the *user* copies and runs themselves
  (INST-10).
- **SEC-4** The CLI performs no HTML sanitization, identical to the app's
  Advanced form (§6.4 of the main spec) and for the same reason: the snippet
  is generated locally, for the user's own page, from the user's own input.

## 9. Performance

- **PERF-1** One-shot execution: launch + encode + self-check + print for a
  typical input completes in well under one second (target < 250 ms on Apple
  silicon; JSC interpreter startup dominates). No daemon, no caching, no
  state.

## 10. Testing

**Package tests (automated, `swift test`):**

- Parsing matrix: each usage-error rule CLI-4…CLI-7 (conflicts, companions
  without `--email`, missing `--link-text`, bare TTY invocation), plus
  defaults and short flags.
- Data validation: CLI-10…CLI-14 — each produces its exact §5.5 message and
  maps to exit 65.
- Round-trip: for Basic and Advanced (inline + injected-stdin) runs, the
  produced snippet passes `SelfCheck.verify` and decodes to exactly the
  canonical input; Basic output equals encoding
  `BasicFields(...).canonicalHTML()` (same construction as the app).
- Output discipline: stdout receives the snippet + exactly one `\n` and
  nothing else; messages land on the stderr seam.
- ENC-6: two runs, identical input → different snippets.
- Fallback: default applied; empty accepted; `@` rejected (65);
  fallback-contains-input surfaces the §5.8 message path (70).
- Install decision table (§6.4) and preflight predicate (INST-4) as pure
  functions: nothing / correct symlink / wrong symlink / regular file /
  directory; translocated and `/Volumes` paths.

**Manual tests (add a CLI section to `docs/MANUAL-TEST-PLAN.md`):**

- Menu install to a writable folder (e.g. `/opt/homebrew/bin` or `~/bin`);
  run `obfuskode` by name; paste output into a real page and confirm the
  link renders.
- Install to root-owned `/usr/local/bin` → INST-10 alert; **Copy Command**;
  run the command in Terminal; verify the link works.
- Replace flow (existing file at target), already-installed flow, Cancel at
  every step.
- Translocation guard: launch from a quarantined location → INST-4 alert.
- Pipeline smoke: `pbpaste | obfuskode | pbcopy`; `obfuskode < f.html`.
- First-run-from-quarantine smoke: fresh, downloaded (quarantined) app —
  install, then run the tool from Terminal.
- `--version` matches the app's version in Finder's Get Info.
- **Help ▸ Command-Line Tool Help** opens its window (and closes with ⌘W);
  the copy matches §11.2.

## 11. Documentation (README & Help)

In scope for v1 (owner, 2026-06-10). Neither artifact exists yet — the repo
has no `README.md`, and the app's Help menu has no custom entries (the main
spec's §6.9 minimum is also still unimplemented) — so this feature creates
both. All copy below is working text the owner will hand-edit.

### 11.1 README

- **DOC-1** The repository gains a root `README.md` containing a
  **“Command-line tool”** section (draft below). If a fuller README exists by
  implementation time, add the section to it; otherwise create a minimal
  `README.md` (project title, one-line description, this section). The main
  spec's broader README obligations (MIT note, Hivelogic Enkoder
  acknowledgement — its §14) remain separate, later work.

  Draft section:

  ```markdown
  ## Command-line tool

  Obfuskoder includes `obfuskode`, a command-line edition of the same
  encoder, embedded in the app at
  `Obfuskoder.app/Contents/Helpers/obfuskode`.

  To install it, choose **Obfuskoder ▸ Install Command Line Tool…** and pick
  a folder (default `/usr/local/bin`). The app creates a symbolic link to
  the tool inside the app bundle, so updating the app updates the tool. If
  the folder isn't writable, Obfuskoder shows a Terminal command you can
  copy and run instead.

  Usage:

      obfuskode --email sue@example.com --link-text "Email Sue"
      obfuskode --html '<a href="mailto:sue@example.com">contact</a>'
      pbpaste | obfuskode | pbcopy

  The obfuscated snippet is written to standard output. Run
  `obfuskode --help` for all options (`--link-title`, `--subject`,
  `--fallback`). Encoding is intentionally randomized: the same input
  produces a different snippet each run; every snippet decodes identically.
  ```

### 11.2 In-app Help

- **DOC-2** The **Help menu** gains **“Command-Line Tool Help”**, which opens
  a small, read-only auxiliary window (SwiftUI `Window` scene; compact fixed
  width; closes with ⌘W) presenting the brief instructions below, with the
  examples in monospaced text. Strings live in the String Catalog. (No Help
  book in v1 — parked in the main spec's §13; fold this content into one if
  it ever ships.)

  Draft window copy — title **Command-Line Tool**:

  > Obfuskoder includes `obfuskode`, a command-line version of the encoder,
  > for scripts and pipelines.
  >
  > Install it with **Obfuskoder ▸ Install Command Line Tool…**, then run it
  > from Terminal:
  >
  > `obfuskode --email sue@example.com --link-text "Email Sue"`
  > `obfuskode --html '<a href="mailto:sue@example.com">contact</a>'`
  > `pbpaste | obfuskode | pbcopy`
  >
  > The obfuscated snippet is written to standard output. For all options,
  > run `obfuskode --help`.

- **DOC-3** Both pieces of copy stay **brief** — full details belong to
  `obfuskode --help` and this specification, not the README or the Help
  window.

## 12. Acceptance criteria (v1)

- [ ] `Obfuskoder.app/Contents/Helpers/obfuskode` exists in the built app, is
      universal, signed, and notarizes with the app.
- [ ] `obfuskode -e a@b.co -t Hi` prints a snippet to stdout (one trailing
      newline, nothing else on stdout) and exits 0; the snippet contains no
      `@` and decodes to the same canonical HTML the app produces for those
      field values.
- [ ] `--html` and stdin (pipe and `<` redirection) both work; bare
      invocation on a TTY exits 64 with usage on stderr — it does not hang.
- [ ] Every rule CLI-4…CLI-14 produces its specified exit code and stderr
      message; stdout stays empty on every failure.
- [ ] Two identical invocations produce different snippets (ENC-6).
- [ ] `--help` shows the full option surface with the §5.10 examples;
      `--version` prints the app's marketing version.
- [ ] **Install Command Line Tool…** appears below Settings… in the app
      menu; the full §6 flow works: fresh install, already-installed,
      replace-after-confirmation, permission-denied with a working copyable
      `sudo` command, translocation guard, PATH hint for off-PATH folders.
- [ ] The app still passes its existing acceptance criteria with the new
      entitlement (BLD-9) — in particular, still **no network requests**.
- [ ] All new user-facing strings are in the String Catalog.
- [ ] `README.md` contains the “Command-line tool” section (DOC-1); **Help ▸
      Command-Line Tool Help** opens and shows the §11.2 instructions (DOC-2).
- [ ] All package tests in §10 pass via `swift test`.

## 13. Out of scope for v1 (parking lot)

- `--preset <name>` — encode using one of the app's saved presets (needs a
  sanctioned way to read the app container; revisit with an app-group or
  shared-file design).
- `--output <file>` / file-path input arguments (redirection suffices).
- `--seed` for reproducible output in tests (engine `RandomSource` is already
  injectable; library tests cover it — no binary flag needed yet).
- Shell completions (`--generate-completion-script` works out of the box with
  ArgumentParser; documenting/shipping completions is a README task later).
- Man page; Homebrew formula/cask distribution of the standalone tool.
- An Uninstall menu item; honoring the app's Settings (fallback/debounce) in
  the CLI.
- Batch mode (multiple inputs per invocation).

## 14. Decisions & open questions

### Decided
- **Argument parsing: `swift-argument-parser`** — the project's first
  external dependency, build-time only (owner, 2026-06-10).
- **Flags-only surface; no subcommands.** One tool, one job; modes are
  implied by which input flag is present (mirrors the app's Basic/Advanced).
- **stdin = Advanced mode** when no input flag is given and stdin is not a
  TTY; TTY + no input = usage error, never a hang.
- **Location: `Contents/Helpers`** (Apple's documented home for helper
  tools); install = **symlink**, app bundle remains the single source.
- **Not sandboxed** (SEC-2), hardened runtime, notarized with the app.
- **Exit codes: `sysexits`** 0/64/65/70.
- **Settings independence** (CLI-19): compiled-in defaults, no container
  reads.
- **Sandbox-compatible install**: powerbox open panel is the grant; the new
  user-selected read-write entitlement amends main-spec §9.1 (BLD-9); on
  permission failure the app offers a copyable `sudo` command and never
  escalates itself (SEC-3, INST-10).
- **Stateless install**: no installed/not-installed tracking; idempotent
  re-install (INST-2, INST-8).
- **Short flags: `-e` and `-t` only** — the required Basic pair; every other
  option is long-only (owner, 2026-06-10).
- **CLI tests live in a sibling `ObfuskodeCLITests` target** (BLD-3; owner,
  2026-06-10).
- **README + in-app Help coverage ships with the feature** (§11) — brief
  copy, owner hand-edits (owner, 2026-06-10).

### Still open
- **Final wording** — the §6 alert/panel copy and §11 README/Help copy are
  working text; finalize during implementation (content edits — String
  Catalog for in-app text — not code edits).

## 15. References

- [SPECIFICATION.md](SPECIFICATION.md) — §6.3/§6.4 (forms whose semantics the
  flags mirror), §7 (encoder contract & self-check), §8 (architecture), §9.1
  (sandbox & distribution posture this spec amends via BLD-9).
- [MAC-ASSED-MAC-APPS.md](MAC-ASSED-MAC-APPS.md) — the install flow's UI
  conventions (real panels, real alerts, no toasts, no silent failure).
- `sysexits(3)` — exit-code vocabulary.
- [swift-argument-parser](https://github.com/apple/swift-argument-parser) —
  parsing, `--help` generation, `ValidationError`/`ExitCode` semantics.
- Apple, *Placing Content in a Bundle* — `Contents/Helpers` as the location
  for embedded helper tools.
