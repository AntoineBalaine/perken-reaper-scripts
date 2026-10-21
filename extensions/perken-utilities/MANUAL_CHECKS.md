# Manual checks: note-length simplification and what it touched

The unit tests cover everything that does not need REAPER. These are the
things that do — see [CONTRIBUTING.md](../CONTRIBUTING.md), "Extensions can
register actions and hooks, but cannot be tested inside REAPER by the
build."

Build and install first:

```sh
zig build -Doptimize=ReleaseSafe     # in extensions/perken-utilities
```

Launch REAPER from a terminal to see the logs; a `ReleaseSafe` build of this
extension logs at `info`, and the simplifier logs under `(rhythm)`.

The regression checks come first on purpose: they cover working features
that were refactored underneath, so a fault there is a fault introduced,
not a feature missing.

## 1. Regressions — features that were refactored underneath

Their note-reading loops were replaced with the shared
`helpers.collectPpqNotes`, and their filtering was re-derived by reading the
old code rather than by test, so this section is where a mistake is most
likely to show.

### kawa: Legato (`Perked: Legato`, MIDI editor)

- [ ] With **nothing** selected: every chord ends where the next one begins,
      the last at the item end. Same result as before the refactor.
- [ ] With **some notes selected**: each selected chord ends at the next
      selected one, and the last selected chord stops before the next
      *unselected* note — not at the item end. This is the case that needed
      both the filtered and the unfiltered note list, so it is the one worth
      checking carefully.
- [ ] Undo restores the original lengths in one step.

### kawa: QuantizeNoteEnds (MIDI editor)

- [ ] With nothing selected: every note's end snaps to the grid, starts
      unchanged.
- [ ] With a selection: only the selected notes move.
- [ ] A take with more than 1000 notes still refuses with the "over 1000
      clip num" message box rather than acting (the cap is in
      `collectTarget`, which also changed).

### Tempo and grid actions (`tempoAt`, `dividedBpmAtTime`, `nearestBarLine`)

Three casts were removed and routed through `timemap`. `tempoAt` now reads
the time-signature denominator from the same `TimeMap2_timeToBeats` call it
always did, so the figure should be identical — but it is used to scale a
tempo, so an error here is a wrong tempo rather than a crash.

- [ ] `ConformItemsToSessionTempo` on an item recorded at another tempo:
      the notes land on the session grid, as before.
- [ ] The same in an **/8 time signature** (6/8 or 12/8). REAPER reports a
      "divided" BPM there, and undoing that division is exactly what the
      refactored `tempoAt` does — a bug would show as the stretch being out
      by a factor of two.
- [ ] A beat-detection commit action (`setProjectTempo` or
      `setTempoForItem`) still sets the tempo it detects.
- [ ] `alignToGrid` still lands bar 1 on the nearest bar line
      (`nearestBarLine`).

### Other extensions (`reaziglib` changed)

`reaper_helpers` gained the shared collectors and `collectNotes` was
reimplemented on top of them. The test suites of all four extensions pass,
but loading is not tested.

- [ ] `console1` loads and its surface responds.
- [ ] `reavim-ext` loads and keys still route.

## 2. ABC export — the meter-change fix

`Timing` now carries a list of signatures and `writeSmf` interleaves a meta
event per change. The single-signature path is the regression risk; the
multi-signature path is the new behaviour.

- [ ] **Regression:** export an item in plain 4/4 with
      `CopyItemsAsAbc`. The ABC should be exactly what it was before this
      branch — one `M:4/4`, same notes.
- [ ] **The fix:** an item spanning a time-signature change (4/4 for a bar
      or two, then 3/4). The exported ABC should show the change, not 4/4
      throughout. This is what silently exported wrong before.
- [ ] A change landing **exactly at the item's start**: the item exports in
      the new meter, with no stray signature from before it.
- [ ] A change **after the last note** but still inside the item: the
      trailing bars carry the new meter.
- [ ] An item that **starts mid-bar**: notes keep their position in the bar
      (ticks still count from the bar line before the item).
- [ ] An **/8 meter** (7/8 or 6/8). The denominator is written as a power of
      two, so a mistake here produces a nonsense meter in the ABC rather
      than a near-miss.
- [ ] All three entry points still work: `CopyItemsAsAbc`,
      `OpenItemsAsAbc`, `PreviewItemsAsAbc`.

## 3. SimplifyNoteLengths — the new action

`Perken: Simplify note lengths…`, registered in the **MIDI editor** section
only, so it should not appear in the main action list.

What it does and does not do is worth keeping in mind while checking: of the
simplifier's three rules only the note-plus-rest collapse changes MIDI data.
Re-tiling rests changes nothing (a rest is not a MIDI object) and a tie is
notation (the note keeps one start and one end). So the expected visible
effect is **note ends moving out**, never starts moving and never notes
appearing or disappearing.

### The motivating case

- [ ] In 4/4, four eighth notes on the beats with an eighth rest after each
      (eighth, rest, eighth, rest…). Each note should become a **quarter**.
- [ ] Note the audible consequence: those notes now *sound* a quarter long.
      That is inherent — MIDI has no staccato — and is the behaviour to
      confirm you want, not a bug. Say so if you would rather the MIDI were
      left alone.

### Scope and selection

- [ ] With **nothing** selected: every note in the take is considered.
- [ ] With **some notes** selected: only those are changed.
- [ ] Undo restores every length in **one** step.
- [ ] An **empty take**, and a take where nothing changes: no crash, no undo
      point full of nothing.

### Cases the code reasons about explicitly

- [ ] A **chord**: every note of the chord gets the same new length.
- [ ] **Overlapping notes**: the earlier note is treated as ending where the
      next begins, so it should not be lengthened past the next attack.
- [ ] The **last note of the item**: it is bounded by the item end, so it
      should be lengthened like any other note with silence after it — and
      never past the item end.
- [ ] A note **crossing a barline**: its length should be *unchanged*. A tie
      is notation only, so there is nothing to write back. If its length
      changes, the attack-mapping is wrong.
- [ ] An item **starting mid-bar**: lengths are computed against the real
      bar grid, not from zero. A note on beat 2 should behave like a note on
      beat 2.
- [ ] A selection **spanning a meter change** (4/4 into 3/4): nothing is
      lost or mangled at the change. Total note count unchanged.
- [ ] A **6/8 or 12/8** project: the beat is a dotted quarter, so the
      collapse is bounded at 3/8 rather than 1/4 — an eighth plus an eighth
      rest should still collapse, a dotted quarter plus a dotted-quarter
      rest should not.
- [ ] A **7/8** project: irregular meters take flat beats, which is
      deliberately conservative. Nothing should be lost; some notes simply
      will not be lengthened where an engraver might.
- [ ] A take with a **playrate other than 1.0**, or a **time-stretched**
      item: positions go through project QN, which accounts for both, so
      lengths should still land on the grid. Raw PPQ would get this wrong.
- [ ] A project with a **tempo change** inside the selection: tempo does not
      enter the arithmetic (bars are beats, not seconds), so the result
      should be unaffected by it.

### Failure handling

- [ ] If the log shows `(rhythm) ... not writing note lengths:
      AttackCountMismatch`, nothing should have been written. That path
      refuses rather than risking lengths landing on the wrong notes; if it
      ever appears in normal use, the input that triggered it is worth
      capturing.

## 4. Notes on the test build

`zig build test` statically links `libhegel` for the property-based tests
and downloads the pinned release on first run, so the first test build needs
network access. It is test-only: the shipped extension does not link it.
