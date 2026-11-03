"""Place existing raster terrain/props and author navigation metadata, not artwork."""
import json
import math
import random
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
rng = random.Random(51023)
forests = [
    {'name': 'BOSQUE DEL NORTE', 'rect': [-7500, -7500, 27000, 6400]},
    {'name': 'PINAR DEL OESTE', 'rect': [-7500, -1000, 6400, 20000]},
    {'name': 'BOSQUE DE LEVANTE', 'rect': [15000, -1000, 4500, 17500]},
    {'name': 'MONTE DEL SUR', 'rect': [-1000, 13800, 20500, 6000]},
]
paths = [
    ('CAMINO DEL NORTE', [[-6900,-1700],[19400,-1700]]),
    ('CIRCUITO DEL BOSQUE', [[-6900,-6000],[-4200,-6500],[-1700,-5700],[2000,-6400],[5200,-5600],[9100,-6400],[12500,-5500],[17000,-6000],[19400,-6000]]),
    ('ACCESO NORTE CENTRO', [[765,-400],[765,-1700],[900,-3400],[2000,-4400],[2000,-6400]]),
    ('ACCESO NORTE ENSANCHE', [[7400,-400],[7400,-1700],[8000,-3800],[9100,-6400]]),
    ('ACCESO NORTE LEVANTE', [[14135,-400],[14135,-1700],[14300,-3600],[12500,-5500]]),
    ('SENDA DEL PINAR', [[-6900,-6000],[-6600,-1700],[-7100,2000],[-6200,6500],[-6900,11000],[-6400,15000],[-6900,18300]]),
    ('CAMINO DE LOS CLAROS', [[-3000,-1700],[-3500,2000],[-2700,6500],[-3400,10500],[-3000,15000],[-2600,18300]]),
    ('ACCESO OESTE CENTRO', [[-200,1300],[-6900,1300]]),
    ('ACCESO OESTE SUR', [[-200,10500],[-6900,10500]]),
    ('CIRCUITO DEL SUR', [[-6900,15000],[765,15000],[4000,14600],[7400,15000],[11500,15500],[14135,15000],[19400,15000]]),
    ('CAMINO DE LAS DUNAS', [[-6900,18300],[-2600,18300],[3000,19000],[7400,18200],[13000,19000],[17000,18300],[19400,18300]]),
    ('ACCESO SUR CENTRO', [[765,12800],[765,15000]]),
    ('ACCESO SUR PUERTO', [[7400,12800],[7400,15000],[7400,18200]]),
    ('ACCESO SUR LEVANTE', [[14135,12800],[14135,15000],[13000,19000]]),
    ('CAMINO DE LEVANTE', [[17000,-6000],[17000,-1700],[16500,2500],[17500,6500],[16800,11000],[17000,15000],[17000,18300]]),
    ('ACCESO ESTE CENTRO', [[14135,2000],[17000,2000],[19400,2000]]),
    ('ACCESO ESTE JARDINES', [[14135,9000],[17000,9000],[19400,9000]]),
    ('CAMINO DE LA COSTA', [[19400,-6000],[19400,18300]]),
    ('ACCESO PLAYA DEL FARO', [[19400,-4500],[21320,-4500]]),
    ('ACCESO PLAYA BRAVA', [[19400,1600],[21320,1600]]),
    ('ACCESO CALA DEL PINAR', [[19400,4000],[21320,4000]]),
    ('ACCESO PLAYA DEL SUR', [[19400,8000],[21320,8000]]),
    ('ACCESO DUNAS DEL SUR', [[19400,15500],[21320,15500]]),
    ('ENLACE NORTE COSTA', [[17000,-6000],[19400,-6000]]),
    ('ENLACE SUR COSTA', [[17000,18300],[19400,18300]]),
]
beaches = [
    {'name':'PLAYA DEL FARO', 'rect':[19600,-6500,2000,9800]},
    {'name':'CALA DEL PINAR', 'rect':[20500,3400,1100,1100]},
    {'name':'PLAYA BRAVA', 'rect':[19800,4700,1800,13000]},
]
segments = [(a, b) for _, points in paths for a, b in zip(points, points[1:])]

def distance_sq(p, a, b):
    dx, dy = b[0]-a[0], b[1]-a[1]
    t = max(0, min(1, ((p[0]-a[0])*dx+(p[1]-a[1])*dy)/(dx*dx+dy*dy)))
    return (p[0]-a[0]-dx*t)**2 + (p[1]-a[1]-dy*t)**2

vegetation = []
for forest in forests:
    x0, y0, w, h = forest['rect']
    for x in range(x0+120, x0+w-100, 220):
        for y in range(y0+120, y0+h-100, 220):
            px, py = x+rng.randint(-65,65), y+rng.randint(-65,65)
            if rng.random() < 0.1 or any(distance_sq((px,py),a,b) < 290**2 for a,b in segments):
                continue
            kind = rng.choices(['tree','shrub','rocks'], [76,22,2])[0]
            size = rng.randint(145,220) if kind == 'tree' else rng.randint(65,115)
            vegetation.append([px,py,kind,size,round(rng.uniform(-math.pi,math.pi),3)])
doc = {
    'version':1, 'bounds':[-8400,-8400,32800,29200],
    'forests': forests, 'beaches':beaches,
    'oceans':[{'name':'COSTA ABIERTA','rect':[21600,-8400,2800,29200]}],
    'trails':[{'name':name,'width':320,'points':points} for name,points in paths],
    'vegetation':vegetation,
}
(ROOT/'data/wilderness.json').write_text(json.dumps(doc,ensure_ascii=False,separators=(',',':'))+'\n')
print(f'{len(vegetation)} plants, {len(paths)} dirt paths, {len(beaches)} coastal beaches')
