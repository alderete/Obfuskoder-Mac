# Architecture and Design Review — 2026-07-28

## Purpose

This document preserves the results of a top-down architectural and design
review of the Obfuskoder macOS app, with particular attention to:

- separation of concerns;
- the reworked undo/redo architecture;
- Swift and SwiftUI patterns;
- Swift concurrency and cancellation;
- the Sparkle software-update integration;
- automated testing, accessibility, and macOS release practices.

The review was performed against commit **`5e79748`** and recorded in the
repository at **`b3ebbcd`**. The intervening commits only added CONTRIBUTING
documentation, so the reviewed application code was unchanged.

No source changes were made as part of the review.

## Executive summary

The architecture is substantially stronger than the previous design. The new
undo system is thoughtful, macOS-native, and unusually well documented. The
app/package boundary, Swift 6 isolation, Observation usage, and Sparkle wrapper
are all solid foundations.

The review found:

- **2 high-priority correctness/release risks**
- **3 medium-priority architecture and release improvements**
- **2 low-priority SwiftUI accessibility improvements**

The most important immediate work is:

1. add Sparkle's missing `-spks` sandbox entitlement;
2. make saved-value mutations and their undo/redo history transactional;
3. make processing cancellation structured and effective.

## Architecture observed

### Application composition

The app target contains the SwiftUI and AppKit integration layers:

- `AppModel` owns the main form session and coordinates processing and form undo;
- `UndoRouter` routes Edit-menu undo/redo to the active AppKit editing context;
- `SoftwareUpdater` is the only type that imports Sparkle;
- SwiftUI views consume shared state through Observation and the environment;
- AppKit wrappers handle the areas where SwiftUI alone is insufficient, such as
  field-editor behavior, responder routing, window access, and WebKit previewing.

### Shared package

`ObfuskoderKit` contains most deterministic and reusable behavior:

- encoding and self-checking;
- form and preset value types;
- semantic edit classification and undo grouping;
- form action recording;
- saved-values storage and saved-values undo;
- update-frequency policy.

This split is effective. Most complex behavior can be tested without launching
the app or constructing SwiftUI views.

### Concurrency model

The app target uses:

- Swift 6;
- warnings as errors;
- MainActor default isolation;
- approachable concurrency;
- `Sendable` domain values;
- retained task handles for debouncing and copy feedback.

UI state is correctly MainActor-isolated. Background encoding does not appear to
introduce a data race, but its detached-task lifetime is not integrated with the
debounce task's cancellation.

## Findings

### P1 — Sparkle sandbox entitlements are incomplete

**Files**

- `Obfuskoder/Obfuskoder.entitlements:11-14`
- `docs/superpowers/specs/2026-07-08-sparkle-updater-design.md`
- `docs/SPECIFICATION.md`

The application grants only:

```xml
<string>$(PRODUCT_BUNDLE_IDENTIFIER)-spki</string>
```

Sparkle requires both `-spks` and `-spki` so a sandboxed host can communicate
with the installer's connection and status services:

```xml
<string>$(PRODUCT_BUNDLE_IDENTIFIER)-spks</string>
<string>$(PRODUCT_BUNDLE_IDENTIFIER)-spki</string>
```

The `com.apple.security.network.client` entitlement makes Sparkle's separate
Downloader XPC service unnecessary. It does **not** eliminate the `-spks`
installer-status channel.

The signed `1.0rc1` distribution archive was inspected during the review. It
also contains only `com.aldosoft.Obfuskoder-spki`, confirming that this is
present in the shipped artifact and not merely a source configuration issue.

**Impact**

Installer status, relaunch, or update-resume coordination may fail or time out
in the sandboxed release build.

**Action**

- Add `$(PRODUCT_BUNDLE_IDENTIFIER)-spks`.
- Correct the design/specification text that says it is unnecessary.
- Perform a signed, sandboxed version-N to version-N+1 update outside Xcode.
- Verify download, install, relaunch, and interrupted/resumed update behavior.

**Reference**

