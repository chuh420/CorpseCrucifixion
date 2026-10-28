import re
import sys


def mat_mul(a, b):
    return [sum(a[r * 4 + k] * b[k * 4 + c] for k in range(4)) for r in range(4) for c in range(4)]


def quat_to_mat(w, x, y, z):
    return [
        1 - 2 * (y * y + z * z), 2 * (x * y + w * z), 2 * (x * z - w * y), 0,
        2 * (x * y - w * z), 1 - 2 * (x * x + z * z), 2 * (y * z + w * x), 0,
        2 * (x * z + w * y), 2 * (y * z - w * x), 1 - 2 * (x * x + y * y), 0,
        0, 0, 0, 1,
    ]


def srt(s, q, t):
    m = quat_to_mat(q[0], -q[1], -q[2], -q[3])
    for r in range(3):
        for c in range(3):
            m[r * 4 + c] *= s[r]
    m[12], m[13], m[14] = t
    return m


def parse_frames(text):
    frames = {}
    order = []
    token = re.compile(r"Frame\s+(\w+)\s*\{|FrameTransformMatrix\s*\{\s*([^;]+);;\s*\}|\{|\}")
    depth = 0
    frame_depths = []
    anim_start = text.find("\nAnimationSet ")
    body = text if anim_start < 0 else text[:anim_start]
    for m in token.finditer(body):
        s = m.group(0)
        if m.group(1):
            depth += 1
            parent = frame_depths[-1][0] if frame_depths else None
            frame_depths.append((m.group(1), depth))
            frames[m.group(1)] = {"parent": parent, "bind": None}
            order.append(m.group(1))
        elif m.group(2):
            frames[frame_depths[-1][0]]["bind"] = [float(v) for v in m.group(2).split(",")]
        elif s == "{":
            depth += 1
        elif s == "}":
            if frame_depths and frame_depths[-1][1] == depth:
                frame_depths.pop()
            depth -= 1
    return frames, order


def parse_anim(text):
    anim = {}
    start = text.find("\nAnimationSet ")
    if start < 0:
        return anim
    for m in re.finditer(r"Animation\s*\{\s*\{\s*(\w+)\s*\}(.*?)\n \}", text[start:], re.S):
        entry = {}
        for k in re.finditer(r"AnimationKey\s*\w*\s*\{\s*(\d+);\s*(\d+);\s*\d+;\d+;([^;]+);;", m.group(2)):
            entry[int(k.group(1))] = [float(v) for v in k.group(3).split(",")]
        anim[m.group(1)] = entry
    return anim


def world_positions(frames, order, anim, use_anim=True):
    world = {}
    for name in order:
        f = frames[name]
        local = f["bind"]
        a = anim.get(name) if use_anim else None
        if a and 0 in a and 2 in a:
            local = srt(a.get(1, [1, 1, 1]), a[0], a[2])
        if local is None:
            local = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
        parent = f["parent"]
        world[name] = mat_mul(local, world[parent]) if parent else local
    return {n: (m[12], m[13], m[14]) for n, m in world.items()}


CHAINS = [
    ["Bip01_Pelvis", "Bip01_Spine", "Bip01_Spine1", "Bip01_Neck", "Bip01_Head", "Bip01_HeadNub"],
    ["Bip01_Neck", "Bip01_L_Clavicle", "Bip01_L_UpperArm", "Bip01_L_Forearm", "Bip01_L_Hand", "Bip01_L_Finger0Nub"],
    ["Bip01_Neck", "Bip01_R_Clavicle", "Bip01_R_UpperArm", "Bip01_R_Forearm", "Bip01_R_Hand", "Bip01_R_Finger0Nub"],
    ["Bip01_Pelvis", "Bip01_L_Thigh", "Bip01_L_Calf", "Bip01_L_Foot", "Bip01_L_Toe0", "Bip01_L_Toe0Nub"],
    ["Bip01_Pelvis", "Bip01_R_Thigh", "Bip01_R_Calf", "Bip01_R_Foot", "Bip01_R_Toe0", "Bip01_R_Toe0Nub"],
]


def svg_view(pos, boxes, axis_h, axis_v, ox, title):
    scale = 300
    out = []

    def P(p):
        return ox + p[axis_h] * scale, 470 - p[axis_v] * scale
    out.append('<text x="%d" y="20" font-size="16">%s</text>' % (ox - 120, title))
    out.append('<line x1="%d" y1="470" x2="%d" y2="470" stroke="#888"/>' % (ox - 200, ox + 200))
    for lo, hi in boxes:
        a0, v0 = P(lo)
        a1, v1 = P(hi)
        out.append('<rect x="%f" y="%f" width="%f" height="%f" fill="#b5835a" opacity="0.6"/>' % (min(a0, a1), min(v0, v1), abs(a1 - a0), abs(v1 - v0)))
    for chain in CHAINS:
        pts = [P(pos[n]) for n in chain if n in pos]
        out.append('<polyline points="%s" fill="none" stroke="#c00" stroke-width="3"/>' % " ".join("%f,%f" % p for p in pts))
    return "\n".join(out)


def main():
    path, out = sys.argv[1], sys.argv[2]
    boxes = []
    if len(sys.argv) > 3:
        for spec in sys.argv[3].split("|"):
            v = [float(x) for x in spec.split(",")]
            boxes.append(((v[0], v[1], v[2]), (v[3], v[4], v[5])))
    text = open(path).read()
    frames, order = parse_frames(text)
    pos = world_positions(frames, order, parse_anim(text))
    for n in ["Bip01", "Bip01_Spine1", "Bip01_Head", "Bip01_L_Hand", "Bip01_R_Hand", "Bip01_L_Foot", "Bip01_R_Foot"]:
        print("%-14s %7.3f %7.3f %7.3f" % ((n,) + tuple(pos[n])))
    svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="900" height="500"><rect width="900" height="500" fill="#fff"/>']
    svg.append(svg_view(pos, boxes, 0, 1, 230, "front"))
    svg.append(svg_view(pos, boxes, 2, 1, 680, "side (z forward right)"))
    svg.append("</svg>")
    open(out, "w").write("\n".join(svg))


if __name__ == "__main__":
    main()
