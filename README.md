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

- **Attacker:** Kali Linux (Parallels VM) — nmap, Burp Suite, sqlmap, etc.
- **Target:** OWASP Juice Shop in the k3d cluster (`make juice-ui` exposes it on
  `http://localhost:3000`; reachable from Kali over the host network).
- All tooling is pre-installed on Kali.

## Writeups

| # | Title | Class | Tools |
|---|-------|-------|-------|
| [01](writeups/01-recon-nmap.md) | Recon & service discovery | Reconnaissance | nmap |
| [02](writeups/02-sqli-login-bypass.md) | SQL injection — login bypass | A03 Injection | Burp, sqlmap |

See [TEMPLATE.md](TEMPLATE.md) for the structure each writeup follows.
