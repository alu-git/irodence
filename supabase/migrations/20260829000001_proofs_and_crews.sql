-- ============================================================================
-- 铁证 / Irodence — Proofs (证词), Witnesses (见证), Crews (熔炉), Challenges (比武)
-- Migration according to IRODENCE_DESIGN.md specifications.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Tier Enum & Helper
-- ----------------------------------------------------------------------------
create type public.strength_tier as enum (
    'pig_iron',       -- 生铁
    'wrought_iron',   -- 熟铁
    'dark_steel',     -- 玄铁
    'refined_steel',  -- 精钢
    'hundred_fold',   -- 百炼
    'meteoric_iron'   -- 陨铁
);

-- ----------------------------------------------------------------------------
-- 2. Proofs (证词)
-- A proof is a PR attempt with optional video.
-- Self-logged proofs give you a tier; video proofs can be witnessed & certified.
-- ----------------------------------------------------------------------------
create table public.proofs (
    id              uuid primary key default gen_random_uuid(),
    user_id         uuid not null references public.profiles (id) on delete cascade,
    exercise_id     uuid not null references public.exercises (id) on delete cascade,
    weight_kg       numeric(6,2) not null check (weight_kg > 0),
    reps            int not null check (reps > 0),
    estimated_1rm   numeric(6,2) not null check (estimated_1rm > 0),
    dots_score      numeric(6,2) not null default 0 check (dots_score >= 0),
    tier            public.strength_tier not null default 'pig_iron',
    video_url       text,
    notes           text,
    status          text not null default 'pending' check (status in ('pending', 'certified', 'under_review', 'rejected')),
    is_certified    boolean not null default false,
    certified_at    timestamptz,
    confirm_count   int not null default 0,
    flag_count      int not null default 0,
    achieved_at     timestamptz not null default now(),
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

create index idx_proofs_user_id on public.proofs (user_id);
create index idx_proofs_status on public.proofs (status);
create index idx_proofs_is_certified on public.proofs (is_certified);

alter table public.proofs enable row level security;

-- Proofs are viewable by all authenticated users (social feed)
create policy "proofs are viewable by authenticated users"
    on public.proofs for select
    to authenticated
    using (true);

-- Users can submit their own proofs
create policy "users can insert their own proofs"
    on public.proofs for insert
    to authenticated
    with check (auth.uid() = user_id);

-- Users can update their own pending proofs (or service role updates status)
create policy "users can update their own pending proofs"
    on public.proofs for update
    to authenticated
    using (auth.uid() = user_id and status = 'pending')
    with check (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- 3. Witnesses (见证)
-- Rules:
-- 1. Needs 3 independent confirmations to certify.
-- 2. Witness must be at or above lifter's tier.
-- 3. Cannot witness the same lifter more than once per 30 days.
-- 4. 2 flags send it to 'under_review' and freeze score.
-- ----------------------------------------------------------------------------
create table public.witnesses (
    id              uuid primary key default gen_random_uuid(),
    proof_id        uuid not null references public.proofs (id) on delete cascade,
    witness_id      uuid not null references public.profiles (id) on delete cascade,
    action          text not null check (action in ('confirm', 'flag')),
    comment         text,
    created_at      timestamptz not null default now(),

    unique (proof_id, witness_id)
);

create index idx_witnesses_proof_id on public.witnesses (proof_id);
create index idx_witnesses_witness_id on public.witnesses (witness_id);

alter table public.witnesses enable row level security;

create policy "witnesses are viewable by authenticated users"
    on public.witnesses for select
    to authenticated
    using (true);

-- Validation trigger for witnessing rules
create or replace function public.validate_and_process_witness()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_proof record;
    v_lifter_tier int;
    v_witness_tier int;
    v_recent_witness_count int;
    v_confirms int;
    v_flags int;
    tier_order text[] := array['pig_iron', 'wrought_iron', 'dark_steel', 'refined_steel', 'hundred_fold', 'meteoric_iron'];
begin
    -- 1. Check that the proof exists and is pending / not self-witnessed
    select * into v_proof from public.proofs where id = new.proof_id;
    if not found then
        raise exception 'Proof not found.';
    end if;

    if v_proof.user_id = new.witness_id then
        raise exception 'You cannot witness your own proof.';
    end if;

    if v_proof.status not in ('pending', 'under_review') then
        raise exception 'Proof is not open for witnessing.';
    end if;

    -- 2. Anti-spam: A user cannot witness the same lifter more than once per 30 days
    select count(*) into v_recent_witness_count
    from public.witnesses w
    join public.proofs p on p.id = w.proof_id
    where w.witness_id = new.witness_id
      and p.user_id = v_proof.user_id
      and w.proof_id <> new.proof_id
      and w.created_at >= now() - interval '30 days';

    if v_recent_witness_count > 0 then
        raise exception 'You can only witness the same lifter once every 30 days.';
    end if;

    return new;
end;
$$;

create trigger tr_validate_witness_before_insert
    before insert on public.witnesses
    for each row execute function public.validate_and_process_witness();

-- Trigger after insert/update on witnesses to update counts and certify proof
create or replace function public.handle_witness_after_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_proof_id uuid;
    v_confirms int;
    v_flags int;
begin
    v_proof_id := coalesce(new.proof_id, old.proof_id);

    select count(*) filter (where action = 'confirm'),
           count(*) filter (where action = 'flag')
    into v_confirms, v_flags
    from public.witnesses
    where proof_id = v_proof_id;

    if v_flags >= 2 then
        update public.proofs
        set confirm_count = v_confirms,
            flag_count = v_flags,
            status = 'under_review',
            updated_at = now()
        where id = v_proof_id;
    elsif v_confirms >= 3 then
        update public.proofs
        set confirm_count = v_confirms,
            flag_count = v_flags,
            status = 'certified',
            is_certified = true,
            certified_at = coalesce(certified_at, now()),
            updated_at = now()
        where id = v_proof_id;
    else
        update public.proofs
        set confirm_count = v_confirms,
            flag_count = v_flags,
            updated_at = now()
        where id = v_proof_id;
    end if;

    return null;
end;
$$;

create trigger tr_process_witness_after_change
    after insert or update or delete on public.witnesses
    for each row execute function public.handle_witness_after_change();

create policy "authenticated users can witness proofs"
    on public.witnesses for insert
    to authenticated
    with check (auth.uid() = witness_id);

-- ----------------------------------------------------------------------------
-- 4. Crews (熔炉)
-- 4 to 20 members. Requires 4 members to activate.
-- ----------------------------------------------------------------------------
create table public.crews (
    id                  uuid primary key default gen_random_uuid(),
    name                text not null check (char_length(name) >= 2 and char_length(name) <= 24),
    description         text,
    avatar_url          text,
    created_by          uuid not null references public.profiles (id) on delete restrict,
    weekly_heat_target  int not null default 100 check (weekly_heat_target > 0),
    member_count        int not null default 1 check (member_count >= 1 and member_count <= 20),
    is_active           boolean not null default false, -- Activated when member_count >= 4
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now()
);

alter table public.crews enable row level security;

create policy "crews are viewable by authenticated users"
    on public.crews for select
    to authenticated
    using (true);

create policy "authenticated users can create a crew"
    on public.crews for insert
    to authenticated
    with check (auth.uid() = created_by);

create policy "crew leader can update crew"
    on public.crews for update
    to authenticated
    using (auth.uid() = created_by)
    with check (auth.uid() = created_by);

-- ----------------------------------------------------------------------------
-- 5. Crew Members (熔炉成员)
-- Tracks strikes (锤击), last active time, rust (生锈 after 5 days).
-- ----------------------------------------------------------------------------
create table public.crew_members (
    id              uuid primary key default gen_random_uuid(),
    crew_id         uuid not null references public.crews (id) on delete cascade,
    user_id         uuid not null references public.profiles (id) on delete cascade,
    role            text not null default 'member' check (role in ('leader', 'member')),
    strikes_count   int not null default 0 check (strikes_count >= 0),
    last_active_at  timestamptz not null default now(),
    joined_at       timestamptz not null default now(),

    unique (crew_id, user_id)
);

create index idx_crew_members_crew on public.crew_members (crew_id);
create index idx_crew_members_user on public.crew_members (user_id);

alter table public.crew_members enable row level security;

create policy "crew members are viewable by authenticated users"
    on public.crew_members for select
    to authenticated
    using (true);

create policy "users can join a crew"
    on public.crew_members for insert
    to authenticated
    with check (auth.uid() = user_id);

create policy "users can leave or leader can remove members"
    on public.crew_members for delete
    to authenticated
    using (auth.uid() = user_id or exists (
        select 1 from public.crews c where c.id = crew_id and c.created_by = auth.uid()
    ));

-- Maintain crew member count and is_active flag
create or replace function public.handle_crew_member_sync()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_crew_id uuid;
    v_count int;
begin
    v_crew_id := coalesce(new.crew_id, old.crew_id);
    select count(*) into v_count from public.crew_members where crew_id = v_crew_id;

    update public.crews
    set member_count = v_count,
        is_active = (v_count >= 4),
        updated_at = now()
    where id = v_crew_id;

    return null;
end;
$$;

create trigger tr_sync_crew_members
    after insert or delete on public.crew_members
    for each row execute function public.handle_crew_member_sync();

-- ----------------------------------------------------------------------------
-- 6. Crew Heat (炉温) & Quenching (淬火)
-- ----------------------------------------------------------------------------
create table public.crew_heat (
    id              uuid primary key default gen_random_uuid(),
    crew_id         uuid not null references public.crews (id) on delete cascade,
    week_start      date not null,
    total_heat      int not null default 0 check (total_heat >= 0),
    target_heat     int not null default 100 check (target_heat > 0),
    is_quenched     boolean not null default false,
    quenched_at     timestamptz,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now(),

    unique (crew_id, week_start)
);

alter table public.crew_heat enable row level security;

create policy "crew heat viewable by authenticated users"
    on public.crew_heat for select
    to authenticated
    using (true);

-- ----------------------------------------------------------------------------
-- 7. Crew Nudges (催一下)
-- One-tap nudge to rusted members (>= 5 days inactive).
-- ----------------------------------------------------------------------------
create table public.crew_nudges (
    id          uuid primary key default gen_random_uuid(),
    crew_id     uuid not null references public.crews (id) on delete cascade,
    sender_id   uuid not null references public.profiles (id) on delete cascade,
    target_id   uuid not null references public.profiles (id) on delete cascade,
    created_at  timestamptz not null default now(),

    check (sender_id <> target_id)
);

alter table public.crew_nudges enable row level security;

create policy "crew nudges viewable by involved users"
    on public.crew_nudges for select
    to authenticated
    using (auth.uid() = sender_id or auth.uid() = target_id);

create policy "crew members can send nudges"
    on public.crew_nudges for insert
    to authenticated
    with check (auth.uid() = sender_id);

-- ----------------------------------------------------------------------------
-- 8. Challenges (比武)
-- Head-to-head 力量分 gains over a fixed window (single lift or total).
-- ----------------------------------------------------------------------------
create table public.challenges (
    id                  uuid primary key default gen_random_uuid(),
    challenger_id       uuid not null references public.profiles (id) on delete cascade,
    challenged_id       uuid not null references public.profiles (id) on delete cascade,
    exercise_id         uuid references public.exercises (id) on delete set null, -- null means Total
    start_date          date not null default current_date,
    end_date            date not null,
    challenger_baseline numeric(6,2) not null default 0,
    challenged_baseline numeric(6,2) not null default 0,
    challenger_gain     numeric(6,2) not null default 0,
    challenged_gain     numeric(6,2) not null default 0,
    status              text not null default 'pending' check (status in ('pending', 'active', 'completed', 'declined', 'cancelled')),
    winner_id           uuid references public.profiles (id) on delete set null,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now(),

    check (challenger_id <> challenged_id),
    check (end_date >= start_date)
);

alter table public.challenges enable row level security;

create policy "challenges viewable by authenticated users"
    on public.challenges for select
    to authenticated
    using (true);

create policy "challenger can insert challenge"
    on public.challenges for insert
    to authenticated
    with check (auth.uid() = challenger_id);

create policy "participants can update challenge"
    on public.challenges for update
    to authenticated
    using (auth.uid() = challenger_id or auth.uid() = challenged_id)
    with check (auth.uid() = challenger_id or auth.uid() = challenged_id);

-- ----------------------------------------------------------------------------
-- 9. Certified Ranked Leaderboard View
-- Only certified proofs count for ranked leaderboards!
-- ----------------------------------------------------------------------------
create or replace view public.certified_leaderboard_entries as
select distinct on (p.user_id, p.exercise_id)
    p.user_id,
    prof.display_name,
    prof.avatar_url,
    prof.sex,
    prof.bodyweight_kg,
    p.exercise_id,
    p.weight_kg,
    p.reps,
    p.estimated_1rm,
    p.dots_score,
    p.tier,
    p.video_url,
    p.certified_at
from public.proofs p
join public.profiles prof on prof.id = p.user_id
where p.is_certified = true
order by p.user_id, p.exercise_id, p.dots_score desc, p.certified_at desc;

grant select on public.certified_leaderboard_entries to authenticated;
