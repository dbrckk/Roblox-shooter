#!/usr/bin/env python3
"""IRON YARD VANGUARD modular 3D asset forge. Run via Blender in background.
All geometry is original; the R6-sized pieces are independent rigid MeshParts, not a skin-weighted mesh.
FBX intended as Roblox Studio import input; GLB and packed .blend for inspection and edits.
"""
import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

COLORS = ["olive", "sand", "slate", "rust"]
ACCENTS = {
    "olive": (0.48, 0.55, 0.34),
    "sand": (0.78, 0.69, 0.53),
    "slate": (0.42, 0.51, 0.56),
    "rust": (0.66, 0.39, 0.29),
}
# Dimensions are in approximate Roblox studs, Blender uses Z-up.
ANCHORS = {
    "torso": (0, 0, 3),
    "head": (0, 0, 4.5),
    "left_arm": (-1.5, 0, 3),
    "right_arm": (1.5, 0, 3),
    "left_leg": (-0.5, 0, 1),
    "right_leg": (0.5, 0, 1),
    "rifle": (1.5, -1.2, 3.15),
}

def args_from_cli():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--out", required=True)
    p.add_argument("--textures", required=True)
    p.add_argument("--skip-render", action="store_true")
    return p.parse_args(argv)

def shader(label, directory, tint=None):
    mat = bpy.data.materials.new(label)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    assert bsdf
    maps = ("ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap")
    images = {}
    for mapname in maps:
        path = directory / (label + "_" + mapname + ".png")
        if not path.exists():
            raise FileNotFoundError(path)
        img = bpy.data.images.load(str(path), check_existing=True)
        if mapname != "ColorMap":
            img.colorspace_settings.name = "Non-Color"
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.label = mapname
        images[mapname] = tex
    nt.links.new(images["ColorMap"].outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(images["RoughnessMap"].outputs["Color"], bsdf.inputs["Roughness"])
    nt.links.new(images["MetalnessMap"].outputs["Color"], bsdf.inputs["Metallic"])
    normal = nt.nodes.new("ShaderNodeNormalMap")
    normal.inputs["Strength"].default_value = 0.45
    nt.links.new(images["NormalMap"].outputs["Color"], normal.inputs["Color"])
    nt.links.new(normal.outputs["Normal"], bsdf.inputs["Normal"])
    if tint is not None:
        bsdf.inputs["Emission Color"].default_value = (tint[0], tint[1], tint[2], 1)
        bsdf.inputs["Emission Strength"].default_value = 0.0
    return mat

def box(objects, name, center, scale, material, bevel=0.045, segs=2):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if bevel > 0:
        modifier = obj.modifiers.new("Physical edge chamfer", "BEVEL")
        modifier.width = min(bevel, min(scale) * 0.35)
        modifier.segments = segs
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        # Maintain broadly compatible meshes; weighted normals on this Blender build
        # require Auto Smooth and otherwise warn for every generated plate.
    obj.data.materials.append(material)
    objects.append(obj)
    return obj

def tube(objects, name, center, radius, depth, material, vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=center, rotation=(math.pi / 2, 0, 0))
    obj = bpy.context.object
    obj.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.materials.append(material)
    objects.append(obj)
    return obj

def merge(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = objects[0]
    joined.name = "VANGUARD_" + name
    # All source primitives were baked with location. Pivot of combined mesh at (0,0,0).
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    for p in joined.data.polygons:
        p.use_smooth = False
    return joined

def part(name, mats, slim):
    armor, carbon, gun, visor, glow = (mats[x] for x in ("armor", "carbon", "gunmetal", "visor", "accent"))
    o = []
    if name == "torso":
        box(o, "Ballistic bodysuit", (0, 0, 0), (1.88, 0.92, 1.91), carbon, 0.12)
        box(o, "Chest armor", (0, -0.54, 0.23), (1.67, 0.27, 1.15), armor, 0.12)
        for s in (-1, 1):
            box(o, "Split chest plate", (s*0.46, -0.75, 0.39), (0.74, 0.17, 0.61), gun, 0.07)
            box(o, "Diagnostic port", (s*0.45, -0.85, 0.08), (0.48, 0.052, 0.085), glow, 0.018)
            box(o, "Reactor cooling fins", (s*0.54, 0.64, 0.06), (0.32, 0.23, 1.10), armor, 0.05)
        box(o, "Spine battery", (0, 0.64, -0.05), (1.26, 0.44, 1.49), gun, 0.11)
        box(o, "Central seam", (0, -0.79, 0.38), (0.10, 0.05, 0.76), glow, 0.019)
        box(o, "Belt body", (0, -0.10, -0.84), (1.92, 1.0, 0.22), gun, 0.06)
        box(o, "Buckled fastener", (0, -0.68, -0.84), (0.49, 0.13, 0.27), armor, 0.025)
        if not slim:
            for s in (-1, 1):
                box(o, "Belt pouch", (s * 0.73, -0.62, -0.75), (0.36, 0.31, 0.36), gun)
                box(o, "Back cooling strip", (s * 0.45, 0.88, -0.08), (0.1, 0.075, 1.04), glow, 0.018)
    elif name == "head":
        box(o, "Helmet enclosure", (0, 0, 0.02), (2.0, 1.10, 0.96), armor, 0.24, 3)
        box(o, "Wraparound visor recess", (0, -0.57, -0.06), (1.73, 0.13, 0.40), carbon, 0.09)
        box(o, "Optical eyeplate", (0, -0.665, -0.02), (1.55, 0.075, 0.24), visor, 0.055)
        box(o, "Scanned horizon", (0, -0.714, -0.015), (1.44, 0.045, 0.064), glow, 0.019)
        box(o, "Chin shield", (0, -0.59, -0.37), (1.13, 0.24, 0.26), gun, 0.08)
        box(o, "Brow armor", (0, -0.57, 0.36), (1.76, 0.22, 0.19), gun, 0.07)
        for s in (-1, 1):
            box(o, "Cheek exoskeleton", (s*0.86, -0.49, -0.16), (0.26, 0.34, 0.40), armor, 0.07)
            box(o, "Headset radio", (s*1.04, 0.02, 0.02), (0.20, 0.65, 0.53), gun, 0.09)
            if not slim:
                box(o, "Sensor antenna", (s*0.85, 0.15, 0.64), (0.09, 0.12, 0.50), glow, 0.025)
    elif name in ("left_arm", "right_arm"):
        s = -1 if name == "left_arm" else 1
        box(o, "Fabric arm underlay", (0, 0, 0), (0.86, 0.85, 1.90), carbon, 0.16)
        box(o, "Shoulder shell", (0, 0, 0.70), (1.17, 1.03, 0.58), armor, 0.16)
        box(o, "Elbow guard", (0, -0.44, -0.12), (0.97, 0.20, 0.42), gun, 0.09)
        box(o, "Forearm barrier", (0, -0.50, -0.55), (1.02, 0.34, 0.72), armor, 0.11)
        box(o, "Shoulder team signal", (s*0.49, -0.13, 0.70), (0.08, 0.49, 0.15), glow, 0.025)
        if not slim:
            box(o, "Forearm diagnostics", (0, -0.705, -0.53), (0.47, 0.05, 0.1), glow, 0.01)
            box(o, "Wrist armor", (0, -0.03, -0.88), (1.04, 1.01, 0.20), gun, 0.08)
    elif name in ("left_leg", "right_leg"):
        box(o, "Motorized cloth leg", (0, 0, 0), (0.84, 0.91, 1.88), carbon, 0.13)
        box(o, "Upper thigh hardplate", (0, -0.49, 0.48), (0.82, 0.27, 0.69), gun, 0.09)
        box(o, "Kneecap", (0, -0.53, -0.11), (0.91, 0.32, 0.38), armor, 0.12)
        box(o, "Shin shield", (0, -0.50, -0.52), (0.78, 0.32, 0.58), gun, 0.12)
        box(o, "Reinforced boot", (0, -0.14, -0.88), (0.99, 1.19, 0.29), armor, 0.08)
        if not slim:
            box(o, "Ankle sensor", (0, -0.70, -0.68), (0.5, 0.058, 0.085), glow, 0.018)
    elif name == "rifle":
        box(o, "Bullpup receiver", (0, 0.16, 0), (0.34, 1.43, 0.41), armor, 0.10)
        box(o, "Charging system", (0, -0.19, 0.16), (0.36, 0.54, 0.19), gun, 0.045)
        box(o, "Rail housing", (0, -0.61, 0.27), (0.22, 0.89, 0.17), gun, 0.043)
        box(o, "Scope glass", (0, -0.52, 0.37), (0.2, 0.26, 0.16), visor, 0.04)
        box(o, "Rail illumination", (0, -0.62, 0.37), (0.11, 0.64, 0.05), glow, 0.02)
        tube(o, "Rifled barrel", (0, -1.1, 0), 0.084, 1.42, gun)
        tube(o, "Tapered muzzle", (0, -1.87, 0), 0.128, 0.16, armor)
        box(o, "Stock", (0, 1.03, -0.05), (0.45, 0.49, 0.32), carbon, 0.11)
        box(o, "Trigger housing", (0, 0.32, -0.34), (0.23, 0.38, 0.40), gun, 0.09)
        box(o, "Removable magazine", (0, 0.23, -0.64), (0.22, 0.38, 0.50), carbon, 0.04)
        if not slim:
            for s in (-1, 1):
                box(o, "Side vents", (s * 0.17, -0.50, -0.09), (0.038, 0.46, 0.08), glow, 0.015)
                box(o, "Side rail", (s * 0.20, -0.74, 0.0), (0.09, 0.82, 0.08), armor, 0.02)
    else:
        raise ValueError(name)
    return merge(o, name)

def select_only(objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]

def export_gltf(path, objects):
    select_only(objects)
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format="GLB", use_selection=True,
        export_apply=False,
        export_materials="EXPORT",
    )

def export_fbx(path, obj):
    select_only([obj])
    bpy.ops.export_scene.fbx(
        filepath=str(path), use_selection=True,
        object_types={"MESH"}, axis_forward="-Z", axis_up="Y",
        apply_unit_scale=True, use_mesh_modifiers=True, bake_anim=False,
    )

def render_gallery(output, gallery):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 12
    # Ubuntu's free Blender build may be compiled without OpenImageDenoiser.
    # Disable denoising explicitly instead of aborting a valid mesh/PBR export.
    if hasattr(scene.cycles, "use_denoising"):
        scene.cycles.use_denoising = False
    for layer in scene.view_layers:
        if hasattr(layer, "cycles") and hasattr(layer.cycles, "use_denoising"):
            layer.cycles.use_denoising = False
    scene.render.resolution_x = 1440
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("Daylight Equipment Studio")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes.get("Background").inputs["Color"].default_value = (0.57, 0.60, 0.61, 1)
    world.node_tree.nodes.get("Background").inputs["Strength"].default_value = 0.55

    def light(name, loc, energy, color, size):
        bpy.ops.object.light_add(type="AREA", location=loc)
        l = bpy.context.object
        l.name = name
        l.data.energy = energy
        l.data.color = color
        l.data.shape = "DISK"
        l.data.size = size
        direction = Vector((0, 0, 2.2)) - l.location
        l.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    light("Large daylight softbox", (0, -8, 10), 2900, (0.96, 0.94, 0.84), 8)
    light("Amber rim softbox", (-8, 4, 9), 1800, (1.0, 0.61, 0.27), 7)
    light("Fill softbox", (7, 5, 7), 1450, (0.85, 0.91, 1.0), 6)

    mat = bpy.data.materials.new("GalleryFloor")
    mat.diffuse_color = (0.24, 0.26, 0.25, 1)
    bpy.ops.mesh.primitive_plane_add(size=2, location=(0, 0, -0.06))
    floor = bpy.context.object
    floor.name = "PhotoStudio floor (not part of exports)"
    floor.scale = (10, 5, 1)
    floor.data.materials.append(mat)

    bpy.ops.object.camera_add(location=(9.3, -18, 9.6))
    camera = bpy.context.object
    direction = Vector((0, 0, 2.55)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 15.1
    scene.camera = camera
    scene.render.filepath = str(output)
    bpy.ops.render.render(write_still=True)

def main():
    args = args_from_cli()
    output = Path(args.out).resolve()
    texture_dir = Path(args.textures).resolve()
    (output / "meshes").mkdir(parents=True, exist_ok=True)
    (output / "parts").mkdir(parents=True, exist_ok=True)
    (output / "preview").mkdir(parents=True, exist_ok=True)

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    all_parts = {}
    stats = {}
    for color in COLORS:
        mats = {name: shader(name, texture_dir) for name in ("armor", "carbon", "gunmetal", "visor")}
        mats["accent"] = shader("accent_" + color, texture_dir, ACCENTS[color])
        assembled = {}
        for component in ANCHORS:
            obj = part(component, mats, slim=False)
            assembled[component] = obj
            if color == "olive":
                export_fbx(output / "parts" / ("vanguard_" + component + ".fbx"), obj)
            obj.location = ANCHORS[component]
        export_gltf(output / "meshes" / ("vanguard_" + color + "_LOD0.glb"), list(assembled.values()))
        stats[color] = sum(len(obj.data.polygons) for obj in assembled.values())
        all_parts[color] = assembled

        # Corresponding LOD1 deliberately has fewer modeled pieces, not just hidden textures.
        low = {component: part(component, mats, slim=True) for component in ANCHORS}
        for component, obj in low.items():
            obj.location = ANCHORS[component]
        export_gltf(output / "meshes" / ("vanguard_" + color + "_LOD1.glb"), list(low.values()))
        for obj in low.values():
            bpy.data.objects.remove(obj, do_unlink=True)

    # Preview figures are placed in their own row after all exports so each GLB stays centered.
    for i, color in enumerate(COLORS):
        for obj in all_parts[color].values():
            obj.location.x += (i - 1.5) * 3.4
    if not args.skip_render:
        render_gallery(output / "preview" / "vanguard_contact_sheet.png", all_parts)

    # Pack all source textures and save a fully editable Blender work file.
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(output / "vanguard_source.blend"))
    manifest = {
        "project": "IRON YARD / VANGUARD",
        "source": "Original programmatically generated mesh and PBR texture maps",
        "license": "Original assets authored for this project",
        "source_files": ["tools/assetforge/build_vanguard.py", "tools/assetforge/generate_maps.py"],
        "palette": COLORS,
        "format": {
            "preview": "GLB per skin per LOD; FBX rigid R6 components in /parts",
            "compatible_import": "Roblox Studio 3D Importer, manual MeshPart upload/publication",
            "components": list(ANCHORS),
            "component_anchor_offset_studs": ANCHORS,
            "axis": "Blender source uses Z-up. FBX exports Y-up, -Z forward.",
            "animation": "Rigid 7-component R6 attachment, existing Motor6D gameplay animation",
            "skinned": False,
            "asset_ids_published": False,
            "textures_imported_to_roblox": False,
        },
        "polygons_by_color_LOD0": stats,
    }
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print("VANGUARD ASSET BUILD COMPLETE", json.dumps(stats))

if __name__ == "__main__":
    main()
