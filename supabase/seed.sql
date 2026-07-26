-- ============================================================================
-- Mock data for UI preview / local development. NOT for production.
--
-- Creates 8 fake users (铁牛, 大力水手, …) with three weeks of finished
-- workouts, PRs on the four core lifts, mutual follows and cross-likes, so
-- the feed, leaderboards and weekly-volume chart have something to show.
--
-- How to run:
--   • Local:  `supabase db reset` picks this file up automatically.
--   • Hosted: paste the whole file into the dashboard SQL editor and run
--     (it runs as postgres, bypassing RLS, and can write auth.users).
--
-- Idempotent: re-running deletes the mock users (cascading to all their
-- data) and recreates them. Your real account is never touched — but note
-- the feed only shows followees, so follow the mock users from your account
-- (Profile tab → 开发者预览 → 关注模拟用户, DEBUG builds only).
--
-- Also creates a fixed "测试进入" account (dev-test@irodence.app /
-- devtest123456, id ...000009) so the DEBUG login bypass has a real,
-- deterministic session and profile instead of depending on Supabase's
-- anonymous-auth dashboard setting. It follows (and is followed by) all
-- mock users, so its feed and the leaderboard are populated immediately.
-- ============================================================================

-- 1. Remove previous mock data (cascades: profiles, workouts, sets, PRs,
--    follows, likes all hang off auth.users / profiles).
delete from auth.users where email like 'mock-%@irodence.app' or email = 'dev-test@irodence.app';

-- 2. Mock auth users. The handle_new_user trigger creates their profiles.
--    Password for all of them: mock123456
insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
)
select
    '00000000-0000-0000-0000-000000000000',
    v.id,
    'authenticated',
    'authenticated',
    v.email,
    crypt('mock123456', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    jsonb_build_object('full_name', v.name),
    now(),
    now()
from (values
    ('a0000000-0000-4000-8000-000000000001'::uuid, 'mock-tieniu@irodence.app',   '铁牛'),
    ('a0000000-0000-4000-8000-000000000002'::uuid, 'mock-dali@irodence.app',     '大力水手'),
    ('a0000000-0000-4000-8000-000000000003'::uuid, 'mock-gangpao@irodence.app',  '小钢炮'),
    ('a0000000-0000-4000-8000-000000000004'::uuid, 'mock-jenny@irodence.app',    'Jenny🏋️'),
    ('a0000000-0000-4000-8000-000000000005'::uuid, 'mock-tuiwang@irodence.app',  '腿王'),
    ('a0000000-0000-4000-8000-000000000006'::uuid, 'mock-alice@irodence.app',    'Alice爱撸铁'),
    ('a0000000-0000-4000-8000-000000000007'::uuid, 'mock-laowang@irodence.app',  '老王'),
    ('a0000000-0000-4000-8000-000000000008'::uuid, 'mock-maikun@irodence.app',   '闪电麦昆')
) as v(id, email, name);

-- 2b. Fixed dev-test-login account used by the "测试进入" DEBUG bypass.
--     Password: devtest123456
insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
)
values (
    '00000000-0000-0000-0000-000000000000',
    'a0000000-0000-4000-8000-000000000009'::uuid,
    'authenticated',
    'authenticated',
    'dev-test@irodence.app',
    crypt('devtest123456', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}',
    jsonb_build_object('full_name', '测试账号'),
    now(),
    now()
);

