# Undo / Redo — Manual Runtime Test Plan

- **Date:** 2026-07-14
- **Status:** Required acceptance gate
- **Normative spec:**
  [Undo / Redo Behavior — Improved Design Spec](superpowers/specs/2026-07-14-undo-redo-design-improved.md)

## Purpose

This plan verifies behavior that model unit tests cannot prove: Edit-menu and
shortcut routing, live AppKit field-editor interaction, menu validation,
first-responder movement, selection/caret restoration, scrolling, and context
priority across windows and sheets.

The feature is not complete until this matrix passes in a normally launched app
on every supported macOS version. Do not use a Terminal-attached launch for
timing-sensitive conclusions.

## Test setup

- Start from a fresh app launch so both mode histories are empty.
- Have at least these saved values:
  - Basic **Personal** with visibly distinct values in all four fields.
  - Basic **Work** with different values.
  - Advanced **HTML snippet** with multiple lines longer than the editor viewport.
- Keep the Edit menu visible during selected tests to confirm titles and enabled
  state, not only keyboard effects.
- Repeat text tests with both keyboard shortcuts and the Edit-menu commands.

## 1. Empty state and standard commands

- [x] 1.1 In a fresh Basic form, Edit shows disabled **Undo** and **Redo** at the
      top, with `⌘Z` and `⇧⌘Z`.
- [x] 1.2 Switching to a fresh Advanced form leaves both commands disabled.
- [x] 1.3 There are no content-area Undo/Redo buttons.
- [x] 1.4 Repeatedly invoking Undo through any available accessibility or command
      path at the bottom of history is a harmless no-op and never crashes.

## 2. Deterministic Basic text grouping

- [x] 2.1 Focus Email and type `first@example.com` continuously. Edit shows
      **Undo Typing**; one Undo removes the continuous insertion and Redo restores
      it with the caret at the recorded position.
- [x] 2.2 Type `first`, pause for at least three seconds without moving the caret,
      then type `@example.com`. One Undo removes the entire continuous insertion;
      the pause did not create a boundary.
- [x] 2.3 Type `abcdef`, move the caret between `c` and `d`, then type `XYZ`.
      Undo removes `XYZ` only; the next Undo removes the earlier insertion.
- [x] 2.4 Type text, then Backspace several consecutive characters. First Undo
      restores the deleted run; the next Undo removes the insertion.
- [x] 2.5 Alternate backward and forward deletion. Each direction is a distinct
      Delete action.
- [ ] FAIL, "Undo Replace" instead of "Undo Paste". 2.6 Paste text. Edit shows **Undo Paste**; Undo restores the pre-paste text
      and selection; Redo restores the post-paste text and selection.
- [ ] FAIL, "Undo Typing" instead of "Undo Replace. 2.7 Replace a selection by typing. Edit shows **Undo Replace**; Undo restores
      both the prior text and its prior selection.
- [ ] FAIL, "Undo Replace" instead of "Undo Cut". 2.8 Cut a selection. Edit shows **Undo Cut**; Undo restores the text and
      selection.
- [x] 2.9 Make two edit groups in Email, then Tab to Subject and edit it. Leaving
      Email does not collapse its two groups. Undo walks Subject, then the two
      Email groups in reverse order.
- [ ] 2.10 An edit that returns the field to its group-starting value before the
      group closes creates no visible/no-op history entry.

Notes:
- A few cases where the menu text describing the action to undo/redo is subtly wrong. For example, "Undo Replace" after cutting or pasting over the contents of a field. Cut/copy/paste/undo/redo is all correct behavior, it's just the menu text that's not 100% right.


## 3. Link text ghost completion

- [x] 3.1 Enter a valid Email and leave Link text empty. The changing ghost value
      creates no Link text history entry.
- [x] 3.2 Focus empty Link text and press Tab once to accept the ghost value. Edit
      shows **Undo Complete Link Text**.
- [x] 3.3 Undo returns stored Link text to empty and reveals the current ghost
      value; Redo restores the accepted literal string.
- [x] 3.4 After Undo, change Email before Redo. The new Email edit invalidates the
      Basic redo future; the ghost follows the new Email without creating its own
      action.

## 4. Advanced text behavior

- [-] 4.1 Repeat tests 2.1–2.8 in the Advanced HTML editor, including multiline
      insertion and deletion.
