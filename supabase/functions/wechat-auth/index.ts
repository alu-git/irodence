// Supabase Edge Function: wechat-auth
//
// Exchanges a WeChat OAuth `code` for a Supabase session.
// WeChat is not a native Supabase auth provider, so this function:
//   1. Calls Tencent's API with the code + AppSecret (server-side only!)
//   2. Gets back openid (+ unionid) for the WeChat user
//   3. Upserts/links a Supabase auth user and returns session tokens
//
// Required secrets (set via `supabase secrets set`):
//   WECHAT_APP_ID, WECHAT_APP_SECRET   <-- you provide these
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (auto-injected by Supabase)
//
// STATUS: STUB — the token-exchange flow is written but untested until you
// supply real WeChat Open Platform credentials.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const WECHAT_TOKEN_URL = "https://api.weixin.qq.com/sns/oauth2/access_token";

interface WeChatTokenResponse {
  access_token?: string;
  openid?: string;
  unionid?: string;
  errcode?: number;
  errmsg?: string;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const { code } = await req.json().catch(() => ({}));
  if (!code) {
    return Response.json({ error: "Missing WeChat auth code" }, { status: 400 });
  }

  // 1. Exchange code for access_token + openid
  const appId = Deno.env.get("WECHAT_APP_ID");
  const appSecret = Deno.env.get("WECHAT_APP_SECRET");
  if (!appId || !appSecret) {
    return Response.json(
      { error: "WeChat credentials not configured on server" },
      { status: 500 },
    );
  }

  const tokenUrl = `${WECHAT_TOKEN_URL}?appid=${appId}&secret=${appSecret}&code=${code}&grant_type=authorization_code`;
  const tokenResp = await fetch(tokenUrl);
  const tokenData = (await tokenResp.json()) as WeChatTokenResponse;

  if (!tokenData.openid) {
    return Response.json(
      { error: `WeChat auth failed: ${tokenData.errmsg ?? "unknown"} (${tokenData.errcode})` },
      { status: 401 },
    );
  }

  // 2. Find or create the Supabase user keyed by WeChat openid.
  //    Synthetic email keeps auth.users happy; openid is stored on profiles.
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const syntheticEmail = `wx_${tokenData.openid}@wechat.irodence.local`;
  const { data: listData, error: listError } = await supabase.auth.admin
    .listUsers();
  if (listError) {
    return Response.json({ error: listError.message }, { status: 500 });
  }

  // TODO: replace list-and-scan with a lookup against profiles.wechat_openid
  // once real data exists (listUsers is fine at tiny scale only).
  let user = listData.users.find((u) => u.email === syntheticEmail);
  if (!user) {
    const { data: created, error: createError } = await supabase.auth.admin
      .createUser({
        email: syntheticEmail,
        email_confirm: true,
        user_metadata: { wechat_openid: tokenData.openid },
      });
    if (createError || !created.user) {
      return Response.json(
        { error: createError?.message ?? "Failed to create user" },
        { status: 500 },
      );
    }
    user = created.user;
  }

  // Link openid on the profile (idempotent).
  await supabase
    .from("profiles")
    .update({ wechat_openid: tokenData.openid })
    .eq("id", user.id);

  // 3. Mint a session for the app.
  const { data: linkData, error: linkError } = await supabase.auth.admin
    .generateLink({ type: "magiclink", email: syntheticEmail });
  if (linkError) {
    return Response.json({ error: linkError.message }, { status: 500 });
  }

  // The client exchanges this hashed token for a session via
  // auth.verifyOtp({ type: 'magiclink', token_hash, ... })
  return Response.json({
    token_hash: linkData.properties.hashed_token,
    email: syntheticEmail,
  });
});
