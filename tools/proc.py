"""The only place Godot is launched from.

Every Godot process is started suspended, put into a Win32 job object with KILL_ON_JOB_CLOSE, and
only then resumed. The real godot.exe that godot_console spawns is therefore inside the job too,
and nothing can outlive the tool. We never kill anything by name: only the job we created.
"""
import csv
import ctypes
import io
import os
import re
import contextlib
import socket
import subprocess
import sys
import threading
import time
from ctypes import wintypes
from dataclasses import dataclass

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paths  # noqa: E402


class ToolError(RuntimeError):
    """A clear, user-facing failure (missing game, missing file...)."""


CREATE_SUSPENDED = 0x00000004
CREATE_NO_WINDOW = 0x08000000
BELOW_NORMAL_PRIORITY_CLASS = 0x00004000
JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x2000
JobObjectBasicProcessIdList = 3
JobObjectExtendedLimitInformation = 9

k32 = ctypes.WinDLL("kernel32", use_last_error=True)
ntdll = ctypes.WinDLL("ntdll")


class _BASIC(ctypes.Structure):
    _fields_ = [("PerProcessUserTimeLimit", ctypes.c_int64), ("PerJobUserTimeLimit", ctypes.c_int64),
                ("LimitFlags", wintypes.DWORD), ("MinimumWorkingSetSize", ctypes.c_size_t),
                ("MaximumWorkingSetSize", ctypes.c_size_t), ("ActiveProcessLimit", wintypes.DWORD),
                ("Affinity", ctypes.c_size_t), ("PriorityClass", wintypes.DWORD),
                ("SchedulingClass", wintypes.DWORD)]


class _IOC(ctypes.Structure):
    _fields_ = [(n, ctypes.c_uint64) for n in ("ro", "wo", "oo", "rb", "wb", "ob")]


class _EXT(ctypes.Structure):
    _fields_ = [("BasicLimitInformation", _BASIC), ("IoInfo", _IOC), ("ProcessMemoryLimit", ctypes.c_size_t),
                ("JobMemoryLimit", ctypes.c_size_t), ("PeakProcessMemoryUsed", ctypes.c_size_t),
                ("PeakJobMemoryUsed", ctypes.c_size_t)]


_MAXP = 512


class _PIDLIST(ctypes.Structure):
    _fields_ = [("NumberOfAssignedProcesses", wintypes.DWORD), ("NumberOfProcessIdsInList", wintypes.DWORD),
                ("ProcessIdList", ctypes.c_size_t * _MAXP)]


k32.CreateJobObjectW.argtypes = [ctypes.c_void_p, wintypes.LPCWSTR]
k32.CreateJobObjectW.restype = wintypes.HANDLE
k32.SetInformationJobObject.argtypes = [wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p, wintypes.DWORD]
k32.SetInformationJobObject.restype = wintypes.BOOL
k32.QueryInformationJobObject.argtypes = [wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p, wintypes.DWORD,
                                          ctypes.c_void_p]
k32.QueryInformationJobObject.restype = wintypes.BOOL
k32.AssignProcessToJobObject.argtypes = [wintypes.HANDLE, wintypes.HANDLE]
k32.AssignProcessToJobObject.restype = wintypes.BOOL
k32.TerminateJobObject.argtypes = [wintypes.HANDLE, wintypes.UINT]
k32.TerminateJobObject.restype = wintypes.BOOL
k32.CloseHandle.argtypes = [wintypes.HANDLE]
k32.CloseHandle.restype = wintypes.BOOL
ntdll.NtResumeProcess.argtypes = [wintypes.HANDLE]
ntdll.NtResumeProcess.restype = ctypes.c_long


@dataclass
class GodotResult:
    returncode: int
    out: str
    timed_out: bool
    seconds: float
    log_path: str = ""


def _log_args(args, log_name):
    if not log_name:
        return list(args), ""
    d = os.path.join(paths.OUT, "logs")
    os.makedirs(d, exist_ok=True)
    lp = os.path.join(d, log_name + ".log")
    args = list(args)
    i = args.index("--") if "--" in args else len(args)
    return args[:i] + ["--log-file", lp] + args[i:], lp


