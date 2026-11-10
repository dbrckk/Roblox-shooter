#!/usr/bin/env python3
"""Blender background builder: original PBR 3D pistol / knife, two LODs each."""
import argparse
import json
import math
import sys
from pathlib import Path
import bpy

def box(name, pos, dims, mat, quality=2):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj=bpy.context.object
    obj.name=name
    obj.dimensions=dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if quality and min(dims)>0.05:
        mod=obj.modifiers.new("CNC bevel","BEVEL")
        mod.width=min(min(dims)*0.17,0.028)
        mod.segments=quality
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.materials.append(mat)
    return obj

def cylinder(name, pos, radius, depth, mat, quality=16, axis="Y"):
    angle=(math.pi/2,0,0) if axis=="Y" else (0,0,0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=quality,radius=radius,depth=depth,
                                         location=pos,rotation=angle)
    obj=bpy.context.object
    obj.name=name
    obj.data.materials.append(mat)
    return obj

def blade(mat):
    verts=[(-.17,.20,-.045),(.17,.20,-.045),(-.17,.20,.045),
           (.17,.20,.045),(-.008,1.37,-.004),(.008,1.37,-.004),
           (-.008,1.37,.004),(.008,1.37,.004)]
    faces=[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),
           (0,2,6,4),(1,5,7,3)]
    mesh=bpy.data.meshes.new("Knife ground bevel")
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj=bpy.data.objects.new("Ground knife blade",mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    # GLB requires UV coordinates, even on manually authored blade edges.
    uv=mesh.uv_layers.new(name="Knife UV")
    for poly in mesh.polygons:
        for loop in poly.loop_indices:
            co=mesh.vertices[mesh.loops[loop].vertex_index].co
            uv.data[loop].uv=(co.x+0.5,co.y/1.6)
    return obj

def joined(parts,name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts: obj.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    bpy.ops.object.join()
    result=bpy.context.object
    result.name=name
    bpy.context.scene.cursor.location=(0,0,0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    return result

def pistol(m,high):
    s=[]
    s.append(box("Frame",(0,0,.03),(.39,.84,.23),m["armor"],3 if high else 1))
    s.append(box("Sloped handle",(0,-.30,-.25),(.25,.27,.54),m["carbon"],3 if high else 1))
    s.append(box("Trigger guard",(0,.13,-.15),(.30,.25,.055),m["gunmetal"]))
    s.append(box("Trigger",(0,.16,-.20),(.04,.08,.13),m["gunmetal"]))
    s.append(box("Underslung rail",(0,.35,-.09),(.27,.29,.075),m["armor"]))
    s.append(cylinder("Barrel",(0,.75,.13),.076,.51,m["gunmetal"],24 if high else 12))
    s.append(cylinder("Muzzle bezel",(0,1.0,.13),.115,.08,m["gunmetal"],24 if high else 12))
    s.append(cylinder("Recessed bore",(0,1.048,.13),.052,.015,m["carbon"]))
    s.append(box("Magazine plate",(0,-.35,-.56),(.23,.21,.065),m["accent_sand"]))
    if high:
        for side in (-1,1):
            for i in range(2):
                s.append(box("Grip rib",(side*.14,-.24+i*.12,-.27),
                    (.022,.045,.29),m["carbon"],1))
    joined(s,"IRONYARD_Pistol_Static")
    parts=[]
    parts.append(box("Chamfered slide",(0,.12,.235),(.43,.92,.18),m["gunmetal"],3 if high else 1))
    parts.append(box("Chamber cutout",(.09,.09,.342),(.16,.21,.014),m["carbon"],0))
    parts.append(box("Front sight",(0,.50,.36),(.08,.06,.07),m["carbon"],1))
    parts.append(box("Rear sight",(0,-.30,.35),(.23,.07,.08),m["carbon"],1))
    for side in (-1,1):
        for i in range(4 if high else 2):
            parts.append(box("Slide serration",(side*.223,-.24+i*.05,.24),
                             (.012,.022,.13),m["carbon"],0))
    joined(parts,"IRONYARD_Pistol_Slide")

def knife(m,high):
    p=[]
    p.append(box("Full tang",(0,-.26,0),(.23,.68,.23),m["carbon"],3 if high else 1))
    p.append(box("Crossguard",(0,.11,0),(.51,.12,.16),m["gunmetal"],3 if high else 1))
    p.append(box("Steel pommel",(0,-.66,0),(.26,.11,.24),m["accent_sand"]))
    p.append(blade(m["gunmetal"]))
    p.append(box("Raised longitudinal blade ridge",(0,.44,.052),(.075,.54,.018),
                 m["armor"],1))
    if high:
        for side in (-1,1):
            for i in range(2):
                p.append(cylinder("Grip pin",(side*.13,-.42+i*.29,.0),.028,
                          .026,m["gunmetal"],16,axis="Z"))
        for i in range(4):
            p.append(box("Blade jimping",(0,.22+i*.08,.08),(.18,.027,.027),
                         m["carbon"],0))
    joined(p,"IRONYARD_Knife_Static")

def pbr(name, folder):
    mat=bpy.data.materials.new("IRONYARD_"+name)
    mat.use_nodes=True
    nodes=mat.node_tree.nodes
    links=mat.node_tree.links
    p=nodes.get("Principled BSDF")
    tex={}
    for kind in ("ColorMap","NormalMap","RoughnessMap","MetalnessMap"):
        path=folder/(name+"_"+kind+".png")
        if not path.is_file(): raise FileNotFoundError(path)
        im=bpy.data.images.load(str(path),check_existing=True)
        if kind!="ColorMap": im.colorspace_settings.name="Non-Color"
        node=nodes.new("ShaderNodeTexImage")
        node.image=im
        tex[kind]=node
    links.new(tex["ColorMap"].outputs["Color"],p.inputs["Base Color"])
    links.new(tex["RoughnessMap"].outputs["Color"],p.inputs["Roughness"])
    links.new(tex["MetalnessMap"].outputs["Color"],p.inputs["Metallic"])
    normal=nodes.new("ShaderNodeNormalMap")
    normal.inputs["Strength"].default_value=.55
    links.new(tex["NormalMap"].outputs["Color"],normal.inputs["Color"])
    links.new(normal.outputs["Normal"],p.inputs["Normal"])
    return mat

def build(weapon,lod,out,textures):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.data.materials.clear()
    mats={n:pbr(n,textures) for n in ("gunmetal","carbon","armor","accent_sand")}
    if weapon=="pistol": pistol(mats,lod=="LOD0")
    else: knife(mats,lod=="LOD0")
    bpy.ops.object.select_all(action="DESELECT")
    parts=[x for x in bpy.context.scene.objects if x.type=="MESH"]
    for x in parts: x.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    path=out/"meshes"/("iron_yard_"+weapon+"_"+lod+".glb")
    bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",
                               use_selection=True,export_yup=True)
    return {"weapon":weapon,"lod":lod,"names":sorted(x.name for x in parts),
            "file":path.name,"bytes":path.stat().st_size}

def main():
    argv=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    ap=argparse.ArgumentParser()
    ap.add_argument("--out",type=Path,required=True)
    ap.add_argument("--textures",type=Path,required=True)
    args=ap.parse_args(argv)
    out=args.out.resolve()
    textures=args.textures.resolve()
    (out/"meshes").mkdir(parents=True,exist_ok=True)
    rows=[]
    for w in ("pistol","knife"):
        for lod in ("LOD0","LOD1"):
            rows.append(build(w,lod,out,textures))
    build("pistol","LOD0",out,textures)
    bpy.ops.wm.save_as_mainfile(filepath=str(out/"weapons_source.blend"))
    (out/"manifest.json").write_text(json.dumps({
        "author":"IRON YARD original AssetForge",
        "weapons":["pistol","knife"],"textureResolution":512,"exports":rows
    },indent=2)+"\n",encoding="utf8")
    print(json.dumps(rows,indent=2))

if __name__=="__main__":
    main()
