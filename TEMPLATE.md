# NN — <Title>

| | |
|---|---|
| **Target** | OWASP Juice Shop @ `http://localhost:3000` (own lab) |
| **Authorization** | Own lab / sanctioned platform — see repo scope |
| **Class** | e.g. OWASP A03:2021 Injection |
| **Tools** | nmap / Burp / sqlmap / … |
| **Date** | YYYY-MM-DD |

## 1. Recon

What was observed before the attack (open ports, endpoints, tech stack).

```bash
# commands used
```

## 2. Vulnerability

What is weak and *why* — the root cause, not just the symptom.

## 3. Exploitation

Step-by-step, reproducible. Include the exact request/payload and a screenshot
or captured output as evidence.

```http
# request / payload
```

> _evidence: ./assets/NN-<name>.png_

## 4. Impact

What an attacker gains (data, access, privilege) and the business risk.

## 5. Remediation

The fix **and** the automatic control that would catch it:

- **Code fix:** …
- **Shift-left (CI):** which SAST/DAST/dep check catches it → project #2.
- **Platform control:** network policy / admission / WAF → project #1.

## References

- …
