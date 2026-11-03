"""Slice, chroma-key and resize generated environment artwork, without drawing."""
from pathlib import Path
import json
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/environment'
OUT.mkdir(exist_ok=True)
manifest={}

def key(image):
    image=image.convert('RGBA'); pixels=[]
    for r,g,b,a in image.getdata():
        strength=min(r,b)-g
        if strength>100: pixels.append((r,g,b,0))
        elif strength>35 and r>150 and b>120: pixels.append((min(r,g+55),g,min(b,g+55),round(a*(100-strength)/65)))
        else: pixels.append((r,g,b,a))
    image.putdata(pixels)
    return image

terrain=Image.open(ROOT/'assets/raw/environment_terrain.png').convert('RGBA')
for i,name in enumerate(['grass','dirt','water','stone']):
    col,row=i%2,i//2
    tile=terrain.crop((col*terrain.width//2,row*terrain.height//2,(col+1)*terrain.width//2,(row+1)*terrain.height//2))
    tile.resize((512,512),Image.Resampling.LANCZOS).save(OUT/f'{name}.png')
    manifest[name]={'source':'environment_terrain.png','cell':i,'size':[512,512]}
props=key(Image.open(ROOT/'assets/raw/environment_props.png'))
for i,name in enumerate(['tree','shrub','rocks','table']):
    col,row=i%2,i//2
    cell=props.crop((col*props.width//2,row*props.height//2,(col+1)*props.width//2,(row+1)*props.height//2))
    bounds=cell.getbbox()
    assert bounds and bounds[0]>0 and bounds[1]>0 and bounds[2]<cell.width and bounds[3]<cell.height
    cell=cell.crop(bounds);cell.thumbnail((384,384),Image.Resampling.LANCZOS)
    cell.save(OUT/f'{name}.png')
    manifest[name]={'source':'environment_props.png','cell':i,'crop':bounds,'size':cell.size,'edge_touch':False,'alpha':True}
bridge=key(Image.open(ROOT/'assets/raw/environment_bridge.png'))
bounds=bridge.getbbox()
assert bounds and bounds[0]>0 and bounds[1]>0 and bounds[2]<bridge.width and bounds[3]<bridge.height
bridge=bridge.crop(bounds);bridge.thumbnail((1536,512),Image.Resampling.LANCZOS);bridge.save(OUT/'bridge.png')
manifest['bridge']={'source':'environment_bridge.png','crop':bounds,'size':bridge.size,'alpha':True,'edge_touch':False}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest,indent=2))
