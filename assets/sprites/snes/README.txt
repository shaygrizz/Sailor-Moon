User-supplied SNES Sailor Moon sprite sheets.
Original filenames:
SNES - Sailor Moon - Playable Characters - Sailor Moon.png
SNES - Sailor Moon - Enemies & Bosses - Queen Beryl.png
Sheet extraction credit shown on originals: Rip by Roket.

Original supplied PNGs are byte-for-byte copies; no repainting or AI generation.
Runtime uses an exact cyan colour key (#80ffff) for Moon and the supplied
alpha channel for Beryl. Original foreground pixel colours are preserved.
Manual frame selections and foot pivots: data/action/snes_sprites.json.
Only neighbouring silhouettes inside overlapping frame rectangles are excluded.
Nearest-neighbour filtering, native 1x sprite scale in the 1280x720 game canvas.

Moon: original SNES poses plus the full 35-frame magic sequence.
Beryl: 14 selected poses, practice boss only; Act 1 story boss stays unchanged.
Additional supplied originals: Sailor Mercury, Sailor Mars, Sailor Jupiter,
Sailor Venus. The original sheets retain their embedded extraction credits
(Mercury: Rip By Vaati; sheet update marks are also preserved).
See docs/GUARDIAN_MOTION.md for the full roster integration and generated art.

Files named *_motion.png, moon_run.png, moon_heart.png and guardian_effects.png
are NEW ChatGPT Images assets, not original SNES sheets. Their prompts are
documented separately. Original files named sailor_*.png and queen_beryl.png
remain byte-identical to the supplied images.

QA: tools/measure_snes.py validates complete connected silhouettes.
tools/check_snes.gd compares every displayed foreground pixel with its source,
checks practice boss integration and captures in-game frames.
