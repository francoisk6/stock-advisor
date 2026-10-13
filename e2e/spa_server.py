"""Static server for the Flutter web build with SPA fallback (deep links -> index.html)."""
import http.server, os, sys

root, port = sys.argv[1], int(sys.argv[2])

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=root, **kw)
    def send_head(self):
        path = self.translate_path(self.path.split("?")[0])
        if not os.path.exists(path):
            self.path = "/index.html"
        return super().send_head()
    def log_message(self, *a):
        pass

http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
