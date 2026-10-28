import fcntl, os, struct, sys, time
UI_SET_EVBIT, UI_SET_KEYBIT, UI_SET_RELBIT = 0x40045564, 0x40045565, 0x40045566
UI_DEV_CREATE, UI_DEV_DESTROY = 0x5501, 0x5502
EV_SYN, EV_KEY, EV_REL = 0, 1, 2
BTN = {"left": 0x110, "right": 0x111}
fifo = sys.argv[1]
fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
fcntl.ioctl(fd, UI_SET_EVBIT, EV_KEY)
for b in BTN.values():
    fcntl.ioctl(fd, UI_SET_KEYBIT, b)
fcntl.ioctl(fd, UI_SET_EVBIT, EV_REL)
for r in (0, 1, 8):
    fcntl.ioctl(fd, UI_SET_RELBIT, r)
os.write(fd, b"pzc-virtual-mouse".ljust(80, b"\0") + struct.pack("HHHHi", 3, 0x1234, 0x5678, 1, 0) + bytes(4 * 64 * 4))
fcntl.ioctl(fd, UI_DEV_CREATE)
def emit(t, c, v):
    os.write(fd, struct.pack("llHHi", 0, 0, t, c, v))
def syn():
    emit(EV_SYN, 0, 0)
try:
    while True:
        with open(fifo) as f:
            for line in f:
                p = line.split()
                if not p:
                    continue
                if p[0] == "quit":
                    raise SystemExit
                if p[0] == "rel":
                    emit(EV_REL, 0, int(p[1])); emit(EV_REL, 1, int(p[2])); syn()
                elif p[0] == "wheel":
                    emit(EV_REL, 8, int(p[1])); syn()
                elif p[0] == "click":
                    emit(EV_KEY, BTN[p[1]], 1); syn(); time.sleep(0.25); emit(EV_KEY, BTN[p[1]], 0); syn()
finally:
    fcntl.ioctl(fd, UI_DEV_DESTROY)
    os.close(fd)
