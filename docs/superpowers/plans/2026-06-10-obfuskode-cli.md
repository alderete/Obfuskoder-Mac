# `obfuskode` Command-Line Tool Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the `obfuskode` CLI (per `SPECIFICATION-CLI.md`) embedded in Obfuskoder.app, with the app-menu install flow, Help window, and docs.

**Architecture:** All CLI logic lives in a new `ObfuskodeCLI` library target in the existing `ObfuskoderKit` package (testable via `swift test`); a three-line Xcode command-line-tool target wraps it and is embedded at `Obfuskoder.app/Contents/Helpers/obfuskode` via a sign-on-copy phase. Pure install-decision logic goes in `ObfuskoderKit` (the `PresetStore` precedent); the app side is a thin AppKit panel/alert controller plus menu/Help wiring.

**Tech Stack:** Swift 6, SwiftPM, swift-argument-parser (first external dependency, build-time only), Swift Testing, SwiftUI/AppKit, hand-edited `project.pbxproj` (objectVersion 77, synchronized folders).

**Working directory for all commands:** `/Users/alderete/Developer/_Projects/Obfuskoder/Obfuskoder Mac` (the git repo). Package commands run in `ObfuskoderKit/` inside it.

**Read `SPECIFICATION-CLI.md` requirement IDs (CLI-x, INST-x, BLD-x, DOC-x, SEC-x) when a step cites them.**

---

### Task 1: Branch + commit the specification

The spec file `SPECIFICATION-CLI.md` exists but is untracked.

**Files:**
- Commit: `SPECIFICATION-CLI.md`

- [ ] **Step 1: Create the feature branch off main**

```bash
git checkout -b feature/obfuskode-cli main
```

Expected: `Switched to a new branch 'feature/obfuskode-cli'`

- [ ] **Step 2: Commit the spec**

```bash
git add SPECIFICATION-CLI.md
git commit -m "docs: add obfuskode CLI specification"
```

Note: `docs/MANUAL-TEST-2026-06-09.md` is also untracked — leave it alone (not ours).

---

### Task 2: Package scaffolding — `ObfuskodeCLI` target, ArgumentParser dependency, sibling test target

**Files:**
- Modify: `ObfuskoderKit/Package.swift`
- Create: `ObfuskoderKit/Sources/ObfuskodeCLI/CLICore.swift` (types only in this task)
- Create: `ObfuskoderKit/Tests/ObfuskodeCLITests/CLICoreTests.swift` (one smoke test)

