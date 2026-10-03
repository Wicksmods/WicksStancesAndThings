# Wick's Stances and Things - Changelog

## Unreleased

- The "Shield for Defensive" checklist row now sees the shield. It read the
  item lookup as the client's bare returns when WickCore hands back one table,
  so it always answered "does not apply" with a shield equipped.

## 0.9.0

One version across the suite for the Forever beta. Every addon carried a
number of its own that said nothing about how finished it was, so they are
aligned here and the suite goes to 1.0.0 together at launch.

## 0.1.0 - 2026-09-22

First build. The warrior kit for World of Warcraft: Forever.

- Stance strip: three stance buttons and a smart key in one 30px row. The
  stance you are in is lit, the ones you have not learned are dim, and the
  smart key says whether pressing it will move you or swing.
- The smart key routes an ability to the stance it needs. `/wst bind
  <ability>`; Charge by default. Sixteen abilities are known by name and
  anything else is cast where you stand. From the wrong stance it takes
  two presses, because the game will not change stance and cast off one.
- Pre-pull checklist: a shout up, in a stance, a weapon equipped, and a
  shield for Defensive when you carry one.
- Talents, racials and a cooldown bar through WickCore, the same as every
  other kit.
- Shift-drag moves the strip even when locked.