- [x] 4.2 Undo an action outside the visible viewport. The editor scrolls to
      reveal the restored caret or selection.
- [x] 4.3 Leave and return to the Advanced editor after making multiple groups.
      Focus loss does not collapse those groups.
- [x] 4.4 Smart substitutions and spell checking remain disabled throughout
      Undo/Redo.
      
Notes:
- 4.1: same results/failures and successes as with the Basic form.


## 5. Cross-field ordering and focus

- [x] 5.1 Edit Email, Link title, and Subject in that order. Three Undos affect
      Subject, Link title, and Email in reverse order.
- [x] 5.2 Each Undo and Redo focuses the affected field and restores the recorded
      caret/selection; it does not select the entire field unless that was the
      recorded state.
- [x] 5.3 The generated result and preview update after each restoration but never
      receive focus as an Undo/Redo side effect.

## 6. Clear Form

- [x] 6.1 Populate all Basic fields, leave a distinctive selection in Link title,
      and invoke Clear Form. It clears Basic in one step.
- [ ] FAIL 6.2 Edit shows **Undo Clear Form**. Undo restores all four fields, focuses
      Link title, and restores its selection. Redo clears all four again in one
      step and keeps a valid empty-field caret.
- [ ] 6.3 Repeat 6.1–6.2 in Advanced, including editor scroll/selection.
- [x] 6.4 Clear on an already-empty active form is disabled/no-op, creates no
      history, and does not invalidate an existing redo future.
- [x] 6.5 Build multiple text actions, then Clear. Undo Clear first, followed by
      the prior text actions with no skipped step or visible no-op.

Notes:
- 6.2, partial failure. Undo restores all four fields, and focuses the right field, but does not preserve the selection. Not sure about a valid empty-field caret; the Email address field is focused, with the caret, but that's not where the caret was before the Redo.

## 7. Apply Saved Values

- [x] 7.1 Put distinctive unsaved content in Basic and apply **Personal**. Edit
      shows **Undo Apply “Personal”**; one Undo restores the prior Basic content
      and its prior focus/selection. Redo reapplies Personal and focuses Email
      without selecting all.
- [x] 7.2 From Advanced with unsaved HTML, apply Basic **Work**. The app switches
      to Basic. Undo stays in Basic and restores Basic's content from before
      Apply; Advanced HTML remains untouched.
- [x] 7.3 From Basic, apply Advanced **HTML snippet**. Undo stays in Advanced and
      restores Advanced's previous content; Basic remains untouched.
- [x] 7.4 Apply a saved value whose content is identical to the destination
      mode's existing content. It creates no action and does not invalidate that
      mode's redo future, even when Apply switched modes.
- [x] 7.5 Apply after Undo. Only the destination mode's redo future is discarded.

## 8. Mode isolation

- [x] 8.1 Build several Basic actions, switch to a fresh Advanced form, and open
      Edit. Undo is disabled even though Basic has history.
- [x] 8.2 Create Advanced history, switch repeatedly between modes, and confirm
      each mode restores its own title, enabled state, undo sequence, and redo
      sequence.
- [x] 8.3 Undo in Basic never changes Advanced content; Undo in Advanced never
      changes Basic content.
- [x] 8.4 A mode switch creates no history and invalidates neither mode's Redo.
- [x] 8.5 Switching modes closes an open text group without merging it with later
      actions.

## 9. Redo invalidation and non-actions

- [x] 9.1 Undo in Basic, then move only the caret/selection. Redo remains
      available and works.
- [x] 9.2 Undo in Basic, then create a real Basic edit. Basic Redo becomes
      unavailable.
- [x] 9.3 Repeat 9.2 while Advanced has a redo future. The Basic edit does not
      discard Advanced Redo.
- [x] 9.4 After Undo, perform Copy Snippet, ordinary Copy, preview/result updates,
      Show/Hide Decoded Source, menu opening, and sheet opening/closing. Redo
      remains intact.
- [x] 9.5 Rejected `@` input in the Settings fallback field creates no form action
      and cannot disturb either form history.

## 10. Sheets, Settings, and key-window routing

- [x] 10.1 Open Save Current Values and type in its name field. `⌘Z` edits the
      name field; it does not alter the main form behind the sheet.
