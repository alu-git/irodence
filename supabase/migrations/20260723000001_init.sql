-- ============================================================================
-- HevyKimi — initial schema
-- Tables: profiles, exercises, workouts, workout_exercises, workout_sets,
--         personal_records
-- RLS is enabled on every table from day one.
--
-- Naming note: we use `public.profiles` (Supabase convention) instead of
-- `users` because `auth.users` already exists and is managed by Supabase Auth.
--
-- Step 1 scope. Planned later:
--   - bodyweight_logs table (step 6) — feeds DOTS calc
--   - follows table + leaderboard read path (step 5) — will need a
--     security-definer view so users can see friends' bests without opening
--     personal_records to everyone
-- ============================================================================

create extension if not exists "pgcrypto";

-- ----------------------------------------------------------------------------
-- profiles — one row per auth user
-- ----------------------------------------------------------------------------
create table public.profiles (
    id              uuid primary key references auth.users (id) on delete cascade,
    wechat_openid   text unique,              -- set by wechat-auth edge function
    display_name    text not null default '老铁',
    avatar_url      text,
    sex             text check (sex in ('male', 'female')),
    bodyweight_kg   numeric(5,2) check (bodyweight_kg > 0 and bodyweight_kg < 500),
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Any signed-in user can view profiles (needed for friend search in step 5).
-- If you want private profiles later, replace with a follows-aware policy.
create policy "profiles are viewable by authenticated users"
    on public.profiles for select
    to authenticated
    using (true);

create policy "users can insert their own profile"
    on public.profiles for insert
    to authenticated
    with check (auth.uid() = id);

create policy "users can update their own profile"
    on public.profiles for update
    to authenticated
    using (auth.uid() = id)
    with check (auth.uid() = id);

-- No delete policy: users cannot delete profiles via the client.

-- Auto-create a profile row when a new auth user signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.profiles (id, display_name, avatar_url)
    values (
        new.id,
        coalesce(new.raw_user_meta_data ->> 'full_name', '老铁'),
        new.raw_user_meta_data ->> 'avatar_url'
    );
    return new;
end;
$$;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- ----------------------------------------------------------------------------
-- exercises — global library, seeded by us; read-only for clients
-- ----------------------------------------------------------------------------
create table public.exercises (
    id              uuid primary key default gen_random_uuid(),
    name_en         text not null,
    name_zh         text not null,
    primary_muscle  text not null,            -- e.g. 'chest', 'back', 'quads'
    equipment       text not null,            -- e.g. 'barbell', 'dumbbell', 'bodyweight'
    is_compound     boolean not null default false,
    instructions    text,                     -- zh instructions, step 2
    created_at      timestamptz not null default now(),

    unique (name_en)
);

alter table public.exercises enable row level security;

create policy "exercises are viewable by authenticated users"
    on public.exercises for select
    to authenticated
    using (true);

-- No insert/update/delete policies: only the service role (migrations/seeds)
-- can modify the library.

-- ----------------------------------------------------------------------------
-- workouts — a logged training session
-- ----------------------------------------------------------------------------
create table public.workouts (
    id          uuid primary key default gen_random_uuid(),
    user_id     uuid not null references public.profiles (id) on delete cascade,
    name        text not null default '训练',
    started_at  timestamptz not null default now(),
    finished_at timestamptz,                  -- null while the workout is live
    notes       text,
    created_at  timestamptz not null default now()
);

create index workouts_user_started_idx on public.workouts (user_id, started_at desc);

alter table public.workouts enable row level security;

create policy "users can view their own workouts"
    on public.workouts for select
    to authenticated
    using (auth.uid() = user_id);

create policy "users can create their own workouts"
    on public.workouts for insert
    to authenticated
    with check (auth.uid() = user_id);

create policy "users can update their own workouts"
    on public.workouts for update
    to authenticated
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

create policy "users can delete their own workouts"
    on public.workouts for delete
    to authenticated
    using (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- workout_exercises — exercises inside a workout, with ordering + supersets.
-- Sets hang off this table (not off workouts directly) so that superset
-- grouping and per-exercise ordering survive re-ordering.
-- ----------------------------------------------------------------------------
create table public.workout_exercises (
    id              uuid primary key default gen_random_uuid(),
    workout_id      uuid not null references public.workouts (id) on delete cascade,
    exercise_id     uuid not null references public.exercises (id),
    order_index     integer not null,
    superset_group  integer,                  -- same non-null value = one superset
    created_at      timestamptz not null default now(),

    unique (workout_id, order_index)
);

create index workout_exercises_workout_idx on public.workout_exercises (workout_id);

alter table public.workout_exercises enable row level security;

-- Ownership is inherited from the parent workout.
create policy "users can view exercises in their own workouts"
    on public.workout_exercises for select
    to authenticated
    using (exists (
        select 1 from public.workouts w
        where w.id = workout_id and w.user_id = auth.uid()
    ));

create policy "users can add exercises to their own workouts"
    on public.workout_exercises for insert
    to authenticated
    with check (exists (
        select 1 from public.workouts w
        where w.id = workout_id and w.user_id = auth.uid()
    ));

create policy "users can update exercises in their own workouts"
    on public.workout_exercises for update
    to authenticated
    using (exists (
        select 1 from public.workouts w
        where w.id = workout_id and w.user_id = auth.uid()
    ))
    with check (exists (
        select 1 from public.workouts w
        where w.id = workout_id and w.user_id = auth.uid()
    ));

create policy "users can delete exercises from their own workouts"
    on public.workout_exercises for delete
    to authenticated
    using (exists (
        select 1 from public.workouts w
        where w.id = workout_id and w.user_id = auth.uid()
    ));

-- ----------------------------------------------------------------------------
-- workout_sets — individual sets (kg only, no lb)
-- ----------------------------------------------------------------------------
create table public.workout_sets (
    id                  uuid primary key default gen_random_uuid(),
    workout_exercise_id uuid not null references public.workout_exercises (id) on delete cascade,
    set_index           integer not null,
    weight_kg           numeric(6,2) not null check (weight_kg >= 0),
    reps                integer not null check (reps > 0),
    rpe                 numeric(3,1) check (rpe >= 1 and rpe <= 10),
    is_warmup           boolean not null default false,
    created_at          timestamptz not null default now(),

    unique (workout_exercise_id, set_index)
);

create index workout_sets_exercise_idx on public.workout_sets (workout_exercise_id);

alter table public.workout_sets enable row level security;

-- Ownership inherited via workout_exercises -> workouts.
create policy "users can view sets in their own workouts"
    on public.workout_sets for select
    to authenticated
    using (exists (
        select 1
        from public.workout_exercises we
        join public.workouts w on w.id = we.workout_id
        where we.id = workout_exercise_id and w.user_id = auth.uid()
    ));

create policy "users can add sets to their own workouts"
    on public.workout_sets for insert
    to authenticated
    with check (exists (
        select 1
        from public.workout_exercises we
        join public.workouts w on w.id = we.workout_id
        where we.id = workout_exercise_id and w.user_id = auth.uid()
    ));

create policy "users can update sets in their own workouts"
    on public.workout_sets for update
    to authenticated
    using (exists (
        select 1
        from public.workout_exercises we
        join public.workouts w on w.id = we.workout_id
        where we.id = workout_exercise_id and w.user_id = auth.uid()
    ))
    with check (exists (
        select 1
        from public.workout_exercises we
        join public.workouts w on w.id = we.workout_id
        where we.id = workout_exercise_id and w.user_id = auth.uid()
    ));

create policy "users can delete sets from their own workouts"
    on public.workout_sets for delete
    to authenticated
    using (exists (
        select 1
        from public.workout_exercises we
        join public.workouts w on w.id = we.workout_id
        where we.id = workout_exercise_id and w.user_id = auth.uid()
    ));

-- ----------------------------------------------------------------------------
-- personal_records — best lifts per exercise per user.
-- `estimated_1rm` (Epley) is computed client-side at write time in step 3 and
-- stored here so DOTS scoring and leaderboards never have to recompute it.
-- ----------------------------------------------------------------------------
create table public.personal_records (
    id              uuid primary key default gen_random_uuid(),
    user_id         uuid not null references public.profiles (id) on delete cascade,
    exercise_id     uuid not null references public.exercises (id),
    weight_kg       numeric(6,2) not null check (weight_kg > 0),
    reps            integer not null check (reps > 0),
    estimated_1rm   numeric(6,2) not null check (estimated_1rm > 0),
    workout_id      uuid references public.workouts (id) on delete set null,
    achieved_at     timestamptz not null default now(),
    created_at      timestamptz not null default now()
);

create index personal_records_user_exercise_idx
    on public.personal_records (user_id, exercise_id, estimated_1rm desc);

alter table public.personal_records enable row level security;

-- NOTE(step 5): leaderboard reads of OTHER users' PRs will go through a
-- security-definer view that only exposes the single best PR per user/lift.
-- Do not broaden this policy to `using (true)` — it would leak full history.
create policy "users can view their own personal records"
    on public.personal_records for select
    to authenticated
    using (auth.uid() = user_id);

create policy "users can insert their own personal records"
    on public.personal_records for insert
    to authenticated
    with check (auth.uid() = user_id);

create policy "users can update their own personal records"
    on public.personal_records for update
    to authenticated
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

create policy "users can delete their own personal records"
    on public.personal_records for delete
    to authenticated
    using (auth.uid() = user_id);
