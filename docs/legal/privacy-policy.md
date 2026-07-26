# Privacy Policy / 隐私政策

**Irodence 铁证**
Effective date: 2026-07-24 · Last updated: 2026-07-24

---

## English

### 1. Overview

Irodence ("the App") is a workout tracking application. This Privacy Policy explains what data we collect, how it is stored, and the choices you have. We do not sell your data, we do not show ads, and we do not use third-party analytics or tracking SDKs.

### 2. Data We Collect

| Category | Data | Purpose |
|---|---|---|
| Account | Apple Sign-In credential (via Supabase Auth); WeChat sign-in is planned but not yet active | Authentication |
| Profile | Display name, sex (optional), bodyweight (optional) | Strength standards, leaderboards, social features |
| Training | Workouts, exercises, sets (weight/reps/RPE), personal records, bodyweight logs | Core app functionality |
| Progress photos | Photos you explicitly upload, optional notes | Private progress tracking (visible only to you) |
| Social | Follows, feed likes, leaderboard rankings | Social features you opt into |
| Preferences | Language, text size, rest-timer duration (stored on-device) | App settings |

### 3. How Data Is Stored

- Backend data is stored on **Supabase** (PostgreSQL + object storage). Row Level Security restricts every per-user table so other users cannot read your private data.
- Progress photos live in a **private storage bucket**; they are served only through short-lived (1-hour) signed URLs and are visible **only to you**.
- Some data (exercise library, profile snapshot, photo bytes) is cached on your device for offline use in the app's sandboxed Caches directory, protected by iOS file encryption.
- Leaderboards and the social feed expose only: your display name, finished-workout summaries (name, duration, volume, set count), and strength rankings — and the feed only to people **you** follow back... (see §5).

### 4. Permissions

- **Photo Library** — only when you choose to add a progress photo. We never scan or upload your library.

### 5. Social Visibility

- Your finished workouts appear in the feed of users who follow you **and** whom the follow relationship covers, per the app's follow model.
- Leaderboards (global scope) are visible to all signed-in users: display name + strength/volume ranking. You can appear on them by completing workouts.
- Likes are visible as aggregate counts.

### 6. Data Retention & Deletion

- Your data is kept while your account exists.
- To delete your account and all associated data (profile, workouts, photos, follows, likes), contact us at **[support email — TODO]** from your account email, or use the in-app deletion option when available. Deletion cascades to all tables within 30 days.

### 7. Third Parties

- **Supabase** (hosting/database): processes data on our behalf.
- **Apple** (Sign in with Apple): authentication only.
No advertising, analytics, or data-broker third parties.

### 8. Children

The App is not directed at children under 13 (or the minimum age in your jurisdiction). Do not use the App if you are under that age.

### 9. Changes

We will update this policy in the repository and in the app when practices change; material changes will be announced in-app.

### 10. Contact

[TODO: contact email]

---

## 中文

### 1. 概述

Irodence 铁证（"本应用"）是一款训练记录应用。本隐私政策说明我们收集哪些数据、如何存储以及您拥有的选择。我们不出售您的数据，不展示广告，也不使用任何第三方分析或追踪 SDK。

### 2. 我们收集的数据

| 类别 | 数据 | 用途 |
|---|---|---|
| 账户 | Apple 登录凭据（通过 Supabase Auth）；微信登录规划中，尚未启用 | 身份验证 |
| 个人资料 | 昵称、性别（可选）、体重（可选） | 力量标准、排行榜、社交功能 |
| 训练数据 | 训练、动作、组数（重量/次数/RPE）、个人纪录、体重记录 | 核心功能 |
| 进度照片 | 您主动上传的照片及备注 | 私人进度记录（仅自己可见） |
| 社交 | 关注关系、动态点赞、排行榜名次 | 您主动使用的社交功能 |
| 偏好设置 | 语言、字体大小、默认休息时长（仅存在设备上） | 应用设置 |

### 3. 数据存储方式

- 后端数据存储于 **Supabase**（PostgreSQL + 对象存储）。所有用户级数据表均启用了行级安全（RLS），其他用户无法读取您的私人数据。
- 进度照片保存在**私有存储桶**中，仅通过短期（1 小时）签名 URL 访问，**仅您本人可见**。
- 部分数据（动作库、资料快照、照片文件）会缓存在您设备的应用沙盒 Caches 目录中以便离线使用，受 iOS 文件加密保护。
- 排行榜和动态仅展示：您的昵称、已完成训练的摘要（名称、时长、容量、组数）和力量排名。

### 4. 权限

- **照片图库** — 仅在您选择添加进度照片时请求。我们绝不扫描或上传您的图库。

### 5. 社交可见性

- 您完成的训练会出现在关注您的用户的动态中（依据应用的关注模型）。
- 全球排行榜对所有登录用户可见：昵称 + 力量/容量排名。完成训练即可能上榜。
- 点赞以聚合计数形式展示。

### 6. 数据保留与删除

- 账户存在期间我们保留您的数据。
- 如需删除账户及全部关联数据（资料、训练、照片、关注、点赞），请通过 **[联系邮箱 — 待补充]** 联系我们，或使用应用内删除功能（上线后）。删除将在 30 天内级联至所有数据表。

### 7. 第三方

- **Supabase**（托管/数据库）：代表我们处理数据。
- **Apple**（Apple 登录）：仅用于身份验证。
无任何广告、分析或数据经纪第三方。

### 8. 儿童

本应用不面向 13 岁以下（或您所在司法辖区的最低年龄）儿童。未达该年龄请勿使用。

### 9. 变更

实践变更时我们会在代码仓库和应用内更新本政策；重大变更将在应用内公告。

### 10. 联系方式

[待补充：联系邮箱]