- [ ] FAIL 10.2 With the Save sheet active and no local action available, Undo is
      disabled rather than targeting the form.
- [x] 10.3 Edit a name in Manage Saved Values. `⌘Z` first targets that native text
      edit, never the form.
- [ ] 10.4 If saved-value Rename/Delete/Reorder undo is implemented, verify its
      separate action titles, ordering, restored payload/list position, and that
      closing the sheet returns unchanged form history.
- [x] 10.5 Focus the Settings fallback-message field and edit it. `⌘Z` targets
      that field. With focus elsewhere in Settings, Undo is disabled.
- [x] 10.6 With a Help window key, Undo and Redo are disabled.
- [x] 10.7 Return the main window to key status. The active mode's previous form
      titles and enabled state return immediately.
      
Notes:
- 10.2: Succeeds the first time we open the Save sheet. But if we click Cancel, and then re-open the Save sheet, Undo Typing remains active in the Edit menu. Choosing it throws an error, caught in Xcode:

Exception thrown while attempting to perform a menu item's action. It has been caught in order to not leave the menu in an inconsistent state. This is a bug in the client code. *** -[NSBigMutableString substringWithRange:]: Range {0, 7} out of bounds; string length 0
(
	0   CoreFoundation                      0x0000000186f4d1c0 __exceptionPreprocess + 176
	1   libobjc.A.dylib                     0x00000001869d691c objc_exception_throw + 88
	2   Foundation                          0x00000001886f7684 -[NSString _newSubstringWithRange:zone:] + 0
	3   AppKit                              0x000000018b4b12c0 -[NSTextStorage(NSUndo) _undoRedoAttributedSubstringFromRange:] + 140
	4   AppKit                              0x000000018bf45df4 -[NSUndoTyping undoRedo:] + 108
	5   Foundation                          0x00000001887d8c14 -[_NSUndoStack popAndInvoke] + 116
	6   Foundation                          0x00000001887d89d0 -[NSUndoManager undoNestedGroup] + 236
	7   AppKit                              0x000000018b9e1470 -[NSCellUndoManager undo] + 80
	8   Obfuskoder.debug.dylib              0x0000000104fe9bf4 $s10Obfuskoder10UndoRouterC07performB0yyF + 192
	9   Obfuskoder.debug.dylib              0x0000000105070438 $s10Obfuskoder11AppCommandsV4bodyQrvg7SwiftUI9TupleViewVyAE0H0PAEE8disabledyQrSbFQOyAiEE16keyboardShortcut_9modifiersQrAE13KeyEquivalentV_AE14EventModifiersVtFQOyAE6ButtonVyAE4TextVG_Qo__Qo__AWtGyXEfU0_yyScMYccfU_ + 168
	10  SwiftUI                             0x00000001bce9c7e0 $s7SwiftUI12ButtonActionO14callAsFunctionyyFyyScMYcXEfU_TA + 32
	11  SwiftUI                             0x00000001bcedf22c $sScM14assumeIsolated_4file4linexxyKScMYcXE_s12StaticStringVSutKs8SendableRzlFZyt_Tg5 + 140
	12  SwiftUI                             0x00000001bce98af0 $s7SwiftUI12ButtonActionO14callAsFunctionyyF + 592
	13  SwiftUI                             0x00000001bbcf4c50 $s7SwiftUI27PlatformItemListButtonStyleV8makeBody13configurationQrAA09PrimitivefG13ConfigurationV_tFyycAGYbcfu_yycfu0_TATm + 88
	14  SwiftUI                             0x00000001bc075974 $s7SwiftUI16MenuItemCallback33_FAC181F369DD6DB976B974E24A2F3570LLC10menuActionyySo06NSMenuD0CSgFTo + 48
	15  AppKit                              0x000000018b4a66c0 -[NSApplication(NSResponder) sendAction:to:from:] + 560
	16  AppKit                              0x000000018bd3cdf8 -[NSMenuItem _corePerformAction:] + 540
	17  AppKit                              0x000000018becc5bc _NSMenuPerformActionWithHighlighting + 160
	18  AppKit                              0x000000018b5a5b38 -[NSMenu performActionForItemAtIndex:] + 208
	19  AppKit                              0x000000018bd28950 -[NSMenu _internalPerformActionForItemAtIndex:invocationType:] + 84
	20  AppKit                              0x000000018bec1e44 +[NSCocoaMenuImpl _performActionForMenuItem:invocationType:] + 184
	21  AppKit                              0x000000018bcddaa8 -[NSMenuTrackingSession _performPostTrackingDismissalActions] + 488
	22  AppKit                              0x000000018bcdd6ec -[NSMenuTrackingSession startRunningMenuEventLoop:] + 1712
	23  AppKit                              0x000000018bcdcfcc -[NSMenuTrackingSession startMonitoringEvents:] + 276
	24  AppKit                              0x000000018bd8ef20 -[NSMenuBarTrackingSession _mouseDownEventHandler:] + 436
	25  AppKit                              0x000000018bd8ed40 -[NSMenuBarTrackingSession _handleMonitorEvent:] + 420
	26  AppKit                              0x000000018bd8ea38 __57-[NSMenuBarTrackingSession _addLocalEventMonitorIfNeeded]_block_invoke + 120
	27  AppKit                              0x000000018b4fb164 _NSSendEventToDequeuingObservers + 252
	28  AppKit                              0x000000018bea1e78 -[NSApplication(NSEventRouting) _nextEventMatchingEventMask:untilDate:inMode:dequeue:] + 2168
	29  AppKit                              0x000000018bea15bc -[NSApplication(NSEventRouting) nextEventMatchingMask:untilDate:inMode:dequeue:] + 72
	30  AppKit                              0x000000018b2ff13c -[NSApplication run] + 368
	31  AppKit                              0x000000018b2d77b0 NSApplicationMain + 880
	32  SwiftUI                             0x00000001bbc8947c $s7SwiftUI6runAppys5NeverOSo21NSApplicationDelegate_So11NSResponderCXcFTf4e_nAA07TestingdG0C_Tg5Tm + 140
	33  SwiftUI                             0x00000001bc03f4a4 $s7SwiftUI6runAppys5NeverOxAA0D0RzlF + 104
	34  SwiftUI                             0x00000001bc30b344 $s7SwiftUI3AppPAAE4mainyyFZ + 224
	35  Obfuskoder.debug.dylib              0x000000010508eb48 $s10Obfuskoder0A3AppV5$mainyyFZ + 40
	36  Obfuskoder.debug.dylib              0x000000010508ebf4 __debug_main_executable_dylib_entry_point + 12
	37  dyld                                0x0000000186a63e00 start + 6992
)
FAULT: NSRangeException: *** -[NSBigMutableString substringWithRange:]: Range {0, 7} out of bounds; string length 0; (user info absent)

