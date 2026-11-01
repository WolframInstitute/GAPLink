"""Check a cloud download without signing in or following redirects."""

import hashlib
import sys
from urllib.request import HTTPRedirectHandler, Request, build_opener


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def verify(url, content_type, expected_hash=None):
    request = Request(url, headers={"Range": "bytes=0-8191"})
    with build_opener(NoRedirect).open(request, timeout=30) as response:
        if response.status not in (200, 206):
            raise ValueError(f"HTTP {response.status}")
        if response.headers.get_content_type() != content_type:
            raise ValueError("Unexpected content type")
        # Cloud paclet downloads may ignore Range. Read only the file header.
        if content_type == "application/zip":
            if response.read(4) != b"PK\x03\x04":
                raise ValueError("The download is not a paclet archive")
        elif content_type == "text/plain":
            body = response.read(65537)
            if len(body) > 65536 or b"ResourceObject[" not in body or b'"WolframInstitute/GAPLink"' not in body:
                raise ValueError("The response is not a GAPLink resource description")
            if expected_hash and hashlib.sha256(body).hexdigest() != expected_hash:
                raise ValueError("The resource description differs from the uploaded file")
        else:
            raise ValueError("Unsupported content type")


if __name__ == "__main__":
    if len(sys.argv) not in (3, 4):
        sys.exit("Usage: verify-cloud.py URL CONTENT_TYPE [SHA256]")
    try:
        verify(*sys.argv[1:])
    except (OSError, ValueError) as error:
        sys.exit(f"ERROR: {sys.argv[1]}: {error}")
    print(f"OK: {sys.argv[1]}")
