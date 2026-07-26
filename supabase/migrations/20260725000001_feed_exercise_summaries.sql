-- ============================================================================
-- Social feed redesign: per-exercise detail on workout_feed.
--
-- Replaces the top_exercises name list with exercise_summaries — a jsonb
-- array (ordered by order_index) of one object per exercise:
--   { name_zh, name_en, primary_muscle, set_count, volume_kg,
--     best_weight_kg, best_reps,
--     sets: [{ weight_kg, reps, is_warmup }] }
--
-- Like the existing aggregates, this lives in the view because RLS on
-- workout_exercises/workout_sets blocks clients from reading other users'
-- rows directly, while the view's WHERE clause scopes visibility to
-- yourself + followees.
--
-- NOTE: CREATE OR REPLACE VIEW can't rename columns (top_exercises ->
-- exercise_summaries), so the view is dropped and recreated.
-- ============================================================================

drop view public.workout_feed;

create view public.workout_feed as
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
        select coalesce(jsonb_agg(t.data order by t.order_index), '[]'::jsonb)
        from (
            select
                we2.order_index,
                jsonb_build_object(
                    'name_zh', e.name_zh,
                    'name_en', e.name_en,
                    'primary_muscle', e.primary_muscle,
                    'set_count', count(s2.id) filter (where not s2.is_warmup),
                    'volume_kg', coalesce(sum(s2.weight_kg * s2.reps) filter (where not s2.is_warmup), 0),
                    'best_weight_kg', max(s2.weight_kg) filter (where not s2.is_warmup),
                    'best_reps', (
                        select s3.reps
                        from public.workout_sets s3
                        where s3.workout_exercise_id = we2.id
                          and not s3.is_warmup
                        order by s3.weight_kg desc, s3.reps desc
                        limit 1
                    ),
                    'sets', coalesce((
                        select jsonb_agg(jsonb_build_object(
                            'weight_kg', s4.weight_kg,
                            'reps', s4.reps,
                            'is_warmup', s4.is_warmup
                        ) order by s4.set_index)
                        from public.workout_sets s4
                        where s4.workout_exercise_id = we2.id
                    ), '[]'::jsonb)
                ) as data
            from public.workout_exercises we2
            join public.exercises e on e.id = we2.exercise_id
            left join public.workout_sets s2 on s2.workout_exercise_id = we2.id
            where we2.workout_id = w.id
            group by we2.id, we2.order_index, e.name_zh, e.name_en, e.primary_muscle
        ) t
    )                                                              as exercise_summaries,
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
