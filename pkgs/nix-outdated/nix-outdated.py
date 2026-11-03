#!/usr/bin/env python3
"""Read-only HTTP API for the nix-outdated page.

The heavy lifting (resolving nixpkgs, evaluating the configuration) happens in
the `nix-outdated-check` systemd unit; this process only serves the cached JSON
and asks systemd to run that unit again. It never touches flake.lock, never
builds and never switches.

Endpoints:
  GET  /                 the single-page UI
  GET  /api/packages     cached check result (404 until the first check)
  GET  /api/status       whether a check is running, last result
  POST /api/check        start a full check
  POST /api/check/<pkg>  same check; <pkg> is echoed back for highlighting
"""

import atexit
import json
import os
import shlex
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import unquote, urlparse

STATE_DIR = os.environ.get("STATE_DIRECTORY") or "/var/lib/nix-outdated"
BIND = os.environ.get("BIND", "127.0.0.1")
PORT = int(os.environ.get("PORT", "30142"))
INDEX_HTML = os.environ.get("INDEX_HTML", "")
# The check runs as a child process; `just outdated` sets this to the check
# script built from this flake.
CHECK_COMMAND = os.environ.get("CHECK_COMMAND", "")
AUTO_CHECK = os.environ.get("AUTO_CHECK") == "1"
FLAKE_DIR = os.environ.get("FLAKE_DIR", "")
NIX_UPDATE = os.environ.get("NIX_UPDATE", "nix-update")
NIX_BIN = os.environ.get("NIX_BIN", "nix")
PACKAGES = os.path.join(STATE_DIR, "packages.json")

check_process = None
check_failed = False


def read_file(path):
    try:
        with open(path, "rb") as handle:
            return handle.read()
    except FileNotFoundError:
        return None



def unit_status():
    global check_failed

    running = check_process is not None and check_process.poll() is None
    if check_process is not None and not running:
        check_failed = check_process.returncode not in (None, 0)
    state = "active" if running else ("failed" if check_failed else "inactive")

    last_checked = None
    try:
        last_checked = int(os.stat(PACKAGES).st_mtime)
    except OSError:
        pass

    return {
        "state": state,
        "running": running,
        "runningScope": "all" if running else None,
        "failed": check_failed,
        "lastChecked": last_checked,
        "dataAvailable": last_checked is not None,
    }


def start_check():
    global check_process, check_failed

    if not CHECK_COMMAND:
        return
    if check_process is not None and check_process.poll() is None:
        return
    check_failed = False
    check_process = subprocess.Popen([CHECK_COMMAND], env=os.environ.copy())


def update_package(name):
    """Run `nix-update -f <file> <attr>` for a package under this repo's pkgs/.

    It rewrites only the version/hash in the checked-out .nix file: no commit,
    no switch, no flake.lock change. Everything else is left to the caller.
    """
    if not FLAKE_DIR:
        return {"ok": False, "error": "FLAKE_DIR is not set"}

    body = read_file(PACKAGES)
    if body is None:
        return {"ok": False, "error": "no check result yet; run a check first"}
    try:
        data = json.loads(body)
    except ValueError:
        return {"ok": False, "error": "packages.json is not valid JSON"}

    pkg = next((p for p in data.get("packages", []) if p.get("name") == name), None)
    if pkg is None:
        return {"ok": False, "error": f"package {name} not found"}
    if not pkg.get("custom"):
        return {"ok": False, "error": "not a package from this repository's pkgs/"}

    position = pkg.get("position", "")
    marker = "/pkgs/"
    if marker not in position:
        return {"ok": False, "error": "not a package from this repository's pkgs/"}

    relative = position.split(":")[0]
    relative = relative[relative.index(marker) + 1 :]
    path = os.path.join(FLAKE_DIR, relative)
    if not os.path.isfile(path):
        return {"ok": False, "error": f"{path} not found"}

    attr = os.path.basename(os.path.dirname(path))
    cmd = [NIX_UPDATE, "-f", path, attr]
    print(f"nix-outdated: update {name}: {shlex.join(cmd)}", flush=True)
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=600,
            check=False,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        print(f"nix-outdated: update {name} failed: {exc}", flush=True)
        return {"ok": False, "error": str(exc)}

    if proc.stdout:
        print(proc.stdout, flush=True)
    if proc.stderr:
        print(proc.stderr, flush=True)

    return {
        "ok": proc.returncode == 0,
        "attr": attr,
        "file": path,
        "stdout": proc.stdout[-4000:],
        "stderr": proc.stderr[-4000:],
    }


