#!/usr/bin/env python3
"""The fake HTTP server of the L3 runner (TESTING.md 3.2, slice 003).

Usage: python3 -I fakehttp.py <routes dir> <fixtures dir> <state dir>

It listens on 127.0.0.1 with a free port, and writes the port to `<state dir>/http.port` when it is ready.
It serves the files of `<routes dir>` (the `given/http/` dir of a case). Each request adds one line to `<state dir>/http.log`.
The highest number of requests in flight at one time is in `<state dir>/http.maxconn`.

Routes. A request `GET /<path>?<query>` is the file `<routes dir>/<path>?<query>`, else `<routes dir>/<path>`.
No file: 404 with the body `{"message":"Not Found"}`. In a body and in a header value, `$PORT` is the port of the server.

| File | Gives |
| --- | --- |
| `<route>` | The body of the answer. Status 200. |
| `<route>.meta` | Optional. One line each: `status <n>`, `header <Name>: <value>`, `slow <ms>`, `body @<file>`. |

| Meta line | Effect |
| --- | --- |
| `status <n>` | The status of the answer (default 200) |
| `header <Name>: <value>` | One more header. A header `ETag` makes the route answer 304 (no body) to a request that has the same `If-None-Match`. |
| `slow <ms>` | The body goes out in 4 parts, with a wait of `<ms>` between them |
| `body @<file>` | The body is the file `<fixtures dir>/<file>`, not the route file. The route file can be missing. A bad hash is a route whose body is the archive of another package. |

Log line: `<METHOD> <path>[?<query>] <status>`, then ` if-none-match=<value>` and ` authorization` when the request has these headers.
"""
import os
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit

ROUTES, FIXTURES, STATE = (os.path.abspath(p) for p in sys.argv[1:4])
LOCK = threading.Lock()
STATS = {"now": 0, "max": 0}
PORT = [0]


def write_state(name, text):
    tmp = os.path.join(STATE, name + ".part")
    with open(tmp, "w") as f:
        f.write(text)
    os.rename(tmp, os.path.join(STATE, name))


def log(line):
    with LOCK:
        with open(os.path.join(STATE, "http.log"), "a") as f:
            f.write(line + "\n")


def subst(data):
    return data.replace(b"$PORT", str(PORT[0]).encode())


def read_meta(path):
    meta = {"status": 200, "headers": [], "slow": 0, "body": None}
    try:
        with open(path + ".meta") as f:
            lines = f.read().split("\n")
    except OSError:
        return meta
    for line in lines:
        key, _, value = line.partition(" ")
        if key == "status":
            meta["status"] = int(value)
        elif key == "header":
            name, _, v = value.partition(":")
            meta["headers"].append((name.strip(), subst(v.strip().encode()).decode()))
        elif key == "slow":
            meta["slow"] = int(value)
        elif key == "body" and value.startswith("@"):
            meta["body"] = value[1:]
    return meta


def find_route(split):
    rel = split.path.lstrip("/")
    if ".." in rel.split("/"):
        return None
    candidates = []
    if split.query:
        candidates.append(os.path.join(ROUTES, rel + "?" + split.query))
    candidates.append(os.path.join(ROUTES, rel))
    for c in candidates:
        if os.path.isfile(c) or os.path.isfile(c + ".meta"):
            return c
    return None


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        pass

    def do_GET(self):
        with LOCK:
            STATS["now"] += 1
            if STATS["now"] > STATS["max"]:
                STATS["max"] = STATS["now"]
                write_state("http.maxconn", "%d\n" % STATS["max"])
        try:
            self.answer()
        finally:
            with LOCK:
                STATS["now"] -= 1

    def answer(self):
        split = urlsplit(self.path)
        target = split.path + ("?" + split.query if split.query else "")
        route = find_route(split)
        extra = ""
        inm = self.headers.get("If-None-Match")
        if inm:
            extra += " if-none-match=" + inm
        if self.headers.get("Authorization"):
            extra += " authorization"
        if route is None:
            body, status, headers, slow = b'{"message":"Not Found"}', 404, [], 0
        else:
            meta = read_meta(route)
            status, headers, slow = meta["status"], meta["headers"], meta["slow"]
            source = os.path.join(FIXTURES, meta["body"]) if meta["body"] else route
            try:
                with open(source, "rb") as f:
                    body = f.read()
            except OSError:
                body = b""
            if meta["body"] is None:
                body = subst(body)
            etags = [v for (n, v) in headers if n.lower() == "etag"]
            if inm and etags and inm == etags[0]:
                status, body = 304, b""
        log("GET %s %d%s" % (target, status, extra))
        self.send_response(status)
        for name, value in headers:
            self.send_header(name, value)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if slow > 0 and len(body) > 3:
            step = (len(body) + 3) // 4
            for i in range(0, len(body), step):
                self.wfile.write(body[i : i + step])
                self.wfile.flush()
                if i + step < len(body):
                    time.sleep(slow / 1000.0)
        else:
            self.wfile.write(body)


def main():
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    server.daemon_threads = True
    # A client that closes or resets its connection is normal (curl, wget). It must not write to the stderr of the case.
    server.handle_error = lambda request, client_address: None
    PORT[0] = server.server_address[1]
    write_state("http.maxconn", "0\n")
    write_state("http.port", "%d\n" % PORT[0])
    server.serve_forever()


main()
