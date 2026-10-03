#!/usr/bin/env python3
"""Локальный сервер без кэша: python3 serve.py [порт]"""
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer


class NoCache(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, max-age=0")
        super().end_headers()


port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
ThreadingHTTPServer(("0.0.0.0", port), NoCache).serve_forever()
