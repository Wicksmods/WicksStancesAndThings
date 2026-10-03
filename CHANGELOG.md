# Wick's Stances and Things - Changelog

## 0.9.2 (unreleased)

- A kick key on the strip, bindable under Key Bindings: the interrupt
  that fits your stance and your hands, at whoever you point at. Pummel
  in Berserker; Shield Bash in Battle or Defensive with a shield on; with
  no shield on there, the first press takes you to Berserker and the
  second Pummels. It hits the enemy under your mouse, else your focus,
  else your target, else the enemy you are facing, and never changes your
  target or your focus. Its icon shows what a press uses now, with the
  cooldown. One press is still one interrupt on one enemy: no key can
  find who is casting for you, so point at them (the nameplate castbars
  show who) and press.

## 0.9.1 - 2026-10-03

- Weapon swap keys, the same two as the paladin kit: one puts your
  two-hander in your hands, the other your one-hander and shield. They
  remember what you last wore, name pieces by item id, and fall back to
  the best piece carried. `/wst pin` chooses by hand, `/wst swap off`
  unloads them. Both sit on the strip after the smart key and are
  bindable under Key Bindings.
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
