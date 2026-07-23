-- ============================================================================
-- Step 5: social — follows + leaderboard read paths.
--
-- personal_records RLS stays owner-only. Leaderboards read through VIEWS,
-- which run as the view owner (bypassing RLS) and only expose each user's
-- BEST lift per exercise — never their full history.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- follows — one-directional follow (like Instagram, not mutual friends)
-- ----------------------------------------------------------------------------
create table public.follows (
    follower_id uuid not null references public.profiles (id) on delete cascade,
    followee_id uuid not null references public.profiles (id) on delete cascade,
    created_at  timestamptz not null default now(),

    primary key (follower_id, followee_id),
    check (follower_id <> followee_id)
);

alter table public.follows enable row level security;

-- You can see follows that involve you. (Friends-only filtering is done
-- client-side from your own follower list.)
create policy "users can view follows that involve them"
    on public.follows for select
    to authenticated
    using (auth.uid() = follower_id or auth.uid() = followee_id);

create policy "users can follow others"
    on public.follows for insert
    to authenticated
    with check (auth.uid() = follower_id);

create policy "users can unfollow"
    on public.follows for delete
    to authenticated
    using (auth.uid() = follower_id);

-- ----------------------------------------------------------------------------
-- leaderboard_entries — best PR per user per lift, joined to profile info
-- needed for DOTS (sex + bodyweight). One row per (user, exercise).
-- ----------------------------------------------------------------------------
create or replace view public.leaderboard_entries as
select distinct on (pr.user_id, pr.exercise_id)
    pr.user_id,
    p.display_name,
    p.avatar_url,
    p.sex,
    p.bodyweight_kg,
    pr.exercise_id,
    pr.weight_kg,
    pr.reps,
    pr.estimated_1rm,
    pr.achieved_at
from public.personal_records pr
join public.profiles p on p.id = pr.user_id
order by pr.user_id, pr.exercise_id, pr.estimated_1rm desc, pr.achieved_at desc;

grant select on public.leaderboard_entries to authenticated;

-- ----------------------------------------------------------------------------
-- weekly_volume — total kg lifted per user for the current ISO week.
-- Rewards consistency, not just maxes. Excludes warmup sets.
-- ----------------------------------------------------------------------------
create or replace view public.weekly_volume as
select
    w.user_id,
    p.display_name,
    p.avatar_url,
    sum(s.weight_kg * s.reps) as total_volume_kg,
    count(s.id)               as total_sets
from public.workout_sets s
join public.workout_exercises we on we.id = s.workout_exercise_id
join public.workouts w on w.id = we.workout_id
join public.profiles p on p.id = w.user_id
where w.finished_at is not null
  and w.finished_at >= date_trunc('week', now())
  and s.is_warmup = false
group by w.user_id, p.display_name, p.avatar_url;

grant select on public.weekly_volume to authenticated;
