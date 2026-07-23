# 举重榜 (HevyKimi)

Native iOS strength-training tracker for the China market. Hevy-style workout
logging + bodyweight-adjusted strength rankings (DOTS) + WeChat login.

- **Stack:** SwiftUI (iOS 16+), Supabase (Postgres + Auth + Storage + Edge Functions), WeChat OpenSDK
- **Units:** kg only
- **UI language:** Simplified Chinese; all code/comments in English
- **Design:** dark mode default, data-dense, numbers-forward

## First-time setup

```sh
# 1. Create the secrets config (never committed)
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
#    Fill in SUPABASE_URL and SUPABASE_ANON_KEY from your Supabase dashboard.
#    WECHAT_APP_ID can stay placeholder until credentials arrive.

# 2. Generate the Xcode project (requires xcodegen: brew install xcodegen)
xcodegen generate

# 3. Open and build
open HevyKimi.xcodeproj
```

## Database

```sh
supabase link --project-ref <your-project-ref>
supabase db push          # applies supabase/migrations/*
```

RLS is enabled on every table — see comments in the migration for the
threat-model notes (e.g. why `personal_records` is owner-only and the
leaderboard will use a security-definer view in step 5).

## WeChat setup (pending credentials)

The WeChat OpenSDK is **not** distributed via SwiftPM. Once you have the
AppID/AppSecret from WeChat Open Platform:

1. Download the SDK (or add the CocoaPod `WechatOpenSDK` — your call)
2. Link it in the Xcode target, add the AppID to `Config/Secrets.xcconfig`
3. `supabase secrets set WECHAT_APP_ID=... WECHAT_APP_SECRET=...`
4. `supabase functions deploy wechat-auth`
5. Un-stub `AuthService.signInWithWeChat()` / `handleOpenURL(_:)`
   (search for `TODO(step1-wechat)`)

Sign in with Apple works today via Supabase's native provider — enable
"Apple" under Authentication → Providers in the Supabase dashboard.

## Data you still owe (flagged stubs)

| What | Where | Needed by |
|---|---|---|
| Supabase URL + anon key | `Config/Secrets.xcconfig` | Step 1 build |
| WeChat AppID/AppSecret | xcconfig + `supabase secrets` | Step 1 login |
| Strength-standard percentile tables | step 4 (will be marked `PLACEHOLDER DATA`) | Step 4 |

## Repo layout

```
Config/                  xcconfigs; Secrets.xcconfig is gitignored
HevyKimi/
  Core/Config/           AppConfig (reads keys from Info.plist)
  Core/Services/         SupabaseService, AuthService
  Features/              per-feature SwiftUI code (Auth done; rest stubbed)
supabase/
  migrations/            schema + RLS, one file per migration
  functions/wechat-auth/ WeChat code -> Supabase session exchange (stub)
```
