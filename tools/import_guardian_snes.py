"""Import supplied SNES sheets byte-for-byte and measure explicit sprite selections."""
import json, shutil
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
PATH=ROOT/'data/action/snes_sprites.json'
specs=json.loads(PATH.read_text(encoding='utf-8'))
KEY=(128,255,255)
def add(spec,name,roi,anchor=None):
    im=Image.open(ROOT/spec['sheet'].removeprefix('res://')).convert('RGBA')
    x0,y0,x1,y1=roi
    points={(x,y) for y in range(y0,y1) for x in range(x0,x1) if im.getpixel((x,y))[:3]!=KEY}
    xs,ys=zip(*points); x,y,r,b=min(xs),min(ys),max(xs)+1,max(ys)+1
    assert x>x0 and y>y0 and r<x1 and b<y1,(spec['sheet'],name,(x,y,r,b),roi)
    if anchor is None:
        feet=[px for px,py in points if py>=b-5]
        anchor=[round((min(feet)+max(feet))/2),b-1]
    spec['frames'][name]={'rect':[x,y,r-x,b-y],'pivot':[anchor[0]-x,anchor[1]-y],
        'selection':[x0,y0,x1-x0,y1-y0],'source_anchor':anchor,'preserve_effects':True,
        'exclusions':[],'source_pixel_count':len(points)}
for id in ['mercury','mars','jupiter','venus']:
    source=Path('D:/Загрузки')/f'SNES - Sailor Moon - Playable Characters - Sailor {id.title()}.png'
    target=ROOT/f'assets/sprites/snes/sailor_{id}.png'
    shutil.copyfile(source,target)
    spec={'sheet':f'res://assets/sprites/snes/sailor_{id}.png','color_key':'#80ffff',
          'canvas':[200,200],'frames':{},'animations':{}}
    add(spec,'idle_side',[3,1,57,110])
    edges=[296,350,406,461,516,570,607] if id!='venus' else [263,305,347,391,433,474,514]
    for i in range(6): add(spec,f'walk_{i}',[edges[i],1,edges[i+1],111])
    if id=='mercury':
        attacks=[[162,1,220,110],[225,1,294,110],[295,302,354,413],[480,302,572,413]]
        casts=[[25,154,89,258],[104,154,169,258],[185,154,225,258],[238,154,299,258],[326,154,369,258],[399,154,450,258],[478,154,523,258]]
        jumps=[[43,1081,91,1202],[93,1081,139,1202],[141,1081,198,1202]]
        hurt=[8,677,58,783]
        special=[[229,914,276,1020],[308,840,402,1022]]
    elif id=='mars':
        attacks=[[160,1,213,110],[214,1,294,110],[210,302,257,410],[256,302,333,411]]
        casts=[[26,154,85,259],[105,154,164,259],[166,154,225,259],[239,154,297,259]]
        jumps=[[44,1080,85,1201],[90,1080,136,1201]]
        hurt=[5,678,59,784]
        special=[[229,912,282,1023],[332,893,429,1023]]
    elif id=='jupiter':
        attacks=[[166,1,216,112],[226,1,291,112],[429,302,505,436],[506,302,557,436]]
        casts=[[62,154,109,269],[110,154,158,269],[175,154,226,269],[230,154,277,269],[278,154,328,269],[329,154,375,269],[375,154,433,269]]
        jumps=[[6,1080,79,1204],[82,1080,131,1204]]
        hurt=[10,670,65,785]
        special=[[128,899,198,1020],[202,899,267,1020],[274,899,337,1020]]
    else:
        attacks=[[180,155,270,263],[271,155,345,263],[345,154,430,263],[430,155,585,263]]
        casts=[[0,154,41,268],[43,154,103,268]]
        jumps=[[21,849,67,951],[67,849,118,951]]
        hurt=[7,500,57,611]
        special=[[106,670,207,781],[207,670,314,781],[331,670,429,781],[430,670,543,781]]
    for name,regions in [('attack',attacks),('cast',casts),('jump',jumps),('original_special',special)]:
        for i,roi in enumerate(regions):add(spec,f'{name}_{i}',roi)
    add(spec,'hurt_0',hurt)
    def anim(name,keys,fps=12,loop=False):spec['animations'][name]={'frames':keys,'fps':fps,'loop':loop}
    anim('idle',['idle_side'],3,True)
    anim('walk',[f'walk_{i}' for i in range(6)],9,True)
    anim('run',[f'walk_{i}' for i in range(6)],12,True)
    anim('attack',[f'attack_{i}' for i in range(len(attacks))],16)
    anim('cast',[f'cast_{i}' for i in range(len(casts))],14)
    anim('jump',[f'jump_{i}' for i in range(len(jumps))],12)
    anim('fall',[f'jump_{len(jumps)-1}'],8)
    anim('dash',['walk_2'],8)
    anim('hurt',['hurt_0'],8)
    anim('land',['jump_0','idle_side'],16)
    anim('special_cast',[f'original_special_{i}' for i in range(len(special))],len(special)/2.4)
    specs[id]=spec
    print(id,len(spec['frames']),'source frames')
PATH.write_text(json.dumps(specs,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
