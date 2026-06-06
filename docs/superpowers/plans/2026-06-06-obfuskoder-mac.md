# Obfuskoder for macOS — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the native macOS Obfuskoder app (Swift/SwiftUI) defined in `SPECIFICATION.md` (Draft v0.2): a single-window tool that turns an email/HTML into an obfuscated HTML+JS web snippet, with a live WebKit preview, named presets, and full Mac conventions.

**Architecture:** All pure, testable logic lives in a **local Swift package, `ObfuskoderKit`** (encoder, JavaScriptCore self-check, validation, canonical-HTML builder, form-state, preset store, config). The existing Xcode app target (`Obfuskoder`) becomes a thin SwiftUI layer that depends on the package: a single `Window` scene, two-pane layout, a `WKWebView` preview, menu commands, and a Settings scene. TDD applies to the package (`swift test`); the SwiftUI layer is build-and-run verified because the project has no unit-test target.

**Tech Stack:** Swift, SwiftUI, AppKit interop (`NSViewRepresentable` for `WKWebView`/`NSTextField`/`NSTextView`), JavaScriptCore (headless self-check), WebKit (visible preview), Observation (`@Observable`), Swift Testing (`import Testing`), SwiftPM local package.

---

## Conventions for every task

- **Repo root:** `/Users/alderete/Developer/_Projects/Obfuskoder/Obfuskoder Mac` (this is the git repo; the parent `Obfuskoder/` is **not** a repo).
- **Run package tests from the package dir:**
  `cd "/Users/alderete/Developer/_Projects/Obfuskoder/Obfuskoder Mac/ObfuskoderKit" && swift test`
  Single suite/test: append `--filter <NamePattern>`.
- **Build the app:**
  `cd "/Users/alderete/Developer/_Projects/Obfuskoder/Obfuskoder Mac" && xcodebuild -scheme Obfuskoder -destination 'platform=macOS' build`
- **Swift TDD "red":** in Swift a missing symbol is a **compile error**, which is the failing state. "Expected: FAIL" means the test target does not compile or the assertion fails — both count as red.
- **Tests use `@testable import ObfuskoderKit`** so they can reach `internal` types (`Encoder`, `EncodedArtifact`, `SelfCheck`, `EncodeParameters`).
- Commit after each green step. Keep commits small.

## File structure (what gets created)

**Package — `ObfuskoderKit/`:**
- `Package.swift` — package manifest (macOS 14, Swift Testing, links JavaScriptCore).
- `Sources/ObfuskoderKit/AppConfig.swift` — shared constants (debounce default, fallback default, accent hex, attempt cap).
- `Sources/ObfuskoderKit/FormMode.swift` — `enum FormMode`.
- `Sources/ObfuskoderKit/BasicFields.swift` — `struct BasicFields` + `canonicalHTML()`.
- `Sources/ObfuskoderKit/EmailValidator.swift` — `enum EmailValidator`.
- `Sources/ObfuskoderKit/HTMLEscaping.swift` — internal escape/percent-encode helpers.
- `Sources/ObfuskoderKit/RandomSource.swift` — `protocol RandomSource` + `SystemRandomSource`.
- `Sources/ObfuskoderKit/Encoder.swift` — `EncodeParameters`, `EncodedArtifact`, `enum Encoder`.
- `Sources/ObfuskoderKit/SelfCheck.swift` — `enum SelfCheck` + `SelfCheckError` (ENC-1/2/3).
- `Sources/ObfuskoderKit/ObfuskodeEngine.swift` — `Snippet`, `ObfuskodeError`, `struct ObfuskodeEngine`.
- `Sources/ObfuskoderKit/FormState.swift` — `struct FormState` (pure form→input mapping).
- `Sources/ObfuskoderKit/Preset.swift` — `PresetPayload`, `Preset`.
- `Sources/ObfuskoderKit/PresetStore.swift` — `@Observable @MainActor final class PresetStore`, `PresetError`.
- `Tests/ObfuskoderKitTests/*` — one test file per source unit.

**App — `Obfuskoder/`:**
- `ObfuskoderApp.swift` — rewrite: `Window` + `Settings` scenes, `.commands`, app-delegate adaptor.
- `AppDelegate.swift` — quit on last window close.
- `AppModel.swift` — `@Observable @MainActor` form/result orchestration + debounced encode; `enum ResultState`.
- `SettingsKeys.swift` — UserDefaults keys.
- `Strings.swift` — `enum UIStrings` (localized accessors).
- `Localizable.xcstrings` — String Catalog (created in Xcode).
- `Obfuskoder.entitlements` — confirm sandbox, no network (managed by build setting; see Task 23).
- `Views/ContentView.swift` — toolbar + split layout.
- `Views/InputPane.swift` — mode container + Saved values + Clear.
- `Views/BasicFormView.swift`, `Views/AdvancedFormView.swift`.
- `Views/FieldHint.swift` — `info.circle` help affordance.
- `Views/MacTextField.swift`, `Views/MacTextEditor.swift` — substitution-free AppKit fields.
- `Views/SavedValuesMenu.swift`, `Views/SaveValuesSheet.swift`, `Views/ManagePresetsSheet.swift`.
- `Views/ResultPane.swift`, `Views/PreviewWebView.swift`.
- `Views/SettingsView.swift`.
- `Assets.xcassets/AccentColor.colorset` — add sage light/dark colors.

---

# Phase 0 — Package scaffold

### Task 1: Create the `ObfuskoderKit` package