- [ ] **Step 1: Replace `ObfuskoderKit/Package.swift` with:**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ObfuskoderKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ObfuskoderKit", targets: ["ObfuskoderKit"]),
        .library(name: "ObfuskodeCLI", targets: ["ObfuskodeCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "ObfuskoderKit",
            swiftSettings: [.swiftLanguageMode(.v6)],
            linkerSettings: [.linkedFramework("JavaScriptCore")]
        ),
        .target(
            name: "ObfuskodeCLI",
            dependencies: [
                "ObfuskoderKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "ObfuskoderKitTests",
            dependencies: ["ObfuskoderKit"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "ObfuskodeCLITests",
            dependencies: ["ObfuskodeCLI"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
```

- [ ] **Step 2: Create `ObfuskoderKit/Sources/ObfuskodeCLI/CLICore.swift` with the value types (no logic yet):**

```swift
import Foundation

/// The parsed invocation, decoupled from ArgumentParser for testability (SPEC-CLI §7.1).
public struct CLIInput: Equatable, Sendable {
    public var email: String?
    public var linkText: String?
    public var linkTitle: String?
    public var subject: String?
    public var html: String?
    public var fallback: String

    public init(email: String? = nil, linkText: String? = nil, linkTitle: String? = nil,
                subject: String? = nil, html: String? = nil, fallback: String) {
        self.email = email
        self.linkText = linkText
        self.linkTitle = linkTitle
        self.subject = subject
        self.html = html
        self.fallback = fallback
    }
}

/// Failure classes mapping to the SPEC-CLI §5.7 exit codes. Messages carry
/// no "obfuskode: " prefix; the output layer adds it (CLI-16).
public enum CLIFailure: Error, Equatable, Sendable {
    case usage(String)     // exit 64 via ValidationError
    case data(String)      // exit 65
    case software(String)  // exit 70
}
```

- [ ] **Step 3: Create `ObfuskoderKit/Tests/ObfuskodeCLITests/CLICoreTests.swift` with a scaffold smoke test:**

```swift
import Testing
import Foundation
import ObfuskoderKit
import ObfuskodeCLI

@Test func cliInputStoresFields() {
    let input = CLIInput(email: "sue@example.com", linkText: "Email Sue",
                         fallback: AppConfig.defaultFallbackMessage)
    #expect(input.email == "sue@example.com")
    #expect(input.html == nil)
    #expect(input.fallback == "Enable JavaScript to view email")
}
```

- [ ] **Step 4: Resolve + run tests**

```bash
cd ObfuskoderKit && swift test 2>&1 | tail -5
```

First run fetches swift-argument-parser from GitHub (network required once; `Package.resolved` is gitignored by existing repo policy).
Expected: all existing 49 kit tests plus `cliInputStoresFields` pass — `0 failures`.

- [ ] **Step 5: Commit**

```bash
cd .. && git add ObfuskoderKit/Package.swift ObfuskoderKit/Sources/ObfuskodeCLI ObfuskoderKit/Tests/ObfuskodeCLITests
git commit -m "feat(kit): scaffold ObfuskodeCLI package target with ArgumentParser"
```

---

### Task 3: Core pipeline — Basic + Advanced(inline) modes, validation, engine wiring

Implements CLI-9…CLI-13 (except stdin), CLI-18, §5.8.

**Files:**
- Modify: `ObfuskoderKit/Sources/ObfuskodeCLI/CLICore.swift`
- Modify: `ObfuskoderKit/Tests/ObfuskodeCLITests/CLICoreTests.swift`

- [ ] **Step 1: Add failing tests to `CLICoreTests.swift`** (append; also add this helper at file scope):

```swift
private func runCore(_ input: CLIInput, stdinData: Data? = nil, tty: Bool = false) throws -> String {
    try ObfuskodeCLICore.run(input, readStdin: { stdinData }, stdinIsTTY: { tty })
}

private func basicInput(email: String? = "sue@example.com",
                        linkText: String? = "Email Sue",
                        linkTitle: String? = nil,
                        subject: String? = nil,
                        html: String? = nil,
                        fallback: String = AppConfig.defaultFallbackMessage) -> CLIInput {
    CLIInput(email: email, linkText: linkText, linkTitle: linkTitle,
             subject: subject, html: html, fallback: fallback)
}

@Test func basicModeProducesVerifiedSnippet() throws {
    let snippet = try runCore(basicInput())
    #expect(!snippet.contains("@"))                    // ENC-3
    #expect(!snippet.contains("sue@example.com"))      // ENC-2
    #expect(snippet.contains("<script"))
    #expect(snippet.contains("Enable JavaScript to view email"))  // default fallback (CLI-19)
}

@Test func basicModeAcceptsAllFields() throws {
    let snippet = try runCore(basicInput(linkTitle: "Send Sue a message", subject: "Hello"))
    #expect(!snippet.contains("@"))
}

@Test func twoEncodesDiffer() throws {                 // ENC-6 / CLI-18
    let input = basicInput()
    #expect(try runCore(input) != (try runCore(input)))
}

@Test func invalidEmailIsDataError() {                 // CLI-10
    #expect(throws: CLIFailure.data("'not-an-email' is not a valid email address")) {
        _ = try runCore(basicInput(email: "not-an-email"))
    }
}

@Test func blankLinkTextIsDataError() {                // CLI-11
    #expect(throws: CLIFailure.data("the link text must not be empty")) {
        _ = try runCore(basicInput(linkText: "   "))
    }
}

@Test func fallbackWithAtSignIsDataError() {           // CLI-12
    #expect(throws: CLIFailure.data("the fallback message must not contain the '@' character")) {
        _ = try runCore(basicInput(fallback: "mail me @ home"))
    }
}

@Test func emptyFallbackIsAllowed() throws {           // CLI-12
    let snippet = try runCore(basicInput(fallback: ""))
    #expect(snippet.contains("<script"))
}

@Test func customFallbackAppears() throws {
    let snippet = try runCore(basicInput(fallback: "JavaScript required"))
    #expect(snippet.contains("JavaScript required"))
}

@Test func htmlModeEncodesVerbatimInput() throws {     // §5.3
    let snippet = try runCore(basicInput(email: nil, linkText: nil, html: "  <b>hi</b>\n"))
    #expect(snippet.contains("<script"))
    #expect(!snippet.contains("<b>hi</b>"))            // ENC-2: input absent from static text
}

@Test func emptyHTMLIsDataError() {                    // CLI-13
    #expect(throws: CLIFailure.data("no HTML to obfuskode (input is empty)")) {
        _ = try runCore(basicInput(email: nil, linkText: nil, html: "   \n"))
    }
}

@Test func fallbackContainingInputIsSoftwareError() {  // §5.8
    do {
        _ = try runCore(basicInput(email: nil, linkText: nil,
                                   html: "hello", fallback: "well hello there"))
        Issue.record("expected a software failure")
    } catch let failure as CLIFailure {
        guard case .software(let message) = failure else {
            Issue.record("expected .software, got \(failure)"); return
        }
        #expect(message.contains("fallback message contains the input text"))
    } catch {
        Issue.record("unexpected error type: \(error)")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd ObfuskoderKit && swift test 2>&1 | tail -5
```

Expected: FAIL to compile — `ObfuskodeCLICore` not defined.

- [ ] **Step 3: Append the core to `CLICore.swift`:**

```swift
/// The tool's pure pipeline: validate → canonical HTML → engine encode (SPEC-CLI §5).
public enum ObfuskodeCLICore {
    /// Runs one invocation and returns the verified snippet (no trailing newline).
    /// `readStdin`/`stdinIsTTY` are injected so tests never touch a real terminal.
    public static func run(_ input: CLIInput,
                           readStdin: () -> Data?,
                           stdinIsTTY: () -> Bool) throws -> String {
        // CLI-12: an '@' in the fallback would fail ENC-3 on every attempt.
        guard !input.fallback.contains("@") else {
            throw CLIFailure.data("the fallback message must not contain the '@' character")
        }

        let canonical: String
        var leakCheckEmail: String?

        if let email = input.email {
            // Basic mode (CLI-10, CLI-11); same construction as the app (§5.3).
            let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            guard EmailValidator.isValid(trimmedEmail) else {
                throw CLIFailure.data("'\(email)' is not a valid email address")
            }
            let text = (input.linkText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                throw CLIFailure.data("the link text must not be empty")
            }
            let fields = BasicFields(email: trimmedEmail,
                                     linkText: input.linkText ?? "",
                                     linkTitle: input.linkTitle ?? "",
                                     subject: input.subject ?? "")
            guard let html = fields.canonicalHTML() else {
                // Unreachable after the guards above; defensive.
                throw CLIFailure.data("the basic fields could not be combined into a link")
            }
            canonical = html
            leakCheckEmail = trimmedEmail                       // CLI-9
        } else if let html = input.html {
            canonical = try advancedInput(html)
        } else {
            canonical = try advancedInput(readFromStdin(readStdin: readStdin,
                                                        stdinIsTTY: stdinIsTTY))
        }

        let engine = ObfuskodeEngine(fallbackMessage: input.fallback)
        do {
            return try engine.encode(canonical, email: leakCheckEmail).html
        } catch {
            throw CLIFailure.software("""
                the encoded snippet failed its self-check repeatedly.
                This can happen when the fallback message contains the input text
                (the snippet would leak it). Otherwise, please report this bug.
                """)
        }
    }

    /// CLI-13: Advanced input is trimmed and must be non-empty.
    private static func advancedInput(_ raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CLIFailure.data("no HTML to obfuskode (input is empty)")
        }
        return trimmed
    }

    /// CLI-7 / CLI-14: stdin is read only when it is not a TTY.
    private static func readFromStdin(readStdin: () -> Data?,
                                      stdinIsTTY: () -> Bool) throws -> String {
        guard !stdinIsTTY() else {
            throw CLIFailure.usage("missing input: pass --email or --html, or pipe HTML to standard input")
        }
        guard let data = readStdin(), !data.isEmpty else {
            throw CLIFailure.data("no HTML to obfuskode (input is empty)")
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw CLIFailure.data("standard input is not valid UTF-8")
        }
        return text
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test 2>&1 | tail -5
```

Expected: PASS, `0 failures`. (`fallbackContainingInputIsSoftwareError` takes ~a second: 8 encode attempts each running JavaScriptCore.)

- [ ] **Step 5: Commit**

```bash
cd .. && git add ObfuskoderKit && git commit -m "feat(cli): core encode pipeline with basic/advanced modes and validation"
```

---

### Task 4: Core pipeline — stdin mode

Implements CLI-7 (core half), CLI-13/14 for stdin. The implementation already landed in Task 3 (`readFromStdin`); this task pins it with tests.

**Files:**
- Modify: `ObfuskoderKit/Tests/ObfuskodeCLITests/CLICoreTests.swift`

- [ ] **Step 1: Append the stdin tests:**

```swift
@Test func stdinModeEncodesPipedHTML() throws {
    let input = basicInput(email: nil, linkText: nil)
    let snippet = try runCore(input, stdinData: Data("<b>hi</b>".utf8))
    #expect(snippet.contains("<script"))
}

@Test func emptyStdinIsDataError() {
    #expect(throws: CLIFailure.data("no HTML to obfuskode (input is empty)")) {
        _ = try runCore(basicInput(email: nil, linkText: nil), stdinData: Data())
    }
}

@Test func nilStdinIsDataError() {
    #expect(throws: CLIFailure.data("no HTML to obfuskode (input is empty)")) {
        _ = try runCore(basicInput(email: nil, linkText: nil), stdinData: nil)
    }
}

@Test func invalidUTF8StdinIsDataError() {             // CLI-14
    #expect(throws: CLIFailure.data("standard input is not valid UTF-8")) {
        _ = try runCore(basicInput(email: nil, linkText: nil),
                        stdinData: Data([0xFF, 0xFE, 0xFD]))
    }
}

@Test func ttyWithNoInputIsUsageError() {              // CLI-7: never hang on a TTY
    #expect(throws: CLIFailure.usage("missing input: pass --email or --html, or pipe HTML to standard input")) {
        _ = try runCore(basicInput(email: nil, linkText: nil), tty: true)
    }
}

@Test func flagsTakePrecedenceOverStdin() throws {     // CLI-8: stdin ignored when a flag is given
    let snippet = try runCore(basicInput(), stdinData: Data("<b>ignored</b>".utf8))
    #expect(!snippet.contains("ignored"))
}
```

- [ ] **Step 2: Run tests — these should already pass (implementation exists); verify**

```bash
cd ObfuskoderKit && swift test 2>&1 | tail -5
```

Expected: PASS, `0 failures`. If any stdin test fails, fix `readFromStdin` — do not weaken the test.

- [ ] **Step 3: Commit**

```bash
cd .. && git add ObfuskoderKit && git commit -m "test(cli): pin stdin advanced-mode behavior"
```

---

### Task 5: `ObfuskodeCommand` — flags, validate(), help, version

Implements §5.2, §5.4, CLI-4…CLI-6, §5.10, BLD-6 (the read side).

**Files:**
- Create: `ObfuskoderKit/Sources/ObfuskodeCLI/ObfuskodeCommand.swift`
- Create: `ObfuskoderKit/Tests/ObfuskodeCLITests/ObfuskodeCommandTests.swift`

- [ ] **Step 1: Create `ObfuskodeCommandTests.swift` with failing tests:**

```swift
import Testing
import Foundation
import ArgumentParser
import ObfuskoderKit
import ObfuskodeCLI

