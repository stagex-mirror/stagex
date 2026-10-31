#!/usr/bin/env python3
"""Minimal ACME mock server for the wardend wire acceptance.

Serves the ACME directory + the JWS-signed POST endpoints (the AcmeWorker
state machine: Idle -> AccountReady -> OrderPending -> Finalized -> Issued).
The mock does NOT verify the JWS signature (that's the client's job); it
returns the right status + the right URLs. For the http-01 challenge, it
fetches the challenge from the wardend's :80 face (over the VPC, via the
domain resolved by DNS) to prove the :80 face works. Returns a self-signed
certificate PEM.

THE CHALLENGE-FETCH RACE FIX: the worker sets its token + pushes it to the
:80 face's pending map only AFTER the authz response is sent back (the
wire loop inserts it into state.pending after step() returns). So fetching
the challenge synchronously in the authz handler is too early (the token
isn't served yet -> 404). The mock now spawns a background thread that
retries the challenge fetch (1s cadence, up to ~15s), giving the worker
time to receive the authz response, set the token, and publish it.
"""
import http.server
import json
import base64
import uuid
import subprocess
import threading
import time
import urllib.request

BASE = "http://172.31.37.195:14001"
DOMAIN = "udunit.lrvick.dev"
nonce_counter = 0

def b64url_decode(s):
    padding = '=' * (-len(s) % 4)
    return base64.urlsafe_b64decode(s + padding).decode('utf-8')

def generate_cert(domain):
    """Generate a self-signed certificate PEM (the wardend just needs a PEM)."""
    result = subprocess.run([
        'openssl', 'req', '-x509', '-newkey', 'rsa:2048',
        '-keyout', '/dev/null', '-out', '/dev/stdout',
        '-days', '1', '-nodes', '-subj', f'/CN={domain}'
    ], capture_output=True, text=True)
    return result.stdout

def fetch_challenge_retry(token, attempts=15, cadence=1.0):
    """Fetch the http-01 challenge from the wardend's :80 face, with
    retries (the worker publishes the token to the :80 face's pending map
    only after the authz response is sent back; the first fetch is too
    early -> 404). The retries give the worker time to publish it."""
    url = f'http://{DOMAIN}/.well-known/acme-challenge/{token}'
    for i in range(attempts):
        try:
            with urllib.request.urlopen(url, timeout=5) as resp:
                ka = resp.read().decode('utf-8')
            print(f"acme-mock: challenge fetched (attempt {i+1}): {ka[:60]}...", flush=True)
            return ka
        except Exception as e:
            if i == attempts - 1:
                print(f"acme-mock: challenge fetch failed after {attempts} attempts: {e}", flush=True)
            time.sleep(cadence)
    return None

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _nonce(self):
        global nonce_counter
        nonce_counter += 1
        return f'nonce-{nonce_counter}'

    def _send(self, status, body=b'', extra=None):
        self.send_response(status)
        self.send_header('Replay-Nonce', self._nonce())
        if extra:
            for k, v in extra.items():
                self.send_header(k, v)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        if body:
            self.wfile.write(body)

    def do_GET(self):
        print(f"acme-mock: GET {self.path}", flush=True)
        if self.path in ('/', '/directory', '/new-nonce'):
            d = {"newNonce": f"{BASE}/new-nonce",
                 "newAccount": f"{BASE}/new-account",
                 "newOrder": f"{BASE}/new-order"}
            self._send(200, json.dumps(d).encode())
        else:
            self._send(404)

    def do_POST(self):
        print(f"acme-mock: POST {self.path}", flush=True)
        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length).decode('utf-8') if length else ''
        p = self.path
        # The http-01 challenge: fetch from the wardend's :80 face (over the
        # VPC) in a BACKGROUND thread with retries (the worker publishes the
        # token to the :80 face only after the authz response is sent back).
        if p.endswith('/authz/1'):
            token = f'tok-{uuid.uuid4().hex[:16]}'
            t = threading.Thread(target=fetch_challenge_retry, args=(token,), daemon=True)
            t.start()
            a = {"status": "valid", "identifier": {"value": DOMAIN},
                 "challenges": [{"type": "http-01", "token": token,
                                 "url": f"{BASE}/chal/1"}]}
            self._send(200, json.dumps(a).encode())
        elif p.endswith('/new-account'):
            self._send(201, b'', {'Location': f'{BASE}/acct/1'})
        elif p.endswith('/new-order'):
            self._send(201, b'', {'Location': f'{BASE}/order/1'})
        elif p.endswith('/order/1'):
            o = {"status": "ready", "authorizations": [f"{BASE}/authz/1"],
                 "finalize": f"{BASE}/order/1/finalize"}
            self._send(200, json.dumps(o).encode())
        elif p.endswith('/order/1/finalize'):
            f = {"status": "valid", "certificate": f"{BASE}/cert/1"}
            self._send(202, json.dumps(f).encode())
        elif p.endswith('/cert/1'):
            self._send(200, generate_cert(DOMAIN).encode())
        elif p.endswith('/new-nonce'):
            self._send(200)
        else:
            self._send(404)

if __name__ == '__main__':
    print("acme-mock: listening on 0.0.0.0:14001", flush=True)
    http.server.ThreadingHTTPServer(('0.0.0.0', 14001), Handler).serve_forever()