-- 3. Profile details (sex + bodyweight feed DOTS / leaderboard tiers).
update public.profiles p
set sex = v.sex, bodyweight_kg = v.bw, avatar_url = v.avatar
from (values
    ('a0000000-0000-4000-8000-000000000001'::uuid, 'male',   82.0, 'https://i.pravatar.cc/150?img=12'),
    ('a0000000-0000-4000-8000-000000000002'::uuid, 'male',   90.0, 'https://i.pravatar.cc/150?img=13'),
    ('a0000000-0000-4000-8000-000000000003'::uuid, 'male',   70.0, 'https://i.pravatar.cc/150?img=14'),
    ('a0000000-0000-4000-8000-000000000004'::uuid, 'female', 58.0, 'https://i.pravatar.cc/150?img=47'),
    ('a0000000-0000-4000-8000-000000000005'::uuid, 'male',   78.0, 'https://i.pravatar.cc/150?img=15'),
    ('a0000000-0000-4000-8000-000000000006'::uuid, 'female', 62.0, 'https://i.pravatar.cc/150?img=44'),
    ('a0000000-0000-4000-8000-000000000007'::uuid, 'male',   85.0, 'https://i.pravatar.cc/150?img=51'),
    ('a0000000-0000-4000-8000-000000000008'::uuid, 'male',   73.0, 'https://i.pravatar.cc/150?img=17'),
    ('a0000000-0000-4000-8000-000000000009'::uuid, 'male',   80.0, 'https://i.pravatar.cc/150?img=33')
) as v(id, sex, bw, avatar)
where p.id = v.id;

-- 4. Workouts, sets, PRs, follows, likes.
do $$
declare
    user_ids  uuid[] := array[
        'a0000000-0000-4000-8000-000000000001'::uuid,
        'a0000000-0000-4000-8000-000000000002'::uuid,
        'a0000000-0000-4000-8000-000000000003'::uuid,
        'a0000000-0000-4000-8000-000000000004'::uuid,
        'a0000000-0000-4000-8000-000000000005'::uuid,
        'a0000000-0000-4000-8000-000000000006'::uuid,
        'a0000000-0000-4000-8000-000000000007'::uuid,
        'a0000000-0000-4000-8000-000000000008'::uuid
    ];
    -- Strength multiplier per user (≈ novice → advanced spread).
    factors   numeric[] := array[1.15, 1.25, 0.85, 0.62, 1.05, 0.68, 0.95, 0.80];

    ex_names  text[] := array[
        'Bench Press', 'Barbell Back Squat', 'Deadlift', 'Overhead Press',
        'Barbell Row', 'Lat Pulldown', 'Dumbbell Bench Press', 'Leg Press',
        'Bicep Curl', 'Lateral Raise', 'Seated Cable Row', 'Incline Bench Press'
    ];
    -- Typical working weight (kg) for a mid-level male lifter per exercise.
    ex_base   numeric[] := array[80, 110, 130, 45, 70, 60, 55, 140, 20, 12, 55, 60];

    workout_names text[] := array[
        '胸部轰炸', '背部训练', '腿日', '上肢力量', '全身循环', '推拉日'
    ];

    ex_ids    uuid[];
    uid       uuid;
    w_id      uuid;
    we_id     uuid;
    ui        int;
    di        int;
    ei        int;
    si        int;
    ex_idx    int;
    day_off   int;
    started   timestamptz;
    w         numeric;
    r         int;