private func expectExit64(_ arguments: [String]) {
    do {
        _ = try ObfuskodeCommand.parse(arguments)
        Issue.record("expected a usage error for \(arguments)")
    } catch {
        #expect(ObfuskodeCommand.exitCode(for: error) == .validationFailure)  // 64
    }
}

@Test func parsesShortFlags() throws {
    let command = try ObfuskodeCommand.parse(["-e", "sue@example.com", "-t", "Email Sue"])
    #expect(command.email == "sue@example.com")
    #expect(command.linkText == "Email Sue")
}

@Test func parsesAllLongOptions() throws {
    let command = try ObfuskodeCommand.parse([
        "--email", "sue@example.com", "--link-text", "Email Sue",
        "--link-title", "Send Sue a message", "--subject", "Hello",
        "--fallback", "JS required"
    ])
    #expect(command.linkTitle == "Send Sue a message")
    #expect(command.subject == "Hello")
    #expect(command.fallback == "JS required")
}

@Test func fallbackDefaultsToAppConfig() throws {
    let command = try ObfuskodeCommand.parse(["--html", "<b>hi</b>"])
    #expect(command.fallback == AppConfig.defaultFallbackMessage)
}

@Test func emailAndHTMLConflict() {                    // CLI-4
    expectExit64(["-e", "a@b.co", "-t", "Hi", "--html", "<p>x</p>"])
}

@Test func companionsRequireEmail() {                  // CLI-5
    expectExit64(["--link-text", "x"])
    expectExit64(["--link-title", "x", "--html", "<p>x</p>"])
    expectExit64(["--subject", "x", "--html", "<p>x</p>"])
}

@Test func emailRequiresLinkText() {                   // CLI-6
    expectExit64(["-e", "a@b.co"])
}

@Test func helpIncludesExamples() {                    // §5.10
    let help = ObfuskodeCommand.helpMessage()
    #expect(help.contains("pbpaste | obfuskode | pbcopy"))
    #expect(help.contains("randomized"))               // CLI-18 documented
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd ObfuskoderKit && swift test 2>&1 | tail -5
```

Expected: FAIL to compile — `ObfuskodeCommand` not defined.

- [ ] **Step 3: Create `ObfuskodeCommand.swift`:**

```swift
import Foundation
import ArgumentParser
import ObfuskoderKit

/// The `obfuskode` command (SPEC-CLI §5). Parsing and flag rules live here;
/// the pipeline lives in ObfuskodeCLICore; I/O goes through CLIIO.
public struct ObfuskodeCommand: ParsableCommand {
    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "obfuskode",
            abstract: "Obfuscate an email address or HTML snippet for safe publication on a web page.",
            discussion: """
            EXAMPLES:
              obfuskode --email sue@example.com --link-text "Email Sue"
              obfuskode -e sue@example.com -t "Email Sue" --link-title "Send Sue a message" --subject "Hello"
              obfuskode --html '<a href="mailto:sue@example.com">contact</a>'
              obfuskode < snippet.html > obfuscated.html
              pbpaste | obfuskode | pbcopy

            Encoding is intentionally randomized: the same input produces a different
            snippet on every run. Every snippet decodes to the same input; the tool
            verifies the round-trip before printing anything.
            """,
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        )
    }

    @Option(name: .shortAndLong,
            help: "Basic mode: the email address to be obfuskoded.")
    public var email: String?

    @Option(name: [.customShort("t"), .long],
            help: "Basic mode: the visible, clickable link text (required with --email).")
    public var linkText: String?

    @Option(name: .long,
            help: "Basic mode: pop-up message shown when hovering the link.")
    public var linkTitle: String?

    @Option(name: .long,
            help: "Basic mode: a pre-set subject line for the email.")
    public var subject: String?

    @Option(name: .long,
            help: "Advanced mode: arbitrary HTML to obfuskode verbatim.")
    public var html: String?

    @Option(name: .long,
            help: "The text shown to visitors without JavaScript.")
    public var fallback: String = AppConfig.defaultFallbackMessage

    public init() {}

    // CLI-4 / CLI-5 / CLI-6 — flag-combination rules → exit 64.
    public func validate() throws {
        if email != nil && html != nil {
            throw ValidationError("--email and --html are mutually exclusive.")
        }
        if email == nil {
            if linkText != nil { throw ValidationError("--link-text requires --email.") }
            if linkTitle != nil { throw ValidationError("--link-title requires --email.") }
            if subject != nil { throw ValidationError("--subject requires --email.") }
        }
        if email != nil && linkText == nil {
            throw ValidationError("--email requires --link-text.")
        }
    }

    public func run() throws {
        try Self.execute(input: CLIInput(email: email, linkText: linkText,
                                         linkTitle: linkTitle, subject: subject,
                                         html: html, fallback: fallback),
                         io: .live)
    }
}
```

(`execute(input:io:)` and `CLIIO` arrive in Task 6 — for this task to compile, add this temporary stub at the end of the file; Task 6 replaces it:)

```swift
extension ObfuskodeCommand {
    /// Replaced in the next commit by the real I/O layer.
    static func execute(input: CLIInput, io: CLIIO) throws {}
}