class GodotJob:
    """A Godot run owned by a job object. Use as a context manager (or call close())."""

    def __init__(self, args, below_normal=False, log_name=None, exe=None):
        args, self.log_path = _log_args(args, log_name)
        self.args = args
        self.cmd = [exe or paths.godot(console=True, check=False)] + args
        self.t0 = time.time()
        self._job = k32.CreateJobObjectW(None, None)
        if not self._job:
            raise OSError("CreateJobObjectW failed: %d" % ctypes.get_last_error())
        try:
            info = _EXT()
            info.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
            if not k32.SetInformationJobObject(self._job, JobObjectExtendedLimitInformation, ctypes.byref(info),
                                               ctypes.sizeof(info)):
                raise OSError("SetInformationJobObject failed: %d" % ctypes.get_last_error())
            flags = CREATE_SUSPENDED | CREATE_NO_WINDOW | (BELOW_NORMAL_PRIORITY_CLASS if below_normal else 0)
            self.proc = subprocess.Popen(self.cmd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                         stderr=subprocess.STDOUT, creationflags=flags)
            h = wintypes.HANDLE(int(self.proc._handle))
            if not k32.AssignProcessToJobObject(self._job, h):
                err = ctypes.get_last_error()
                self.proc.kill()
                raise OSError("AssignProcessToJobObject failed: %d" % err)
            ntdll.NtResumeProcess(h)
        except BaseException:
            self._close_job()
            raise
        self._chunks = []
        self._reader = threading.Thread(target=self._read, daemon=True)
        self._reader.start()

    def _read(self):
        try:
            while True:
                b = self.proc.stdout.read1(65536)
                if not b:
                    break
                self._chunks.append(b)
        except Exception:
            pass

    def _close_job(self):
        if getattr(self, "_job", None):
            k32.CloseHandle(self._job)  # KILL_ON_JOB_CLOSE ends anything still inside
            self._job = None

    def pids(self):
        if not self._job:
            return []
        buf = _PIDLIST()
        if not k32.QueryInformationJobObject(self._job, JobObjectBasicProcessIdList, ctypes.byref(buf),
                                             ctypes.sizeof(buf), None):
            return []
        return [int(buf.ProcessIdList[i]) for i in range(buf.NumberOfProcessIdsInList)]

    def poll(self):
        return self.proc.poll()

    def kill(self):
        if self._job:
            k32.TerminateJobObject(self._job, 1)

    def wait(self, timeout=None):
        timed_out = False
        try:
            self.proc.wait(timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            self.kill()
            try:
                self.proc.wait(15)
            except subprocess.TimeoutExpired:
                pass
        # Let a clean exit finish; kill anything still left inside the job after a short grace period.
        end = time.time() + (0 if timed_out else 3)
        while self.pids() and time.time() < end:
            time.sleep(0.1)
        self.kill()
        self._reader.join(10)
        out = b"".join(self._chunks).decode("utf-8", errors="replace")
        rc = self.proc.returncode if self.proc.returncode is not None else -1
        return GodotResult(rc, out, timed_out, time.time() - self.t0, self.log_path)

    def close(self):
        try:
            self.kill()
        finally:
            self._close_job()

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()
        return False


def run_godot(args, timeout, log_name=None, below_normal=False, exe=None):
    job = GodotJob(args, below_normal=below_normal, log_name=log_name, exe=exe)
    try:
        return job.wait(timeout)
    finally:
        job.close()


@contextlib.contextmanager
def editor_lock(wait=600, stale=1200):
    """Exclusive lock for editor-mode Godot calls (--import, --export-*), harness/out/locks/editor.lock."""
    d = os.path.join(paths.OUT, "locks")
    os.makedirs(d, exist_ok=True)
    lp = os.path.join(d, "editor.lock")
    end = time.time() + wait
    while True:
        try:
            fd = os.open(lp, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            os.write(fd, f"pid {os.getpid()} {time.ctime()}".encode())
            os.close(fd)
            break
        except FileExistsError:
            try:
                if time.time() - os.path.getmtime(lp) > stale:
                    os.remove(lp)
                    continue
            except OSError:
                pass
            if time.time() > end:
                raise ToolError(f"editor lock {lp} still held after {wait}s")
            time.sleep(2)
    try:
        yield
    finally:
        try:
            os.remove(lp)
        except OSError:
            pass


def gpu_warning(name):
    """Print a warning and return True when the adapter is not an NVIDIA GPU."""
    if name and "nvidia" not in name.lower():
        print(f"WARNING: not on the NVIDIA GPU ({name})")
        return True
    return False


def adapter_from(out):
    m = re.search(r"(?:SHOTS|CAPTURE) done .*?renderer (.+)", out)
    return m.group(1).strip() if m else ""


def free_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    p = s.getsockname()[1]
    s.close()
    return p


def require_game():
    if not os.path.exists(os.path.join(paths.GAME, "project.godot")):
        raise ToolError(f"game side missing: {os.path.join(paths.GAME, 'project.godot')} does not exist yet")


def import_project(timeout=900, ports=True, project=None, log_name="import"):
    project = project or paths.GAME
    if not os.path.exists(os.path.join(project, "project.godot")):
        raise ToolError(f"cannot import: {os.path.join(project, 'project.godot')} does not exist")
    args = ["--headless", "--path", project, "--import"]
    if ports:
        args += ["--lsp-port", str(free_port()), "--dap-port", str(free_port())]
    with editor_lock():
        return run_godot(args, timeout, log_name=log_name)


_NOISE = ("invalid UID", "still in use", "leaked", "ObjectDB instances", "Pages in use")
_ERR = re.compile(r"(SCRIPT ERROR|SHADER ERROR|USER ERROR|Parse Error|Compile Error)|^\s*ERROR:")


def bad_lines(out, limit=30):
    lines = out.splitlines()
    res, seen = [], set()
    for i, l in enumerate(lines):
        if not _ERR.search(l) or any(n in l for n in _NOISE):
            continue
        s = l.strip()
        nxt = lines[i + 1].strip() if i + 1 < len(lines) else ""
        if nxt.startswith("at:"):
            s += "  " + nxt
        if s not in seen:
            seen.add(s)
            res.append(s)
            if len(res) >= limit:
                break
    return res


def other_godot_processes(exclude_pids=()):
    """Read-only listing of running Godot processes (image name contains 'godot'), as (pid, name)."""
    try:
        out = subprocess.run(["tasklist", "/FO", "CSV", "/NH"], capture_output=True, text=True,
                             encoding="utf-8", errors="replace", timeout=30).stdout
    except Exception:
        return []
    ex = set(int(p) for p in exclude_pids)
    res = []
    for row in csv.reader(io.StringIO(out)):
        if len(row) >= 2 and "godot" in row[0].lower() and row[1].isdigit() and int(row[1]) not in ex:
            res.append((int(row[1]), row[0]))
    return res