begin
    -- Resolve library UUIDs, preserving ex_names order.
    select array_agg(e.id order by x.ord) into ex_ids
    from unnest(ex_names) with ordinality as x(name, ord)
    join public.exercises e on e.name_en = x.name;

    if ex_ids is null or array_length(ex_ids, 1) < array_length(ex_names, 1) then
        raise warning 'exercise library incomplete (% / % found) — run migrations first; skipping mock workouts',
            coalesce(array_length(ex_ids, 1), 0), array_length(ex_names, 1);
        return;
    end if;

    for ui in 1..array_length(user_ids, 1) loop
        uid := user_ids[ui];

        -- Seven workouts each, ~3 days apart, spread over the last 3 weeks.
        for di in 0..6 loop
            day_off := di * 3 + (ui % 3);
            started := date_trunc('day', now())
                       - make_interval(days => day_off)
                       + make_interval(hours => 17 + (ui % 4));
            w_id := gen_random_uuid();
            insert into public.workouts (id, user_id, name, started_at, finished_at)
            values (
                w_id, uid,
                workout_names[((ui + di) % array_length(workout_names, 1)) + 1],
                started,
                started + make_interval(mins => 55 + ((ui * 7 + di * 13) % 30))
            );

            -- Three exercises per workout, rotating through the list.
            for ei in 0..2 loop
                ex_idx := ((ui + di + ei * 3) % array_length(ex_ids, 1)) + 1;
                we_id := gen_random_uuid();
                insert into public.workout_exercises (id, workout_id, exercise_id, order_index)
                values (we_id, w_id, ex_ids[ex_idx], ei);

                w := round((ex_base[ex_idx] * factors[ui]
                            * (0.95 + 0.1 * ((di + ei) % 3))) / 2.5) * 2.5;

                -- One warmup set…
                insert into public.workout_sets
                    (workout_exercise_id, set_index, weight_kg, reps, is_warmup)
                values (we_id, 0, greatest(round(w * 0.6 / 2.5) * 2.5, 0), 10, true);

                -- …and three working sets.
                for si in 1..3 loop
                    r := 5 + ((ui + di + si) % 4);
                    insert into public.workout_sets
                        (workout_exercise_id, set_index, weight_kg, reps, rpe, is_warmup)
                    values (we_id, si, w, r, 7 + ((ui + si) % 3) * 0.5, false);
                end loop;
            end loop;

            -- A handful of likes from other mock users.
            insert into public.workout_likes (workout_id, user_id)
            select w_id, user_ids[((ui + k - 1) % 8) + 1]
            from generate_series(1, 2 + (di % 3)) as k
            where user_ids[((ui + k - 1) % 8) + 1] <> uid
            on conflict do nothing;
        end loop;

        -- PRs on the four core lifts (drives leaderboards / DOTS tiers).
        for ei in 1..4 loop
            w := round(ex_base[ei] * factors[ui] * 1.08 / 2.5) * 2.5;
            r := 3 + (ui % 3);
            insert into public.personal_records
                (user_id, exercise_id, weight_kg, reps, estimated_1rm, achieved_at)
            values (
                uid, ex_ids[ei], w, r,
                round(w * (1 + r / 30.0), 1),
                now() - make_interval(days => ui * 2 + ei)
            );
        end loop;
    end loop;

    -- Mock users all follow each other (their feeds look alive when you
    -- log in as one of them; your own account follows them via the app).
    insert into public.follows (follower_id, followee_id)
    select a, b
    from unnest(user_ids) as a
    cross join unnest(user_ids) as b
    where a <> b
    on conflict do nothing;

    -- The fixed dev-test-login account (see 2b.) follows and is followed by
    -- everyone too, so "测试进入" lands on a fully populated feed/leaderboard
    -- without any extra manual steps.
    insert into public.follows (follower_id, followee_id)
    select 'a0000000-0000-4000-8000-000000000009'::uuid, a
    from unnest(user_ids) as a
    union all
    select a, 'a0000000-0000-4000-8000-000000000009'::uuid
    from unnest(user_ids) as a
    on conflict do nothing;

    -- A couple of finished workouts of its own, so the profile/summary
    -- screens and weekly-volume chart aren't empty when testing as this user.
    uid := 'a0000000-0000-4000-8000-000000000009'::uuid;
    for di in 0..2 loop
        started := date_trunc('day', now())
                   - make_interval(days => di * 3)
                   + make_interval(hours => 18);
        w_id := gen_random_uuid();
        insert into public.workouts (id, user_id, name, started_at, finished_at)
        values (
            w_id, uid,
            workout_names[(di % array_length(workout_names, 1)) + 1],
            started,
            started + make_interval(mins => 60)
        );

        for ei in 0..2 loop
            ex_idx := ((di + ei * 3) % array_length(ex_ids, 1)) + 1;
            we_id := gen_random_uuid();
            insert into public.workout_exercises (id, workout_id, exercise_id, order_index)
            values (we_id, w_id, ex_ids[ex_idx], ei);

            w := round((ex_base[ex_idx] * 1.0) / 2.5) * 2.5;

            insert into public.workout_sets
                (workout_exercise_id, set_index, weight_kg, reps, is_warmup)
            values (we_id, 0, greatest(round(w * 0.6 / 2.5) * 2.5, 0), 10, true);

            for si in 1..3 loop
                insert into public.workout_sets
                    (workout_exercise_id, set_index, weight_kg, reps, rpe, is_warmup)
                values (we_id, si, w, 8, 7.5, false);
            end loop;
        end loop;
    end loop;
end $$;