public struct CLIIO {
    public static let live = CLIIO()
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test 2>&1 | tail -5
```

Expected: PASS, `0 failures`.

- [ ] **Step 5: Commit**

```bash
cd .. && git add ObfuskoderKit && git commit -m "feat(cli): obfuskode command surface (flags, validate, help, version)"
```

---

### Task 6: `execute(input:io:)` — output contract and exit codes

Implements CLI-15…CLI-17, §5.7, §5.8 mapping.

**Files:**
- Modify: `ObfuskoderKit/Sources/ObfuskodeCLI/ObfuskodeCommand.swift`
- Modify: `ObfuskoderKit/Tests/ObfuskodeCLITests/ObfuskodeCommandTests.swift`

- [ ] **Step 1: Append failing tests to `ObfuskodeCommandTests.swift`:**

```swift
private final class IOCapture {
    var out = ""
    var err = ""
    func io(stdin: Data? = nil, tty: Bool = false) -> CLIIO {
        CLIIO(readStdin: { stdin },
              stdinIsTTY: { tty },
              writeOut: { self.out += $0 },
              writeErr: { self.err += $0 })
    }
}

@Test func executeWritesSnippetPlusOneNewline() throws {   // CLI-15 / CLI-16
    let capture = IOCapture()
    try ObfuskodeCommand.execute(
        input: CLIInput(email: "sue@example.com", linkText: "Email Sue",
                        fallback: AppConfig.defaultFallbackMessage),
        io: capture.io())
    #expect(capture.out.hasSuffix("\n"))
    #expect(!capture.out.hasSuffix("\n\n"))
    #expect(capture.out.contains("<script"))
    #expect(!capture.out.contains("@"))
    #expect(capture.err.isEmpty)
}

@Test func executeDataErrorWritesStderrAndExits65() {      // §5.7
    let capture = IOCapture()
    do {
        try ObfuskodeCommand.execute(
            input: CLIInput(email: "nope", linkText: "Hi",
                            fallback: AppConfig.defaultFallbackMessage),
            io: capture.io())
        Issue.record("expected ExitCode(65)")
    } catch let code as ExitCode {
        #expect(code == ExitCode(65))
    } catch {
        Issue.record("unexpected error type: \(error)")
    }
    #expect(capture.err == "obfuskode: 'nope' is not a valid email address\n")
    #expect(capture.out.isEmpty)
}

@Test func executeSoftwareErrorExits70() {                 // §5.8
    let capture = IOCapture()
    do {
        try ObfuskodeCommand.execute(
            input: CLIInput(html: "hello", fallback: "well hello there"),
            io: capture.io())
        Issue.record("expected ExitCode(70)")
    } catch let code as ExitCode {
        #expect(code == ExitCode(70))
    } catch {
        Issue.record("unexpected error type: \(error)")
    }
    #expect(capture.err.hasPrefix("obfuskode: the encoded snippet failed its self-check repeatedly."))
    #expect(capture.out.isEmpty)
}

@Test func executeTTYNoInputThrowsValidationError() {      // CLI-7 → 64 with usage
    let capture = IOCapture()
    do {
        try ObfuskodeCommand.execute(
            input: CLIInput(fallback: AppConfig.defaultFallbackMessage),
            io: capture.io(tty: true))
        Issue.record("expected ValidationError")
    } catch {
        #expect(ObfuskodeCommand.exitCode(for: error) == .validationFailure)
    }
}

@Test func executeStdinPipeline() throws {
    let capture = IOCapture()
    try ObfuskodeCommand.execute(
        input: CLIInput(fallback: AppConfig.defaultFallbackMessage),
        io: capture.io(stdin: Data("<b>hi</b>".utf8)))
    #expect(capture.out.contains("<script"))
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd ObfuskoderKit && swift test 2>&1 | tail -5
```

Expected: FAIL to compile — the `CLIIO` stub has no such initializer.

- [ ] **Step 3: In `ObfuskodeCommand.swift`, delete the temporary stub block from Task 5 (both the `extension ObfuskodeCommand` stub and the stub `CLIIO`) and append:**

```swift
/// Injected I/O seams (SPEC-CLI §7.1): tests capture; `.live` is the process.
public struct CLIIO {
    public var readStdin: () -> Data?
    public var stdinIsTTY: () -> Bool
    public var writeOut: (String) -> Void
    public var writeErr: (String) -> Void

    public init(readStdin: @escaping () -> Data?,
                stdinIsTTY: @escaping () -> Bool,
                writeOut: @escaping (String) -> Void,
                writeErr: @escaping (String) -> Void) {
        self.readStdin = readStdin
        self.stdinIsTTY = stdinIsTTY
        self.writeOut = writeOut
        self.writeErr = writeErr
    }

    public static let live = CLIIO(
        readStdin: { try? FileHandle.standardInput.readToEnd() },
        stdinIsTTY: { isatty(STDIN_FILENO) == 1 },
        writeOut: { FileHandle.standardOutput.write(Data($0.utf8)) },
        writeErr: { FileHandle.standardError.write(Data($0.utf8)) }
    )
}

extension ObfuskodeCommand {
    /// Runs the pipeline and maps failures to the §5.7 exit codes.
    /// Usage failures re-throw as ValidationError so ArgumentParser prints
    /// usage and exits 64; data/software failures write "obfuskode: <msg>"
    /// to stderr and exit 65 / 70.
    public static func execute(input: CLIInput, io: CLIIO) throws {
        do {
            let snippet = try ObfuskodeCLICore.run(input,
                                                   readStdin: io.readStdin,
                                                   stdinIsTTY: io.stdinIsTTY)
            io.writeOut(snippet + "\n")                       // CLI-15
        } catch let failure as CLIFailure {
            switch failure {
            case .usage(let message):
                throw ValidationError(message)
            case .data(let message):
                io.writeErr("obfuskode: \(message)\n")
                throw ExitCode(65)
            case .software(let message):
                io.writeErr("obfuskode: \(message)\n")
                throw ExitCode(70)
            }
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test 2>&1 | tail -5
```

Expected: PASS, `0 failures`.

- [ ] **Step 5: Commit**

```bash
cd .. && git add ObfuskoderKit && git commit -m "feat(cli): execute() wires output, stderr, and sysexits codes"
```

---

### Task 7: Pure install-decision logic in `ObfuskoderKit`

Implements BLD-10's testable half: the §6.4 decision table, INST-4 preflight, INST-6 default folder, INST-10 sudo command, INST-11 PATH set.

**Files:**
- Create: `ObfuskoderKit/Sources/ObfuskoderKit/CLIInstall.swift`
- Create: `ObfuskoderKit/Tests/ObfuskoderKitTests/CLIInstallTests.swift`

- [ ] **Step 1: Create `CLIInstallTests.swift` with failing tests:**

```swift
import Testing
import Foundation
@testable import ObfuskoderKit

private let source = "/Applications/Obfuskoder.app/Contents/Helpers/obfuskode"

@Test func nothingAtTargetCreatesLink() {
    #expect(CLIInstall.action(existing: nil, sourcePath: source) == .createLink)
}

@Test func correctSymlinkIsAlreadyInstalled() {
    #expect(CLIInstall.action(existing: .symlink(destination: source),
                              sourcePath: source) == .alreadyInstalled)
}

@Test func wrongSymlinkNeedsConfirmation() {
    #expect(CLIInstall.action(existing: .symlink(destination: "/old/path/obfuskode"),
                              sourcePath: source) == .confirmReplace)
}

@Test func regularFileNeedsConfirmation() {
    #expect(CLIInstall.action(existing: .file, sourcePath: source) == .confirmReplace)
}

@Test func directoryIsRefused() {
    #expect(CLIInstall.action(existing: .directory, sourcePath: source) == .refuseDirectory)
}

@Test func translocatedAndVolumePathsAreEphemeral() {     // INST-4
    #expect(CLIInstall.isEphemeralLocation(
        "/private/var/folders/ab/xyz/T/AppTranslocation/123-456/d/Obfuskoder.app"))
    #expect(CLIInstall.isEphemeralLocation("/Volumes/Obfuskoder/Obfuskoder.app"))
    #expect(!CLIInstall.isEphemeralLocation("/Applications/Obfuskoder.app"))
}

@Test func defaultFolderPrefersUsrLocalBin() {            // INST-6
    #expect(CLIInstall.defaultInstallFolder(existsCheck: { _ in true },
                                            home: "/Users/x") == "/usr/local/bin")
    #expect(CLIInstall.defaultInstallFolder(existsCheck: { $0 == "/opt/homebrew/bin" },
                                            home: "/Users/x") == "/opt/homebrew/bin")
    #expect(CLIInstall.defaultInstallFolder(existsCheck: { _ in false },
                                            home: "/Users/x") == "/Users/x")
}

@Test func sudoCommandQuotesPaths() {                     // INST-10
    let command = CLIInstall.sudoInstallCommand(folder: "/usr/local/bin", sourcePath: source)
    #expect(command == "sudo mkdir -p '/usr/local/bin' && sudo ln -sf '\(source)' '/usr/local/bin/obfuskode'")
}

