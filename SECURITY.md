# Security Policy

## Reporting a Vulnerability

Please report security issues privately to **[TODO: security contact email]** — do not open a public GitHub issue. Include steps to reproduce and the affected area (iOS app, Supabase schema/RLS, storage). We aim to acknowledge within 72 hours.

## Architecture Notes (for researchers)

- **Auth**: Supabase Auth (Sign in with Apple; WeChat planned). Anonymous sign-in is used only by the `#if DEBUG` development bypass in the iOS app.
- **Authorization**: Postgres Row Level Security on every per-user table. Social features that must read other users' rows go through the `workout_feed` view, which scopes rows to the caller (`auth.uid()`) and their followees inside the view definition.
- **Storage**: `progress-photos` is a private bucket; access is restricted to the owner's top-level folder (`<user_id>/...`) via storage RLS, and reads use short-lived signed URLs.
- **Client secrets**: the app ships only the Supabase anon key, which is safe by design — all enforcement is server-side RLS.

## Known / Accepted Limitations (tracked)

1. `workout_likes` SELECT policy is `using (true)` — like rows (workout_id + user_id pairs) are enumerable by any authenticated user. Aggregate like counts are considered non-sensitive.
2. The `progress-photos` bucket currently relies on client-side compression; server-side size/MIME limits are not yet configured on the bucket.
3. Anonymous sign-ins must be **disabled in the Supabase dashboard for production** (they exist only for the DEBUG test-login bypass).
