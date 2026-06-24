# Learning web attacks by hand

`attack.sh` automates the methodology below. To actually *learn*, do these steps
yourself first — **hints, not solutions**. Peek at a writeup or
<https://pwning.owasp-juice.shop> only after you've tried.

> You already know HTTP, APIs, JWT and networking. The new skill is the
> **attacker's lens**: assume nothing, discover everything, test every input.

## The mindset
1. **Map** the app — every page, every request.
2. **Discover** what isn't linked — fuzz for hidden paths/files.
3. **Enumerate** what you find — read listings, source, JS, errors.
4. **Test every input** — one weird char at a time; watch the response change.
5. **Question auth** — what proves who you are? can you forge it?

Each maps to an **OWASP Top 10** category, so you have a framework, not guesswork.

## Tools you need
- **Browser DevTools** (F12 → Network) — your first interceptor. "Copy as cURL"
  to replay/modify any request. (Burp/ZAP optional: `sudo apt install burpsuite`.)
- **ffuf** — content discovery. **curl** — replay requests. **jwt.io** — decode JWTs.

## Exercises (Juice Shop) — try before you peek

**A. Map & find the Score Board** *(Miscellaneous)*
- Open DevTools → Network, browse the site. What endpoints do you see?
- The score board is hidden. *Hint:* search the loaded `.js` files for `score`.

**B. Content discovery** *(the method behind phase 2-3)*
```bash
ffuf -u http://<ip>:8088/FUZZ -w /usr/share/wordlists/dirb/common.txt -mc 200,301,403
```
- Found a directory? Open it in the browser. Is it **browsable**? What's inside?
- *Hint:* one directory lists files you were never meant to see.

**C. Get a blocked file** *(Broken Access Control)*
- Try downloading a backup file directly. What status do you get?
- *Hint:* the server checks the **extension in the URL string**, but the file is
  opened by a layer that stops at a null byte. What could you append?

**D. Spot an injection** *(Injection)*
- Intercept the login request (DevTools). What does it send?
- Put a single `'` in the email field. Does an **error** change? That's the tell.
- *Hint:* if input breaks the query, input can also *rewrite* its logic.

**E. Inspect the token** *(Auth failures)*
- After logging in, copy the JWT from the `Authorization` header → paste in jwt.io.
- What algorithm? What's in the payload? What would the server have to do wrong
  for you to forge one? *Hint:* never trust the `alg` field from the token.

## How `attack.sh` maps to this
| Phase | Technique it demonstrates |
|-------|---------------------------|
| 2 | content discovery (ffuf) — find, don't assume |
| 3 | parse a directory listing — dynamic enumeration |
| 4 | fuzz **bypasses** on a 403 — try, don't assume one works |
| 5 | **anomaly detection** (quote → SQL error) then confirm |

Read the script — it's commented to show the *why*, not just the *what*.

## Where to go deeper
- **PortSwigger Web Security Academy** — <https://portswigger.net/web-security> (free, structured, the gold standard)
- **TryHackMe** — guided beginner rooms
- **"Pwning OWASP Juice Shop"** — <https://pwning.owasp-juice.shop> (use as a check, after trying)

> Scope: only your own lab / sanctioned platforms. Never unauthorized targets.
