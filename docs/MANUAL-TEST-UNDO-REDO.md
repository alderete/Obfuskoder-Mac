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

- [ ] 1.1 In a fresh Basic form, Edit shows disabled **Undo** and **Redo** at the
      top, with `⌘Z` and `⇧⌘Z`.
- [ ] 1.2 Switching to a fresh Advanced form leaves both commands disabled.
- [ ] 1.3 There are no content-area Undo/Redo buttons.
- [ ] 1.4 Repeatedly invoking Undo through any available accessibility or command
      path at the bottom of history is a harmless no-op and never crashes.

## 2. Deterministic Basic text grouping

> **Known naming limitation (accepted 2026-07-15).** Menu action *names* for
> Cut/Paste are inferred from the text diff, because the shared `NSTextField`
> field editor exposes no reliable cut/paste signal. Undo/redo **behavior** is
> always correct; only the label deviates: a multi-char clean paste reads
> **Undo Paste**, but a **Cut**, a paste *over a selection*, and a single-char
> paste read **Undo Replace**/**Undo Typing**. Score 2.6/2.8 on behavior, not
> the exact word. A proper `cut:`/`paste:` interception fix is backlogged.

- [ ] 2.1 Focus Email and type `first@example.com` continuously. Edit shows
      **Undo Typing**; one Undo removes the continuous insertion and Redo restores
      it with the caret at the recorded position.
- [ ] 2.2 Type `first`, pause for at least three seconds without moving the caret,
      then type `@example.com`. One Undo removes the entire continuous insertion;
      the pause did not create a boundary.
- [ ] 2.3 Type `abcdef`, move the caret between `c` and `d`, then type `XYZ`.
      Undo removes `XYZ` only; the next Undo removes the earlier insertion.
- [ ] 2.4 Type text, then Backspace several consecutive characters. First Undo
      restores the deleted run; the next Undo removes the insertion.
- [ ] 2.5 Alternate backward and forward deletion. Each direction is a distinct
      Delete action.
- [ ] 2.6 Paste text. Edit shows **Undo Paste**; Undo restores the pre-paste text
      and selection; Redo restores the post-paste text and selection.
- [ ] 2.7 Replace a selection by typing. Edit shows **Undo Replace**; Undo restores
      both the prior text and its prior selection.
- [ ] 2.8 Cut a selection. Undo restores the text and selection. (Menu label
      currently reads **Undo Replace**, not **Undo Cut** — see the naming note
      above; behavior is what matters here.)
- [ ] 2.9 Make two edit groups in Email, then Tab to Subject and edit it. Leaving
      Email does not collapse its two groups. Undo walks Subject, then the two
      Email groups in reverse order.
- [ ] 2.10 An edit that returns the field to its group-starting value before the
      group closes creates no visible/no-op history entry.

## 3. Link text ghost completion

- [ ] 3.1 Enter a valid Email and leave Link text empty. The changing ghost value
      creates no Link text history entry.
- [ ] 3.2 Focus empty Link text and press Tab once to accept the ghost value. Edit
      shows **Undo Complete Link Text**.
- [ ] 3.3 Undo returns stored Link text to empty and reveals the current ghost
      value; Redo restores the accepted literal string.
- [ ] 3.4 After Undo, change Email before Redo. The new Email edit invalidates the
      Basic redo future; the ghost follows the new Email without creating its own
      action.

## 4. Advanced text behavior

- [ ] 4.1 Repeat tests 2.1–2.8 in the Advanced HTML editor, including multiline
      insertion and deletion.
- [ ] 4.2 Undo an action outside the visible viewport. The editor scrolls to
      reveal the restored caret or selection.
- [ ] 4.3 Leave and return to the Advanced editor after making multiple groups.
      Focus loss does not collapse those groups.
- [ ] 4.4 Smart substitutions and spell checking remain disabled throughout
      Undo/Redo.

## 5. Cross-field ordering and focus

- [ ] 5.1 Edit Email, Link title, and Subject in that order. Three Undos affect
      Subject, Link title, and Email in reverse order.
- [ ] 5.2 Each Undo and Redo focuses the affected field and restores the recorded
      caret/selection; it does not select the entire field unless that was the
      recorded state.
- [ ] 5.3 The generated result and preview update after each restoration but never
      receive focus as an Undo/Redo side effect.

## 6. Clear Form

- [ ] 6.1 Populate all Basic fields, leave a distinctive selection in Link title,
      and invoke Clear Form. It clears Basic in one step.
- [ ] 6.2 Edit shows **Undo Clear Form**. Undo restores all four fields, focuses
      Link title, and restores its selection. Redo clears all four again in one
      step and keeps a valid empty-field caret.
- [ ] 6.3 Repeat 6.1–6.2 in Advanced, including editor scroll/selection.
- [ ] 6.4 Clear on an already-empty active form is disabled/no-op, creates no
      history, and does not invalidate an existing redo future.
- [ ] 6.5 Build multiple text actions, then Clear. Undo Clear first, followed by
      the prior text actions with no skipped step or visible no-op.

## 7. Apply Saved Values

- [ ] 7.1 Put distinctive unsaved content in Basic and apply **Personal**. Edit
      shows **Undo Apply “Personal”**; one Undo restores the prior Basic content
      and its prior focus/selection. Redo reapplies Personal and focuses Email
      without selecting all.
- [ ] 7.2 From Advanced with unsaved HTML, apply Basic **Work**. The app switches
      to Basic. Undo stays in Basic and restores Basic's content from before
      Apply; Advanced HTML remains untouched.
- [ ] 7.3 From Basic, apply Advanced **HTML snippet**. Undo stays in Advanced and
      restores Advanced's previous content; Basic remains untouched.
- [ ] 7.4 Apply a saved value whose content is identical to the destination
      mode's existing content. It creates no action and does not invalidate that
      mode's redo future, even when Apply switched modes.
- [ ] 7.5 Apply after Undo. Only the destination mode's redo future is discarded.

## 8. Mode isolation

- [ ] 8.1 Build several Basic actions, switch to a fresh Advanced form, and open
      Edit. Undo is disabled even though Basic has history.
- [ ] 8.2 Create Advanced history, switch repeatedly between modes, and confirm
      each mode restores its own title, enabled state, undo sequence, and redo
      sequence.
- [ ] 8.3 Undo in Basic never changes Advanced content; Undo in Advanced never
      changes Basic content.
- [ ] 8.4 A mode switch creates no history and invalidates neither mode's Redo.
- [ ] 8.5 Switching modes closes an open text group without merging it with later
      actions.

## 9. Redo invalidation and non-actions

- [ ] 9.1 Undo in Basic, then move only the caret/selection. Redo remains
      available and works.
- [ ] 9.2 Undo in Basic, then create a real Basic edit. Basic Redo becomes
      unavailable.
- [ ] 9.3 Repeat 9.2 while Advanced has a redo future. The Basic edit does not
      discard Advanced Redo.
- [ ] 9.4 After Undo, perform Copy Snippet, ordinary Copy, preview/result updates,
      Show/Hide Decoded Source, menu opening, and sheet opening/closing. Redo
      remains intact.
- [ ] 9.5 Rejected `@` input in the Settings fallback field creates no form action
      and cannot disturb either form history.

## 10. Sheets, Settings, and key-window routing

- [ ] 10.1 Open Save Current Values and type in its name field. `⌘Z` edits the
      name field; it does not alter the main form behind the sheet.
- [ ] 10.2 With the Save sheet active and no local action available, Undo is
      disabled rather than targeting the form.
- [ ] 10.3 Edit a name in Manage Saved Values. `⌘Z` first targets that native text
      edit, never the form.
- [ ] 10.4 In Manage Saved Values (per-session undo, a stack separate from the
      form): delete a preset → `⌘Z` restores it at its original position (the
      row animates in as rows make room); `⇧⌘Z` deletes again. Reorder — drag
      and Move Up/Down — → `⌘Z` restores the order; `⇧⌘Z` re-applies. The Edit
      menu shows **Undo Delete “Name”** / **Undo Move “Name”** (symmetric Redo),
      disabled when the stack is empty. While a name field is focused and edited,
      `⌘Z` undoes the text (native), not the list; a merely-focused field does
      not shadow the list undo. Closing and reopening the panel starts empty.
      With Reduce Motion on, restores are instant. The panel is a fixed height
      (~3.5 rows) and scrolls; it does not resize as items are added/removed.
- [ ] 10.5 Focus the Settings fallback-message field and edit it. `⌘Z` targets
      that field. With focus elsewhere in Settings, Undo is disabled.
- [ ] 10.6 With a Help window key, Undo and Redo are disabled.
- [ ] 10.7 Return the main window to key status. The active mode's previous form
      titles and enabled state return immediately.

## 11. Menu naming and localization

- [ ] 11.1 Verify the action titles **Typing**, **Delete**, **Paste**,
      **Replace**, **Complete Link Text**, **Clear Form**, and named Apply where
      each is applicable. (**Cut** currently surfaces as **Replace** — accepted
      diff-based-naming limitation, see the §2 note.)
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
| | | | | |
