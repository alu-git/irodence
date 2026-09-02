# IRODENCE_SAFETY.md

Safety, moderation, and privacy spec for 铁证 / Irodence.
Read alongside IRODENCE_DESIGN.md and IRODENCE_PALETTE.md.

This covers a social product that collects video of users' bodies in a
majority-male community, in a jurisdiction with strict UGC rules. None of it
is optional before 见证 ships.

Nothing here is legal advice. Sections marked **[法务确认]** must be checked
with someone qualified in mainland Chinese internet regulation before launch.

---

## 1. Threat model

What can actually go wrong, roughly in order of likelihood:

1. **Harassment of women.** Users upload video of themselves in gym clothing.
   Strangers get a legitimate reason to watch closely, comment, and make
   contact. This is the single largest risk to the product and the most
   likely cause of women abandoning it.
2. **Screenshot and reupload.** A user's video ends up somewhere else. The
   app cannot prevent this technically; it can limit exposure surface and
   respond fast.
3. **Collusion.** Friends rubber-stamp each other's lifts, devaluing
   certification and therefore the whole moat.
4. **Injury content.** Someone uploads a failed max attempt that ends badly,
   or the community encourages a lift beyond someone's capacity.
5. **Minors.** Under-18 users uploading body video, and separately, minors
   being pushed toward maximal loading.
6. **Doxxing via metadata.** Gym location, training schedule, and body stats
   combine into a stalking kit.
7. **Illegal or unrelated content** uploaded through the video pipeline.

---

## 2. Privacy defaults

Every default is the conservative option. Users may open things up; the app
never opens them by default.

| Setting | Default |
|---|---|
| Proof video visibility | 仅熔炉可见 (crew only) |
| Profile discoverability | Not searchable by name |
| Leaderboard scope | Own sex and weight class |
| Global leaderboard participation | Opt-in |
| Direct messages | Disabled entirely (see 4) |
| Location on proofs | Never captured, never stored |
| Bodyweight visibility | Shown as weight class, not exact figure, unless the user opts in |

Location: do not request location permission at all. It is the highest-risk
field and the product does not need it. If 同城 (local) feed ships later,
derive it from a user-selected city, never from device GPS, and treat that
choice as public information shown to the user as such.

EXIF and all metadata are stripped from every uploaded video server-side
before storage. Original files are never retained.

---

## 3. Certification integrity

Server-side only. Never trust the client for any of this.

- 3 independent witnesses required to certify a proof.
- A witness must be at or above the lifter's tier.
- A user may witness the same lifter at most once per 30 days.
- Witnesses are assigned, not chosen: the lifter cannot pick who reviews
  their proof, and cannot see witness identities before the outcome.
- Any witness may flag rather than confirm. Two flags freeze the score
  change and send the proof to 复核.
- Certification affects ranked standing only. Self-logged 力量分 is never
  revoked by a failed certification.
- Rate limit: a user may submit at most N proofs per week, and witness at
  most M per day. Pick values that make farming expensive.

Collusion detection worth building early: flag clusters of accounts that
witness each other at unusual rates, and accounts created in bursts from one
device or IP.

---

## 4. Contact and harassment

**No direct messages between users. At all, in v1.** This removes the single
largest harassment vector and costs almost nothing, because 熔炉 already
provides the group channel the product actually needs.

Other rules:

- Comments on a proof are restricted to assigned witnesses and crew members.
  The open feed cannot comment.
- Crews are invite-only and private by default.
- One-tap block. Blocking hides the blocker's proofs from that account
  entirely, prevents crew invitations, and is silent to the blocked user.
- Report reasons must include harassment and inappropriate contact, not only
  cheating. A cheating-only report flow signals that harassment is not
  considered a problem here.
- Reports involving harassment route to a human queue with a target response
  under 24 hours, separate from the cheating queue.
- Repeat-offender tracking at the account level, not the report level.

**Copy rule.** The app never addresses the user with a gendered term. No
老哥, no 兄弟, no 肌友. 铁友 or plain second person only. This applies to
every empty state, notification, and marketing string. The forge voice stays
hard; it does not stay male.

---

## 5. Content moderation

- **Pre-publication scan.** Every uploaded video passes automated screening
  before it becomes visible to anyone, including crew. Not after. **[法务确认]**
  Mainland UGC video services generally carry content-review obligations and
  may require specific licensing; confirm which apply.
- Human review queue for anything flagged, with a documented turnaround.
- Admin panel for the review queue (web, buildable and testable outside iOS).
- Takedown must be immediate and single-action, with the video purged from
  CDN and storage, not merely hidden.
- Appeal path for the uploader.
- Retain moderation decision logs. **[法务确认]** for required retention
  period and format.

---

## 6. Physical safety

- Never display a suggested target load above what the user's own history
  supports. No "you should be able to hit X" prompts based on other users.