It seems like something isn't being cleaned up oe reset in between closing and opening the Save sheet.

- In Manage Saved Values panel, changing an item's name is undoable immediately, but isn't _saved_ unless you hit return. Clicking the Done button should also save name changes.

## 11. Menu naming and localization

- [ ] 11.1 Verify the action titles **Typing**, **Delete**, **Cut**, **Paste**,
      **Replace**, **Complete Link Text**, **Clear Form**, and named Apply where
      each is applicable.
- [ ] 11.2 Every Undo title changes to the symmetric Redo title after invocation,
      and back again after Redo.
- [ ] 11.3 With a non-English test localization, the system-provided Undo/Redo
      prefix and app-provided action name are both localized and grammatical.

## 12. Accessibility and alternate input

- [ ] 12.1 With VoiceOver, invoke cross-field Undo/Redo. The affected field and
      changed value are discoverable without hunting through the form.
- [ ] 12.2 Whole-form Undo/Redo gives clear feedback without duplicate VoiceOver
      announcements.
- [ ] 12.3 Full Keyboard Access shows a standard visible focus ring on the field
      affected by Undo/Redo.
- [ ] 12.4 Menu commands and shortcuts produce identical focus, selection, and
      content results.

## Result record

Record the app build, macOS version, date, tester, and failures below. A failure
in any section blocks completion of the undo/redo feature.

| Build | macOS | Date | Tester | Result / failures |
|---|---|---|---|---|
| 125 | 26.5.2 | 2026-07-25 | Alderete | Failures noted inline. All but one cosmetic. 10.2 failure appears to be a resource allocation or staleness bug. |
