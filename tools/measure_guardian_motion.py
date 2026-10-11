"""Measure generated sprite alpha; write metadata only, never repaint PNGs."""
import json, statistics
from collections import deque
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
IDS=['mercury','mars','jupiter','venus','chibimoon','uranus','neptune','pluto','saturn']
HEIGHTS=[96,96,102,98,76,104,100,108,92]
def components(im):
    w,h=im.size
    alpha=im.getchannel('A').tobytes()
    mask=bytearray(v>=128 for v in alpha)
    groups=[]
    for seed in range(w*h):
        if not mask[seed]:continue
        mask[seed]=0;q=deque([seed]);points=[]
        while q:
            p=q.popleft();points.append(p);x,y=p%w,p//w
            for dy in [-1,0,1]:
                for dx in [-1,0,1]:
                    nx,ny=x+dx,y+dy
                    if 0<=nx<w and 0<=ny<h:
                        n=ny*w+nx
                        if mask[n]:mask[n]=0;q.append(n)
        if len(points)>=8:
            xs=[p%w for p in points];ys=[p//w for p in points]
            groups.append((len(points),(min(xs),min(ys),max(xs)+1,max(ys)+1),points))
    return sorted(groups,reverse=True),alpha
def measure(path,cols,rows):
    im=Image.open(path).convert('RGBA');w,h=im.size
    groups,alpha=components(im);cellw,cellh=w/cols,h/rows
    own={};bodies={};selected=set()
    for area,box,points in groups:
        x,y,r,b=box
        index=min(rows-1,int((y+b)/2/cellh))*cols+min(cols-1,int((x+r)/2/cellw))
        if index not in bodies and area>300:
            bodies[index]=box;own[index]=set(points);selected.add(points[0])
    assert len(bodies)==cols*rows,(path.name,'missing bodies',sorted(bodies))
    # Detached sparks belong to the nearest complete silhouette, not the nominal
    # grid cell: a long chain or projectile can extend beyond its cell.
    for area,box,points in groups:
        if points[0] in selected:continue
        x,y,r,b=box;cx,cy=(x+r)/2,(y+b)/2
        def distance(i):
            bx,by,br,bb=bodies[i]
            gap=max(bx-cx,0,cx-br)**2+max(by-cy,0,cy-bb)**2
            return gap+0.001*((cx-(bx+br)/2)**2+(cy-(by+bb)/2)**2)
        index=min(bodies,key=distance)
        if distance(index)<(min(cellw,cellh)*0.3)**2:own[index].update(points)
    result=[]
    for i in range(cols*rows):
        points=own[i];xs=[p%w for p in points];ys=[p//w for p in points]
        x,y,r,b=min(xs),min(ys),max(xs)+1,max(ys)+1
        bx,by,br,bb=bodies[i]
        assert br-bx<cellw*1.4 and bb-by<cellh*1.4,(path.name,i,'merged silhouettes',bodies[i])
        feet=[p%w for p in points if bb-8<=p//w<bb and bx<=p%w<br]
        anchor=(statistics.median(feet),bb-1)
        spans=[]
        for yy in range(y,b):
            start=None
            for xx in range(x,r+1):
                foreign=xx<r and alpha[yy*w+xx]>=128 and yy*w+xx not in points
                if foreign and start is None:start=xx
                if not foreign and start is not None:spans.append([start-x,yy-y,xx-start,1]);start=None
        result.append({'rect':[x,y,r-x,b-y],'pivot':[anchor[0]-x,anchor[1]-y],
            'exclusions':spans,'body':list(bodies[i]),'pixels':len(points)})
    return result
target=ROOT/'data/action/guardian_motion.json'
specs=json.loads(target.read_text(encoding='utf-8')) if target.exists() else {}
for id,height in zip(IDS,HEIGHTS):
    path=ROOT/f'assets/sprites/snes/{id}_motion.png'
    if not path.exists():continue
    inner=id in IDS[:4];frames=measure(path,4,4 if inner else 8)
    run=list(range(8)) if inner else list(range(8,16))
    scale=height/statistics.median([frames[i]['body'][3]-frames[i]['body'][1] for i in run])
    animations={'run':{'frames':run,'fps':12},'special_cast':{'frames':list(range(8,16)) if inner else list(range(24,32)),'fps':1,'durations':[0.45,0.45,0.45,0.45,0.3,0.1,0.1,0.1]}}
    if not inner:
        for name,indices,fps in [('idle',[0,1,2,3],4),('walk',[4,5,6,7],8),('jump',[16],10),('fall',[17],10),('hurt',[18],8),('dash',[19],8),('attack',[20,21,22,23],16),('cast',[24,25,26,27],12),('land',[16,0],16)]:
            animations[name]={'frames':indices,'fps':fps}
    specs[id]={'sheet':f'res://assets/sprites/snes/{id}_motion.png','scale':scale,'frames':frames,'animations':animations}
    print(id,len(frames),'frames, scale',round(scale,3),flush=True)
effect_frames=measure(ROOT/'assets/sprites/snes/guardian_effects.png',3,3)
skills=['ice','fire','thunder','chain','sugar','earth','ocean','scream','glaive']
sizes=[[40,40],[46,46],[32,58],[90,28],[24,24],[44,36],[44,44],[48,40],[74,92]]
specs['effects']={id:{'rect':frame['rect'],'exclusions':frame['exclusions'],'size':size} for id,frame,size in zip(skills,effect_frames,sizes)}
specs['effects']['mist']=specs['effects']['ice']
target.write_text(json.dumps(specs,indent=2)+'\n',encoding='utf-8')