- 测试周 templates must carry a warmup protocol and a spotter or safety-bar
  reminder in the template itself, not buried in a disclaimer.
- No comment reactions that reward failed maximal attempts. Do not build a
  "grind" or "beast" reaction that makes injury video rewarding to post.
- If a proof video is flagged as showing injury, remove it and do not count
  it, regardless of whether the lift completed.
- No streak mechanic that penalizes rest. 炉温 resets weekly and 淬火 exists
  precisely so recovery is rewarded rather than punished.
- 生锈 is cosmetic. Inactivity never demotes a tier, and never triggers
  guilt-framed notifications.

---

## 7. Minors

- **[法务确认]** Mainland rules on minor users, real-name verification, and
  minors mode are strict and change; confirm current obligations before
  launch.
- Do not allow under-18 accounts to upload proof videos or appear on public
  leaderboards.
- If under-18 accounts are permitted at all, they get crew-only visibility,
  no discoverability, and no maximal-attempt templates.
- Age is asked at signup. **[法务确认]** on whether verification, not
  self-declaration, is required.

---

## 8. Data handling

- **[法务确认]** PIPL obligations: consent flow, purpose limitation, and
  whether video of identifiable persons plus body metrics constitutes
  sensitive personal information requiring separate explicit consent. Assume
  it does until told otherwise.
- **[法务确认]** Data localization. If users are in mainland China, storage
  location is a compliance question, not an engineering preference. This
  affects the Supabase region choice and may be decisive.
- Account deletion must actually delete: videos purged, proofs removed,
  leaderboard entries removed. A soft-delete flag is not deletion.
- Data export on request.
- Minimum retention. Videos that fail certification and are not appealed are
  deleted after a fixed window rather than kept indefinitely.
- **[法务确认]** ICP filing and any app store filing requirements for
  distribution in mainland China.

---

## 9. Launch sequencing: two different gates

Not all of this section 8 machinery is live from day one. It is triggered by
**mainland-facing distribution**, not by having mainland users incidentally
find the app. This matters because Irodence currently has no company entity
behind it, and several of the section 8 obligations either require one
(ICP filing for a commercial app) or become far cheaper to satisfy once one
exists.

**Gate A — required for any launch, any storefront.** Everything in
section 9's original list below: report flow, human review queue, block,
pre-publication scan for anything actually public, crew-only default,
metadata stripping, real account deletion, age gate. These are product
safety requirements independent of jurisdiction and should not wait on a
company entity.

**Gate B — required only once distribution targets mainland China.**
ICP filing (备案) with MIIT, plus the 网信办 App filing that follows it,
data localization for mainland users' data, PIPL data-export procedures if
storage stays outside mainland China, and the stricter mainland minors-mode
requirements. As of the 2023–2024 rollout, Apple enforces ICP filing at
submission time for apps distributed to the China App Store storefront
specifically — the check does not fire for other storefronts. Individual
developers can file ICP for non-commercial tool-category apps only; a
commercial app (any monetization) requires a company entity as the filing
subject. **[法务确认]** whether Irodence's certification/leaderboard model
counts as commercial for this purpose, and at what point.

**Practical sequencing:** launch and test on non-China App Store storefronts
first, without China distribution selected and without marketing through
mainland-only channels (WeChat, Xiaohongshu). This keeps you fully in Gate A
and defers all of Gate B until there is a company entity to file under.
Flipping on China distribution is a deliberate, later decision, not a
default to reach for once the app works. Treat "stand up a company entity
before mainland distribution" as an explicit milestone in the project plan,
not an afterthought discovered at submission time.

---

## 10. Launch gate

见证 does not ship until all of the following exist:

1. Report flow with harassment reasons
2. Human review queue and admin panel
3. Block function
4. Pre-publication automated scan
5. Crew-only default visibility
6. EXIF and metadata stripping
7. Account deletion that purges video
8. Age gate

Shipping video upload without these means owning whatever gets uploaded, with
no way to respond. This is not a v2 list.

---

## 11. Agent instructions

1. Read this file, IRODENCE_DESIGN.md, and IRODENCE_PALETTE.md before any
   work touching proofs, video, crews, comments, profiles, or accounts.
   Build against Gate A (section 9) only, unless told the project has moved
   to mainland distribution. Do not implement China-specific filing or
   localization machinery speculatively.
2. Every rule in sections 3, 4, and 7 is enforced server-side in Supabase RLS
   policies or edge functions. Client-side enforcement of any of them is a
   defect, not an implementation.
3. Produce an audit before writing code: list every existing surface that
   exposes user content or allows user-to-user contact, and check it against
   sections 2 and 4. Report gaps. Wait for approval.
4. Never widen a default. If a task requires making something more visible,
   stop and ask.
5. Do not implement anything marked **[法务确认]** as though the question is
   settled. Flag it, build the conservative version, and note it needs review.
6. Write RLS policies with tests. This is the one area where you can verify
   your own work, since it runs outside iOS.