@Test func pathFolderSetCoversEtcPathsAndHomebrew() {     // INST-11
    #expect(CLIInstall.assumedPathFolders.contains("/usr/local/bin"))
    #expect(CLIInstall.assumedPathFolders.contains("/opt/homebrew/bin"))
    #expect(!CLIInstall.assumedPathFolders.contains("/Users/x/bin"))
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd ObfuskoderKit && swift test 2>&1 | tail -5
```

Expected: FAIL to compile — `CLIInstall` not defined.

- [ ] **Step 3: Create `ObfuskoderKit/Sources/ObfuskoderKit/CLIInstall.swift`:**

```swift
import Foundation

/// Pure decision logic for the app's "Install Command Line Tool" flow
/// (SPEC-CLI §6). Presentation lives in the app target; this is the
/// unit-testable half (BLD-10).
public enum CLIInstall {
    /// What stands at the destination path before installing.
    public enum ExistingItem: Equatable, Sendable {
        case symlink(destination: String)
        case file
        case directory
    }

    /// What the installer should do (SPEC-CLI §6.4 decision table).
    public enum Action: Equatable, Sendable {
        case createLink
        case alreadyInstalled
        case confirmReplace
        case refuseDirectory
    }

    public static func action(existing: ExistingItem?, sourcePath: String) -> Action {
        switch existing {
        case nil: .createLink
        case .symlink(let destination) where destination == sourcePath: .alreadyInstalled
        case .symlink, .file: .confirmReplace
        case .directory: .refuseDirectory
        }
    }

    /// INST-4: true when the app runs somewhere a symlink must not point into
    /// (Gatekeeper app translocation, or a disk image / removable volume).
    public static func isEphemeralLocation(_ bundlePath: String) -> Bool {
        bundlePath.contains("/AppTranslocation/") || bundlePath.hasPrefix("/Volumes/")
    }

    /// INST-11: folders assumed to be on PATH (/etc/paths defaults + Homebrew);
    /// any other install folder earns the PATH hint.
    public static let assumedPathFolders: Set<String> = [
        "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin", "/opt/homebrew/bin"
    ]

    /// INST-10: the copyable Terminal command. The app never runs this itself.
    public static func sudoInstallCommand(folder: String, sourcePath: String) -> String {
        "sudo mkdir -p '\(folder)' && sudo ln -sf '\(sourcePath)' '\(folder)/obfuskode'"
    }

    /// INST-6: the panel's initial directory — first existing candidate, else home.
    public static func defaultInstallFolder(existsCheck: (String) -> Bool, home: String) -> String {
        for candidate in ["/usr/local/bin", "/opt/homebrew/bin"] where existsCheck(candidate) {
            return candidate
        }
        return home
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test 2>&1 | tail -5
```

Expected: PASS, `0 failures`.

- [ ] **Step 5: Commit**

```bash
cd .. && git add ObfuskoderKit && git commit -m "feat(kit): pure install-decision logic for the CLI install flow"
```

---

### Task 8: Xcode tool target, embedding, and the app entitlement (pbxproj surgery)

Implements CLI-1/2/3, BLD-4…BLD-9 (build half). **`project.pbxproj` uses TAB indentation — Read the file first and preserve tabs exactly in every edit.** New object IDs use the prefix `0BF5C0DE` (valid hex, no collisions with existing `9287…`/`AA00…` IDs).

**Files:**
- Create: `obfuskode/main.swift`
- Create: `obfuskode/Info.plist`
- Modify: `Obfuskoder.xcodeproj/project.pbxproj`

- [ ] **Step 1: Create `obfuskode/main.swift`:**

```swift
import ObfuskodeCLI

ObfuskodeCommand.main()
```

- [ ] **Step 2: Create `obfuskode/Info.plist`** (embedded into the binary for `--version`, BLD-6):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key>
	<string>com.aldosoft.Obfuskoder.obfuskode</string>
	<key>CFBundleName</key>
	<string>obfuskode</string>
	<key>CFBundleShortVersionString</key>
	<string>$(MARKETING_VERSION)</string>
	<key>CFBundleVersion</key>
	<string>$(CURRENT_PROJECT_VERSION)</string>
</dict>
</plist>
```

- [ ] **Step 3: Edit `Obfuskoder.xcodeproj/project.pbxproj` — apply ALL of the following edits** (each "add" inserts the new lines immediately before the matching `/* End … */` marker or inside the named list, keeping tab indentation):

**3a — PBXBuildFile section: add two entries:**

```
		0BF5C0DE0000000000000001 /* ObfuskodeCLI in Frameworks */ = {isa = PBXBuildFile; productRef = 0BF5C0DE0000000000000002 /* ObfuskodeCLI */; };
		0BF5C0DE0000000000000003 /* obfuskode in Embed CLI Tool */ = {isa = PBXBuildFile; fileRef = 0BF5C0DE0000000000000004 /* obfuskode */; settings = {ATTRIBUTES = (CodeSignOnCopy, ); }; };
```

**3b — PBXFileReference section: add the tool product:**

```
		0BF5C0DE0000000000000004 /* obfuskode */ = {isa = PBXFileReference; explicitFileType = "compiled.mach-o.executable"; includeInIndex = 0; path = obfuskode; sourceTree = BUILT_PRODUCTS_DIR; };
```

**3c — after `/* End PBXFileReference section */`, add two whole new sections:**

```
/* Begin PBXCopyFilesBuildPhase section */
		0BF5C0DE000000000000000A /* Embed CLI Tool */ = {
			isa = PBXCopyFilesBuildPhase;
			buildActionMask = 2147483647;
			dstPath = Contents/Helpers;
			dstSubfolderSpec = 1;
			files = (
				0BF5C0DE0000000000000003 /* obfuskode in Embed CLI Tool */,
			);
			name = "Embed CLI Tool";
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXCopyFilesBuildPhase section */

/* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section */
		0BF5C0DE0000000000000006 /* Exceptions for "obfuskode" folder in "obfuskode" target */ = {
			isa = PBXFileSystemSynchronizedBuildFileExceptionSet;
			membershipExceptions = (
				Info.plist,
			);
			target = 0BF5C0DE0000000000000007 /* obfuskode */;
		};
/* End PBXFileSystemSynchronizedBuildFileExceptionSet section */
```

**3d — PBXFileSystemSynchronizedRootGroup section: add the tool's folder group:**

```
		0BF5C0DE0000000000000005 /* obfuskode */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			exceptions = (
				0BF5C0DE0000000000000006 /* Exceptions for "obfuskode" folder in "obfuskode" target */,
			);
			path = obfuskode;
			sourceTree = "<group>";
		};
```

**3e — PBXFrameworksBuildPhase section: add the tool's phase:**

```
		0BF5C0DE0000000000000008 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				0BF5C0DE0000000000000001 /* ObfuskodeCLI in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
```

**3f — PBXGroup: main group `children` gains `0BF5C0DE0000000000000005 /* obfuskode */,` (after the `Obfuskoder` line); Products group `children` gains `0BF5C0DE0000000000000004 /* obfuskode */,` (after the `Obfuskoder.app` line).**

**3g — PBXNativeTarget section: add the tool target, and amend the app target.** New target:

```
		0BF5C0DE0000000000000007 /* obfuskode */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 0BF5C0DE000000000000000B /* Build configuration list for PBXNativeTarget "obfuskode" */;
			buildPhases = (
				0BF5C0DE0000000000000009 /* Sources */,
				0BF5C0DE0000000000000008 /* Frameworks */,
			);
			buildRules = (
			);
			dependencies = (
			);
			fileSystemSynchronizedGroups = (
				0BF5C0DE0000000000000005 /* obfuskode */,
			);
			name = obfuskode;
			packageProductDependencies = (
				0BF5C0DE0000000000000002 /* ObfuskodeCLI */,
			);
			productName = obfuskode;
			productReference = 0BF5C0DE0000000000000004 /* obfuskode */;
			productType = "com.apple.product-type.tool";
		};
```

App target (`9287A9022FD3E0F90061BEF9`): `buildPhases` gains `0BF5C0DE000000000000000A /* Embed CLI Tool */,` after the `Resources` line; `dependencies = ();` becomes:

```
			dependencies = (
				0BF5C0DE000000000000000D /* PBXTargetDependency */,
			);
```

**3h — PBXProject `targets` list gains `0BF5C0DE0000000000000007 /* obfuskode */,` after the Obfuskoder line.**

**3i — PBXSourcesBuildPhase section: add the tool's phase:**

```
		0BF5C0DE0000000000000009 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
```

**3j — after `/* End PBXSourcesBuildPhase section */`, add a new section** (proxy-less form — the project sets `minimizedProjectReferenceProxies = 1`):

```
/* Begin PBXTargetDependency section */
		0BF5C0DE000000000000000D /* PBXTargetDependency */ = {
			isa = PBXTargetDependency;
			target = 0BF5C0DE0000000000000007 /* obfuskode */;
		};
/* End PBXTargetDependency section */
```

**3k — XCBuildConfiguration section: add the tool's two configurations** (note: deliberately NOT sandboxed — SEC-2; hardened runtime ON — BLD-5):

```
		0BF5C0DE000000000000000E /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CODE_SIGN_STYLE = Automatic;
				CREATE_INFOPLIST_SECTION_IN_BINARY = YES;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = 49E99H2Q84;
				ENABLE_HARDENED_RUNTIME = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = obfuskode/Info.plist;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.aldosoft.Obfuskoder.obfuskode;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_VERSION = 6.0;
			};
			name = Debug;
		};
		0BF5C0DE000000000000000F /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CODE_SIGN_STYLE = Automatic;
				CREATE_INFOPLIST_SECTION_IN_BINARY = YES;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = 49E99H2Q84;
				ENABLE_HARDENED_RUNTIME = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = obfuskode/Info.plist;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.aldosoft.Obfuskoder.obfuskode;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_VERSION = 6.0;
			};
			name = Release;
		};
```

**3l — XCConfigurationList section: add the tool's list:**

```
		0BF5C0DE000000000000000B /* Build configuration list for PBXNativeTarget "obfuskode" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				0BF5C0DE000000000000000E /* Debug */,
				0BF5C0DE000000000000000F /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
```

**3m — XCSwiftPackageProductDependency section: add the product dependency:**

```
		0BF5C0DE0000000000000002 /* ObfuskodeCLI */ = {
			isa = XCSwiftPackageProductDependency;
			productName = ObfuskodeCLI;
		};
```

**3n — BLD-9 entitlement: in BOTH app configurations (`9287A90F…` Debug and `9287A9102…` Release), insert after the `ENABLE_PREVIEWS = YES;` line** (use replace-all on that line — it appears exactly twice):

```
				ENABLE_PREVIEWS = YES;
				ENABLE_USER_SELECTED_FILES = readwrite;
```

- [ ] **Step 4: Verify the project parses and lists both targets**

```bash
xcodebuild -project Obfuskoder.xcodeproj -list
```

Expected: `Targets:` shows `Obfuskoder` and `obfuskode`. If this errors, the pbxproj edit is malformed — fix before proceeding.

- [ ] **Step 5: Build the app (builds + embeds the tool via the dependency)**

```bash
xcodebuild -project Obfuskoder.xcodeproj -scheme Obfuskoder -configuration Debug -derivedDataPath build build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`, zero warnings (the AppIntents metadata note is benign). `build/` is gitignored.

- [ ] **Step 6: Smoke-test the embedded binary**

```bash
CLI="build/Build/Products/Debug/Obfuskoder.app/Contents/Helpers/obfuskode"
test -x "$CLI" && echo embedded-ok
"$CLI" --version
"$CLI" -e sue@example.com -t "Email Sue" | grep -q '@' && echo LEAK || echo no-at-sign
echo '<b>hi</b>' | "$CLI" | head -c 40; echo
"$CLI" --html '<p>x</p>' -e a@b.co -t x; echo "exit=$?"
"$CLI" -e bad -t x; echo "exit=$?"
"$CLI" < /dev/null; echo "exit=$?"
```

Expected: `embedded-ok`; `1.0`; `no-at-sign`; a snippet starting `<span id="OBFUSKODER_`; `exit=64` (with usage on stderr); `exit=65` (with `obfuskode: 'bad' is not a valid email address`); `exit=65` (empty-input message).

- [ ] **Step 7: Verify signing and the app entitlement**

```bash
codesign --verify --strict "build/Build/Products/Debug/Obfuskoder.app" && echo app-sig-ok
codesign -d --entitlements - "build/Build/Products/Debug/Obfuskoder.app" 2>/dev/null | grep -q "user-selected.read-write" && echo entitlement-ok
codesign -d --entitlements - "$CLI" 2>/dev/null | grep -q "app-sandbox" && echo SANDBOXED || echo cli-unsandboxed-ok
```

Expected: `app-sig-ok`, `entitlement-ok`, `cli-unsandboxed-ok`.

- [ ] **Step 8: Commit**

```bash
git add obfuskode Obfuskoder.xcodeproj/project.pbxproj
git commit -m "feat: obfuskode tool target embedded in app at Contents/Helpers"
```

---

### Task 9: App-side install flow — strings, controller, menu item

Implements INST-1…INST-12 presentation (decisions already tested in Task 7).

**Files:**
- Modify: `Obfuskoder/Strings.swift`
- Create: `Obfuskoder/CLIToolInstaller.swift`
- Modify: `Obfuskoder/AppCommands.swift`

- [ ] **Step 1: Append to `enum UIStrings` in `Obfuskoder/Strings.swift`** (before the `// Helpers` comment):

```swift
    // Command-line tool install (SPEC-CLI §6)
    static let installCLITool = String(localized: "Install Command Line Tool…")
    static let cliInstallPrompt = String(localized: "Install")
    static let cliInstallPanelMessage = String(localized: "Choose where to install the obfuskode command-line tool. A symbolic link to the tool inside Obfuskoder will be created in this folder.")
    static let cliMoveToApplicationsTitle = String(localized: "Move Obfuskoder to your Applications folder first.")
    static let cliMoveToApplicationsBody = String(localized: "Obfuskoder is running from a temporary location. A command-line tool installed now would stop working. Move Obfuskoder to your Applications folder, then choose Install Command Line Tool again.")
    static let cliReplaceTitle = String(localized: "An item named “obfuskode” already exists in this folder.")
    static let cliReplaceBody = String(localized: "Replacing it will remove the existing item and create a link to the tool inside Obfuskoder.")
    static let cliFailTitle = String(localized: "Obfuskoder couldn't install the command-line tool there.")
    static let cliFailReasonDirectory = String(localized: "A folder named “obfuskode” is in the way.")
    static func cliFailReasonPermission(folder: String) -> String {
        String(localized: "You don't have permission to write to \(folder).")
    }
    static func cliFailBody(reason: String, command: String) -> String {
        String(localized: "\(reason) You can install it yourself by running this command in Terminal:\n\n\(command)")
    }
    static let cliCopyCommand = String(localized: "Copy Command")
    static let cliSuccessTitle = String(localized: "The obfuskode command-line tool was installed.")
    static func cliSuccessBody(target: String) -> String {
        String(localized: "A link was created at \(target).")
    }
    static func cliAlreadyInstalledBody(target: String) -> String {
        String(localized: "The tool is already installed at \(target).")
    }
    static func cliPathHint(folder: String) -> String {
        String(localized: "If \(folder) isn't in your shell's PATH, add it to run obfuskode by name.")
    }
```

- [ ] **Step 2: Create `Obfuskoder/CLIToolInstaller.swift`:**

```swift
import AppKit
import ObfuskoderKit

/// Presents the "Install Command Line Tool…" flow (SPEC-CLI §6).
/// Decisions are pure functions in ObfuskoderKit.CLIInstall; this type only
/// inspects the filesystem and drives the panel/alerts. Stateless (INST-2).
@MainActor
enum CLIToolInstaller {
    static let toolName = "obfuskode"

    static func run() {
        // INST-4: a symlink into a translocated/mounted bundle would break.
        guard !CLIInstall.isEphemeralLocation(Bundle.main.bundleURL.path) else {
            presentInfo(title: UIStrings.cliMoveToApplicationsTitle,
                        body: UIStrings.cliMoveToApplicationsBody)
            return
        }
        let source = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/\(toolName)")
            .standardizedFileURL
        // INST-5: never create a dangling link.
        guard FileManager.default.fileExists(atPath: source.path) else {
            presentFailure(folder: defaultFolder(), source: source.path, reason: nil)
            return
        }
        // INST-6: the panel IS the sandbox permission grant.
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = UIStrings.cliInstallPrompt
        panel.message = UIStrings.cliInstallPanelMessage
        panel.directoryURL = URL(fileURLWithPath: defaultFolder(), isDirectory: true)
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        install(into: folder, source: source)
    }

    private static func defaultFolder() -> String {
        CLIInstall.defaultInstallFolder(
            existsCheck: { FileManager.default.fileExists(atPath: $0) },
            home: NSHomeDirectory())
    }

    private static func install(into folder: URL, source: URL) {
        let target = folder.appendingPathComponent(toolName)
        switch CLIInstall.action(existing: existingItem(at: target), sourcePath: source.path) {
        case .alreadyInstalled:
            presentSuccess(target: target.path, folder: folder.path, alreadyInstalled: true)
        case .createLink:
            createLink(target: target, source: source, folder: folder)
        case .confirmReplace:
            guard confirmReplace() else { return }
            try? FileManager.default.removeItem(at: target)
            createLink(target: target, source: source, folder: folder)
        case .refuseDirectory:
            presentFailure(folder: folder.path, source: source.path,
                           reason: UIStrings.cliFailReasonDirectory)
        }
    }

    private static func existingItem(at url: URL) -> CLIInstall.ExistingItem? {
        let fm = FileManager.default
        if let destination = try? fm.destinationOfSymbolicLink(atPath: url.path) {
            let resolved = URL(fileURLWithPath: destination,
                               relativeTo: url.deletingLastPathComponent())
                .standardizedFileURL.path
            return .symlink(destination: resolved)
        }
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return nil }
        return isDirectory.boolValue ? .directory : .file
    }

    private static func createLink(target: URL, source: URL, folder: URL) {
        do {
            try FileManager.default.createSymbolicLink(at: target, withDestinationURL: source)
            presentSuccess(target: target.path, folder: folder.path, alreadyInstalled: false)
        } catch {
            presentFailure(folder: folder.path, source: source.path,
                           reason: error.localizedDescription)
        }
    }

    // MARK: Alerts

    private static func presentInfo(title: String, body: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.runModal()
    }

    /// INST-9: Cancel is the default; Replace is explicitly destructive (INST-12).
    private static func confirmReplace() -> Bool {
        let alert = NSAlert()
        alert.messageText = UIStrings.cliReplaceTitle
        alert.informativeText = UIStrings.cliReplaceBody
        alert.addButton(withTitle: UIStrings.cancel)
        let replaceButton = alert.addButton(withTitle: UIStrings.replace)
        replaceButton.hasDestructiveAction = true
        return alert.runModal() == .alertSecondButtonReturn
    }

    /// INST-10: failures explain the reason and offer the copyable sudo command.
    private static func presentFailure(folder: String, source: String, reason: String?) {
        let command = CLIInstall.sudoInstallCommand(folder: folder, sourcePath: source)
        let alert = NSAlert()
        alert.messageText = UIStrings.cliFailTitle
        alert.informativeText = UIStrings.cliFailBody(
            reason: reason ?? UIStrings.cliFailReasonPermission(folder: folder),
            command: command)
        alert.addButton(withTitle: UIStrings.cliCopyCommand)
        alert.addButton(withTitle: UIStrings.cancel)
        if alert.runModal() == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command, forType: .string)
        }
    }

    /// INST-11: success names the link; off-PATH folders get the PATH hint.
    private static func presentSuccess(target: String, folder: String, alreadyInstalled: Bool) {
        let alert = NSAlert()
        alert.messageText = UIStrings.cliSuccessTitle
        var body = alreadyInstalled ? UIStrings.cliAlreadyInstalledBody(target: target)
                                    : UIStrings.cliSuccessBody(target: target)
        if !CLIInstall.assumedPathFolders.contains(folder) {
            body += "\n\n" + UIStrings.cliPathHint(folder: folder)
        }
        alert.informativeText = body
        alert.runModal()
    }
}
```

- [ ] **Step 3: Add the menu item (INST-1) to `Obfuskoder/AppCommands.swift`** — insert as the FIRST CommandGroup inside `var body: some Commands` (before the existing `CommandGroup(after: .toolbar)`):

```swift
        // Obfuskoder ▸ Install Command Line Tool… (SPEC-CLI §6.1)
        CommandGroup(after: .appSettings) {
            Button(UIStrings.installCLITool) { CLIToolInstaller.run() }
        }
```

- [ ] **Step 4: Build (also re-extracts the String Catalog)**

```bash
xcodebuild -project Obfuskoder.xcodeproj -scheme Obfuskoder -configuration Debug -derivedDataPath build build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`, zero warnings. `Obfuskoder/Localizable.xcstrings` will be modified by the build's string-catalog extraction — include it in the commit.

- [ ] **Step 5: Commit**

```bash
git add Obfuskoder/Strings.swift Obfuskoder/CLIToolInstaller.swift Obfuskoder/AppCommands.swift Obfuskoder/Localizable.xcstrings
git commit -m "feat(app): Install Command Line Tool menu flow"
```

---

### Task 10: Help window — `CLIHelpView`, scene, Help menu item

Implements DOC-2/DOC-3 (§11.2).

**Files:**
- Modify: `Obfuskoder/Strings.swift`
- Create: `Obfuskoder/Views/CLIHelpView.swift`
- Modify: `Obfuskoder/ObfuskoderApp.swift`
- Modify: `Obfuskoder/AppCommands.swift`

- [ ] **Step 1: Append to `enum UIStrings`** (after the Task 9 additions):

```swift
    // Command-line tool help window (SPEC-CLI §11.2)
    static let cliHelpMenu = String(localized: "Command-Line Tool Help")
    static let cliHelpWindowTitle = String(localized: "Command-Line Tool")
    static let cliHelpIntro = String(localized: "Obfuskoder includes obfuskode, a command-line version of the encoder, for scripts and pipelines.")
    static let cliHelpInstall = String(localized: "Install it with Obfuskoder ▸ Install Command Line Tool…, then run it from Terminal:")
    static let cliHelpOutro = String(localized: "The obfuscated snippet is written to standard output. For all options, run obfuskode --help.")
```

- [ ] **Step 2: Create `Obfuskoder/Views/CLIHelpView.swift`:**

```swift
import SwiftUI

/// SPEC-CLI §11.2: brief in-app instructions for the obfuskode tool.
/// Deliberately short — full detail lives in `obfuskode --help`.
struct CLIHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(UIStrings.cliHelpIntro)
            Text(UIStrings.cliHelpInstall)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "obfuskode --email sue@example.com --link-text \"Email Sue\"")
                Text(verbatim: "obfuskode --html '<a href=\"mailto:sue@example.com\">contact</a>'")
                Text(verbatim: "pbpaste | obfuskode | pbcopy")
            }
            .font(.system(.callout, design: .monospaced))
            .textSelection(.enabled)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 6))
            Text(UIStrings.cliHelpOutro)
        }
        .padding(20)
        .frame(width: 460)
    }
}

#Preview {
    CLIHelpView()
}
```

- [ ] **Step 3: Add the window scene to `Obfuskoder/ObfuskoderApp.swift`** — insert after the `Settings { … }` scene, inside `var body: some Scene`:

```swift
        // SPEC-CLI §11.2 — small fixed-size help window, closes with ⌘W.
        Window(UIStrings.cliHelpWindowTitle, id: "cli-help") {
            CLIHelpView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
```

- [ ] **Step 4: Add the Help menu item to `Obfuskoder/AppCommands.swift`.** Add the environment property to the struct (below `let model: AppModel`):

```swift
    @Environment(\.openWindow) private var openWindow
```

and append a new CommandGroup at the end of `var body: some Commands` (after the `.pasteboard` group):

```swift
        // Help ▸ Command-Line Tool Help (SPEC-CLI §11.2)
        CommandGroup(after: .help) {
            Button(UIStrings.cliHelpMenu) { openWindow(id: "cli-help") }
        }
```

- [ ] **Step 5: Build**

```bash
xcodebuild -project Obfuskoder.xcodeproj -scheme Obfuskoder -configuration Debug -derivedDataPath build build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`, zero warnings; `Localizable.xcstrings` updated again.

- [ ] **Step 6: Commit**

```bash
git add Obfuskoder/Strings.swift Obfuskoder/Views/CLIHelpView.swift Obfuskoder/ObfuskoderApp.swift Obfuskoder/AppCommands.swift Obfuskoder/Localizable.xcstrings
git commit -m "feat(app): Command-Line Tool Help window"
```

---

### Task 11: Documentation — README, main-spec amendment, manual-test additions

Implements DOC-1, BLD-9 (doc half), §10 (manual tests).

**Files:**
- Create: `README.md`
- Modify: `SPECIFICATION.md`
- Modify: `docs/MANUAL-TEST-PLAN.md`

- [ ] **Step 1: Create `README.md`** (repo root; minimal per DOC-1 — owner will expand):

````markdown
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
````

- [ ] **Step 2: Amend `SPECIFICATION.md` §9.1 (BLD-9).** Replace this bullet:

```
  - **No network *server* entitlement; no user-selected file access** — presets
    and settings live in the app's own container.
```

with:

```
  - **`com.apple.security.files.user-selected.read-write`** — declared so
    the *Install Command Line Tool* flow (SPECIFICATION-CLI.md §6) can
    create its symlink in the folder the user picks in the open panel.
    Presets and settings still live in the app's own container; the app
    opens no other user files.
  - **No network *server* entitlement.**
```

- [ ] **Step 3: Add a new section to `docs/MANUAL-TEST-PLAN.md`** — insert before the `## Appendix A — Test data` heading:

```markdown
## 18. Command-line tool (obfuskode)

> Requires a built app. CLI behavior details: SPECIFICATION-CLI.md §5–§6.

- [ ] **Install (writable folder):** Obfuskoder ▸ Install Command Line
      Tool…, choose a folder you can write to (e.g. `/opt/homebrew/bin` or
      `~/bin`). Success alert names the link path; for an off-PATH folder it
      adds the PATH hint. The link works: `obfuskode --version` prints the
      app's version (matches Finder ▸ Get Info).
- [ ] **Install (root-owned folder):** choose `/usr/local/bin` on a machine
      where it is root-owned. The failure alert explains, **Copy Command**
      puts a `sudo mkdir -p … && sudo ln -sf …` line on the clipboard; running
      it in Terminal produces a working link.
- [ ] **Already installed / replace:** re-running the flow to the same folder
      reports "already installed"; with a foreign file named `obfuskode` at
      the target it asks before replacing (Cancel is the default button);
      Cancel at the panel and at the alert leaves everything untouched.
- [ ] **Translocation guard:** launch a quarantined copy (or from a DMG) —
      the flow shows "Move Obfuskoder to your Applications folder first"
      instead of the panel.
- [ ] **Pipelines:** `pbpaste | obfuskode | pbcopy` and
      `obfuskode < in.html > out.html` work; output pasted into a real page
      renders the expected link; the snippet contains no `@`.
- [ ] **Exit codes:** `obfuskode` alone on a TTY prints usage and exits 64
      (does not hang); `obfuskode -e bad -t x` exits 65; success exits 0
      (`echo $?`).
- [ ] **Help window:** Help ▸ Command-Line Tool Help opens the small window;
      examples are selectable; ⌘W closes it.
```

- [ ] **Step 4: Commit**

```bash
git add README.md SPECIFICATION.md docs/MANUAL-TEST-PLAN.md
git commit -m "docs: README, spec §9.1 amendment, manual-test additions for CLI"
```

---

### Task 12: Full verification sweep

- [ ] **Step 1: Package tests**

```bash
cd ObfuskoderKit && swift test 2>&1 | tail -3 && cd ..
```

Expected: all tests pass (49 pre-existing + ~30 new), `0 failures`.

- [ ] **Step 2: Clean Debug and Release builds**

```bash
xcodebuild -project Obfuskoder.xcodeproj -scheme Obfuskoder -configuration Debug -derivedDataPath build clean build 2>&1 | grep -E "warning|error|SUCCEEDED"
xcodebuild -project Obfuskoder.xcodeproj -scheme Obfuskoder -configuration Release -derivedDataPath build build 2>&1 | grep -E "warning|error|SUCCEEDED"
```

Expected: `** BUILD SUCCEEDED **` twice, no warnings or errors (AppIntents metadata note is benign).

- [ ] **Step 3: Release-build smoke + universal check**

```bash
CLI="build/Build/Products/Release/Obfuskoder.app/Contents/Helpers/obfuskode"
lipo -archs "$CLI"
"$CLI" --version
"$CLI" -e sue@example.com -t "Email Sue" | grep -q '@' || echo no-at-sign
codesign -d --verbose "$CLI" 2>&1 | grep -o "flags=.*runtime.*" || codesign -d --verbose "$CLI" 2>&1 | grep flags
```

Expected: `arm64 x86_64` (universal — on a local single-arch Debug-style build this may show one arch; the firm universal requirement is verified at archive time), `1.0`, `no-at-sign`, and the hardened-runtime flag in the signature.

- [ ] **Step 4: Acceptance-criteria sweep** — re-read `SPECIFICATION-CLI.md` §12 and check off every box that is machine-verifiable. The remaining manual items (install flows, Help window interaction) are covered by `docs/MANUAL-TEST-PLAN.md` §18 for the owner's manual pass.

- [ ] **Step 5: Commit any stragglers** (e.g., `Localizable.xcstrings` re-extraction); otherwise nothing to commit.

```bash
git status --short
```

Expected: clean (except the user-local `xcschememanagement.plist`, which stays unstaged as before).

**Do not merge or push** — finishing the branch (superpowers:finishing-a-development-branch, Option 1: merge to `main` locally, then push `main`) happens only on the owner's go-ahead, after their manual test pass.

---

## Notes for the implementer

- **Swift 6 / ArgumentParser:** `ObfuskodeCommand.configuration` is a computed property deliberately (avoids a stored static of a non-Sendable-in-older-versions type). If the resolved ArgumentParser version flags any Sendable warnings, prefer raising the dependency floor over sprinkling `@unchecked`.
- **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` applies only to the app target** — the tool target and package targets stay nonisolated-by-default. Don't add that setting to the tool target.
- **Do NOT touch** `ENABLE_OUTGOING_NETWORK_CONNECTIONS` / `com.apple.security.network.client` (the WKWebView preview needs it), and never add a JIT entitlement for JavaScriptCore (BLD-7).
- **pbxproj:** tabs, not spaces. After any pbxproj edit, `xcodebuild -list` is the cheap parse check.
- **SourceKit may briefly report "No such module 'ObfuskodeCLI'"** in the editor before the first build — trust `swift test`/`xcodebuild`, as with `ObfuskoderKit` previously.
