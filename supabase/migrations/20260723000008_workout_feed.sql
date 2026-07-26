-- ============================================================================
-- Step 9: social feed — friends' finished workouts + likes.
--
-- workout_feed is a per-user view: auth.uid() in the WHERE clause scopes it
-- to your own + your followees' finished workouts (views bypass table RLS,
-- so the follow check must live inside the view itself).
-- Aggregates (volume, set count, top exercises) are computed in SQL because
-- workout_exercises/workout_sets RLS blocks reading other users' rows.
-- ============================================================================

create table public.workout_likes (
    workout_id  uuid not null references public.workouts (id) on delete cascade,
    user_id     uuid not null references public.profiles (id) on delete cascade,
    created_at  timestamptz not null default now(),

    primary key (workout_id, user_id)
);

alter table public.workout_likes enable row level security;

-- Like counts aren't sensitive; visibility of the underlying workout is
-- enforced by workout_feed, and clients only render likes for feed items.
create policy "likes are viewable by authenticated users"
    on public.workout_likes for select
    to authenticated
    using (true);

create policy "users can like workouts"
    on public.workout_likes for insert
    to authenticated
    with check (auth.uid() = user_id);

create policy "users can remove their own likes"
    on public.workout_likes for delete
    to authenticated
    using (auth.uid() = user_id);

create or replace view public.workout_feed as
select
    w.id,
    w.user_id,
    p.display_name,
    w.name,
    w.started_at,
    w.finished_at,
    count(distinct we.id)                                          as exercise_count,
    count(s.id) filter (where not s.is_warmup)                     as set_count,
    coalesce(sum(s.weight_kg * s.reps) filter (where not s.is_warmup), 0) as total_volume_kg,
    (
        select jsonb_agg(t.name_zh)
        from (
            select e.name_zh
            from public.workout_exercises we2
            join public.exercises e on e.id = we2.exercise_id
            where we2.workout_id = w.id
            order by we2.order_index
            limit 3
        ) t
    )                                                              as top_exercises,
    (select count(*) from public.workout_likes wl where wl.workout_id = w.id) as like_count,
    exists(
        select 1 from public.workout_likes wl
        where wl.workout_id = w.id and wl.user_id = auth.uid()
    )                                                              as liked_by_me
from public.workouts w
join public.profiles p on p.id = w.user_id
left join public.workout_exercises we on we.workout_id = w.id
left join public.workout_sets s on s.workout_exercise_id = we.id
where w.finished_at is not null
  and (
      w.user_id = auth.uid()
      or w.user_id in (
          select followee_id from public.follows
          where follower_id = auth.uid()
      )
  )
group by w.id, w.user_id, p.display_name, w.name, w.started_at, w.finished_at
order by w.finished_at desc;

grant select on public.workout_feed to authenticated;