**Files:**
- Create: `ObfuskoderKit/Package.swift`
- Create: `ObfuskoderKit/Sources/ObfuskoderKit/Placeholder.swift`
- Create: `ObfuskoderKit/Tests/ObfuskoderKitTests/SmokeTests.swift`

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ObfuskoderKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ObfuskoderKit", targets: ["ObfuskoderKit"])
    ],
    targets: [
        .target(
            name: "ObfuskoderKit",
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [.linkedFramework("JavaScriptCore")]
        ),
        .testTarget(
            name: "ObfuskoderKitTests",
            dependencies: ["ObfuskoderKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
```

- [ ] **Step 2: Write a placeholder source so the target compiles**

`ObfuskoderKit/Sources/ObfuskoderKit/Placeholder.swift`:

```swift
// Intentionally minimal; replaced by real types in later tasks.
enum ObfuskoderKitPlaceholder {}
```

- [ ] **Step 3: Write a smoke test**

`ObfuskoderKit/Tests/ObfuskoderKitTests/SmokeTests.swift`:

```swift
import Testing
@testable import ObfuskoderKit

@Test func packageBuildsAndTestsRun() {
    #expect(Bool(true))
}
```

- [ ] **Step 4: Run tests**

Run: `cd "/Users/alderete/Developer/_Projects/Obfuskoder/Obfuskoder Mac/ObfuskoderKit" && swift test`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
cd "/Users/alderete/Developer/_Projects/Obfuskoder/Obfuskoder Mac"
git add ObfuskoderKit
git commit -m "build: scaffold ObfuskoderKit Swift package with Swift Testing"
```

---

# Phase 1 — Config, models, validation

### Task 2: AppConfig constants

**Files:**
- Create: `ObfuskoderKit/Sources/ObfuskoderKit/AppConfig.swift`
- Test: `ObfuskoderKit/Tests/ObfuskoderKitTests/AppConfigTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import ObfuskoderKit

@Test func appConfigDefaults() {
    #expect(AppConfig.defaultDebounceSeconds == 0.4)
    #expect(AppConfig.defaultFallbackMessage == "Enable JavaScript to view email")
    #expect(AppConfig.accentHex == "5E7C50")
    #expect(AppConfig.maxSelfCheckAttempts == 8)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "…/ObfuskoderKit" && swift test --filter appConfigDefaults`
Expected: FAIL (cannot find `AppConfig`).

- [ ] **Step 3: Write the implementation**

```swift
import Foundation

public enum AppConfig {
    public static let defaultDebounceSeconds: Double = 0.4
    public static let minDebounceSeconds: Double = 0.1
    public static let maxDebounceSeconds: Double = 1.0
    public static let defaultFallbackMessage = "Enable JavaScript to view email"
    public static let accentHex = "5E7C50"
    public static let maxSelfCheckAttempts = 8
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd "…/ObfuskoderKit" && swift test --filter appConfigDefaults`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ObfuskoderKit/Sources/ObfuskoderKit/AppConfig.swift ObfuskoderKit/Tests/ObfuskoderKitTests/AppConfigTests.swift
git commit -m "feat(kit): add AppConfig constants"
```

---

### Task 3: FormMode enum

**Files:**
- Create: `ObfuskoderKit/Sources/ObfuskoderKit/FormMode.swift`
- Test: `ObfuskoderKit/Tests/ObfuskoderKitTests/FormModeTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import Foundation
@testable import ObfuskoderKit

@Test func formModeIsCodableRoundTrip() throws {
    for mode in FormMode.allCases {
        let data = try JSONEncoder().encode(mode)
        let back = try JSONDecoder().decode(FormMode.self, from: data)
        #expect(back == mode)
    }
    #expect(FormMode.basic.rawValue == "basic")
    #expect(FormMode.advanced.rawValue == "advanced")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "…/ObfuskoderKit" && swift test --filter formModeIsCodableRoundTrip`
Expected: FAIL (cannot find `FormMode`).

- [ ] **Step 3: Write the implementation**

```swift
public enum FormMode: String, Codable, Sendable, CaseIterable {
    case basic
    case advanced
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd "…/ObfuskoderKit" && swift test --filter formModeIsCodableRoundTrip`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ObfuskoderKit/Sources/ObfuskoderKit/FormMode.swift ObfuskoderKit/Tests/ObfuskoderKitTests/FormModeTests.swift
git commit -m "feat(kit): add FormMode"
```

---

### Task 4: EmailValidator

**Files:**
- Create: `ObfuskoderKit/Sources/ObfuskoderKit/EmailValidator.swift`
- Test: `ObfuskoderKit/Tests/ObfuskoderKitTests/EmailValidatorTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import ObfuskoderKit

@Test func acceptsWellFormedAddresses() {
    #expect(EmailValidator.isValid("user@example.com"))
    #expect(EmailValidator.isValid("a.b+c@sub.example.co.uk"))
    #expect(EmailValidator.isValid("  trimmed@example.com  "))   // trims first
}

@Test func rejectsMalformedAddresses() {
    #expect(!EmailValidator.isValid(""))
    #expect(!EmailValidator.isValid("no-at-sign.com"))
    #expect(!EmailValidator.isValid("two@@example.com"))
    #expect(!EmailValidator.isValid("missing@domain"))
    #expect(!EmailValidator.isValid("space in@example.com"))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "…/ObfuskoderKit" && swift test --filter EmailValidator`
Expected: FAIL (cannot find `EmailValidator`).

- [ ] **Step 3: Write the implementation**

Mirrors the web edition's pattern `^[^\s@]+@[^\s@]+\.[^\s@]+$`.

```swift
import Foundation

public enum EmailValidator {
    /// Trims surrounding whitespace, then matches the web edition's basic pattern.
    public static func isValid(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd "…/ObfuskoderKit" && swift test --filter EmailValidator`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add ObfuskoderKit/Sources/ObfuskoderKit/EmailValidator.swift ObfuskoderKit/Tests/ObfuskoderKitTests/EmailValidatorTests.swift
git commit -m "feat(kit): add EmailValidator"
```

---

### Task 5: HTML/URL escaping helpers

**Files:**
- Create: `ObfuskoderKit/Sources/ObfuskoderKit/HTMLEscaping.swift`
- Test: `ObfuskoderKit/Tests/ObfuskoderKitTests/HTMLEscapingTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import ObfuskoderKit

@Test func escapesTextContent() {
    #expect(htmlEscapeText("a & b < c > d") == "a &amp; b &lt; c &gt; d")
    #expect(htmlEscapeText("plain") == "plain")
}

@Test func escapesAttributeContent() {
    #expect(htmlEscapeAttribute(#"say "hi" & <go>"#) == "say &quot;hi&quot; &amp; &lt;go&gt;")
}

@Test func percentEncodesSubjectLikeEncodeURIComponent() {
    #expect(percentEncodeComponent("Hello World & more") == "Hello%20World%20%26%20more")
    #expect(percentEncodeComponent("a-b_c.d~e") == "a-b_c.d~e")   // unreserved untouched
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "…/ObfuskoderKit" && swift test --filter Escap`
Expected: FAIL (cannot find helpers).

- [ ] **Step 3: Write the implementation**

```swift
import Foundation

func htmlEscapeText(_ s: String) -> String {
    s.replacingOccurrences(of: "&", with: "&amp;")
     .replacingOccurrences(of: "<", with: "&lt;")
     .replacingOccurrences(of: ">", with: "&gt;")
}

func htmlEscapeAttribute(_ s: String) -> String {
    htmlEscapeText(s).replacingOccurrences(of: "\"", with: "&quot;")
}

/// Equivalent to JS encodeURIComponent's unreserved set: A–Z a–z 0–9 - _ . ~
func percentEncodeComponent(_ s: String) -> String {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-_.~")
    return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd "…/ObfuskoderKit" && swift test --filter Escap`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add ObfuskoderKit/Sources/ObfuskoderKit/HTMLEscaping.swift ObfuskoderKit/Tests/ObfuskoderKitTests/HTMLEscapingTests.swift
git commit -m "feat(kit): add HTML/URL escaping helpers"
```

---

### Task 6: BasicFields + canonicalHTML

**Files:**
- Create: `ObfuskoderKit/Sources/ObfuskoderKit/BasicFields.swift`
- Test: `ObfuskoderKit/Tests/ObfuskoderKitTests/BasicFieldsTests.swift`

Implements SPEC §6.3 (canonical `<a>` HTML, optional subject/title, validation).

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import ObfuskoderKit

@Test func buildsFullAnchor() {
    let f = BasicFields(email: "user@example.com", linkText: "Email me",
                        linkTitle: "Contact", subject: "Hello there")
    #expect(f.canonicalHTML() ==
        #"<a href="mailto:user@example.com?subject=Hello%20there" title="Contact">Email me</a>"#)
}

@Test func omitsSubjectAndTitleWhenEmpty() {
    let f = BasicFields(email: "user@example.com", linkText: "Email me")
    #expect(f.canonicalHTML() == #"<a href="mailto:user@example.com">Email me</a>"#)
}

@Test func returnsNilWhenInvalid() {
    #expect(BasicFields(email: "bad", linkText: "x").canonicalHTML() == nil)        // bad email
    #expect(BasicFields(email: "user@example.com", linkText: "   ").canonicalHTML() == nil) // empty text
}

@Test func escapesTextAndTitleAndEncodesSubject() {
    let f = BasicFields(email: "user@example.com", linkText: "A & B <x>",
                        linkTitle: #"q"o"#, subject: "a & b")
    #expect(f.canonicalHTML() ==
        #"<a href="mailto:user@example.com?subject=a%20%26%20b" title="q&quot;o">A &amp; B &lt;x&gt;</a>"#)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "…/ObfuskoderKit" && swift test --filter BasicFields`
Expected: FAIL (cannot find `BasicFields`).

- [ ] **Step 3: Write the implementation**

```swift
import Foundation

public struct BasicFields: Codable, Equatable, Sendable {
    public var email: String
    public var linkText: String
    public var linkTitle: String
    public var subject: String

    public init(email: String = "", linkText: String = "",
                linkTitle: String = "", subject: String = "") {
        self.email = email
        self.linkText = linkText
        self.linkTitle = linkTitle
        self.subject = subject
    }

    /// Canonical `<a>` HTML, or nil when the email is invalid or link text is empty (SPEC §6.3).
    public func canonicalHTML() -> String? {
        let emailTrimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard EmailValidator.isValid(emailTrimmed) else { return nil }
        let text = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let title = linkTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let subj = subject.trimmingCharacters(in: .whitespacesAndNewlines)

        var href = "mailto:" + emailTrimmed
        if !subj.isEmpty { href += "?subject=" + percentEncodeComponent(subj) }

        var html = "<a href=\"" + htmlEscapeAttribute(href) + "\""
        if !title.isEmpty { html += " title=\"" + htmlEscapeAttribute(title) + "\"" }
        html += ">" + htmlEscapeText(text) + "</a>"
        return html
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd "…/ObfuskoderKit" && swift test --filter BasicFields`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add ObfuskoderKit/Sources/ObfuskoderKit/BasicFields.swift ObfuskoderKit/Tests/ObfuskoderKitTests/BasicFieldsTests.swift
git commit -m "feat(kit): add BasicFields and canonical HTML builder"
```

---

# Phase 2 — Encoder

### Task 7: RandomSource

**Files:**
- Create: `ObfuskoderKit/Sources/ObfuskoderKit/RandomSource.swift`
- Test: `ObfuskoderKit/Tests/ObfuskoderKitTests/RandomSourceTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import ObfuskoderKit

@Test func systemRandomStaysInRange() {
    let r = SystemRandomSource()
    for _ in 0..<200 {
        let v = r.int(in: 3...250)
        #expect(v >= 3 && v <= 250)
    }
}

@Test func scriptedRandomReturnsQueuedValuesInOrder() {
    let r = ScriptedRandom(ints: [7, 42, 1, 2, 3, 4, 5, 6], bools: [true, false])
    #expect(r.int(in: 0...999) == 7)
    #expect(r.bool() == true)
    #expect(r.int(in: 0...999) == 42)
    #expect(r.bool() == false)
}
```

> `ScriptedRandom` is a test-only helper. Define it in this test file (see Step 3b).

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "…/ObfuskoderKit" && swift test --filter Random`
Expected: FAIL (cannot find `SystemRandomSource` / `ScriptedRandom`).

- [ ] **Step 3a: Write the implementation**

```swift
public protocol RandomSource {
    func int(in range: ClosedRange<Int>) -> Int
    func bool() -> Bool
}

public struct SystemRandomSource: RandomSource {
    public init() {}
    public func int(in range: ClosedRange<Int>) -> Int { Int.random(in: range) }
    public func bool() -> Bool { Bool.random() }
}
```

- [ ] **Step 3b: Add the test helper to the test file**

Append to `RandomSourceTests.swift`:

```swift
final class ScriptedRandom: RandomSource {
    private var ints: [Int]
    private var bools: [Bool]
    private var intCursor = 0
    private var boolCursor = 0
    init(ints: [Int], bools: [Bool]) { self.ints = ints; self.bools = bools }
    func int(in range: ClosedRange<Int>) -> Int {
        defer { intCursor += 1 }
        return ints[intCursor]
    }
    func bool() -> Bool {
        defer { boolCursor += 1 }
        return bools[boolCursor]
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd "…/ObfuskoderKit" && swift test --filter Random`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add ObfuskoderKit/Sources/ObfuskoderKit/RandomSource.swift ObfuskoderKit/Tests/ObfuskoderKitTests/RandomSourceTests.swift
git commit -m "feat(kit): add RandomSource abstraction"
```

---

### Task 8: EncodeParameters + scalar encoding

**Files:**
- Create: `ObfuskoderKit/Sources/ObfuskoderKit/Encoder.swift`
- Test: `ObfuskoderKit/Tests/ObfuskoderKitTests/EncoderScalarTests.swift`

Implements the SPEC §7.2 transform: `n = (cp + k) [^ m]`, optional reverse. Decoder inverts: `cp = (n [^ m]) - k`.

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import ObfuskoderKit

@Test func encodesScalarsWithOffsetOnly() {
    let p = EncodeParameters(k: 5, mask: 0, reversed: false, id: "OBFUSKODER_aaaaaa")
    // "AB" -> [65+5, 66+5] = [70, 71]
    #expect(Encoder.encodeScalars("AB", with: p) == [70, 71])
}

@Test func encodesScalarsWithMaskThenReverse() {
    let p = EncodeParameters(k: 5, mask: 1, reversed: true, id: "OBFUSKODER_aaaaaa")
    // "AB": (65+5)^1=71, (66+5)^1=70 -> [71,70] reversed -> [70,71]
    #expect(Encoder.encodeScalars("AB", with: p) == [70, 71])
}

@Test func handlesNonBMPScalars() {
    let p = EncodeParameters(k: 3, mask: 0, reversed: false, id: "OBFUSKODER_aaaaaa")
    // "😀" is U+1F600 = 128512 -> 128515
    #expect(Encoder.encodeScalars("😀", with: p) == [128515])
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "…/ObfuskoderKit" && swift test --filter EncoderScalar`
Expected: FAIL (cannot find `EncodeParameters` / `Encoder`).

- [ ] **Step 3: Write the implementation**

```swift
import Foundation

struct EncodeParameters: Equatable {
    let k: Int          // [3, 250]
    let mask: Int       // 0 = no mask, else [1, 255]
    let reversed: Bool
    let id: String      // span id; script id = id + "_s"

    static func make(using random: RandomSource) -> EncodeParameters {
        let k = random.int(in: 3...250)
        let mask = random.bool() ? random.int(in: 1...255) : 0
        let reversed = random.bool()
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        var token = ""
        for _ in 0..<6 { token.append(alphabet[random.int(in: 0...(alphabet.count - 1))]) }
        return EncodeParameters(k: k, mask: mask, reversed: reversed, id: "OBFUSKODER_" + token)
    }
}

struct EncodedArtifact: Equatable {
    let html: String
    let spanID: String
    let scriptID: String
    let decoderJS: String
    let input: String
}

enum Encoder {
    static func encodeScalars(_ input: String, with p: EncodeParameters) -> [Int] {
        var nums = input.unicodeScalars.map { scalar -> Int in
            var n = Int(scalar.value) + p.k
            if p.mask != 0 { n = n ^ p.mask }
            return n
        }
        if p.reversed { nums.reverse() }
        return nums
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd "…/ObfuskoderKit" && swift test --filter EncoderScalar`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add ObfuskoderKit/Sources/ObfuskoderKit/Encoder.swift ObfuskoderKit/Tests/ObfuskoderKitTests/EncoderScalarTests.swift
git commit -m "feat(kit): add EncodeParameters, EncodedArtifact, scalar encoding"
```

---

### Task 9: EncodeParameters.make ordering

**Files:**
- Modify: `ObfuskoderKit/Sources/ObfuskoderKit/Encoder.swift` (already has `make`)
- Test: `ObfuskoderKit/Tests/ObfuskoderKitTests/EncodeParametersTests.swift`

- [ ] **Step 1: Write the failing test**

Reuses `ScriptedRandom` from `RandomSourceTests.swift` (same test target, so it is visible).

```swift
import Testing
@testable import ObfuskoderKit

@Test func makeConsumesRandomInExpectedOrder() {
    // order: k(int), maskFlag(bool), [maskVal(int)], reversed(bool), 6× token(int)
    let r = ScriptedRandom(ints: [100, 200, 0, 1, 2, 3, 4, 5], bools: [true, false])
    let p = EncodeParameters.make(using: r)
    #expect(p.k == 100)
    #expect(p.mask == 200)          // maskFlag true -> reads 200
    #expect(p.reversed == false)
    #expect(p.id == "OBFUSKODER_abcdef")  // ints 0,1,2,3,4,5 -> a,b,c,d,e,f
}

@Test func makeSkipsMaskValueWhenFlagFalse() {
    let r = ScriptedRandom(ints: [50, 0, 1, 2, 3, 4, 5], bools: [false, true])
    let p = EncodeParameters.make(using: r)
    #expect(p.k == 50)
    #expect(p.mask == 0)            // maskFlag false -> no mask, no int consumed
    #expect(p.reversed == true)
    #expect(p.id == "OBFUSKODER_abcdef")
}
```

- [ ] **Step 2: Run test to verify it fails or passes**

Run: `cd "…/ObfuskoderKit" && swift test --filter EncodeParameters`
Expected: PASS (the `make` implementation from Task 8 already satisfies this). If it FAILS, fix `make` so call order matches the test, then re-run.

- [ ] **Step 3: Commit**

```bash
git add ObfuskoderKit/Tests/ObfuskoderKitTests/EncodeParametersTests.swift
git commit -m "test(kit): lock EncodeParameters.make random ordering"
```

---

### Task 10: buildArtifact (snippet assembly)

**Files:**
- Modify: `ObfuskoderKit/Sources/ObfuskoderKit/Encoder.swift`
- Test: `ObfuskoderKit/Tests/ObfuskoderKitTests/BuildArtifactTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import ObfuskoderKit

@Test func buildsSnippetStructureWithoutAtSign() {
    let p = EncodeParameters(k: 5, mask: 0, reversed: false, id: "OBFUSKODER_test01")
    let art = Encoder.buildArtifact(input: #"<a href="mailto:user@example.com">Email me</a>"#,
                                    parameters: p,
                                    fallbackMessage: "Enable JavaScript to view email")
    #expect(art.spanID == "OBFUSKODER_test01")
    #expect(art.scriptID == "OBFUSKODER_test01_s")
    #expect(art.html.contains(#"<span id="OBFUSKODER_test01">Enable JavaScript to view email</span>"#))
    #expect(art.html.contains(#"<script id="OBFUSKODER_test01_s">"#))
    #expect(art.html.hasSuffix("</script>"))
    #expect(!art.html.contains("@"))                 // ENC-3 by construction
    #expect(!art.html.contains("user@example.com"))  // ENC-2 by construction
    #expect(art.input == #"<a href="mailto:user@example.com">Email me</a>"#)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "…/ObfuskoderKit" && swift test --filter BuildArtifact`
Expected: FAIL (cannot find `Encoder.buildArtifact`).

- [ ] **Step 3: Add `buildArtifact` and `makeArtifact` to `enum Encoder`**

Add inside `enum Encoder { … }`:

```swift
    static func buildArtifact(input: String,
                              parameters p: EncodeParameters,
                              fallbackMessage: String) -> EncodedArtifact {
        let nums = encodeScalars(input, with: p)
        let numbers = nums.map(String.init).joined(separator: ",")
        let spanID = p.id
        let scriptID = p.id + "_s"
        let r = p.reversed ? 1 : 0

        let decoderJS =
            "(function(){var d=[\(numbers)];var k=\(p.k),m=\(p.mask),r=\(r);" +
            "if(r)d.reverse();var s=\"\";for(var i=0;i<d.length;i++){var n=d[i];" +
            "if(m)n=n^m;n=n-k;s+=String.fromCodePoint(n);}" +
            "var el=document.getElementById(\"\(spanID)\");if(el){el.outerHTML=s;}" +
            "var sc=document.getElementById(\"\(scriptID)\");" +
            "if(sc&&sc.parentNode){sc.parentNode.removeChild(sc);}})();"

        let html =
            "<span id=\"\(spanID)\">\(fallbackMessage)</span>" +
            "<script id=\"\(scriptID)\">\(decoderJS)</script>"

        return EncodedArtifact(html: html, spanID: spanID, scriptID: scriptID,
                               decoderJS: decoderJS, input: input)
    }

    static func makeArtifact(input: String,
                             fallbackMessage: String,
                             random: RandomSource) -> EncodedArtifact {
        buildArtifact(input: input,
                      parameters: EncodeParameters.make(using: random),
                      fallbackMessage: fallbackMessage)
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd "…/ObfuskoderKit" && swift test --filter BuildArtifact`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ObfuskoderKit/Sources/ObfuskoderKit/Encoder.swift ObfuskoderKit/Tests/ObfuskoderKitTests/BuildArtifactTests.swift
git commit -m "feat(kit): assemble AJAX-safe snippet in buildArtifact"
```

---

# Phase 3 — Self-check (ENC-1/2/3)

### Task 11: String-property checks (ENC-2, ENC-3)

**Files:**
- Create: `ObfuskoderKit/Sources/ObfuskoderKit/SelfCheck.swift`
- Test: `ObfuskoderKit/Tests/ObfuskoderKitTests/SelfCheckStringTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import ObfuskoderKit

@Test func passesCleanArtifact() throws {
    let p = EncodeParameters(k: 7, mask: 0, reversed: false, id: "OBFUSKODER_clean1")
    let art = Encoder.buildArtifact(input: #"<a href="mailto:user@example.com">hi</a>"#,
                                    parameters: p, fallbackMessage: "Enable JavaScript to view email")
    try SelfCheck.verifyStringProperties(art, email: "user@example.com")  // no throw
}

@Test func throwsOnAtSign() {
    let p = EncodeParameters(k: 7, mask: 0, reversed: false, id: "OBFUSKODER_atsign")
    let art = Encoder.buildArtifact(input: "hello", parameters: p, fallbackMessage: "ping@pong")
    #expect(throws: SelfCheckError.atSignPresent) {
        try SelfCheck.verifyStringProperties(art, email: nil)
    }
}

@Test func throwsOnPlaintextLeak() {
    // Hand-built artifact whose html contains the input verbatim.
    let art = EncodedArtifact(html: "<span>leak: secret-input</span>",
                              spanID: "x", scriptID: "x_s", decoderJS: "", input: "secret-input")
    #expect(throws: SelfCheckError.plaintextLeak) {
        try SelfCheck.verifyStringProperties(art, email: nil)
    }
}

@Test func throwsWhenEmailAppears() {
    let art = EncodedArtifact(html: "<span>contact user@example.com</span>",
                              spanID: "x", scriptID: "x_s", decoderJS: "", input: "unrelated")
    #expect(throws: SelfCheckError.plaintextLeak) {
        try SelfCheck.verifyStringProperties(art, email: "user@example.com")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "…/ObfuskoderKit" && swift test --filter SelfCheckString`
Expected: FAIL (cannot find `SelfCheck` / `SelfCheckError`).

- [ ] **Step 3: Write the implementation**

```swift
import Foundation

public enum SelfCheckError: Error, Equatable {
    case plaintextLeak
    case atSignPresent
    case roundTripMismatch(recovered: String)
    case engineError(String)
}

enum SelfCheck {
    /// ENC-2 + ENC-3 (SPEC §7.3).
    static func verifyStringProperties(_ artifact: EncodedArtifact, email: String?) throws {
        if artifact.html.contains("@") { throw SelfCheckError.atSignPresent }            // ENC-3
        if artifact.html.contains(artifact.input) { throw SelfCheckError.plaintextLeak } // ENC-2
        if let email, !email.isEmpty, artifact.html.contains(email) {                    // ENC-2
            throw SelfCheckError.plaintextLeak
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd "…/ObfuskoderKit" && swift test --filter SelfCheckString`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add ObfuskoderKit/Sources/ObfuskoderKit/SelfCheck.swift ObfuskoderKit/Tests/ObfuskoderKitTests/SelfCheckStringTests.swift
git commit -m "feat(kit): self-check ENC-2/ENC-3 string properties"
```

---

### Task 12: Round-trip check via JavaScriptCore (ENC-1)

**Files:**
- Modify: `ObfuskoderKit/Sources/ObfuskoderKit/SelfCheck.swift`
- Test: `ObfuskoderKit/Tests/ObfuskoderKitTests/SelfCheckRoundTripTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import ObfuskoderKit

private func roundTrips(_ input: String, k: Int, mask: Int, reversed: Bool) throws {
    let p = EncodeParameters(k: k, mask: mask, reversed: reversed, id: "OBFUSKODER_rt0001")
    let art = Encoder.buildArtifact(input: input, parameters: p,
                                    fallbackMessage: "Enable JavaScript to view email")
    try SelfCheck.verifyRoundTrip(art)   // throws on mismatch
}

@Test func roundTripsSimpleAnchor() throws {
    try roundTrips(#"<a href="mailto:user@example.com">Email me</a>"#, k: 9, mask: 0, reversed: false)
}

@Test func roundTripsWithMaskAndReverse() throws {
    try roundTrips(#"<a href="mailto:user@example.com" title="hi">Email me</a>"#, k: 200, mask: 137, reversed: true)
}

@Test func roundTripsUnicodeAndMultiTag() throws {
    try roundTrips("<p>Hi 😀 <strong>bold</strong> &amp; more</p>", k: 17, mask: 42, reversed: true)
}

@Test func detectsBrokenDecoder() {
    // Artifact whose decoder yields the wrong string.
    let art = EncodedArtifact(
        html: #"<span id="OBFUSKODER_bad001">f</span><script id="OBFUSKODER_bad001_s">(function(){var el=document.getElementById("OBFUSKODER_bad001");if(el){el.outerHTML="WRONG";}})();</script>"#,
        spanID: "OBFUSKODER_bad001", scriptID: "OBFUSKODER_bad001_s",
        decoderJS: #"(function(){var el=document.getElementById("OBFUSKODER_bad001");if(el){el.outerHTML="WRONG";}})();"#,
        input: "RIGHT")
    #expect(throws: (any Error).self) { try SelfCheck.verifyRoundTrip(art) }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "…/ObfuskoderKit" && swift test --filter SelfCheckRoundTrip`
Expected: FAIL (cannot find `SelfCheck.verifyRoundTrip`).

- [ ] **Step 3: Add the JavaScriptCore round-trip check**

Add to `enum SelfCheck`:

```swift
    /// ENC-1: execute the decoder against a faked `document` in JavaScriptCore and
    /// confirm the recovered string equals the input verbatim (SPEC §7.3).
    static func verifyRoundTrip(_ artifact: EncodedArtifact) throws {
        guard let context = JSContext() else {
            throw SelfCheckError.engineError("could not create JSContext")
        }
        var thrown: String?
        context.exceptionHandler = { _, value in thrown = value?.toString() }

        let harness = """
        var __captured = null;
        var document = {
            _e: {},
            getElementById: function(id) { return this._e[id] || null; }
        };
        document._e["\(artifact.spanID)"] = {
            set outerHTML(v) { __captured = v; },
            get outerHTML() { return ""; }
        };
        document._e["\(artifact.scriptID)"] = { parentNode: { removeChild: function() {} } };
        \(artifact.decoderJS)
        __captured;
        """

        let result = context.evaluateScript(harness)
        if let thrown { throw SelfCheckError.engineError(thrown) }
        let recovered = (result?.isNull == true) ? "" : (result?.toString() ?? "")
        if recovered != artifact.input {
            throw SelfCheckError.roundTripMismatch(recovered: recovered)
        }
    }
```

Add `import JavaScriptCore` at the top of `SelfCheck.swift` (keep the existing `import Foundation`).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd "…/ObfuskoderKit" && swift test --filter SelfCheckRoundTrip`
Expected: PASS (4 tests).
If you hit a linker error for JavaScriptCore, confirm `linkerSettings: [.linkedFramework("JavaScriptCore")]` is present in `Package.swift` (Task 1).

- [ ] **Step 5: Commit**

```bash
git add ObfuskoderKit/Sources/ObfuskoderKit/SelfCheck.swift ObfuskoderKit/Tests/ObfuskoderKitTests/SelfCheckRoundTripTests.swift
git commit -m "feat(kit): ENC-1 round-trip self-check via JavaScriptCore"
```

---

### Task 13: Combined verify

**Files:**
- Modify: `ObfuskoderKit/Sources/ObfuskoderKit/SelfCheck.swift`
- Test: `ObfuskoderKit/Tests/ObfuskoderKitTests/SelfCheckVerifyTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import ObfuskoderKit

@Test func verifyRunsAllThreeChecks() throws {
    let p = EncodeParameters(k: 11, mask: 99, reversed: true, id: "OBFUSKODER_all001")
    let art = Encoder.buildArtifact(input: #"<a href="mailto:user@example.com">Email me</a>"#,
                                    parameters: p, fallbackMessage: "Enable JavaScript to view email")
    try SelfCheck.verify(art, email: "user@example.com")  // no throw
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "…/ObfuskoderKit" && swift test --filter SelfCheckVerify`
Expected: FAIL (cannot find `SelfCheck.verify`).

- [ ] **Step 3: Add `verify`**

```swift
    /// ENC-1 + ENC-2 + ENC-3.
    static func verify(_ artifact: EncodedArtifact, email: String?) throws {
        try verifyStringProperties(artifact, email: email)
        try verifyRoundTrip(artifact)
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd "…/ObfuskoderKit" && swift test --filter SelfCheckVerify`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ObfuskoderKit/Sources/ObfuskoderKit/SelfCheck.swift ObfuskoderKit/Tests/ObfuskoderKitTests/SelfCheckVerifyTests.swift
git commit -m "feat(kit): combined ENC-1/2/3 verify"
```

---

# Phase 4 — Engine

### Task 14: ObfuskodeEngine.encode

**Files:**
- Create: `ObfuskoderKit/Sources/ObfuskoderKit/ObfuskodeEngine.swift`
- Test: `ObfuskoderKit/Tests/ObfuskoderKitTests/ObfuskodeEngineTests.swift`

Implements SPEC §7.3 retry loop and the public `Snippet`.

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import ObfuskoderKit

@Test func encodeProducesValidSnippet() throws {
    let engine = ObfuskodeEngine(fallbackMessage: "Enable JavaScript to view email")
    let input = #"<a href="mailto:user@example.com">Email me</a>"#
    let snippet = try engine.encode(input, email: "user@example.com")
    #expect(snippet.decodedSource == input)
    #expect(!snippet.html.contains("@"))
    #expect(!snippet.html.contains("user@example.com"))
    #expect(snippet.html.contains("<script"))
}

@Test func encodeIsNonDeterministic() throws {
    let engine = ObfuskodeEngine(fallbackMessage: "Enable JavaScript to view email")
    let input = #"<a href="mailto:user@example.com">Email me</a>"#
    let a = try engine.encode(input, email: "user@example.com")
    let b = try engine.encode(input, email: "user@example.com")
    #expect(a.html != b.html)   // ENC-6 (random seed per encode)
}

@Test func encodeRoundTripsFiftyRandomInputs() throws {
    let engine = ObfuskodeEngine(fallbackMessage: "Enable JavaScript to view email")
    for i in 0..<50 {
        let input = #"<a href="mailto:user\#(i)@example.com" title="t\#(i)">Email \#(i) 😀</a>"#
        let snippet = try engine.encode(input, email: "user\(i)@example.com")
        // Re-verify the produced snippet independently.
        let art = EncodedArtifact(html: snippet.html, spanID: "", scriptID: "",
                                  decoderJS: extractDecoder(from: snippet.html), input: input)
        try SelfCheck.verifyRoundTrip(art)
    }
}

// Helper: pull the IIFE out of the snippet for independent re-verification.
private func extractDecoder(from html: String) -> String {
    guard let open = html.range(of: "<script"),
          let gt = html.range(of: ">", range: open.upperBound..<html.endIndex),
          let close = html.range(of: "</script>", range: gt.upperBound..<html.endIndex)
    else { return "" }
    return String(html[gt.upperBound..<close.lowerBound])
}
```

> Note: `verifyRoundTrip` reads `spanID`/`scriptID` only via the decoder's own embedded ids, so the empty ids on the re-built artifact are fine — the decoder string contains the real ids.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "…/ObfuskoderKit" && swift test --filter ObfuskodeEngine`
Expected: FAIL (cannot find `ObfuskodeEngine`).

- [ ] **Step 3: Write the implementation**

```swift
import Foundation

public struct Snippet: Equatable, Sendable {
    public let html: String
    public let decodedSource: String
    public init(html: String, decodedSource: String) {
        self.html = html
        self.decodedSource = decodedSource
    }
}

public enum ObfuskodeError: Error, Equatable {
    case selfCheckFailedRepeatedly
}

public struct ObfuskodeEngine: Sendable {
    public var fallbackMessage: String
    public var maxAttempts: Int

    public init(fallbackMessage: String, maxAttempts: Int = AppConfig.maxSelfCheckAttempts) {
        self.fallbackMessage = fallbackMessage
        self.maxAttempts = maxAttempts
    }

    /// Encode `input` to a verified snippet. `email` (when non-nil) is also checked for leakage.
    public func encode(_ input: String,
                       email: String? = nil,
                       random: RandomSource = SystemRandomSource()) throws -> Snippet {
        for _ in 0..<maxAttempts {
            let art = Encoder.makeArtifact(input: input, fallbackMessage: fallbackMessage, random: random)
            do {
                try SelfCheck.verify(art, email: email)
                return Snippet(html: art.html, decodedSource: input)
            } catch {
                continue   // extremely rare random-id collision; retry
            }
        }
        throw ObfuskodeError.selfCheckFailedRepeatedly
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd "…/ObfuskoderKit" && swift test --filter ObfuskodeEngine`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add ObfuskoderKit/Sources/ObfuskoderKit/ObfuskodeEngine.swift ObfuskoderKit/Tests/ObfuskoderKitTests/ObfuskodeEngineTests.swift
git commit -m "feat(kit): ObfuskodeEngine with verified retry loop"
```

---

# Phase 5 — Form state & presets

### Task 15: FormState (pure form→input mapping)

**Files:**
- Create: `ObfuskoderKit/Sources/ObfuskoderKit/FormState.swift`
- Test: `ObfuskoderKit/Tests/ObfuskoderKitTests/FormStateTests.swift`

Depends on `Preset`/`PresetPayload` (Task 16) for `apply`. To keep tasks ordered, **define `apply(_:)` in Task 16** after the preset types exist. This task implements everything else.

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import ObfuskoderKit

@Test func basicModeInputAndEmail() {
    var s = FormState()
    s.mode = .basic
    s.basic = BasicFields(email: "user@example.com", linkText: "Email me")
    #expect(s.canonicalInput == #"<a href="mailto:user@example.com">Email me</a>"#)
    #expect(s.emailForSelfCheck == "user@example.com")
}

@Test func basicModeInvalidYieldsNilInput() {
    var s = FormState()
    s.mode = .basic
    s.basic = BasicFields(email: "bad", linkText: "x")
    #expect(s.canonicalInput == nil)
    #expect(s.emailForSelfCheck == nil)
}

@Test func advancedModeUsesTrimmedTextAndNilEmail() {
    var s = FormState()
    s.mode = .advanced
    s.advanced = "  <b>hi</b>  "
    #expect(s.canonicalInput == "<b>hi</b>")
    #expect(s.emailForSelfCheck == nil)
}

@Test func activeIsEmptyTracksActiveModeOnly() {
    var s = FormState()
    s.mode = .basic
    #expect(s.activeIsEmpty)
    s.basic.email = "x"
    #expect(!s.activeIsEmpty)
    s.mode = .advanced
    #expect(s.activeIsEmpty)         // advanced empty even though basic has data
}

@Test func clearActiveClearsOnlyActiveMode() {
    var s = FormState()
    s.mode = .basic
    s.basic = BasicFields(email: "user@example.com", linkText: "Email me")
    s.advanced = "keep me"
    s.clearActive()
    #expect(s.basic == BasicFields())
    #expect(s.advanced == "keep me")  // untouched
}

@Test func payloadReflectsActiveMode() {
    var s = FormState()
    s.mode = .advanced
    s.advanced = "<i>x</i>"
    #expect(s.payload() == .advanced("<i>x</i>"))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "…/ObfuskoderKit" && swift test --filter FormState`
Expected: FAIL (cannot find `FormState`). The `payloadReflectsActiveMode` test also needs `PresetPayload` (Task 16); it will fail to compile until then — that is expected and resolved in Task 16. For now, **comment out `payloadReflectsActiveMode` and `s.payload()`/`apply` references**, get the rest green, then restore them in Task 16.

- [ ] **Step 3: Write the implementation (without `apply`/`payload` referencing presets yet)**

```swift
import Foundation

public struct FormState: Equatable, Sendable {
    public var mode: FormMode
    public var basic: BasicFields
    public var advanced: String

    public init(mode: FormMode = .basic,
                basic: BasicFields = BasicFields(),
                advanced: String = "") {
        self.mode = mode
        self.basic = basic
        self.advanced = advanced
    }

    /// The HTML to encode for the active mode, or nil when the active form is invalid/empty.
    public var canonicalInput: String? {
        switch mode {
        case .basic:
            return basic.canonicalHTML()
        case .advanced:
            let trimmed = advanced.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    /// The email to leak-check (basic mode only, when valid).
    public var emailForSelfCheck: String? {
        guard mode == .basic else { return nil }
        let trimmed = basic.email.trimmingCharacters(in: .whitespacesAndNewlines)
        return EmailValidator.isValid(trimmed) ? trimmed : nil
    }

    public var activeIsEmpty: Bool {
        switch mode {
        case .basic:
            return basic == BasicFields()
        case .advanced:
            return advanced.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    public mutating func clearActive() {
        switch mode {
        case .basic: basic = BasicFields()
        case .advanced: advanced = ""
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd "…/ObfuskoderKit" && swift test --filter FormState`
Expected: PASS (the non-preset tests).

- [ ] **Step 5: Commit**

```bash
git add ObfuskoderKit/Sources/ObfuskoderKit/FormState.swift ObfuskoderKit/Tests/ObfuskoderKitTests/FormStateTests.swift
git commit -m "feat(kit): add FormState input mapping"
```

---

### Task 16: Preset model + FormState payload/apply

**Files:**
- Create: `ObfuskoderKit/Sources/ObfuskoderKit/Preset.swift`
- Modify: `ObfuskoderKit/Sources/ObfuskoderKit/FormState.swift` (add `payload()` and `apply(_:)`)
- Test: `ObfuskoderKit/Tests/ObfuskoderKitTests/PresetTests.swift`
- Modify: `ObfuskoderKit/Tests/ObfuskoderKitTests/FormStateTests.swift` (restore commented tests)

- [ ] **Step 1: Write the failing test**

`PresetTests.swift`:

```swift
import Testing
import Foundation
@testable import ObfuskoderKit

@Test func presetPayloadCodableRoundTrip() throws {
    let payloads: [PresetPayload] = [
        .basic(BasicFields(email: "user@example.com", linkText: "Email me")),
        .advanced("<b>hi</b>")
    ]
    for payload in payloads {
        let preset = Preset(id: UUID(), name: "n", payload: payload)
        let data = try JSONEncoder().encode(preset)
        let back = try JSONDecoder().decode(Preset.self, from: data)
        #expect(back == preset)
    }
}

@Test func applyBasicPresetSwitchesModeAndFills() {
    var s = FormState()
    s.mode = .advanced
    s.apply(Preset(id: UUID(), name: "p",
                   payload: .basic(BasicFields(email: "user@example.com", linkText: "Email me"))))
    #expect(s.mode == .basic)
    #expect(s.basic.email == "user@example.com")
}

@Test func applyAdvancedPresetSwitchesModeAndFills() {
    var s = FormState()
    s.apply(Preset(id: UUID(), name: "p", payload: .advanced("<i>x</i>")))
    #expect(s.mode == .advanced)
    #expect(s.advanced == "<i>x</i>")
}
```

Also **restore** `payloadReflectsActiveMode` (and the `s.payload()` reference) in `FormStateTests.swift`.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "…/ObfuskoderKit" && swift test --filter "Preset|FormState"`
Expected: FAIL (cannot find `Preset` / `PresetPayload` / `payload()` / `apply`).

- [ ] **Step 3a: Write `Preset.swift`**

```swift
import Foundation

public enum PresetPayload: Codable, Equatable, Sendable {
    case basic(BasicFields)
    case advanced(String)
}

public struct Preset: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var payload: PresetPayload
    public init(id: UUID = UUID(), name: String, payload: PresetPayload) {
        self.id = id
        self.name = name
        self.payload = payload
    }
}
```

- [ ] **Step 3b: Add `payload()` and `apply(_:)` to `FormState`**

```swift
    /// Snapshot of the active mode's values (SPEC §6.7).
    public func payload() -> PresetPayload {
        switch mode {
        case .basic: return .basic(basic)
        case .advanced: return .advanced(advanced)
        }
    }

    /// Restore the form to a saved preset's state.
    public mutating func apply(_ preset: Preset) {
        switch preset.payload {
        case .basic(let fields):
            mode = .basic
            basic = fields
        case .advanced(let text):
            mode = .advanced
            advanced = text
        }
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd "…/ObfuskoderKit" && swift test --filter "Preset|FormState"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ObfuskoderKit/Sources/ObfuskoderKit/Preset.swift ObfuskoderKit/Sources/ObfuskoderKit/FormState.swift ObfuskoderKit/Tests/ObfuskoderKitTests/PresetTests.swift ObfuskoderKit/Tests/ObfuskoderKitTests/FormStateTests.swift
git commit -m "feat(kit): add Preset model and FormState payload/apply"
```

---

### Task 17: PresetStore (persistence + CRUD)

**Files:**
- Create: `ObfuskoderKit/Sources/ObfuskoderKit/PresetStore.swift`
- Test: `ObfuskoderKit/Tests/ObfuskoderKitTests/PresetStoreTests.swift`

Implements SPEC §6.7 (unique names, save/replace/rename/delete/reorder, JSON persistence).

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import Foundation
@testable import ObfuskoderKit

@MainActor
private func tempStore() -> (PresetStore, URL) {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("obfuskoder-tests-\(UUID().uuidString)", isDirectory: true)
    let url = dir.appendingPathComponent("presets.json")
    return (PresetStore(fileURL: url), url)
}

@MainActor @Test func savesWithUniqueName() throws {
    let (store, _) = tempStore()
    let p = try store.save(name: "Personal", payload: .advanced("<b>hi</b>"))
    #expect(store.presets.count == 1)
    #expect(store.presets.first == p)
}

@MainActor @Test func rejectsDuplicateName() throws {
    let (store, _) = tempStore()
    _ = try store.save(name: "Dup", payload: .advanced("a"))
    #expect(throws: PresetError.duplicateName("Dup")) {
        _ = try store.save(name: "Dup", payload: .advanced("b"))
    }
}

@MainActor @Test func replaceUpdatesExisting() throws {
    let (store, _) = tempStore()
    let p = try store.save(name: "P", payload: .advanced("a"))
    try store.replace(id: p.id, name: "P", payload: .advanced("b"))
    #expect(store.presets.first?.payload == .advanced("b"))
}

@MainActor @Test func renameAndDelete() throws {
    let (store, _) = tempStore()
    let p = try store.save(name: "Old", payload: .advanced("a"))
    try store.rename(id: p.id, to: "New")
    #expect(store.presets.first?.name == "New")
    try store.delete(id: p.id)
    #expect(store.presets.isEmpty)
}

@MainActor @Test func renameToExistingNameThrows() throws {
    let (store, _) = tempStore()
    _ = try store.save(name: "A", payload: .advanced("a"))
    let b = try store.save(name: "B", payload: .advanced("b"))
    #expect(throws: PresetError.duplicateName("A")) {
        try store.rename(id: b.id, to: "A")
    }
}

@MainActor @Test func persistsAcrossReload() throws {
    let (store, url) = tempStore()
    _ = try store.save(name: "Keep", payload: .advanced("data"))
    let reloaded = PresetStore(fileURL: url)
    #expect(reloaded.presets.count == 1)
    #expect(reloaded.presets.first?.name == "Keep")
}

@MainActor @Test func reordersPresets() throws {
    let (store, _) = tempStore()
    _ = try store.save(name: "1", payload: .advanced("a"))
    _ = try store.save(name: "2", payload: .advanced("b"))
    store.move(fromOffsets: IndexSet(integer: 0), toOffset: 2)
    #expect(store.presets.map(\.name) == ["2", "1"])
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "…/ObfuskoderKit" && swift test --filter PresetStore`
Expected: FAIL (cannot find `PresetStore` / `PresetError`).

- [ ] **Step 3: Write the implementation**

```swift
import Foundation
import Observation

public enum PresetError: Error, Equatable {
    case duplicateName(String)
    case notFound
}

@MainActor
@Observable
public final class PresetStore {
    public private(set) var presets: [Preset] = []
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
        load()
    }

    public func save(name: String, payload: PresetPayload) throws -> Preset {
        try ensureNameAvailable(name, excluding: nil)
        let preset = Preset(name: name, payload: payload)
        presets.append(preset)
        try persist()
        return preset
    }

    public func replace(id: UUID, name: String, payload: PresetPayload) throws {
        guard let idx = presets.firstIndex(where: { $0.id == id }) else { throw PresetError.notFound }
        try ensureNameAvailable(name, excluding: id)
        presets[idx].name = name
        presets[idx].payload = payload
        try persist()
    }

    public func rename(id: UUID, to newName: String) throws {
        guard let idx = presets.firstIndex(where: { $0.id == id }) else { throw PresetError.notFound }
        try ensureNameAvailable(newName, excluding: id)
        presets[idx].name = newName
        try persist()
    }

    public func delete(id: UUID) throws {
        guard let idx = presets.firstIndex(where: { $0.id == id }) else { throw PresetError.notFound }
        presets.remove(at: idx)
        try persist()
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        presets.move(fromOffsets: source, toOffset: destination)
        try? persist()
    }

    public func nameExists(_ name: String) -> Bool {
        presets.contains { $0.name == name }
    }

    private func ensureNameAvailable(_ name: String, excluding id: UUID?) throws {
        if presets.contains(where: { $0.name == name && $0.id != id }) {
            throw PresetError.duplicateName(name)
        }
    }

    private func persist() throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(presets)
        try data.write(to: fileURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Preset].self, from: data) else { return }
        presets = decoded
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd "…/ObfuskoderKit" && swift test --filter PresetStore`
Expected: PASS (7 tests).

- [ ] **Step 5: Run the FULL package suite**

Run: `cd "/Users/alderete/Developer/_Projects/Obfuskoder/Obfuskoder Mac/ObfuskoderKit" && swift test`
Expected: PASS (all tests). This closes out the package layer.

- [ ] **Step 6: Commit**

```bash
git add ObfuskoderKit/Sources/ObfuskoderKit/PresetStore.swift ObfuskoderKit/Tests/ObfuskoderKitTests/PresetStoreTests.swift
git commit -m "feat(kit): add PresetStore with persistence and CRUD"
```

---

# Phase 6 — App project setup

> From here, tasks touch the Xcode app target. There is no unit-test target, so verification is **building** (and at the end, **running**) the app. All testable logic is already covered by the package.

### Task 18: Fix deployment target and link the package

**Files:**
- Modify: `Obfuskoder.xcodeproj` (build setting + package dependency — done in Xcode UI)

- [ ] **Step 1: Lower the deployment target to macOS 14**

In Xcode: select the **Obfuskoder** project → **Obfuskoder** target → **General** → **Minimum Deployments** → set macOS to **14.0**.
(Equivalent build setting: `MACOSX_DEPLOYMENT_TARGET = 14.0`, currently `26.5`.)

- [ ] **Step 2: Add the local package**

In Xcode: **File ▸ Add Package Dependencies… ▸ Add Local…** → choose the `ObfuskoderKit` folder → add the **ObfuskoderKit** library product to the **Obfuskoder** target.

- [ ] **Step 3: Verify it links**

Add a temporary import to confirm. Edit `Obfuskoder/ObfuskoderApp.swift` and add `import ObfuskoderKit` under `import SwiftUI`, then build.

Run: `cd "/Users/alderete/Developer/_Projects/Obfuskoder/Obfuskoder Mac" && xcodebuild -scheme Obfuskoder -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add Obfuskoder.xcodeproj Obfuskoder/ObfuskoderApp.swift
git commit -m "build(app): target macOS 14 and link ObfuskoderKit"
```

---

### Task 19: AccentColor (dusty sage, light + dark)

**Files:**
- Modify: `Obfuskoder/Assets.xcassets/AccentColor.colorset/Contents.json`

- [ ] **Step 1: Write the color set (sRGB #5E7C50 with a slightly lighter dark-mode variant)**

```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : { "alpha" : "1.000", "blue" : "0.314", "green" : "0.486", "red" : "0.369" }
      },
      "idiom" : "universal"
    },
    {
      "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
      "color" : {
        "color-space" : "srgb",
        "components" : { "alpha" : "1.000", "blue" : "0.380", "green" : "0.560", "red" : "0.440" }
      },
      "idiom" : "universal"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

> Light components are #5E7C50 (94/124/80 → 0.369/0.486/0.314). The dark variant is a lifted sibling for contrast on dark backgrounds.

- [ ] **Step 2: Build**

Run: `cd "…/Obfuskoder Mac" && xcodebuild -scheme Obfuskoder -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Obfuskoder/Assets.xcassets/AccentColor.colorset/Contents.json
git commit -m "feat(app): set dusty-sage accent for light and dark"
```

---

### Task 20: Strings + SettingsKeys

**Files:**
- Create: `Obfuskoder/Strings.swift`
- Create: `Obfuskoder/SettingsKeys.swift`

> The String Catalog (`Localizable.xcstrings`) is created in Xcode (**File ▸ New ▸ File ▸ String Catalog**). `String(localized:)` works without it (keys fall back to their default value), so the app builds before the catalog exists; add the catalog any time to start translating. SPEC §9.5.

- [ ] **Step 1: Write `SettingsKeys.swift`**

```swift
enum SettingsKeys {
    static let debounceSeconds = "debounceSeconds"
    static let fallbackMessage = "fallbackMessage"
}
```

- [ ] **Step 2: Write `Strings.swift`** (every user-facing label routed here; "Saved values" is the working title)

```swift
import SwiftUI

enum UIStrings {
    static let appName = String(localized: "Obfuskoder")

    // Mode
    static let basic = String(localized: "Basic")
    static let advanced = String(localized: "Advanced")

    // Basic fields
    static let emailLabel = String(localized: "Email address")
    static let linkTextLabel = String(localized: "Link text")
    static let linkTitleLabel = String(localized: "Link title")
    static let subjectLabel = String(localized: "Subject")
    static let optional = String(localized: "optional")

    // Hints (SPEC §6.3)
    static let emailHint = String(localized: "The email address to be obfuskoded.")
    static let linkTextHint = String(localized: "The text users will see and click. Also obfuskoded, so you can repeat your email address.")
    static let linkTitleHint = String(localized: "Pop-up message seen when the mouse hovers over the link.")
    static let subjectHint = String(localized: "A pre-set subject line for the email. Supported by most email clients.")
    static let advancedLabel = String(localized: "HTML to obfuskode")
    static let advancedHint = String(localized: "Paste arbitrary HTML. Whatever you enter will round-trip through Obfuskoder verbatim. (Surrounding whitespace is trimmed.)")

    // Result
    static let snippetHeading = String(localized: "Obfuskoded snippet")
    static let updatesAsYouType = String(localized: "updates as you type")
    static let copy = String(localized: "Copy")
    static let copied = String(localized: "Copied")
    static let previewHeading = String(localized: "Preview")
    static let showDecodedSource = String(localized: "Show decoded source")
    static let emptyResult = String(localized: "Enter a valid email or HTML to generate a snippet.")
    static let encodeFailed = String(localized: "Could not generate a valid snippet. Check your input.")

    // Saved values (working label)
    static let savedValues = String(localized: "Saved values")
    static let saveCurrentValues = String(localized: "Save Current Values…")
    static let manageSavedValues = String(localized: "Manage Saved Values…")
    static let clearForm = String(localized: "Clear Form")

    // Sheets
    static let presetNamePrompt = String(localized: "Name for these values:")
    static let presetNameDuplicate = String(localized: "A saved set with that name already exists.")
    static let replace = String(localized: "Replace")
    static let save = String(localized: "Save")
    static let cancel = String(localized: "Cancel")
    static let delete = String(localized: "Delete")
    static let done = String(localized: "Done")

    // Settings
    static let settingsEncodingDelay = String(localized: "Encoding delay")
    static let settingsFallbackMessage = String(localized: "No-JavaScript fallback message")

    // Helpers
    static func hintAccessibilityLabel(for field: String) -> String {
        String(localized: "\(field) help")
    }
}
```

- [ ] **Step 3: Build**

Run: `cd "…/Obfuskoder Mac" && xcodebuild -scheme Obfuskoder -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add Obfuskoder/Strings.swift Obfuskoder/SettingsKeys.swift
git commit -m "feat(app): centralize UI strings and settings keys"
```

---

# Phase 7 — AppKit-backed text fields (Mac hygiene)

### Task 21: MacTextField (single-line, no substitutions)

**Files:**
- Create: `Obfuskoder/Views/MacTextField.swift`

Implements SPEC §10 "native text-field hygiene": smart quotes/dashes/auto-replace and spell correction disabled.

- [ ] **Step 1: Write the file**

```swift
import SwiftUI
import AppKit

/// NSTextField wrapper that disables macOS text substitutions so emails/HTML are never mangled.
struct MacTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var onChange: () -> Void = {}

    func makeNSView(context: Context) -> NSTextField {
        let field = NoSubstitutionTextField()
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.isBordered = true
        field.bezelStyle = .roundedBezel
        field.focusRingType = .default
        field.lineBreakMode = .byClipping
        field.usesSingleLineMode = true
        field.cell?.sendsActionOnEndEditing = true
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text { nsView.stringValue = text }
        nsView.placeholderString = placeholder
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: MacTextField
        init(_ parent: MacTextField) { self.parent = parent }
        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
            parent.onChange()
        }
    }
}

/// Configures the shared field editor to turn off substitutions when this field gains focus.
final class NoSubstitutionTextField: NSTextField {
    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if let editor = currentEditor() as? NSTextView {
            editor.isAutomaticQuoteSubstitutionEnabled = false
            editor.isAutomaticDashSubstitutionEnabled = false
            editor.isAutomaticTextReplacementEnabled = false
            editor.isAutomaticSpellingCorrectionEnabled = false
            editor.isAutomaticPeriodSubstitutionEnabled = false
            editor.smartInsertDeleteEnabled = false
        }
        return ok
    }
}
```

- [ ] **Step 2: Build**

Run: `cd "…/Obfuskoder Mac" && xcodebuild -scheme Obfuskoder -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Obfuskoder/Views/MacTextField.swift
git commit -m "feat(app): substitution-free MacTextField"
```

---

### Task 22: MacTextEditor (multi-line, no substitutions, monospaced)

**Files:**
- Create: `Obfuskoder/Views/MacTextEditor.swift`

- [ ] **Step 1: Write the file**

```swift
import SwiftUI
import AppKit

/// NSTextView wrapper for the Advanced HTML field: monospaced, spell/substitution-free, scrollable.
struct MacTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onChange: () -> Void = {}

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        guard let textView = scroll.documentView as? NSTextView else { return scroll }
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticPeriodSubstitutionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 4, height: 6)
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text { textView.string = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let parent: MacTextEditor
        init(_ parent: MacTextEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.onChange()
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `cd "…/Obfuskoder Mac" && xcodebuild -scheme Obfuskoder -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Obfuskoder/Views/MacTextEditor.swift
git commit -m "feat(app): substitution-free monospaced MacTextEditor"
```

---

# Phase 8 — App model & shell

### Task 23: Confirm sandbox entitlements (no network)

**Files:**
- Inspect: `Obfuskoder.xcodeproj` build settings / generated entitlements

- [ ] **Step 1: Verify App Sandbox is on and no network entitlement is present**

The scaffold has `ENABLE_APP_SANDBOX = YES` (good). Confirm there is **no** `com.apple.security.network.client`/`.server` entitlement enabled (Target ▸ Signing & Capabilities ▸ App Sandbox → all network checkboxes **off**). This satisfies SPEC §9.1/§9.2 (no network).

- [ ] **Step 2: Record the check**

Run: `cd "…/Obfuskoder Mac" && grep -Rn "network" Obfuskoder.xcodeproj || echo "no network entitlement references — good"`
Expected: prints the "no network entitlement references" line (or shows none enabled).

- [ ] **Step 3: Commit (only if a `.entitlements` file was added/changed)**

```bash
git add -A
git commit -m "chore(app): confirm sandbox-on, network-off entitlements" || echo "nothing to commit"
```

---

### Task 24: AppModel (debounced encode + result state)

**Files:**
- Create: `Obfuskoder/AppModel.swift`

Implements SPEC §6.5 (semi-live debounce) and §6.6 result handling. Drives the pure `FormState`/`ObfuskodeEngine` from the package.

- [ ] **Step 1: Write the file**

```swift
import SwiftUI
import Observation
import ObfuskoderKit

enum ResultState: Equatable {
    case empty
    case snippet(Snippet)
    case failure
}

@MainActor
@Observable
final class AppModel {
    var form = FormState()
    private(set) var result: ResultState = .empty

    var debounceSeconds: Double = AppConfig.defaultDebounceSeconds
    var fallbackMessage: String = AppConfig.defaultFallbackMessage

    private var encodeTask: Task<Void, Never>?

    /// Call whenever the form, debounce, or fallback changes.
    func scheduleEncode() {
        encodeTask?.cancel()
        guard let input = form.canonicalInput else {
            result = .empty
            return
        }
        let email = form.emailForSelfCheck
        let fallback = fallbackMessage
        let delay = debounceSeconds

        encodeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            if Task.isCancelled { return }
            let engine = ObfuskodeEngine(fallbackMessage: fallback)
            let outcome: ResultState
            do {
                let snippet = try await Task.detached(priority: .userInitiated) {
                    try engine.encode(input, email: email)
                }.value
                outcome = .snippet(snippet)
            } catch {
                outcome = .failure
            }
            if Task.isCancelled { return }
            self?.result = outcome
        }
    }

    var snippetText: String? {
        if case .snippet(let s) = result { return s.html }
        return nil
    }

    var decodedSource: String? {
        if case .snippet(let s) = result { return s.decodedSource }
        return nil
    }

    func clearActiveForm() {
        form.clearActive()
        scheduleEncode()
    }

    func apply(_ preset: Preset) {
        form.apply(preset)
        scheduleEncode()
    }
}
```

- [ ] **Step 2: Build**

Run: `cd "…/Obfuskoder Mac" && xcodebuild -scheme Obfuskoder -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Obfuskoder/AppModel.swift
git commit -m "feat(app): AppModel with debounced encoding pipeline"
```

---

### Task 25: App scenes, app delegate, menu commands

**Files:**
- Create: `Obfuskoder/AppDelegate.swift`
- Rewrite: `Obfuskoder/ObfuskoderApp.swift`

Implements SPEC §6.1 (single `Window`), §6.9 (menu/shortcuts), §6.10 (Settings), §10 (quit on last window close). `ContentView`/`SettingsView` are created in later tasks; this task references them, so build at the END of Task 28 (a note is included). To keep commits green, this task includes **temporary stubs** for `ContentView`/`SettingsView` that Task 26–28 replace.

- [ ] **Step 1: Write `AppDelegate.swift`**

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true   // focused single-window utility (SPEC §10)
    }
}
```

- [ ] **Step 2: Rewrite `ObfuskoderApp.swift`**

```swift
import SwiftUI
import ObfuskoderKit

@main
struct ObfuskoderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var model = AppModel()
    @State private var store = PresetStore(fileURL: ObfuskoderApp.presetsURL())

    var body: some Scene {
        Window(UIStrings.appName, id: "main") {
            ContentView()
                .environment(model)
                .environment(store)
                .frame(minWidth: 720, minHeight: 420)
        }
        .windowResizability(.contentMinSize)
        .commands { AppCommands(model: model, store: store) }

        Settings {
            SettingsView()
                .environment(model)
        }
    }

    /// presets.json in the sandbox Application Support container (SPEC §6.7/§9.2).
    static func presetsURL() -> URL {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Obfuskoder", isDirectory: true)
        return dir.appendingPathComponent("presets.json")
    }
}
```

- [ ] **Step 3: Add the menu commands (in the same file or a new `AppCommands.swift`)**

Create `Obfuskoder/AppCommands.swift`:

```swift
import SwiftUI
import ObfuskoderKit

struct AppCommands: Commands {
    let model: AppModel
    let store: PresetStore

    var body: some Commands {
        // View ▸ Basic / Advanced
        CommandGroup(after: .toolbar) {
            Button(UIStrings.basic) { model.form.mode = .basic; model.scheduleEncode() }
                .keyboardShortcut("1", modifiers: .command)
            Button(UIStrings.advanced) { model.form.mode = .advanced; model.scheduleEncode() }
                .keyboardShortcut("2", modifiers: .command)
        }
        // Edit ▸ Clear Form (⌘K)  + Copy Snippet (⇧⌘C)
        CommandGroup(after: .pasteboard) {
            Button(UIStrings.copy) {
                if let html = model.snippetText {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(html, forType: .string)
                }
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(model.snippetText == nil)

            Button(UIStrings.clearForm) { model.clearActiveForm() }
                .keyboardShortcut("k", modifiers: .command)
                .disabled(model.form.activeIsEmpty)
        }
    }
}
```

> `Save Current Values… (⌘S)` is added in Task 27 alongside the Saved-values UI so it can present the naming sheet.

- [ ] **Step 4: Add temporary stubs so the project compiles now**

Create `Obfuskoder/Views/_Stubs.swift` (deleted in Task 28):

```swift
import SwiftUI

struct ContentView: View {
    var body: some View { Text("ContentView placeholder").frame(width: 720, height: 420) }
}

struct SettingsView: View {
    var body: some View { Text("Settings placeholder").padding() }
}
```

Delete the old placeholder body in the scaffold's `Obfuskoder/ContentView.swift` (remove that file; its `ContentView` is now defined by the stub and later by Task 26).

```bash
git rm Obfuskoder/ContentView.swift
```

- [ ] **Step 5: Build**

Run: `cd "…/Obfuskoder Mac" && xcodebuild -scheme Obfuskoder -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add Obfuskoder/ObfuskoderApp.swift Obfuskoder/AppDelegate.swift Obfuskoder/AppCommands.swift Obfuskoder/Views/_Stubs.swift
git commit -m "feat(app): single Window + Settings scenes, app delegate, menu commands"
```

---

# Phase 9 — Views

### Task 26: FieldHint + Basic/Advanced forms + InputPane

**Files:**
- Create: `Obfuskoder/Views/FieldHint.swift`
- Create: `Obfuskoder/Views/BasicFormView.swift`
- Create: `Obfuskoder/Views/AdvancedFormView.swift`
- Create: `Obfuskoder/Views/InputPane.swift`

Implements SPEC §6.3 hints (info.circle affordance), §6.4 advanced field.

- [ ] **Step 1: Write `FieldHint.swift`**

```swift
import SwiftUI

/// Trailing info.circle affordance: help tag on hover, popover on click, accessible to VoiceOver (SPEC §6.3).
struct FieldHint: View {
    let fieldLabel: String
    let hint: String
    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .help(hint)                                   // hover help tag (also VoiceOver help)
        .accessibilityLabel(UIStrings.hintAccessibilityLabel(for: fieldLabel))
        .accessibilityHint(hint)
        .popover(isPresented: $showPopover, arrowEdge: .trailing) {
            Text(hint)
                .font(.callout)
                .padding(12)
                .frame(maxWidth: 280)
        }
    }
}
```

- [ ] **Step 2: Write `BasicFormView.swift`**

```swift
import SwiftUI
import ObfuskoderKit

struct BasicFormView: View {
    @Bindable var model: AppModel

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 10) {
            row(UIStrings.emailLabel, hint: UIStrings.emailHint,
                text: $model.form.basic.email)
            row(UIStrings.linkTextLabel, hint: UIStrings.linkTextHint,
                text: $model.form.basic.linkText)
            row(UIStrings.linkTitleLabel, hint: UIStrings.linkTitleHint,
                text: $model.form.basic.linkTitle, optional: true)
            row(UIStrings.subjectLabel, hint: UIStrings.subjectHint,
                text: $model.form.basic.subject, optional: true)
        }
    }

    @ViewBuilder
    private func row(_ label: String, hint: String, text: Binding<String>, optional: Bool = false) -> some View {
        GridRow {
            HStack(spacing: 4) {
                Text(label)
                if optional {
                    Text("(\(UIStrings.optional))").foregroundStyle(.tertiary).font(.caption)
                }
            }
            .gridColumnAlignment(.trailing)

            HStack(spacing: 6) {
                MacTextField(text: text, onChange: { model.scheduleEncode() })
                    .frame(minWidth: 220)
                FieldHint(fieldLabel: label, hint: hint)
            }
        }
    }
}
```

- [ ] **Step 3: Write `AdvancedFormView.swift`**

```swift
import SwiftUI
import ObfuskoderKit

struct AdvancedFormView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(UIStrings.advancedLabel).font(.headline)
                FieldHint(fieldLabel: UIStrings.advancedLabel, hint: UIStrings.advancedHint)
            }
            MacTextEditor(text: $model.form.advanced, onChange: { model.scheduleEncode() })
                .frame(minHeight: 180)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
        }
    }
}
```

- [ ] **Step 4: Write `InputPane.swift`** (mode-driven content; Saved values + Clear added in Task 27)

```swift
import SwiftUI
import ObfuskoderKit

struct InputPane: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch model.form.mode {
            case .basic: BasicFormView(model: model)
            case .advanced: AdvancedFormView(model: model)
            }
            Spacer(minLength: 0)
            SavedValuesBar(model: model)   // Task 27
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
```

> `SavedValuesBar` is created in Task 27. To build this task standalone, temporarily replace `SavedValuesBar(model: model)` with `EmptyView()`, then restore it in Task 27. (Or implement Task 27 before first building Task 26.)

- [ ] **Step 5: Build** (after Task 27 if you used the EmptyView shortcut)

Run: `cd "…/Obfuskoder Mac" && xcodebuild -scheme Obfuskoder -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add Obfuskoder/Views/FieldHint.swift Obfuskoder/Views/BasicFormView.swift Obfuskoder/Views/AdvancedFormView.swift Obfuskoder/Views/InputPane.swift
git commit -m "feat(app): input pane, forms, and accessible field hints"
```

---

### Task 27: Saved values menu + save/manage sheets

**Files:**
- Create: `Obfuskoder/Views/SavedValuesBar.swift`
- Create: `Obfuskoder/Views/SaveValuesSheet.swift`
- Create: `Obfuskoder/Views/ManagePresetsSheet.swift`
- Modify: `Obfuskoder/AppCommands.swift` (add Save Current Values… ⌘S)

Implements SPEC §6.7 and the Clear Form button (§6.8).

- [ ] **Step 1: Write `SaveValuesSheet.swift`**

```swift
import SwiftUI
import ObfuskoderKit

struct SaveValuesSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: PresetStore
    let payload: PresetPayload

    @State private var name = ""
    @State private var duplicate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(UIStrings.presetNamePrompt).font(.headline)
            TextField("", text: $name)
                .frame(width: 280)
                .onChange(of: name) { duplicate = false }
            if duplicate {
                Text(UIStrings.presetNameDuplicate).foregroundStyle(.red).font(.caption)
            }
            HStack {
                Spacer()
                Button(UIStrings.cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                if duplicate {
                    Button(UIStrings.replace) { replaceExisting() }.keyboardShortcut(.defaultAction)
                } else {
                    Button(UIStrings.save) { trySave() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .padding(20)
    }

    private func trySave() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        do { _ = try store.save(name: trimmed, payload: payload); dismiss() }
        catch PresetError.duplicateName { duplicate = true }
        catch { dismiss() }
    }

    private func replaceExisting() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let existing = store.presets.first(where: { $0.name == trimmed }) {
            try? store.replace(id: existing.id, name: trimmed, payload: payload)
        }
        dismiss()
    }
}
```

- [ ] **Step 2: Write `ManagePresetsSheet.swift`**

```swift
import SwiftUI
import ObfuskoderKit

struct ManagePresetsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: PresetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(UIStrings.manageSavedValues).font(.headline)
            List {
                ForEach(store.presets) { preset in
                    PresetRow(store: store, preset: preset)
                }
                .onMove { store.move(fromOffsets: $0, toOffset: $1) }
            }
            .frame(width: 360, height: 240)
            HStack { Spacer(); Button(UIStrings.done) { dismiss() }.keyboardShortcut(.defaultAction) }
        }
        .padding(16)
    }
}

private struct PresetRow: View {
    let store: PresetStore
    let preset: Preset
    @State private var editedName: String

    init(store: PresetStore, preset: Preset) {
        self.store = store
        self.preset = preset
        _editedName = State(initialValue: preset.name)
    }

    var body: some View {
        HStack {
            TextField("", text: $editedName, onCommit: {
                try? store.rename(id: preset.id, to: editedName.trimmingCharacters(in: .whitespaces))
            })
            Spacer()
            Button(role: .destructive) { try? store.delete(id: preset.id) } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(UIStrings.delete)
        }
    }
}
```

- [ ] **Step 3: Write `SavedValuesBar.swift`** (the menu + Clear Form button)

```swift
import SwiftUI
import ObfuskoderKit

struct SavedValuesBar: View {
    @Bindable var model: AppModel
    @Environment(PresetStore.self) private var store

    @State private var showSaveSheet = false
    @State private var showManageSheet = false

    var body: some View {
        HStack {
            Menu(UIStrings.savedValues) {
                Button(UIStrings.saveCurrentValues) { showSaveSheet = true }
                if !store.presets.isEmpty {
                    Divider()
                    ForEach(store.presets) { preset in
                        Button(preset.name) { model.apply(preset) }
                    }
                    Divider()
                    Button(UIStrings.manageSavedValues) { showManageSheet = true }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Button(UIStrings.clearForm) { model.clearActiveForm() }
                .disabled(model.form.activeIsEmpty)
        }
        .sheet(isPresented: $showSaveSheet) {
            SaveValuesSheet(store: store, payload: model.form.payload())
        }
        .sheet(isPresented: $showManageSheet) {
            ManagePresetsSheet(store: store)
        }
    }
}
```

- [ ] **Step 4: Add Save Current Values… (⌘S) to the menu bar**

In `AppCommands.swift`, the `Save Current Values…` command must trigger the same sheet. Because `.commands` can't present a sheet directly, route it through a notification the `ContentView` observes. Add to `AppCommands.body` (inside a `CommandGroup(after: .newItem)`):

```swift
        CommandGroup(after: .newItem) {
            Button(UIStrings.saveCurrentValues) {
                NotificationCenter.default.post(name: .saveCurrentValues, object: nil)
            }
            .keyboardShortcut("s", modifiers: .command)
        }
```

Add at file scope in `AppCommands.swift`:

```swift
extension Notification.Name {
    static let saveCurrentValues = Notification.Name("ObfuskoderSaveCurrentValues")
}
```

`ContentView` (Task 28) listens for `.saveCurrentValues` and shows the save sheet.

- [ ] **Step 5: Restore `SavedValuesBar(model: model)` in `InputPane.swift`** if you stubbed it with `EmptyView()` in Task 26.

- [ ] **Step 6: Build**

Run: `cd "…/Obfuskoder Mac" && xcodebuild -scheme Obfuskoder -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Commit**

```bash
git add Obfuskoder/Views/SavedValuesBar.swift Obfuskoder/Views/SaveValuesSheet.swift Obfuskoder/Views/ManagePresetsSheet.swift Obfuskoder/AppCommands.swift Obfuskoder/Views/InputPane.swift
git commit -m "feat(app): saved-values menu, save/manage sheets, clear form"
```

---

### Task 28: PreviewWebView, ResultPane, ContentView, SettingsView

**Files:**
- Create: `Obfuskoder/Views/PreviewWebView.swift`
- Create: `Obfuskoder/Views/ResultPane.swift`
- Create: `Obfuskoder/Views/ContentView.swift`
- Create: `Obfuskoder/Views/SettingsView.swift`
- Delete: `Obfuskoder/Views/_Stubs.swift`

Implements SPEC §6.6 (read-only WebKit preview, Copy, decoded-source disclosure), §6.1 (toolbar + split), §6.10 (Settings).

- [ ] **Step 1: Write `PreviewWebView.swift`**

```swift
import SwiftUI
import WebKit

/// Read-only, non-interactive WKWebView that runs the actual snippet (SPEC §6.6). No network.
struct PreviewWebView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let document = """
        <!doctype html><html><head><meta charset="utf-8">
        <style>body{font:13px -apple-system,system-ui,sans-serif;margin:8px;color:canvastext}</style>
        </head><body>\(html)</body></html>
        """
        webView.loadHTMLString(document, baseURL: nil)   // no network, no baseURL
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate {
        // Allow the initial in-memory load; cancel any user-initiated navigation (read-only).
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(navigationAction.navigationType == .other ? .allow : .cancel)
        }
    }
}
```

- [ ] **Step 2: Write `ResultPane.swift`**

```swift
import SwiftUI
import ObfuskoderKit

struct ResultPane: View {
    @Bindable var model: AppModel
    @State private var showDecoded = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(UIStrings.snippetHeading).font(.headline)
                Spacer()
                Text(UIStrings.updatesAsYouType).font(.caption).foregroundStyle(.tertiary)
            }

            snippetView

            HStack {
                Spacer()
                Button(copied ? UIStrings.copied : UIStrings.copy) { copy() }
                    .disabled(model.snippetText == nil)
                    .accessibilityLabel(UIStrings.copy)
            }

            Text(UIStrings.previewHeading).font(.headline)
            Group {
                if let html = model.snippetText {
                    PreviewWebView(html: html)
                } else {
                    placeholder
                }
            }
            .frame(minHeight: 120)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))

            if model.decodedSource != nil {
                DisclosureGroup(UIStrings.showDecodedSource, isExpanded: $showDecoded) {
                    Text(model.decodedSource ?? "")
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder private var snippetView: some View {
        switch model.result {
        case .snippet(let s):
            ScrollView {
                Text(s.html)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(minHeight: 90)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 6))
        case .failure:
            Text(UIStrings.encodeFailed).foregroundStyle(.red).frame(minHeight: 90, alignment: .topLeading)
        case .empty:
            placeholder.frame(minHeight: 90)
        }
    }

    private var placeholder: some View {
        Text(UIStrings.emptyResult)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func copy() {
        guard let html = model.snippetText else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(html, forType: .string)
        copied = true
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: UIStrings.copied])
        Task { try? await Task.sleep(for: .seconds(2)); copied = false }
    }
}
```

- [ ] **Step 3: Write `ContentView.swift`**

```swift
import SwiftUI
import ObfuskoderKit

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(PresetStore.self) private var store

    @AppStorage(SettingsKeys.debounceSeconds) private var debounce = AppConfig.defaultDebounceSeconds
    @AppStorage(SettingsKeys.fallbackMessage) private var fallback = AppConfig.defaultFallbackMessage

    @State private var showSaveSheet = false

    var body: some View {
        @Bindable var model = model
        HSplitView {
            InputPane(model: model)
                .frame(minWidth: 320)
            ResultPane(model: model)
                .frame(minWidth: 320)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("", selection: $model.form.mode) {
                    Text(UIStrings.basic).tag(FormMode.basic)
                    Text(UIStrings.advanced).tag(FormMode.advanced)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
        .onAppear { syncSettings() }
        .onChange(of: model.form) { model.scheduleEncode() }
        .onChange(of: debounce) { syncSettings() }
        .onChange(of: fallback) { syncSettings() }
        .onReceive(NotificationCenter.default.publisher(for: .saveCurrentValues)) { _ in
            showSaveSheet = true
        }
        .sheet(isPresented: $showSaveSheet) {
            SaveValuesSheet(store: store, payload: model.form.payload())
        }
    }

    private func syncSettings() {
        model.debounceSeconds = debounce
        model.fallbackMessage = fallback
        model.scheduleEncode()
    }
}
```

- [ ] **Step 4: Write `SettingsView.swift`**

```swift
import SwiftUI
import ObfuskoderKit

struct SettingsView: View {
    @AppStorage(SettingsKeys.debounceSeconds) private var debounce = AppConfig.defaultDebounceSeconds
    @AppStorage(SettingsKeys.fallbackMessage) private var fallback = AppConfig.defaultFallbackMessage

    var body: some View {
        Form {
            Section {
                Slider(value: $debounce,
                       in: AppConfig.minDebounceSeconds...AppConfig.maxDebounceSeconds,
                       step: 0.05) {
                    Text(UIStrings.settingsEncodingDelay)
                } minimumValueLabel: { Text("0.1s") } maximumValueLabel: { Text("1.0s") }
                Text(String(format: "%.2fs", debounce)).foregroundStyle(.secondary).font(.caption)
            }
            Section(UIStrings.settingsFallbackMessage) {
                TextField("", text: $fallback)
                // Fallback must not contain "@" (would violate ENC-3). Strip it defensively.
                    .onChange(of: fallback) { fallback = fallback.replacingOccurrences(of: "@", with: "") }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .padding(20)
    }
}
```

- [ ] **Step 5: Delete the stubs**

```bash
git rm Obfuskoder/Views/_Stubs.swift
```

- [ ] **Step 6: Build**

Run: `cd "…/Obfuskoder Mac" && xcodebuild -scheme Obfuskoder -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Commit**

```bash
git add Obfuskoder/Views/PreviewWebView.swift Obfuskoder/Views/ResultPane.swift Obfuskoder/Views/ContentView.swift Obfuskoder/Views/SettingsView.swift
git commit -m "feat(app): result pane, WebKit preview, content view, settings"
```

---

# Phase 10 — Manual verification & polish

### Task 29: Run the app and walk the acceptance criteria

**Files:** none (manual verification of SPEC §12).

- [ ] **Step 1: Launch**

Run: `cd "…/Obfuskoder Mac" && xcodebuild -scheme Obfuskoder -destination 'platform=macOS' build` then open the built app (or run from Xcode, ⌘R).

- [ ] **Step 2: Walk each acceptance criterion (SPEC §12)** and note pass/fail:
  - Single resizable window; size/position restore; opens to empty form.
  - Toolbar + ⌘1/⌘2 switch Basic/Advanced.
  - Basic: valid input → preview renders the `mailto:` link from the real snippet.
  - Advanced: arbitrary HTML round-trips in the preview.
  - Live encoding updates ~400 ms after typing stops; invalid → empty state, Copy disabled; delay adjustable in Settings.
  - Snippet shows no `@`, no input email; copy works; "Copied" announced.
  - Saved values: save (unique name), recall (restores mode+fields), rename/delete/reorder, replace prompt; persist across relaunch.
  - Field hints: hover help tag + click popover + VoiceOver.
  - Clear Form: button + ⌘K, undoable, only active form, disabled when empty.
  - Light & Dark both correct.
  - Smart quotes/dashes/replace off in fields (type `"` and `--` → not converted).
  - No network (next task).

- [ ] **Step 3: Fix any failures** by returning to the relevant task's file. Re-run `swift test` if a package file changed. Commit each fix:

```bash
git add -A && git commit -m "fix(app): <describe>"
```

---

### Task 30: Verify no-network and universal build

**Files:** none (verification of SPEC §9.1/§9.2 and §5).

- [ ] **Step 1: Confirm zero network at runtime**

With the app running, open **Activity Monitor ▸ Network** (or `nettop -p <pid>`), exercise Basic + Advanced + preview, and confirm no outbound traffic from the app. (The preview uses `loadHTMLString` with `baseURL: nil`, so nothing should be fetched.)

- [ ] **Step 2: Confirm a universal release binary**

Run:
```bash
cd "/Users/alderete/Developer/_Projects/Obfuskoder/Obfuskoder Mac"
xcodebuild -scheme Obfuskoder -configuration Release -destination 'generic/platform=macOS' build
# then locate the built .app and check the binary:
# lipo -archs <DerivedData>/.../Obfuskoder.app/Contents/MacOS/Obfuskoder
```
Expected: `lipo -archs` prints `x86_64 arm64`. If not, set the target's **Architectures** to **Standard ($(ARCHS_STANDARD))** and **Build Active Architecture Only = No** for Release.

- [ ] **Step 3: Commit any build-setting fixes**

```bash
git add Obfuskoder.xcodeproj
git commit -m "build(app): ensure universal Release binary" || echo "nothing to commit"
```

---

## Self-Review (spec coverage map)

| SPEC section | Covered by |
|---|---|
| §5 platform / macOS 14 / universal | Tasks 1 (pkg platform), 18 (deployment target), 30 (universal) |
| §6.1 single Window, two-pane, restore | Tasks 25, 28 |
| §6.2 mode switch + ⌘1/⌘2 | Tasks 25, 28 |
| §6.3 Basic fields + canonical HTML + hints | Tasks 6, 26 |
| §6.4 Advanced field + hint | Tasks 22, 26 |
| §6.5 live encoding + debounce (400 ms, tunable) | Tasks 24, 28 |
| §6.6 read-only snippet, Copy, WebKit preview, decoded source | Task 28 |
| §6.7 saved values (save/recall/rename/delete/reorder/replace, local JSON) | Tasks 16, 17, 27 |
| §6.8 Clear Form (button + ⌘K, undoable, active-only) | Tasks 25 (cmd), 27 (button), 15 (clearActive) |
| §6.9 menu bar + shortcuts (⌘S, ⇧⌘C, ⌘K, ⌘1/2, ⌘,) | Tasks 25, 27 |
| §6.10 Settings (debounce, fallback) | Task 28 |
| §7 encoder ENC-1…7 + self-check | Tasks 8, 10, 11, 12, 13, 14 |
| §8 architecture (pure core + thin UI) | package (Tasks 1–17) + app (18–28) |
| §9.1 sandbox / notarization-ready | Task 23 |
| §9.2 privacy / no network | Tasks 28 (loadHTMLString nil), 30 |
| §9.4 accessibility (VoiceOver, keyboard) | Tasks 26 (hints), 28 (copy announce), 29 (walk) |
| §9.5 String Catalog | Task 20 |
| §9.6 light/dark + accent | Task 19 |
| §10 Mac-assed (quit-on-close, text hygiene, etc.) | Tasks 21, 22, 25 |
| §12 acceptance | Tasks 29, 30 |

**Notes for the implementer:**
- The build-order coupling between Task 26 (`InputPane` references `SavedValuesBar`) and Task 27 is called out in both tasks; do Task 27 before first building Task 26, or use the documented `EmptyView()` shortcut.
- `Task 24`/`28` engine call runs off the main actor via `Task.detached`; `ObfuskodeEngine` and its inputs are `Sendable`.
- If `swift test` ever fails to find a type, confirm the test file uses `@testable import ObfuskoderKit`.
- Keyboard shortcuts (⌘K, ⇧⌘C, ⌘1/2, ⌘S, ⌘,) still need the conflict audit noted in SPEC §14 before 1.0.
