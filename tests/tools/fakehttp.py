#!/usr/bin/env python3
"""The fake HTTP server of the L3 runner (TESTING.md 3.2, slice 003).

Usage: python3 -I fakehttp.py <routes dir> <fixtures dir> <state dir>

It listens on 127.0.0.1 with a free port, and writes the port to `<state dir>/http.port` when it is ready.
It serves the files of `<routes dir>` (the `given/http/` dir of a case). Each request adds one line to `<state dir>/http.log`.
The highest number of requests in flight at one time is in `<state dir>/http.maxconn`.

Routes. A request `GET /<path>?<query>` is the file `<routes dir>/<path>?<query>`, else `<routes dir>/<path>`.
File names: the runner decodes the names of `given/` before the server starts (tests/lib.sh decode_names), so the file of `GET /x?page=2` is named `x%3Fpage=2` in the repo
(`%3F` is `?`, `%3A` is `:`, `%5C` is `\\`, `%25` is `%`: Windows refuses the characters `? : * < > | "` in a name) and `x?page=2` in the work dir. This file only sees the decoded names.
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

Slice 200 adds writes (the route form of TESTING 3.1):

| Item | Rule |
| --- | --- |
| Methods | `GET`, `POST`, `PUT` and `DELETE`. Another method: 405. |
| The file of the method | `<route>` is for `GET`. `<route>.POST`, `<route>.PUT` and `<route>.DELETE` are for the other methods, each with its `.meta` (`x.POST.meta`). A route with no file: 404, for each method. |
| The n-th answer | `<file>.<n>` (n = 2, 3, ...) is the answer to the n-th request of the same method and path and query in the case. It has its own `.meta` (`x.POST.2`, `x.POST.2.meta`). With no `<file>.<n>`, the answer is `<file>`. |
| `require <name>: <value>` | A meta line. The request must have this header with this exact value (the name in any case). Else the answer is 599 with the body `wrong header`. |
| `require-none <name>` | A meta line. The request must not have this header. Else 599 as above. |
| 204 and 304 | A status 204 or 304 in the meta gives no body. |
| Request body | `<state dir>/http-bodies/<k>` is the body of the k-th request of the log (the line number in `http.log`, from 1), as bytes, when the body is not empty. A request with no body has no file. The runner compares the dir with `expect/http-bodies/` when the case has it. |

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
SEEN = {}
SEQ = [0]
PORT = [0]


def write_state(name, text):
    tmp = os.path.join(STATE, name + ".part")
    with open(tmp, "w") as f:
        f.write(text)
    os.rename(tmp, os.path.join(STATE, name))



def log_request(line, body):
    """Writes the log line and the body file of the request under one lock, so that the number of the file is the line number."""
    with LOCK:
        SEQ[0] += 1
        if body:
            d = os.path.join(STATE, "http-bodies")
            os.makedirs(d, exist_ok=True)
            with open(os.path.join(d, str(SEQ[0])), "wb") as f:
                f.write(body)
        with open(os.path.join(STATE, "http.log"), "a") as f:
            f.write(line + "\n")


def subst(data):
    return data.replace(b"$PORT", str(PORT[0]).encode())


def read_meta(path):
    meta = {"status": 200, "headers": [], "slow": 0, "body": None, "require": []}
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
        elif key == "require":
            name, _, v = value.partition(":")
            meta["require"].append((name.strip().lower(), v.strip()))
        elif key == "require-none":
            meta["require"].append((value.strip().lower(), None))
    return meta


def find_route(split, method, n):
    rel = split.path.lstrip("/")
    if ".." in rel.split("/"):
        return None
    suffix = "" if method == "GET" else "." + method
    candidates = []
    if split.query:
        candidates.append(os.path.join(ROUTES, rel + "?" + split.query + suffix))
    candidates.append(os.path.join(ROUTES, rel + suffix))
    for c in candidates:
        if os.path.isfile(c) or os.path.isfile(c + ".meta"):
            nth = "%s.%d" % (c, n)
            if n > 1 and (os.path.isfile(nth) or os.path.isfile(nth + ".meta")):
                return nth
            return c
    return None


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        pass

    def do_GET(self):
        self.handle_method("GET")

    def do_POST(self):
        self.handle_method("POST")

    def do_PUT(self):
        self.handle_method("PUT")

    def do_DELETE(self):
        self.handle_method("DELETE")

    def do_PATCH(self):
        self.handle_method("PATCH")

    def read_body(self):
        if "chunked" in (self.headers.get("Transfer-Encoding") or "").lower():
            data = b""
            while True:
                size = int(self.rfile.readline().strip().split(b";")[0] or b"0", 16)
                if size == 0:
                    self.rfile.readline()
                    return data
                data += self.rfile.read(size)
                self.rfile.readline()
        length = int(self.headers.get("Content-Length") or 0)
        return self.rfile.read(length) if length > 0 else b""

    def handle_method(self, method):
        with LOCK:
            STATS["now"] += 1
            if STATS["now"] > STATS["max"]:
                STATS["max"] = STATS["now"]
                write_state("http.maxconn", "%d\n" % STATS["max"])
        try:
            body = self.read_body()
            self.answer(method, body)
        finally:
            with LOCK:
                STATS["now"] -= 1

    def answer(self, method, request_body):
        split = urlsplit(self.path)
        target = split.path + ("?" + split.query if split.query else "")
        with LOCK:
            key = (method, target)
            SEEN[key] = SEEN.get(key, 0) + 1
            n = SEEN[key]
        route = find_route(split, method, n) if method in ("GET", "POST", "PUT", "DELETE") else None
        extra = ""
        inm = self.headers.get("If-None-Match")
        if inm:
            extra += " if-none-match=" + inm
        if self.headers.get("Authorization"):
            extra += " authorization"
        if method not in ("GET", "POST", "PUT", "DELETE"):
            body, status, headers, slow = b'{"message":"Method Not Allowed"}', 405, [("Allow", "GET, POST, PUT, DELETE")], 0
        elif route is None:
            body, status, headers, slow = b'{"message":"Not Found"}', 404, [], 0
        else:
            meta = read_meta(route)
            status, headers, slow = meta["status"], meta["headers"], meta["slow"]
            wrong = False
            for name, want in meta["require"]:
                got = self.headers.get(name)
                if (want is None and got is not None) or (want is not None and got != want):
                    wrong = True
            source = os.path.join(FIXTURES, meta["body"]) if meta["body"] else route
            try:
                with open(source, "rb") as f:
                    body = f.read()
            except OSError:
                body = b""
            if meta["body"] is None:
                body = subst(body)
            etags = [v for (n2, v) in headers if n2.lower() == "etag"]
            if wrong:
                status, body, headers, slow = 599, b"wrong header", [], 0
            elif inm and etags and inm == etags[0]:
                status, body = 304, b""
            elif status in (204, 304):
                body = b""
        log_request("%s %s %d%s" % (method, target, status, extra), request_body)
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
