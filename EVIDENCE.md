# Evidence capture checklist

Turn the writeups from scaffold into proof. Run the attacks from Kali against the
lab, capture each screenshot into `writeups/assets/`, and the `_evidence:_`
placeholders in the writeups will resolve.

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
