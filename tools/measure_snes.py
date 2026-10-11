"""Validate manual source selections and record exact silhouette bounds; PNGs unchanged."""
import json
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[1]
path=root/'data/action/snes_sprites.json'
specs=json.loads(path.read_text(encoding='utf-8'))
for actor,spec in specs.items():
    image=Image.open(root/spec['sheet'].removeprefix('res://')).convert('RGBA')
    key=(128,255,255) if actor=='moon' else None
    for name,entry in spec['frames'].items():
        if entry.get('preserve_effects'): continue # Explicit full-effect ROIs in add_moon_motion.py.
        original=entry.setdefault('selection',entry['rect'][:])
        anchor=entry.setdefault('source_anchor',[entry['rect'][0]+entry['pivot'][0],entry['rect'][1]+entry['pivot'][1]])
        x,y,w,h=original
        x0,y0=max(0,x-16),max(0,y-4)
        x1,y1=min(image.width,x+w+16),min(image.height,y+h+4)
        opaque={(xx,yy) for yy in range(y0,y1) for xx in range(x0,x1) if image.getpixel((xx,yy))[3] and image.getpixel((xx,yy))[:3]!=key}
        pending=opaque.copy(); components=[]
        while pending:
            seed=pending.pop(); queue=[seed]; component={seed}
            while queue:
                xx,yy=queue.pop()
                for dy in [-1,0,1]:
                    for dx in [-1,0,1]:
                        p=(xx+dx,yy+dy)
                        if p in pending:
                            pending.remove(p); component.add(p); queue.append(p)
            components.append(component)
        body=max(components,key=len)
        xs,ys=zip(*body); left,top,right,bottom=min(xs),min(ys),max(xs)+1,max(ys)+1
        assert left>x0 and top>y0 and right<x1 and bottom<y1, (actor,name,'selection cuts silhouette',(left,top,right,bottom),(x0,y0,x1,y1))
        entry['rect']=[left,top,right-left,bottom-top]
        entry['pivot']=[anchor[0]-left,anchor[1]-top]
        entry['exclusions']=[]
        for yy in range(top,bottom):
            start=None
            for xx in range(left,right+1):
                foreign=xx<right and (xx,yy) in opaque and (xx,yy) not in body
                if foreign and start is None:start=xx
                if not foreign and start is not None:
                    entry['exclusions'].append([start-left,yy-top,xx-start,1]);start=None
        entry['source_pixel_count']=len(body)
        print(actor,name,len(body),'pixels',len(entry['exclusions']),'excluded spans')
path.write_text(json.dumps(specs,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
