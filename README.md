# Wick's Stances and Things

The warrior kit for **World of Warcraft: Forever**, built on
[WickCore](https://github.com/Wicks-mods/WickCore).

A warrior's loadout is a stance. Half the class is locked behind the wrong
one, and the cost of that is a second spent remembering which. This kit
puts the three stances in a row, lights the one you are in, and gives you
one key that reaches for an ability and the stance it needs.

## What it does

**Stance strip.** One 30px row: Battle, Defensive, Berserker, a smart
key, a kick key, and the two weapon swap keys. The stance you are in is ringed in fel green; stances you have not
learned yet are dim. Shift-drag moves it even when locked.

**The smart key.** Bind an ability with `/wst bind <ability>`. The key
puts you in the stance that ability needs and then uses it. From the
right stance that is a single press. From the wrong one it takes two: the
game applies a stance change and a cast from the same press as the change
only, and pretending otherwise with a castsequence just makes it
unpredictable. Sixteen abilities are known by name; anything else is cast
where you stand.

**The kick key.** One key for the interrupt that fits your stance and
your hands. Pummel in Berserker; Shield Bash in Battle or Defensive with a
shield on; with no shield on there, the first press takes you to
Berserker and the second Pummels. It hits the enemy under your mouse,
else your focus, else your target, else the enemy you are facing, and it
never changes your target or your focus. Its icon shows what a press uses
right now, with the cooldown. One press is one interrupt on one enemy: no
key can find who is casting for you, so point at them and press. Bind it
under Key Bindings, AddOns.

**Weapon swap keys.** Two keys, tied to nothing. One puts your
two-hander in your hands, the other your one-hander and shield. They
remember what you last wore, so a new weapon needs nothing done to it
beyond putting it on once, and they name every piece by item id so two
swords called the same thing cannot pick the wrong one. With nothing
remembered they take the best piece you carry; `/wst pin 2h` with an
item link makes a key reach for one piece and no other. Each macro
names where the set should end up rather than describing a move, so
pressing a key twice does nothing the second time. The strip shows the
piece each key puts on, with a mark on the set you are already wearing.

Worth knowing before you bind them: swapping resets your swing timer.

**Pre-pull checklist.** A shout up, in a stance, a weapon equipped, and a
shield for Defensive when you carry one. Read out of combat, from your
own auras and inventory.

**Talents, racials and a cooldown bar** through WickCore, the same as
every other kit.

## Commands

| | |
|---|---|
| `/wst` | show or hide the stance strip |
| `/wst kit` | talents and the pre-pull checklist |
| `/wst bind <ability>` | set the smart key |
| `/wst swap on|off` | keep the swap keys loaded |
| `/wst pin <2h|1h|shield> [link|clear]` | choose a piece by hand |
| `/wst lock` / `/wst unlock` | the strip's position |
| `/wst cd` | the cooldown bar |
| `/wst options` | everything above, with switches |
| `/wst status` | what the kit can see |

## Why it is not a combat tracker

Forever's addon rules make health, power and most combat state secret.
Stance is not: it is a loadout, readable at any time. Everything this kit
reads is readable out of combat and nothing of Blizzard's is written to.
Rage is deliberately absent for that reason.

## The suite

Wick's Bags, Wick's Comforts, Wick's Gear, and one kit per class: Stances
(warrior), Seals (paladin), Totems (shaman), Demons (warlock), Forms
(druid), Beasts (hunter), Poisons (rogue), Conjures (mage).
<https://wicksmods.com>

## Compatibility

World of Warcraft: Forever, 1.60.x, Interface 16001. Requires WickCore.

## License

MIT for code (see [LICENSE](LICENSE)). Brand chrome and the "Wick's" wordmark are trademarked, see [TRADEMARK.md](https://github.com/Wicks-mods/WickSuite/blob/main/TRADEMARK.md). Racial data from [talentsforever.com](https://talentsforever.com) (CC BY 4.0) via WickCore.
