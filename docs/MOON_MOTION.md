# Усаги: стойка, бег и сердца

- В покое используется боковая стойка `stop go` из предоставленного SNES-листа; направление сохраняется после движения.
- Вдали от противника — шесть исходных кадров ходьбы. В пределах 440 пикселей по горизонтали и 160 по вертикали от живого врага — восемь новых кадров бега. Скорость ходьбы составляет 65% скорости бега.
- В тренировке **L / E** запускает Moon Spiral Heart Attack: 35 исходных кадров, 2,4 секунды. Затем вылетают пиксельные сердца. Во время каста движение, прыжок, рывок и другие атаки заблокированы. Получение урона отменяет каст; энергия уже потрачена. Смена персонажа также отменяет отложенный выстрел.
- Обычная тиара **K / Q** сохраняет быстрый запуск. Доступность приёмов в сюжетном режиме не менялась.

## Ассеты и проверка

Новые рисунки созданы встроенным ChatGPT Images:

- `assets/sprites/snes/moon_run.png` — восемь кадров бега, 4 × 2.
- `assets/sprites/snes/moon_heart.png` — пиксельное сердце.

`scripts/action/moon_motion.gd` переносит рисунки на игровую пиксельную сетку с nearest-neighbor масштабированием и бинарной прозрачностью. Оригинальные SNES-листы не изменены. `tools/add_moon_motion.py` сохраняет только координаты кадров в JSON: палочка, искры и волосы входят целиком. `tools/check_moon_motion.gd` проверяет задержку, единственный выстрел, отмену, стойку и переход ходьба/бег, а также снимает игровые скриншоты. `tools/check_snes.gd` сверяет исходные пиксели.

## Использованные промпты

### Бег

Create a production sprite sheet: Sailor Moon RUN cycle, matching the supplied SNES walking sprite reference exactly in costume, slim long-legged proportions and low resolution pixel-art palette. Eight distinct chronological running frames, arranged in exactly 4 equal columns and 2 equal rows on a genuinely transparent background. All facing RIGHT, side profile, leaning forward into energetic combat run, alternating bent knees, feet contact/passing/airborne poses, arms pumping, long gold twin tails trailing LEFT. No wand. Every sprite fully contained within its cell with ample transparent margins. Uniform character scale and baseline within cells. Crisp hard square pixels, limited SNES palette, dark outlines, white/navy sailor outfit, red bow and boots. Not chibi, no smooth painting, no labels, no text, no grid lines, no scenery. Landscape sheet 1536x1024, cells384x512, characters about300pixels tall, center each body at cell horizontal center. Reference is identity/style only; DRAW new RUNNING poses, not walking poses.

### Сердце

Game sprite asset: a single small pink magical HEART projectile in strict SNES 16-bit pixel art, transparent background. Centered large enough to read, symmetric heart silhouette with chunky square pixel staircase edges, dark magenta 1-pixel outline, hot pink middle, pale pink highlight at upper left, small white 2-pixel glint. Limited 5-color palette, no blur, no glow outside silhouette, no shadows, no particles, no text, no checkerboard. Render as a 24x24 pixel icon enlarged with nearest neighbor on a square canvas. This is for Sailor Moon heart attack.
