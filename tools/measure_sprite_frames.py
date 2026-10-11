"""Measure connected alpha silhouettes; write atlas coordinates, never alter PNGs."""
import json
from collections import deque
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]

def measure(path):
    image = Image.open(path).convert('RGBA')
    width, height = image.size
    mask = bytearray(1 if a > 32 else 0 for a in image.getchannel('A').get_flattened_data())
    components = []
    for seed in range(len(mask)):
        if not mask[seed]: continue
        mask[seed] = 0
        queue = deque([seed])
        left = right = seed % width
        top = bottom = seed // width
        area = 0
        pixels = []
        while queue:
            index = queue.popleft()
            x, y = index % width, index // width
            left, right = min(left, x), max(right, x)
            top, bottom = min(top, y), max(bottom, y)
            area += 1
            pixels.append(index)
            neighbors = []
            if x: neighbors.append(index - 1)
            if x + 1 < width: neighbors.append(index + 1)
            if y: neighbors.append(index - width)
            if y + 1 < height: neighbors.append(index + width)
            for other in neighbors:
                if mask[other]:
                    mask[other] = 0
                    queue.append(other)
        if area > 250:
            components.append((area, [left, top, right-left+1, bottom-top+1], pixels))
    frames = {}
    bodies = {}
    for area, rect, pixels in sorted(components, reverse=True):
        cx, cy = rect[0] + rect[2]/2, rect[1] + rect[3]/2
        index = min(3, int(cy / (height/4))) * 8 + min(7, int(cx / (width/8)))
        if index not in frames:
            frames[index] = rect
            bodies[index] = set(pixels)
    if len(frames) != 32:
        raise ValueError(f'{path.name}: expected 32 isolated bodies, found {len(frames)}; {sorted(frames)}')
    canvas = [max(r[2] for r in frames.values()) + 8, max(r[3] for r in frames.values()) + 8]
    exclusions = []
    alpha = image.getchannel('A').tobytes()
    for index in range(32):
        left, top, rw, rh = frames[index]
        own = bodies[index]
        spans = []
        for y in range(top, top+rh):
            start = None
            for x in range(left, left+rw+1):
                pos = y*width+x
                foreign = x < left+rw and alpha[pos] > 0 and pos not in own
                # Preserve antialiased pixels adjoining the main silhouette.
                if foreign:
                    foreign = not any((y+dy)*width+x+dx in own for dy in [-1,0,1] for dx in [-1,0,1])
                if foreign and start is None: start = x
                if not foreign and start is not None:
                    spans.append([start-left,y-top,x-start,1]); start = None
        exclusions.append(spans)
    print(path.name, '32 bodies', 'canvas', canvas)
    return {'rects': [frames[i] for i in range(32)], 'canvas': canvas, 'exclusions': exclusions}

if __name__ == '__main__':
    result = {p.stem: measure(p) for p in sorted((ROOT/'assets/sprites/expanded').glob('*.png'))}
    (ROOT/'data/action/sprite_regions.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
