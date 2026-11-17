#!/usr/bin/env python3
"""
Local Static Web Server with Automatic Browser-Close Shutdown (`scripts/serve_web.py`)

Serves the `web/` directory (and project root `/src/simulations/*/explanations.md` fallback)
and monitors client browser heartbeats (`POST /__heartbeat`) and pagehide beacons (`POST /__tab_closed`).
When all open browser tabs are closed, the server shuts down cleanly within seconds.
"""

import argparse
import functools
import http.server
import os
import posixpath
import sys
import threading
import time
import urllib.parse
import webbrowser

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
WEB_DIR = os.path.join(ROOT_DIR, "web")

state_lock = threading.Lock()
state = {
    "has_connected": False,
    "last_heartbeat": time.time(),
    "open_tabs": 0,
    "last_close_signal": 0.0,
}


class LifecycleStaticHandler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".md": "text/markdown; charset=utf-8",
        ".jl": "text/plain; charset=utf-8",
    }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def translate_path(self, path):
        parsed = urllib.parse.urlparse(path).path
        clean = posixpath.normpath(urllib.parse.unquote(parsed))
        if clean.startswith("/src/"):
            rel = clean.lstrip("/")
            candidate = os.path.abspath(os.path.join(ROOT_DIR, rel))
            src_root = os.path.abspath(os.path.join(ROOT_DIR, "src"))
            if candidate == src_root or candidate.startswith(src_root + os.sep):
                return candidate
        return super().translate_path(path)

    def log_message(self, fmt, *args):
        # Suppress noisy heartbeat logs while keeping page requests visible
        if args and "/__heartbeat" in str(args[0]):
            return
        super().log_message(fmt, *args)

    def do_POST(self):
        content_len = int(self.headers.get("Content-Length", 0) or 0)
        if content_len > 0:
            self.rfile.read(content_len)
        now = time.time()
        if self.path.startswith("/__heartbeat"):
            with state_lock:
                state["has_connected"] = True
                state["last_heartbeat"] = now
                state["open_tabs"] = max(1, state["open_tabs"])
            self.send_response(204)
            self.end_headers()
            return

        if self.path.startswith("/__tab_closed"):
            with state_lock:
                state["open_tabs"] = max(0, state["open_tabs"] - 1)
                state["last_close_signal"] = now
            self.send_response(204)
            self.end_headers()
            return

        self.send_response(404)
        self.end_headers()


def monitor_browser_lifecycle(httpd, idle_timeout_sec=8.0, close_grace_sec=2.5):
    while True:
        time.sleep(0.5)
        now = time.time()
        with state_lock:
            if not state["has_connected"]:
                continue
            since_hb = now - state["last_heartbeat"]
            since_close = now - state["last_close_signal"] if state["last_close_signal"] > 0 else 999.0
            tabs = state["open_tabs"]

        # If a tab sent a close beacon and no other tab sent a heartbeat within `close_grace_sec`, shut down
        if state["last_close_signal"] > 0 and tabs == 0 and since_close >= close_grace_sec and since_hb >= close_grace_sec:
            print("\n[serve_web] Browser closed (`/__tab_closed` received). Shutting down server cleanly...")
            httpd.shutdown()
            return

        # Or if all browser heartbeats stopped (e.g. browser process killed) for `idle_timeout_sec`
        if since_hb >= idle_timeout_sec:
            print(f"\n[serve_web] No active browser heartbeat for {idle_timeout_sec:.0f}s. Shutting down server cleanly...")
            httpd.shutdown()
            return


def main():
    parser = argparse.ArgumentParser(description="Serve the AI ROI Simulator web UI and auto-close when browser exits.")
    parser.add_argument("--port", type=int, default=8080, help="Port to serve on (default: 8080)")
    parser.add_argument("--open-browser", action="store_true", help="Automatically open the default web browser")
    parser.add_argument("--idle-timeout", type=float, default=8.0, help="Seconds after last heartbeat before auto-shutdown")
    args = parser.parse_args()

    http.server.ThreadingHTTPServer.allow_reuse_address = True
    httpd = http.server.ThreadingHTTPServer(("0.0.0.0", args.port), LifecycleStaticHandler)

    url = f"http://localhost:{args.port}/index.html"
    print("=" * 78)
    print(f"Serving AI Adoption Business Case Simulator at: {url}")
    print("Auto-Shutdown Active: Server will automatically close when the browser tab closes.")
    print("=" * 78)

    watcher = threading.Thread(
        target=monitor_browser_lifecycle,
        args=(httpd, args.idle_timeout),
        daemon=True
    )
    watcher.start()

    if args.open_browser:
        threading.Timer(0.4, lambda: webbrowser.open(url)).start()

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n[serve_web] Interrupted by user. Closing server.")
    finally:
        httpd.server_close()


if __name__ == "__main__":
    main()

