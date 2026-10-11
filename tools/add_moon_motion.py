"""Record source rectangles, not image edits. Original PNG pixels stay untouched."""
import json
from pathlib import Path
from PIL import Image
root = Path(__file__).resolve().parents[1]
path = root / 'data/action/snes_sprites.json'
specs = json.loads(path.read_text(encoding='utf-8'))
moon = specs['moon']
im = Image.open(root / 'assets/sprites/snes/sailor_moon.png').convert('RGBA')
def add(name, bounds, anchor):
    x0,y0,x1,y1 = bounds
    points = [(x,y) for y in range(y0,y1) for x in range(x0,x1)
              if im.getpixel((x,y))[:3] != (128,255,255)]
    xs,ys = zip(*points)
    x,y,r,b = min(xs),min(ys),max(xs)+1,max(ys)+1
    assert x>x0 and y>y0 and r<x1 and b<y1, (name,(x,y,r,b))
    moon['frames'][name] = {'rect':[x,y,r-x,b-y], 'pivot':[anchor[0]-x,anchor[1]-y],
        'selection':[x0,y0,x1-x0,y1-y0], 'source_anchor':anchor,
        'preserve_effects':True, 'exclusions':[], 'source_pixel_count':len(points)}
add('idle_side', [1,5,57,110], [29,108])
rows = [
    (838,965, [8,62,116,177,254,330,409,489,575,667], [36,88,145,222,294,371,447,531,621],960),
    (968,1088,[5,91,175,259,344,427,508,585,670], [48,130,216,301,385,468,553,635],1080),
    (1092,1223,[8,85,162,235,308,377,445,511,577,650], [53,131,205,278,347,418,485,552,615],1215),
    (1225,1362,[10,78,145,219,289,358,426,490,550,613], [53,115,190,258,325,395,463,523,582],1356)
]
keys=[]
for y0,y1,edges,anchors,baseline in rows:
    for i,anchor in enumerate(anchors):
        name=f'spiral_{len(keys):02}'
        add(name,[edges[i],y0,edges[i+1],y1],[anchor,baseline])
        keys.append(name)
moon['animations']['idle']={'frames':['idle_side'],'fps':3,'loop':True}
moon['animations']['land']={'frames':['jump_a','idle_side'],'fps':16,'loop':False}
moon['animations']['walk']=moon['animations']['run'].copy()
moon['animations']['walk']['fps']=9
moon['animations']['special_cast']={'frames':keys,'fps':len(keys)/2.4,'loop':False}
path.write_text(json.dumps(specs,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Added side idle and',len(keys),'complete magic frames (including detached sparks).')
