import sys

sys.path.insert(0, sys.argv[1])
import xpose

U0, U1 = 0.02, 0.58


def box(x0, y0, z0, x1, y1, z1, grain):
    faces = [
        ((1, 0, 0), [(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)]),
        ((-1, 0, 0), [(x0, y0, z1), (x0, y1, z1), (x0, y1, z0), (x0, y0, z0)]),
        ((0, 1, 0), [(x0, y1, z0), (x0, y1, z1), (x1, y1, z1), (x1, y1, z0)]),
        ((0, -1, 0), [(x0, y0, z1), (x0, y0, z0), (x1, y0, z0), (x1, y0, z1)]),
        ((0, 0, 1), [(x1, y0, z1), (x1, y1, z1), (x0, y1, z1), (x0, y0, z1)]),
        ((0, 0, -1), [(x0, y0, z0), (x0, y1, z0), (x1, y1, z0), (x1, y0, z0)]),
    ]
    out = []
    for normal, quad in faces:
        a, b, c, d = quad
        e1 = [b[i] - a[i] for i in range(3)]
        e2 = [c[i] - a[i] for i in range(3)]
        cr = [e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0]]
        if sum(cr[i] * normal[i] for i in range(3)) < 0:
            quad = [a, d, c, b]
        uvs = []
        for p in quad:
            if grain == "y":
                along = (p[1] - y0) / (y1 - y0)
                across = (0.0 if p[2] == z0 else 1.0) if normal[0] != 0 else (0.0 if p[0] == x0 else 1.0)
            else:
                along = (p[0] - x0) / (x1 - x0)
                across = (0.0 if p[2] == z0 else 1.0) if normal[1] != 0 else (0.0 if p[1] == y0 else 1.0)
            uvs.append((U0 + (U1 - U0) * across, 1.0 - along))
        out.append((normal, quad, uvs))
    return out


def inverse_rigid(m):
    r = [[m[row * 4 + col] for col in range(3)] for row in range(3)]
    rt = [[r[c][rr] for c in range(3)] for rr in range(3)]
    t = [m[12], m[13], m[14]]
    nt = [-sum(t[k] * rt[k][c] for k in range(3)) for c in range(3)]
    return [rt[0][0], rt[0][1], rt[0][2], 0, rt[1][0], rt[1][1], rt[1][2], 0, rt[2][0], rt[2][1], rt[2][2], 0, nt[0], nt[1], nt[2], 1]


def main():
    skel_path, anim_path, out_path, front = sys.argv[2], sys.argv[3], sys.argv[4], float(sys.argv[5])
    skel = open(skel_path).read()
    anim_text = open(anim_path).read()
    frames, order = xpose.parse_frames(skel)
    world = {}
    for name in order:
        parent = frames[name]["parent"]
        world[name] = xpose.mat_mul(frames[name]["bind"], world[parent]) if parent else frames[name]["bind"]
    offsets = {b: inverse_rigid(world[b]) for b in ("Bip01", "Bip01_Pelvis")}

    pz0, pz1 = front, front + 0.09
    parts = box(-0.05, 0.0, pz0, 0.05, 1.36, pz1, "y")
    parts += box(-0.47, 0.895, pz0 + 0.005, 0.47, 0.985, pz1 + 0.005, "x")

    verts, normals, uvs, faces = [], [], [], []
    for normal, quad, quv in parts:
        base = len(verts)
        verts += quad
        normals += [normal] * 4
        uvs += quv
        faces += [(base, base + 1, base + 2), (base, base + 2, base + 3)]

    header_end = skel.index("\nMaterial ") + 1
    frames_start = skel.index("Frame Dummy01 {")
    mesh_frame_start = skel.index("Frame Body_Scarecrow")
    anim_start = anim_text.index("\nAnimationSet ")

    L = [skel[:header_end]]
    L.append('Material PZC_CrossWood {\n 1.000000;1.000000;1.000000;1.000000;;\n 9.999999;\n 0.000000;0.000000;0.000000;;\n 0.000000;0.000000;0.000000;;\n\n TextureFilename {\n  "PZC_CrossWood.png";\n }\n}\n\n')
    L.append(skel[frames_start:mesh_frame_start])
    L.append("Frame PZC_Cross {\n \n\n FrameTransformMatrix {\n  1.000000,0.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,0.000000,1.000000;;\n }\n\n")
    L.append(" Mesh PZC_Cross {\n  %d;\n" % len(verts))
    L.append(",\n".join("  %f;%f;%f;" % v for v in verts) + ";\n")
    L.append("  %d;\n" % len(faces))
    L.append(",\n".join("  3;%d,%d,%d;" % f for f in faces) + ";\n\n")
    L.append("  MeshNormals {\n   %d;\n" % len(normals))
    L.append(",\n".join("   %f;%f;%f;" % n for n in normals) + ";\n")
    L.append("   %d;\n" % len(faces))
    L.append(",\n".join("   3;%d,%d,%d;" % f for f in faces) + ";\n  }\n\n")
    L.append("  MeshTextureCoords {\n   %d;\n" % len(uvs))
    L.append(",\n".join("   %f;%f;" % uv for uv in uvs) + ";\n  }\n\n")
    L.append("  MeshMaterialList {\n   1;\n   %d;\n" % len(faces))
    L.append(",\n".join("   0" for _ in faces) + ";\n\n   { PZC_CrossWood }\n  }\n\n")
    L.append("  XSkinMeshHeader {\n   2;\n   2;\n   2;\n  }\n\n")
    for bone, off in offsets.items():
        L.append('  SkinWeights {\n   "%s";\n   %d;\n' % (bone, len(verts)))
        L.append(",\n".join("   %d" % i for i in range(len(verts))) + ";\n")
        L.append(",\n".join("   0.500000" for _ in verts) + ";\n")
        L.append("   " + ",".join("%f" % v for v in off) + ";;\n  }\n\n")
    L.append(" }\n}\n")
    L.append(anim_text[anim_start:].replace("AnimationSet Bob_PZC_Cross", "AnimationSet PZC_CrossMeshPose", 1))
    open(out_path, "w").write("".join(L))


if __name__ == "__main__":
    main()
