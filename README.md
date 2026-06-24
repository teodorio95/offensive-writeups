# offensive-writeups

> Project **#4** of the DevSecOps portfolio: documented, **authorized** attacks
> against my own lab — each one closed with a concrete remediation. The point
> isn't "I can hack", it's "I can attack, then engineer the fix."

This repo is the offensive half of the loop. The targets are deployed and
isolated in [secure-k8s-lab](../secure-k8s-lab) (project #1); the fixes tie back
to the network policies / admission control there and the CI security gate in
[devsecops-pipeline](../devsecops-pipeline) (project #2).

## ⚠️ Scope & authorization (read first)

Every technique here is performed **only** against:

- **My own lab** — OWASP Juice Shop / DVWA running in my isolated k3d cluster.
- **Platforms explicitly built for practice** — TryHackMe, Hack The Box,
  PortSwigger Web Security Academy.

**Never** against systems I don't own or lack written authorization to test.
Scanning or attacking arbitrary internet hosts is illegal in most
jurisdictions. The lab is network-isolated (default-deny egress) precisely so
these exercises stay contained.

## Methodology

Every writeup follows the same arc — and the **last** step is the one that
matters for a DevSecOps role:

1. **Recon** — what's exposed, what's running.
2. **Vulnerability** — what's weak and why.
3. **Exploitation** — the concrete steps / payloads, with evidence.
4. **Impact** — what an attacker gains.
5. **Remediation** — how to fix it *and* how to catch it automatically
   (SAST/DAST in CI, network policy, admission control, WAF).

## Lab setup

The **target** is always OWASP Juice Shop from [secure-k8s-lab](../secure-k8s-lab)
(`make up`), exposed by the lab's Traefik ingress on the host. Pick either
attacker setup:

### Option A — tooling local on the Mac (recommended, no VM)

The simplest path: run the CLI tools natively, target `localhost`. No Kali, no
Parallels, no networking between VMs.

```bash
brew install nmap ffuf sqlmap hydra          # jq/curl/git usually already present
git clone --depth 1 https://github.com/danielmiessler/SecLists.git ~/tools/SecLists
```

- **Target:** `http://localhost:8081` (the ingress port; confirm with
  `curl -I http://localhost:8081`).
- **Wordlist:** `~/tools/SecLists/Discovery/Web-Content/common.txt` — pass it with
  `--wordlist` (the Kali default path `/usr/share/wordlists/...` doesn't exist on
  macOS; optionally `sudo ln -s` it there once).

`attack.sh` is portable (pure-bash host/port parse, ffuf `-ac` to filter the
Juice Shop SPA's catch-all 200s), so it runs the same on macOS and Linux.

### Option B — Kali Linux (Parallels VM)

If you specifically want the offensive distro (Burp Suite, Metasploit, etc.):

- **Attacker:** Kali — nmap, Burp Suite, sqlmap, hydra, ffuf pre-installed.
- **Target:** `http://<mac-ip>:8081` (the ingress is bound to all interfaces).
  Find the Mac IP with `ipconfig getifaddr en0`; confirm from Kali with
  `curl -I http://<mac-ip>:8081`.

> Note: Burp Suite's official installer is x86_64; on Apple-Silicon Kali you need
> an arm64 JRE 21 to launch it. Option A sidesteps this entirely for the
> CLI-driven attacks here.

## Run the attacks

[`attack.sh`](attack.sh) is **discovery-driven** — it *finds* paths/files by
fuzzing + parsing directory listings and *detects* flaws by anomaly (it doesn't
hard-code the answers). Phases: recon → content discovery (ffuf) → enumerate
browsable dirs → fuzz 403 bypasses → injection by anomaly → optional brute force.

```bash
# Mac-native (Option A): target localhost, point at the SecLists wordlist
TARGET=http://localhost:8081 ./attack.sh --wordlist ~/tools/SecLists/Discovery/Web-Content/common.txt
TARGET=http://localhost:8081 ./attack.sh --wordlist ~/tools/SecLists/Discovery/Web-Content/common.txt --brute

# Kali (Option B): target the Mac's IP; tooling/wordlists are pre-installed
TARGET=http://<mac-ip>:8081 ./attack.sh
TARGET=http://<mac-ip>:8081 ./attack.sh --brute
```

Want to learn the methodology by hand (hints, not solutions)? → [LEARNING.md](LEARNING.md).
Capture reproducible proof with [`evidence.sh`](evidence.sh) → [EVIDENCE.md](EVIDENCE.md).

## How we defend against each attack

[**defenses.md**](defenses.md) is the payoff: every attack mapped to its code-level
fix **and** the automated control elsewhere in the portfolio that catches or
prevents it (CI gate #2, network policy + admission #1, supply chain #3, runtime
detection #5) — plus the defense-in-depth layering.

## Writeups

| # | Title | Class | Tools |
|---|-------|-------|-------|
| [01](writeups/01-recon-nmap.md) | Recon & service discovery | Reconnaissance | nmap |
| [02](writeups/02-sqli-login-bypass.md) | SQL injection — login bypass | A03 Injection | Burp, sqlmap |
| [03](writeups/03-jwt-forgery.md) | JWT forgery — auth bypass | A07 Auth failures | Burp, jwt_tool |
| [04](writeups/04-nosql-injection.md) | NoSQL injection — query manipulation | A03 Injection | Burp, curl |
| [05](writeups/05-persistent-xss.md) | Persistent (stored) XSS via API | A03 Injection (XSS) | Burp |
| [06](writeups/06-sensitive-data-exposure.md) | Sensitive data exposure — poison null byte | A01 Broken Access Control | curl |

Each follows [TEMPLATE.md](TEMPLATE.md) and ends with remediation. `attack.sh`
also probes brute force (A07) and sensitive-file exposure (A01); see
[defenses.md](defenses.md) for the full attack→defense map.

## Confirming a solve (Juice Shop score board)
Juice Shop is a gamified CTF: each exploit is a **challenge**. Find the hidden
**Score Board** first (`/#/score-board`) — solving any challenge pops a toast and
marks it ✓ there (also queryable at `/api/Challenges`). Screenshot the solved
challenge as evidence. Full walkthroughs: <https://pwning.owasp-juice.shop>.
