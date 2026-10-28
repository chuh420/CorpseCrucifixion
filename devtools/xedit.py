import re
import sys
import math
import json

sys.path.insert(0, sys.argv[1])
import xpose


def m3(m):
    return [[m[r * 4 + c] for c in range(3)] for r in range(3)]


def mul3(a, b):
    return [[sum(a[r][k] * b[k][c] for k in range(3)) for c in range(3)] for r in range(3)]


def tr3(a):
    return [[a[c][r] for c in range(3)] for r in range(3)]


def norm(v):
    l = math.sqrt(sum(x * x for x in v))
    return [x / l for x in v]


def cross(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def rot_between(a, b):
    a, b = norm(a), norm(b)
    c = dot(a, b)
    ax = cross(a, b)
    s = math.sqrt(sum(x * x for x in ax))
    if s < 1e-9:
        return [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
    x, y, z = (v / s for v in ax)
    ang = math.atan2(s, c)
    co, si = math.cos(ang), math.sin(ang)
    t = 1 - co
    col = [
        [t * x * x + co, t * x * y - si * z, t * x * z + si * y],
        [t * x * y + si * z, t * y * y + co, t * y * z - si * x],
        [t * x * z - si * y, t * y * z + si * x, t * z * z + co],
    ]
    return tr3(col)


def mat_to_filequat(r):
    tr = r[0][0] + r[1][1] + r[2][2]
    if tr > 0:
        s = math.sqrt(tr + 1) * 2
        w, x, y, z = 0.25 * s, (r[1][2] - r[2][1]) / s, (r[2][0] - r[0][2]) / s, (r[0][1] - r[1][0]) / s
    elif r[0][0] > r[1][1] and r[0][0] > r[2][2]:
        s = math.sqrt(1 + r[0][0] - r[1][1] - r[2][2]) * 2
        w, x, y, z = (r[1][2] - r[2][1]) / s, 0.25 * s, (r[0][1] + r[1][0]) / s, (r[0][2] + r[2][0]) / s
    elif r[1][1] > r[2][2]:
        s = math.sqrt(1 + r[1][1] - r[0][0] - r[2][2]) * 2
        w, x, y, z = (r[2][0] - r[0][2]) / s, (r[0][1] + r[1][0]) / s, 0.25 * s, (r[1][2] + r[2][1]) / s
    else:
        s = math.sqrt(1 + r[2][2] - r[0][0] - r[1][1]) * 2
        w, x, y, z = (r[0][1] - r[1][0]) / s, (r[0][2] + r[2][0]) / s, (r[1][2] + r[2][1]) / s, 0.25 * s
    return [w, -x, -y, -z]


def world_mats(frames, order, anim):
    world = {}
    for name in order:
        local = frames[name]["bind"]
        a = anim.get(name)
        if a and 0 in a and 2 in a:
            local = xpose.srt(a.get(1, [1, 1, 1]), a[0], a[2])
        parent = frames[name]["parent"]
        world[name] = xpose.mat_mul(local, world[parent]) if parent else local
    return world


def aim_bone(text, bone, child, target):
    frames, order = xpose.parse_frames(text)
    anim = xpose.parse_anim(text)
    world = world_mats(frames, order, anim)
    wb, wc = world[bone], world[child]
    pos_b = [wb[12], wb[13], wb[14]]
    d_cur = [wc[12 + i] - pos_b[i] for i in range(3)]
    d_new = [target[i] - pos_b[i] for i in range(3)]
    new_world = mul3(m3(wb), rot_between(d_cur, d_new))
    new_local = mul3(new_world, tr3(m3(world[frames[bone]["parent"]])))
    return set_key(text, bone, "R", 4, mat_to_filequat(new_local))


def set_key(text, bone, kind, n, values):
    start = text.find("\nAnimationSet ")
    head, tail = text[:start], text[start:]
    m = re.search(r"\{\s*" + bone + r"\s*\}", tail)
    ks = tail.index("AnimationKey " + kind, m.end())
    ke = tail.index("}", ks)
    val = ",".join("%f" % v for v in values)
    nb = re.sub(r"(\d+);%d;[^;]+;;" % n, lambda mm: "%s;%d;%s;;" % (mm.group(1), n, val), tail[ks:ke])
    return head + tail[:ks] + nb + tail[ke:]


def shift_root(text, delta):
    start = text.find("\nAnimationSet ")
    tail = text[start:]
    m = re.search(r"\{\s*Bip01\s*\}", tail)
    ks = tail.index("AnimationKey T", m.end())
    cur = re.search(r"\d+;3;([^;]+);;", tail[ks:]).group(1)
    x, y, z = (float(v) for v in cur.split(","))
    return set_key(text, "Bip01", "T", 3, [x + delta[0], y + delta[1], z + delta[2]])


def main():
    src, dst, spec = sys.argv[2], sys.argv[3], json.loads(sys.argv[4])
    text = open(src).read()
    text = text.replace("AnimationSet Bob_Mannequin_Scarecrow", "AnimationSet " + spec["name"])
    for bone, child, target in spec.get("aims", []):
        text = aim_bone(text, bone, child, target)
    if spec.get("shift"):
        text = shift_root(text, spec["shift"])
    open(dst, "w").write(text)


if __name__ == "__main__":
    main()
