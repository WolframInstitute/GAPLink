import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path

spec = spec_from_file_location("verify_cloud", Path(__file__).parents[1] / "verify-cloud.py")
cloud = module_from_spec(spec)
spec.loader.exec_module(cloud)


class Handler(BaseHTTPRequestHandler):
    responses = {
        "/paclet": (200, "application/zip", b"PK\x03\x04"),
        "/range": (206, "application/zip", b"PK\x03\x04"),
        "/page": (200, "text/html; charset=utf-8", b"<title>GAPLink</title>"),
        "/redirect": (302, "text/html", b""),
        "/private": (401, "text/html", b"Sign in"),
        "/signin": (200, "text/html", b"<title>Sign in</title>"),
        "/invalid": (200, "application/zip", b"not a paclet"),
        "/empty": (200, "application/zip", b""),
    }

    def do_GET(self):
        status, content_type, body = self.responses[self.path]
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Location", "/paclet")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


class PublicDownloadTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = HTTPServer(("127.0.0.1", 0), Handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.url = f"http://127.0.0.1:{cls.server.server_port}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.thread.join()
        cls.server.server_close()

    def test_public_downloads(self):
        for path, content_type in [("/paclet", "application/zip"), ("/range", "application/zip"), ("/page", "text/html")]:
            with self.subTest(path=path):
                cloud.verify(self.url + path, content_type)

    def test_reject_private_or_invalid_downloads(self):
        for path in ("/redirect", "/private", "/signin", "/invalid", "/empty"):
            with self.subTest(path=path), self.assertRaises((OSError, ValueError)):
                cloud.verify(self.url + path, "application/zip")

    def test_reject_signin_page(self):
        with self.assertRaises(ValueError):
            cloud.verify(self.url + "/signin", "text/html")


if __name__ == "__main__":
    unittest.main()
