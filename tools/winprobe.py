"""Window probe: launch the game in bot mode (as captures do) and measure whether its window is ever on
Stewart's screen or in the foreground. Run: python tools/winprobe.py (about 15 s, one windowed run)."""
import ctypes, os, sys, time
from ctypes import wintypes
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paths, proc
u = ctypes.WinDLL("user32")
EnumProc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
u.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
u.GetWindowRect.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.RECT)]
u.GetForegroundWindow.restype = wintypes.HWND
def windows_of(pids):
    out = []
    def cb(h, _):
        pid = wintypes.DWORD(0)
        u.GetWindowThreadProcessId(h, ctypes.byref(pid))
        if pid.value in pids and u.IsWindowVisible(h):
            r = wintypes.RECT()
            u.GetWindowRect(h, ctypes.byref(r))
            out.append((r.left, r.top, r.right, r.bottom))
        return True
    u.EnumWindows(EnumProc(cb), 0)
    return out
screen = (u.GetSystemMetrics(76), u.GetSystemMetrics(77), u.GetSystemMetrics(78), u.GetSystemMetrics(79))
print("virtual screen (x, y, w, h):", screen)
args = ["--path", paths.GAME, "--resolution", "1280x720", "--position", "-32000,-32000", "--", "--scenario=fire_drill", "--seed=5", "--run-ticks=600"]
on_screen, samples, fg_ours, seen = 0, 0, 0, set()
first_seen = []
with proc.GodotJob(args, log_name="winprobe") as job:
    end = time.time() + 40
    while job.poll() is None and time.time() < end:
        pids = set(job.pids())
        for (l, t, r, b) in windows_of(pids):
            seen.add((l, t, r, b))
            if r > screen[0] and b > screen[1] and l < screen[0] + screen[2] and t < screen[1] + screen[3]:
                on_screen += 1
                first_seen.append(round(time.time() - job.t0, 2))
        h = u.GetForegroundWindow()
        pid = wintypes.DWORD(0)
        u.GetWindowThreadProcessId(h, ctypes.byref(pid))
        fg_ours += 1 if pid.value in pids else 0
        samples += 1
        time.sleep(0.005)
    job.wait(15)
print("window rects seen:", sorted(seen))
print("on-screen sample times (s after launch):", first_seen[:5], "...", first_seen[-3:])
print(f"samples {samples}, our window on screen {on_screen}, our window in the foreground {fg_ours}")
