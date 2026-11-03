"""Build deterministic city placement metadata; never generates visual art."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
old = [
 (0,630,[[0,630],[850,340],[1410,930],[2560,620],[3420,810]]),
 (900,440,[[0,340],[560,940],[1740,600],[2560,340],[3120,1110]]),
 (1570,920,[[0,950],[1190,620],[2050,340],[2630,950],[3820,410]]),
 (2750,560,[[0,340],[570,620],[1420,630],[2290,940],[3470,760]]),
 (3530,700,[[0,630],[850,930],[2020,340],[2580,630],[3430,800]]),
 (4550,1100,[[0,950],[1190,620],[2050,930],[3220,1000]])]
extra = [[4500,620],[5400,850],[6500,900],[8700,650],[9650,900],[10800,620],[11700,700]]
columns=[]
for index,(x,width,initial) in enumerate(old):
    entries=[]
    for row,(y,height) in enumerate(initial+extra):
        kind='buildings'
        if (index,row) in [(0,2),(3,1)] or row>=len(initial) and (row+index*3)%7 in [1,5]: kind='park'
        if (index,row)==(2,3) or row>=len(initial) and (row+index*2)%9 in [2,7]: kind='vacant'
        angle = 0
        if kind == 'buildings' and width >= 600 and height >= 600 and (index, row) in [(2,0),(4,1),(5,2),(5,3)]:
            angle = 14 if (index + row) % 2 == 0 else -14
        entries.append({'y':y,'height':height,'kind':kind,'sidewalk':(index*3+row)%4,'angle':angle})
    columns.append({'x':x,'width':width,'blocks':entries})
for index,(x,width) in enumerate([(7700,600),(8590,920),(9820,460),(10580,1100),(12000,630),(12950,920)]):
    y=0;row=0;entries=[]
    while y+340<=12400:
        height=min([620,930,340,760,950,630,820][(row+index*2)%7],12400-y)
        kind='park' if (row+index*3)%9 in [2,6] else ('vacant' if (row+index*2)%8 in [3,7] else 'buildings')
        angle = 0
        if kind == 'buildings' and width >= 900 and height >= 620 and (row + index*2) % 7 == 3:
            angle = 13 if (index + row) % 2 == 0 else -13
        entries.append({'y':y,'height':height,'kind':kind,'sidewalk':(index+row*3)%4,'angle':angle})
        y+=height+[240,280,220][(row+index)%3];row+=1
    columns.append({'x':x,'width':width,'blocks':entries})
doc={
 'version':5,'bounds':[-400,-400,14800,13200],
 'columns':columns,
 'rivers':[
  {'name':'RÍO COBRE','rect':[6200,-400,900,13200]},
  {'name':'BRAZO DEL OESTE','rect':[-400,7800,6600,600]}],
 'bridges':[
  {'name':'PUENTE DEL CENTRO','rect':[5800,1900,1700,320],'axis':'horizontal'},
  {'name':'PUENTE INDUSTRIAL','rect':[5800,6000,1700,320],'axis':'horizontal'},
  {'name':'PUENTE DEL SUR','rect':[5800,10600,1700,320],'axis':'horizontal'},
  {'name':'PUENTE DE LA AVENIDA','rect':[625,7540,280,1120],'axis':'vertical'},
  {'name':'PUENTE DE RIBERA','rect':[5660,7540,280,1120],'axis':'vertical'}],
 'districts':[
  {'name':'CENTRO','rect':[-400,-400,4800,4800]},
  {'name':'RIBERA OESTE','rect':[4400,-400,1800,8200]},
  {'name':'POLÍGONO','rect':[-400,4400,4800,3400]},
  {'name':'LAS VEGAS','rect':[-400,8400,6600,4400]},
  {'name':'ENSANCHE','rect':[7100,-400,7300,4600]},
  {'name':'LOS JARDINES','rect':[7100,4200,7300,4200]},
  {'name':'PUERTO SUR','rect':[7100,8400,7300,4400]}]
}
(ROOT/'data/city_layout.json').write_text(json.dumps(doc,ensure_ascii=False,indent=2)+'\n')
print('Generated',sum(len(col['blocks']) for col in columns),'blocks')
