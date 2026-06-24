# Evidence capture checklist

Turn the writeups from scaffold into proof. Most of it is **automated**; only a
couple of *visual* things need a screenshot.

## Automated (recommended) — `evidence.sh`
```bash
TARGET=http://<mac-ip>:8088 ./evidence.sh
```
Produces (see [evidence/](evidence/)):
- **`evidence/solved-challenges.md`** — committed proof: which challenges are
  solved, straight from `/api/Challenges` (the gamified confirmation as a table).
- `evidence/files/` + `evidence/attack-<ts>.log` — raw artifacts/log, kept local.

That alone proves which attacks landed. Screenshots below are just for polish.

## Manual screenshots (visual only)
Take them on Kali (`xfce4-screenshooter`, `flameshot gui`, or `scrot`), save into
`writeups/assets/`:
- `assets/03-xss.png` — the XSS payload *executing* in the browser (can't be shown in text)
- `assets/score-board.png` — the Score Board with green ✓ marks
- `assets/hubble-l7.png` — the same attack seen in Hubble on the Mac (`make hubble-ui`)

## Getting evidence into the repo (+ GitHub mirror)
The repo is public — clone it on Kali and work there:
```bash
git clone https://gitlab.com/teodorio95/offensive-writeups.git
cd offensive-writeups
TARGET=http://<mac-ip>:8088 ./evidence.sh      # generates evidence/
# add screenshots to writeups/assets/, then:
git add evidence/solved-challenges.md writeups/assets/ && git commit -m "evidence" && git push
```
(Needs git auth on Kali — a token or SSH key. Alternatively `scp` the files to the
Mac clone and commit there.)

---

### Older manual checklist (optional, the `_evidence:_` placeholders)

## Setup (once)
- [ ] Lab up on the Mac: `cd secure-k8s-lab && make up` (Juice Shop on `:8081`)
- [ ] From Kali, confirm reachability: `curl -I http://192.168.0.200:8081` → `200`
- [ ] (optional) On the Mac, open Hubble: `make hubble-ui` → <http://localhost:12000>
- [ ] Run the suite: `TARGET=http://192.168.0.200:8081 ./attack.sh`

## Capture
- [ ] `assets/01-nmap-output.png` — nmap showing the single open port + Juice Shop title
- [ ] `assets/02-sqli-admin-token.png` — the auth token returned by the `' OR 1=1--` login
- [ ] `assets/03-xss.png` — the XSS payload executing in the browser (search box)
- [ ] `assets/04-ftp.png` — a downloadable backup/source file under `/ftp`
- [ ] `assets/05-bruteforce.png` — (optional, `--brute`) hydra output
- [ ] `assets/hubble-l7.png` — the **same attack** seen in Hubble (method/path) — closes the #4↔#5 loop

## Defense shots (the "how we protect" half)
- [ ] `assets/def-verify-netpol.png` — `make verify-netpol` (egress BLOCKED)
- [ ] `assets/def-kyverno.png` — Kyverno flagging a privileged/`:latest` pod (`make kyverno-reports`)
- [ ] `assets/def-ci-gate.png` — the #2 pipeline catching SQLi/CVE/IaC (red→green)

## Then
- [ ] Reference the screenshots in the writeups + [defenses.md](defenses.md)
- [ ] Each row in [defenses.md](defenses.md) can grow into its own full writeup

> Scope reminder: only the lab / sanctioned platforms. Never unauthorized targets.
