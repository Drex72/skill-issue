# Skill Issue 💀

Two-person accountability tracker. Local-first, syncs through Supabase, installs as a PWA.

## 1. Supabase setup (one time, ~5 minutes)

1. Create a free project at https://supabase.com
2. SQL Editor -> New query -> paste all of `migrations/0001_init.sql` (then optionally `migrations/0002_seed.sql`) -> Run
3. Authentication -> Sign In / Providers -> enable **Anonymous sign-ins**
4. Settings -> API: copy the **Project URL** and **anon public key** into `config.js`

## 2. Deploy on GitHub Pages

```bash
git init && git add . && git commit -m "skill issue"
gh repo create skill-issue --public --source=. --push
gh api repos/<you>/skill-issue/pages -X POST -f 'source[branch]=main' -f 'source[path]=/'
```

Open `https://<you>.github.io/skill-issue/` on your phone, then browser menu -> **Add to Home Screen**.

## 3. Using it

- Each of you opens the URL, claims a username, builds your own room.
- Pair by typing the other person's username. Duo tab shows both rooms.
- Checking off a task sends proof ("show your workings") for the other to approve or reject.
- Pings are live (Supabase realtime) with optional trash talk attached.
- Bell = self nudges at your chosen times (defaults 9am/12pm/3pm/6pm/9pm) until the day is clear.

## How it works

- Your device's localStorage is the source of truth. Reads never wait on the network.
- Writes save locally, then push to Supabase ~1s later (skipped offline, retried when back online).
- Deletes are tombstoned locally and flushed on the next push.
- Partner data + pings + vibe checks arrive over realtime websockets, with a 45s poll as backup.
- Leave `config.js` empty and everything runs in local demo mode (pair with `teledua` for fake data).

## Honest limitations (v1)

- Identity is anonymous-auth per browser: clearing site data or switching devices creates a fresh account.
  Fine for two friends; upgrade path is Supabase email/OTP auth with the same profiles table.
- Notifications (pings, nudges) fire while the app is open or backgrounded. Guaranteed delivery with
  the app fully closed needs Web Push + a small server (Cloudflare Worker) - next step if wanted.
- Proof receipts are stored in a public-read bucket (URLs are unguessable but not private).
