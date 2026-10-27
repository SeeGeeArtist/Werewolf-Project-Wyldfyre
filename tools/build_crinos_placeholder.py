#!/usr/bin/env python3
"""Build original, deliberately simple Crinos head/collar and fur swatches.

Requires Pillow and numpy. No game meshes or third-party geometry are copied.
GLB is STATIC, in head-bone-local coordinates: X up, Y forward, Z sideways.
Replace the GLB at the same path; it is not a human rest-pose skinned rig.
"""
import argparse
import io
import json
import math
import struct
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
BODY = ROOT / "common/media/textures/Body"
ASSETS = ROOT / "common/media/models_X/WTAGarou"


def swatch(source, suffix):
    im = Image.open(source).convert("RGBA")
    w, h = im.size
    # A central torso patch, not the whole UV sheet (black padding, eyes, nose).
    crop = np.array(im.crop((int(.40*w), int(.40*h), int(.60*w), int(.60*h))))
    pixels = crop[:, :, :3][(crop[:, :, 3] > 200) & (crop[:, :, :3].max(axis=2) > 24)]
    if len(pixels) < 16:
        raise ValueError(f"{source}: sampling patch has too few fur pixels; choose another patch")
    color = np.median(pixels, axis=0)
    rng = np.random.default_rng(430)
    noise = Image.fromarray(rng.integers(0, 256, (256, 256), dtype=np.uint8))
    noise = noise.resize((512, 512)).filter(ImageFilter.GaussianBlur(.6))
    grain = (np.array(noise, dtype=float)-127.5)/127.5 * 15
    rgb = np.clip(color[None, None, :] + grain[:, :, None], 0, 255).astype(np.uint8)
    fur = Image.fromarray(rgb).convert("RGBA")
    body_path = BODY / f"WTAGarou_CrinosBody_{suffix}.png"
    fur.save(body_path)
    atlas = fur.copy()
    # Lower strip reserved for muzzle/nose, teeth, eyes; all body pixels stay fur.
    for box, c in [((0, 448, 170, 512), (25, 23, 21, 255)),
                   ((170, 448, 340, 512), (220, 212, 190, 255)),
                   ((340, 448, 512, 512), (191, 137, 55, 255))]:
        atlas.paste(c, box)
    atlas.save(BODY / f"WTAGarou_CrinosHead_{suffix}.png")
    return atlas, [int(c) for c in color]


def head_glb(atlas):
    positions, normals, uvs = [], [], []

    def triangle(a, b, c, uv=None):
        a, b, c = [np.array(p, dtype=float) for p in (a, b, c)]
        n = np.cross(b-a, c-a)
        length = np.linalg.norm(n)
        if length < 1e-9:
            return
        n /= length
        for p in (a, b, c):
            positions.append(p.tolist())
            normals.append(n.tolist())
            uvs.append(list(uv) if uv else [(.5 + p[2]*2) % 1, .12 + (p[0]+.2)*1.15])

    def ellipsoid(center, size, uv=None, rings=8, sides=12):
        def p(i, j):
            t, a = math.pi*i/rings, 2*math.pi*j/sides
            return [center[0]+size[0]*math.cos(t),
                    center[1]+size[1]*math.sin(t)*math.cos(a),
                    center[2]+size[2]*math.sin(t)*math.sin(a)]
        for i in range(rings):
            for j in range(sides):
                a,b,c,d = p(i,j),p(i+1,j),p(i+1,j+1),p(i,j+1)
                triangle(a,b,c,uv); triangle(a,c,d,uv)

    # Closed overlapping low-poly volumes: replace with an authored unified mesh.
    ellipsoid((-.055,-.010,0), (.125,.100,.135))  # thick neck/mane cuff
    ellipsoid((.085,.015,0), (.125,.105,.092))    # skull
    ellipsoid((.060,.130,0), (.050,.115,.060))    # muzzle
    ellipsoid((.048,.231,0), (.032,.027,.045), (.12,.94), 4, 8)
    for side in (-1,1):
        z = side*.068
        verts = [(.150,-.018,z-.040),(.150,.030,z+.025),(.270,-.020,z+side*.015),(.150,-.057,z+.022)]
        for face in ((0,1,2),(1,3,2),(3,0,2),(0,3,1)):
            triangle(*(verts[i] for i in face))
        ellipsoid((.108,.096,side*.067),(.012,.015,.008),(.83,.94),4,6)

    buffers, views, accessors = [], [], []
    offset = 0
    for array, kind in ((positions,"VEC3"),(normals,"VEC3"),(uvs,"VEC2")):
        data=np.asarray(array,dtype="<f4").tobytes()
        views.append({"buffer":0,"byteOffset":offset,"byteLength":len(data),"target":34962})
        acc={"bufferView":len(views)-1,"componentType":5126,"count":len(array),"type":kind}
        if array is positions:
            acc.update(min=np.min(array,axis=0).tolist(),max=np.max(array,axis=0).tolist())
        accessors.append(acc); buffers.append(data); offset+=len(data)
    image=io.BytesIO(); atlas.save(image,format="PNG")
    data=image.getvalue(); views.append({"buffer":0,"byteOffset":offset,"byteLength":len(data)})
    buffers.append(data)
    binary=b"".join(buffers); binary+=b"\0"*(-len(binary)%4)
    doc={"asset":{"version":"2.0","generator":"WTAGarou original Crinos placeholder"},
         "scene":0,"scenes":[{"nodes":[0]}],
         "nodes":[{"name":"WTAGarou_CrinosHead_ReplaceMe","mesh":0,
                   "extras":{"axes":"head bone local: +X up, +Y muzzle, +Z side",
                             "rig":"STATIC head + rigid neck cuff; no animation/skeleton"}}],
         "meshes":[{"primitives":[{"attributes":{"POSITION":0,"NORMAL":1,"TEXCOORD_0":2},"material":0}]}],
         "buffers":[{"byteLength":len(binary)}],"bufferViews":views,"accessors":accessors,
         "images":[{"bufferView":3,"mimeType":"image/png"}],"textures":[{"source":0}],
         "materials":[{"name":"CoatMatchedFur","pbrMetallicRoughness":{"baseColorTexture":{"index":0},"metallicFactor":0,"roughnessFactor":1}}]}
    text=json.dumps(doc,separators=(",",":")).encode(); text+=b" "*(-len(text)%4)
    ASSETS.mkdir(parents=True,exist_ok=True)
    path=ASSETS/"WTAGarou_CrinosHead.glb"
    path.write_bytes(struct.pack("<III",0x46546c67,2,28+len(text)+len(binary))+
                     struct.pack("<II",len(text),0x4e4f534a)+text+
                     struct.pack("<II",len(binary),0x004e4942)+binary)
    print(f"Head: {len(positions)//3} triangles, {path}")


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--coat",nargs=2,metavar=("PNG","SUFFIX"),
                        help="generate another coat pair without overwriting the authored GLB")
    args=parser.parse_args()
    if args.coat:
        source,suffix=args.coat
        if not suffix.replace("_","").replace("-","").isalnum():
            raise ValueError("Use an alphanumeric filename suffix")
        _,color=swatch(source,suffix); print(suffix,color)
        return
    for suffix,name in (("Timber","WTAGarou_Wolf_Timber.png"),("Brown","WTAGarou_Wolf_Brown.png"),
                        ("Blonde","WTAGarou_Wolf_Blonde.png"),("Brindle","WTAGarou_Wolf_Brindle.png")):
        atlas,color=swatch(BODY/name,suffix); print(suffix,color)
        if suffix=="Timber":
            head_glb(atlas)


if __name__=="__main__":
    main()
