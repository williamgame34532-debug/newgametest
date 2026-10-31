import sys, bpy
sys.path.insert(0,'/tmp/bscripts'); import srcmdl
from mathutils import Vector
from mathutils.bvhtree import BVHTree
r=srcmdl.load('/tmp/u/fab/combine_fabricator/models/cf_rework/station.mdl'); V=r['verts']
vs=[];fs=[]
for m in r['meshes']:
    for t in m['tris']:
        b=len(vs)
        for i in t: p=V[i][0]; vs.append(Vector((-p[1],p[0],p[2])))
        fs.append((b,b+1,b+2))
bvh=BVHTree.FromPolygons(vs,fs)
for x,y in [(-4.1,-33.7),(3,-10),(6.5,6.6),(-5.4,-10.7)]:
    loc,n,i,d=bvh.ray_cast(Vector((x,y,100)),Vector((0,0,-1)))
    print(x,y,'roof z',round(loc.z,2) if loc else None)
