# Attacks → defenses (how the portfolio protects against each)

For every attack `attack.sh` runs, this is the **fix** and the **automated
control in the portfolio that catches or prevents it**. This is the whole point:
not "I can attack", but "I attack, then engineer + automate the defense".

> Juice Shop's app code is intentionally vulnerable and can't be patched, so the
> *code-level* fix is the pattern you'd apply in real code (and the CI gate that
> catches it), while the *platform* defenses (network policy, admission,
> detection) are demonstrated live in the lab.

| # | Attack | Code-level fix | Automated defense in the portfolio |
|---|--------|----------------|-------------------------------------|
| 1 | **Recon / port scan** | minimize exposed surface | **#1** default-deny NetworkPolicy → only the app port is reachable (`make verify-netpol`); **#5** Hubble shows the scan, Cilium drops the rest |
| 2 | **SQL injection** (auth bypass) | parameterized queries / ORM bound params | **#2** Semgrep (SAST) flags string-built SQL; **#2** ZAP (DAST) flags it at runtime — build gated before ship |
| 3 | **XSS** (reflected/DOM) | output encoding + Content-Security-Policy | **#2** Semgrep + ZAP catch it; CSP header blocks execution |
| 4 | **Broken access control / sensitive files** | server-side authz on every object; don't ship backups | **#2** DAST + review; **#1** egress default-deny stops data exfil even if read |
| 5 | **Brute force** (credentials) | rate limiting + lockout + MFA | WAF / ingress rate-limit; **#5** Hubble shows the burst of requests |
| 6 | **Post-exploitation** (shell, tools, file reads in a pod) | least privilege, read-only FS, non-root | **#1/#3** Kyverno blocks privileged/root/`:latest` & unsigned images; **#1** egress default-deny kills C2/exfil; **#5** Falco alerts on the shell/tool/file-read (on a real node) |
| 7 | **Vulnerable dependencies / image CVEs** | bump to patched versions | **#2** Trivy (deps + image) gates HIGH/CRITICAL; **#3** cosign-signed, SBOM'd images only |

## Defense in depth — the layers
1. **Shift-left (CI, #2):** catch it before it ships — fast, cheap, but bypassable.
2. **Supply chain (#3):** only signed, known images run — cosign + Kyverno verifyImages.
3. **Admission (#1, Kyverno):** the cluster rejects non-compliant workloads — can't be bypassed.
4. **Network (#1, Cilium):** default-deny ingress/egress — limits reach and stops exfil/C2.
5. **Runtime detection (#5, Falco + Hubble):** see the attack as it happens — the last line.

No single layer is the answer; an attacker who slips one still hits the next.

## Live before/after you can demo
- **Recon containment:** `make verify-netpol` — the target can't reach the internet.
- **Network detection:** run `attack.sh` from Kali, watch the requests (method/path)
  appear in **Hubble** (`make hubble-ui`) on the Mac.
- **Admission:** `kubectl run bad --image=nginx:latest --privileged` → Kyverno
  flags it (Audit) / would block it (Enforce).
- **Supply chain:** an unsigned image from our registry is flagged by the
  verifyImages policy (project #3).
