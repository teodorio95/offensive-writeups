# 01 — Recon & service discovery

| | |
|---|---|
| **Target** | k3d lab node / Juice Shop @ `localhost:3000` (own lab) |
| **Authorization** | Own lab — see repo scope |
| **Class** | Reconnaissance (PTES / MITRE ATT&CK T1046) |
| **Tools** | nmap |
| **Date** | 2026-06-22 |

## 1. Recon

Recon is the first step of any assessment: enumerate what's reachable before
touching anything. Against the lab target exposed on the host:

```bash
# Host + port discovery (top 1000 TCP ports)
nmap -sV -sC -T4 -oN nmap-initial.txt 127.0.0.1

# Focused service/version + default scripts on the app port
nmap -sV -p 3000 --script http-headers,http-title 127.0.0.1
```

Expected finding: a single application port open (`3000/tcp`) running a
Node.js/Express app (Juice Shop), and **nothing else** — because the lab's
NetworkPolicies only allow ingress on the app port.

```
PORT     STATE SERVICE   VERSION
3000/tcp open  http      Node.js Express framework
|_http-title: OWASP Juice Shop
```

> _evidence: ./assets/01-nmap-output.png_

## 2. Vulnerability

Recon itself isn't a vulnerability — it's information disclosure surface. The
finding here is what an attacker *learns*: framework, version, and that exactly
one service is exposed. A large open-port surface would be the real weakness.

## 3. Exploitation

No exploitation at this stage — the goal is an accurate map:

- Open ports & services → attack surface.
- Server headers / titles → tech fingerprint to guide the next phase.
- What is **not** reachable → confirms the isolation is working.

## 4. Impact

A minimal surface (one port) sharply limits what an attacker can do. Recon
confirms the lab's containment: the target can be reached only on `3000`, and
its egress is denied — so even if compromised, it can't pivot.

## 5. Remediation

- **Platform control (project #1):** the `default-deny` NetworkPolicy + the
  single `allow-ingress` on the app port is exactly why nmap sees one port. Run
  `make verify-netpol` to prove egress is blocked.
- **Reduce fingerprinting:** disable verbose framework headers
  (`X-Powered-By`), set a reverse proxy to strip server banners.
- **Detection (project #5):** a sweep across many ports is a classic signal —
  Falco / NetworkPolicy logs surface it.

## References

- nmap docs: <https://nmap.org/book/man.html>
- MITRE ATT&CK T1046 — Network Service Discovery
