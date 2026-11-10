#!/usr/bin/env python3
"""Strict offline structural audit of Blender first-person weapon GLBs."""
import json
from pathlib import Path
import struct
import sys

REQUIRED={
 "pistol":{"IRONYARD_Pistol_Static","IRONYARD_Pistol_Slide"},
 "knife":{"IRONYARD_Knife_Static"},
 "assault_rifle":{"IRONYARD_AssaultRifle_Static","IRONYARD_AssaultRifle_ChargingHandle",
                  "IRONYARD_AssaultRifle_Magazine"},
 "shotgun":{"IRONYARD_Shotgun_Static","IRONYARD_Shotgun_PumpAction"},
 "sniper":{"IRONYARD_Sniper_Static","IRONYARD_Sniper_Bolt"},
}
def check(ok,message):
    if not ok: raise ValueError(message)

def inspect(path,weapon):
    payload=path.read_bytes()
    check(2048<len(payload)<=20_000_000,"Invalid Roblox asset size")
    magic,version,size=struct.unpack_from("<4sII",payload)
    check(magic==b"glTF" and version==2 and size==len(payload),"Bad GLB header")
    pos=12
    chunks=[]
    while pos<len(payload):
        check(pos+8<=len(payload),"Truncated chunk")
        length,kind=struct.unpack_from("<I4s",payload,pos)
        pos+=8
        check(length%4==0 and pos+length<=len(payload),"Bad GLB chunk")
        chunks.append((kind,payload[pos:pos+length]))
        pos+=length
    check(len(chunks)==2 and chunks[0][0]==b"JSON" and chunks[1][0]==b"BIN\x00",
          "Missing GLB binary")
    data=json.loads(chunks[0][1].decode())
    binary=chunks[1][1]
    for view in data.get("bufferViews",[]):
        start=view.get("byteOffset",0)
        check(start+view["byteLength"]<=len(binary),"Broken buffer view")
    names={node["name"] for node in data.get("nodes",[]) if "mesh" in node}
    check(names==REQUIRED[weapon],"Wrong mesh names: "+str(names))
    triangles=0
    materials=set()
    for node in data["nodes"]:
        if "mesh" not in node: continue
        mesh=data["meshes"][node["mesh"]]
        for primitive in mesh["primitives"]:
            check("indices" in primitive and primitive.get("mode",4)==4,
                  "Not triangulated")
            for key in ("POSITION","NORMAL","TEXCOORD_0"):
                check(key in primitive.get("attributes",{}),"Missing "+key)
            idx=data["accessors"][primitive["indices"]]
            check(idx["count"]%3==0,"Corrupt triangle count")
            triangles+=idx["count"]//3
            materials.add(primitive["material"])
    check(250<=triangles<=40000,
          f"Mesh triangle budget violated on {weapon}: {triangles} triangles")
    check(len(materials)>=2,"No material segmentation")
    ready=0
    for i in materials:
        material=data["materials"][i]
        pbr=material.get("pbrMetallicRoughness",{})
        if "baseColorTexture" in pbr and "metallicRoughnessTexture" in pbr \
           and "normalTexture" in material:
            ready+=1
    check(ready>=2,"Missing actual PBR texture channels")
    images=data.get("images",[])
    check(len(images)>=3,"Expected embedded maps")
    check(all("bufferView" in im and im.get("mimeType","").startswith("image/")
              for im in images),"GLB images must be embedded")
    return {"triangles":triangles,"bytes":len(payload),
            "pbrMaterials":ready,"images":len(images)}

def main(root):
    root=Path(root)
    manifest=json.loads((root/"manifest.json").read_text())
    check(manifest["textureResolution"]==512,"Unexpected mobile texture size")
    check(set(manifest["weapons"])==set(REQUIRED), "Unexpected weapon manifest")
    check(len(manifest.get("exports",[]))==2*len(REQUIRED),
          "Missing complete ten-GLB export manifest")
    report={}
    for weapon in REQUIRED:
        report[weapon]={}
        for lod in ("LOD0","LOD1"):
            report[weapon][lod]=inspect(
                root/"meshes"/("iron_yard_"+weapon+"_"+lod+".glb"),weapon)
        check(report[weapon]["LOD0"]["triangles"] >
              report[weapon]["LOD1"]["triangles"],
              "LOD0 must exceed LOD1 in geometry")
    check((root/"weapons_source.blend").stat().st_size>10000,
          "Missing editable Blender source")
    for weapon in REQUIRED:
        check((root/("iron_yard_"+weapon+"_source.blend")).stat().st_size>10000,
              "Missing per-weapon Blender source: "+weapon)
    (root/"validation_summary.json").write_text(json.dumps(report,indent=2)+"\n")
    print("IRON YARD weapon geometry / GLB PBR audit OK",report)

if __name__=="__main__":
    if len(sys.argv)!=2: raise SystemExit("usage: validate_weapon_exports.py <assets>")
    main(sys.argv[1])