def update_nixpkgs():
    """Bump the nixpkgs flake input (flake.lock only: no commit, no switch)."""
    if not FLAKE_DIR:
        return {"ok": False, "error": "FLAKE_DIR is not set"}

    cmd = [NIX_BIN, "flake", "update", "nixpkgs", "--flake", FLAKE_DIR]
    print(f"nix-outdated: update nixpkgs: {shlex.join(cmd)}", flush=True)
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=600,
            check=False,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        print(f"nix-outdated: update nixpkgs failed: {exc}", flush=True)
        return {"ok": False, "error": str(exc)}

    if proc.stdout:
        print(proc.stdout, flush=True)
    if proc.stderr:
        print(proc.stderr, flush=True)

    return {
        "ok": proc.returncode == 0,
        "stdout": proc.stdout[-4000:],
        "stderr": proc.stderr[-4000:],
    }


class Handler(BaseHTTPRequestHandler):
    server_version = "nix-outdated"

    def _send(self, code, body, content_type):
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _json(self, code, payload):
        self._send(code, json.dumps(payload).encode(), "application/json")

    def do_GET(self):
        path = urlparse(self.path).path

        if path in ("/", "/index.html"):
            body = read_file(INDEX_HTML) if INDEX_HTML else None
            if body is None:
                self._send(500, b"index.html is missing", "text/plain")
            else:
                self._send(200, body, "text/html; charset=utf-8")
        elif path == "/api/packages":
            body = read_file(PACKAGES)
            if body is None:
                self._json(404, {"error": "no data yet; run a check"})
            else:
                self._send(200, body, "application/json")
        elif path == "/api/status":
            self._json(200, unit_status())
        else:
            self._send(404, b"not found", "text/plain")

    def do_POST(self):
        # A custom header cannot be set by a cross-origin HTML form, which is
        # enough to keep a random page from starting checks or updates on
        # localhost.
        if self.headers.get("X-Nix-Outdated") != "1":
            self._json(403, {"error": "missing X-Nix-Outdated header"})
            return

        path = urlparse(self.path).path
        if path == "/api/check":
            start_check()
            self._json(202, {"started": True, "scope": "all", "package": None})
        elif path == "/api/check-inputs":
            start_check()
            self._json(202, {"started": True, "scope": "inputs", "package": None})
        elif path.startswith("/api/check/"):
            name = unquote(path[len("/api/check/") :])
            start_check()
            self._json(202, {"started": True, "scope": "all", "package": name})
        elif path == "/api/update-nixpkgs":
            self._json(200, update_nixpkgs())
        elif path.startswith("/api/update/"):
            name = unquote(path[len("/api/update/") :])
            self._json(200, update_package(name))
        else:
            self._send(404, b"not found", "text/plain")

    def log_message(self, fmt, *args):
        print(f"{self.address_string()} - {fmt % args}", flush=True)


def main():
    if AUTO_CHECK:
        start_check()

    def stop_check():
        if check_process is not None and check_process.poll() is None:
            check_process.terminate()

    atexit.register(stop_check)

    server = ThreadingHTTPServer((BIND, PORT), Handler)
    server.daemon_threads = True
    print(f"nix-outdated listening on {BIND}:{PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