- [Sparkle: Sandboxing with Sparkle](https://sparkle-project.org/documentation/sandboxing/)

### P1 — Persistence failures can diverge saved-values undo history

**Files**

- `ObfuskoderKit/Sources/ObfuskoderKit/PresetStore.swift:56-90`
- `ObfuskoderKit/Sources/ObfuskoderKit/SavedValuesUndo.swift:47-82`
- `Obfuskoder/Views/ManagePresetsSheet.swift:125-135`

`PresetStore.move`, `insert`, and `setOrder` catch and discard persistence
errors. `SavedValuesUndo` then registers the inverse operation regardless of
whether the mutation succeeded.

For example:

```swift
do { try persist(result); presets = result } catch { }
```

and later:

```swift
target.store.setOrder(restore)
target.registerReorder(restore: reapply, reapply: restore, name: name)
```

This breaks an essential undo invariant: the history stack must describe
changes that actually occurred.

**Impact**

A disk-full, permissions, or other filesystem error can:

- make a reorder/delete undo appear to succeed when nothing changed;
- advance the undo/redo stack independently of persisted state;
- register a future delete or reinsert for an operation that never happened;
- leave the UI unable to explain the error beyond a beep.

**Action**

- Make `move`, `insert`, and `setOrder` throwing operations.
- Preserve the existing persist-before-commit behavior.
- Register an inverse only after the corresponding mutation succeeds.
- Give `SavedValuesUndo` an injected error-reporting closure or observable error
  state, because `UndoManager` callbacks cannot throw to their caller.
- On replay failure, report the error and do not register the next inverse.
- Add reorder, delete-undo, and delete-redo failure tests using the existing
  `/dev/null/...` test technique.

### P2 — Detached encoding work escapes debounce cancellation

**Files**

- `Obfuskoder/AppModel.swift:87-117`
- `ObfuskoderKit/Sources/ObfuskoderKit/ObfuskodeEngine.swift:31-52`

`AppModel.scheduleEncode()` cancels the prior debounce task, but the actual
encoding runs in `Task.detached`.

Cancelling the outer task does not cancel that detached task. The cancellation
check after awaiting it correctly prevents a stale result from reaching the UI,
so this is not currently a stale-state or data-race bug. However, rapid edits
can leave several obsolete JavaScriptCore/self-check operations running at
once.

**Impact**

- wasted CPU and energy;
- unnecessary JavaScriptCore contention;
- processing latency under sustained input;
- cancellation semantics that are difficult to test and reason about.

**Action**

- Extract a `SnippetProcessor` dependency.
- Give it a nonisolated/`@concurrent` async entry point.
- Await processing through structured concurrency rather than
  `Task.detached`.
- Add cancellation checks between encoding/self-check attempts.
- Test that superseded work terminates and never publishes a result.

### P2 — Processing ownership is split and app orchestration lacks test seams

**Files**

- `Obfuskoder/AppModel.swift`
- `Obfuskoder/Views/ContentView.swift:33-59`
- `Obfuskoder/UndoRouter.swift`
- `Obfuskoder/SoftwareUpdater.swift`
- `Obfuskoder.xcodeproj/project.pbxproj`

`ContentView` schedules processing in `onChange(of: model.form)`, while
`AppModel` methods such as clear, apply, undo, redo, restore, and mode switching
also schedule processing themselves.

This creates two owners for the same derived-state lifecycle:

- direct field changes depend on `ContentView` being mounted;
- command/model mutations process themselves;
- some operations cause redundant cancel-and-reschedule cycles.

`AppModel` also coordinates form state, encoding, form undo, focus restoration,
clipboard feedback, settings inputs, and Edit-menu state. It is still a
manageable size, but it is becoming both an application facade and the concrete
implementation of several subsystems.

The 146 package tests cover the pure engine and undo semantics well. The Xcode
project has no app unit-test target for `AppModel`, `UndoRouter`, or
`SoftwareUpdater`, where much of the integration risk now lives.

**Action**

- Keep `AppModel` as the composition root and public UI facade.
- Extract debounce/encoding behavior into a testable `SnippetPipeline`.
- Establish one form-mutation-to-processing path and remove the view/model
  scheduling duplication.
- Consider extracting a form-history coordinator while preserving the
  model-owned undo design documented in ADR 0001.
- Add an application unit-test target.
- Inject the processor/scheduler, a small updater protocol, and a pure undo
  routing policy where practical.
- Keep live AppKit responder lookup as a thin adapter and retain manual tests
  for actual first-responder behavior.

### P2 — Release and appcast metadata have multiple sources of truth

**File**

- `scripts/release.sh:20-110`

The release script uses `git describe --tags --always`, so it can run from an
untagged commit and create a version such as `1.0rc1-2-g…`. It then constructs
appcast metadata independently:

- build number from `git rev-list --count HEAD`;
- hard-coded `sparkle:shortVersionString` of `1.0`;
- hard-coded `sparkle:minimumSystemVersion` of `14.0`.

The build phase currently derives matching values, and the inspected rc1
artifact correctly contains build `147` and marketing version `1.0`. The
problem is future drift: a correctly built app can be paired with incorrect
appcast metadata after a marketing-version or deployment-target change.

**Action**

- Require `git describe --exact-match --tags HEAD` during preflight.
- Prefer failing, rather than merely warning, on a dirty release tree.
- Read `CFBundleVersion`, `CFBundleShortVersionString`, and
  `LSMinimumSystemVersion` from the exported application's `Info.plist`.
- Normalize Sparkle's minimum-system version to a three-part value.
- Validate that the release tag, archive, filename, and appcast agree.
- Consider Sparkle's recommended `generate_appcast` workflow, or retain the
  custom workflow with equivalent product-metadata validation.

**Reference**

- [Sparkle: Publishing an update](https://sparkle-project.org/documentation/publishing/)

### P3 — Drag animations do not fully honor Reduce Motion

**File**

- `Obfuskoder/Views/ManagePresetsSheet.swift:73-90`

The list insertion/removal animation correctly checks
`accessibilityReduceMotion`, but the drag scale, shadow, spring, and ease-out
animations remain active.

**Action**

- Disable the full drag-animation treatment when Reduce Motion is enabled.
- Preserve direct position feedback without spring or scale effects.
- Verify drag reordering, keyboard reordering, delete, and undo with Reduce
  Motion both enabled and disabled.

### P3 — The decoded-source label adds non-semantic tap behavior

**File**

- `Obfuskoder/Views/ResultPane.swift:66-80`

The `DisclosureGroup` label uses `onTapGesture` to make the full label clickable.
This introduces control behavior without button semantics.

**Action**

- Prefer the native `DisclosureGroup` interaction.
- If the full label must toggle, implement that behavior with a semantic control
  that exposes the appropriate keyboard and accessibility behavior.
- Verify VoiceOver announcement and keyboard operation.

## Positive findings

### Separation of concerns

- Encoding, self-checking, value semantics, edit classification, grouping, and
  most undo mechanics live in `ObfuskoderKit`.
- AppKit responder-chain behavior remains in the app target.
- Sparkle is isolated behind one `SoftwareUpdater` type.
- The package does not depend on SwiftUI for its core undo semantics.

### Undo and redo

- Basic and Advanced modes have independent undo managers and histories.
- Semantic grouping is represented by a pure `UndoGroupingEngine`.
- `EditClassifier` and `FormActionRecorder` separate edit interpretation from
  AppKit history registration.
- Open text groups, menu titles, focus, and caret restoration are explicitly
  modeled.
- `UndoRouter` respects native auxiliary text editing, the saved-values panel,
  the main form, and unrelated windows as separate contexts.
- ADR 0001 clearly records the rationale and rejected alternatives.

### Swift and SwiftUI

- Shared state uses modern `@Observable`, `@State`, `@Environment`, and
  `@Bindable` patterns rather than legacy `ObservableObject`.
- App-owned mutable UI state is MainActor-isolated.
- Native SwiftUI controls are used where practical.
- AppKit bridges are focused on behaviors SwiftUI does not expose adequately.
- Several motion-heavy areas already honor Reduce Motion.

### Concurrency

- Captured values sent to background processing are value types and `Sendable`.
- Debounce and feedback tasks are retained and cancelled.
- Stale processing results are checked before publication.
- Notification callbacks delivered on the main queue use explicit actor
  assumptions.
- Sparkle KVO state is delivered to the main run loop before changing observable
  MainActor state.

### Release engineering

- The feed is HTTPS.
- Updates are EdDSA-signed.
- The release flow archives, exports with Developer ID, notarizes, staples, and
  verifies before packaging.
- The archive command preserves the application/framework structure.
- The appcast was well-formed during review.
- The signed rc1 application and embedded Sparkle components passed strict
  code-signature verification.

## Verification performed

### Package tests

Command:

```sh
cd ObfuskoderKit
swift test --disable-sandbox --skip-build
```

Result:

```text
Test run with 146 tests in 0 suites passed.
```

### Application build

Command:

```sh
xcodebuild \
  -project Obfuskoder.xcodeproj \
  -scheme Obfuskoder \
  -configuration Debug \
  -derivedDataPath /tmp/obfuskoder-review-derived \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Result:

```text
BUILD SUCCEEDED
```

The target has warnings-as-errors enabled.

### Sparkle/release artifact

The `dist/Obfuskoder-1.0rc1.zip` artifact was extracted and inspected.

Confirmed:

- `CFBundleVersion = 147`;
- `CFBundleShortVersionString = 1.0`;
- app and embedded Sparkle components satisfy strict code-signature
  verification;
- the shipped sandbox entitlement contains `-spki` but not `-spks`;
- `updates/obfuskoder/appcast.xml` is well-formed XML.

### Not performed

- A live signed version-N to version-N+1 Sparkle update.
- GUI automation or a full manual UI pass.
- Fault injection during a real `UndoManager` callback.
- Instruments profiling under sustained rapid input.

## Prioritized action checklist

### Before the next Sparkle release

- [ ] Add `$(PRODUCT_BUNDLE_IDENTIFIER)-spks` to the app entitlements.
- [ ] Correct the Sparkle design/specification documents.
- [ ] Require an exact release tag in `release.sh`.
- [ ] Source appcast version metadata from the exported application.
- [ ] Run a signed, sandboxed end-to-end update outside Xcode.

### Correctness and data integrity

- [ ] Make saved-value reorder/insert/set-order mutations throwing.
- [ ] Register undo/redo inverses only after successful persistence.
- [ ] Add a user-visible error path for undo/redo persistence failures.
- [ ] Add failure-path tests for reorder and undo/redo replay.

### Architecture and concurrency

- [ ] Extract a testable `SnippetPipeline`/`SnippetProcessor`.
- [ ] Replace detached processing with structured cancellation.
- [ ] Add cancellation checks between engine attempts.
- [ ] Establish one owner for mutation-triggered processing.
- [ ] Add an app unit-test target.
- [ ] Add focused tests for `AppModel`, updater adaptation, and undo routing
      policy.

### SwiftUI and accessibility

- [ ] Honor Reduce Motion for the full saved-value drag treatment.
- [ ] Replace the decoded-source label tap gesture with semantic interaction.
- [ ] Perform VoiceOver and keyboard checks for the disclosure and preset list.

## Suggested implementation order

1. **Sparkle entitlement and release guardrails**  
   Small changes with high release impact. Follow with the signed end-to-end
   update test.

2. **Transactional saved-values undo**  
   Fix the correctness invariant and add fault-injection tests before further
   undo features are added.

3. **Processing pipeline extraction and cancellation**  
   Create the test seam, move processing into structured concurrency, and
   remove duplicate scheduling ownership.

4. **Application integration tests**  
   Cover the extracted pipeline and `AppModel` coordination first, then updater
   adaptation and the pure portion of routing.

5. **Accessibility cleanup**  
   Address the two localized SwiftUI findings and include them in the manual
   accessibility test plan.

## Re-review criteria

The high-priority findings can be considered closed when:

- the signed application contains both `-spks` and `-spki`;
- a sandboxed update installs and relaunches successfully outside Xcode;
- every saved-values history entry corresponds to a successful persisted
  mutation;
- persistence replay failures are visible and do not fabricate inverse actions;
- fault-injection tests cover initial actions, undo, and redo.

The architecture improvements can be considered complete when:

- superseded encoding work is actually cancelled;
- form changes have one processing trigger path;
- app-layer orchestration is testable without rendering SwiftUI;
- the release script derives appcast metadata from the shipped product.
