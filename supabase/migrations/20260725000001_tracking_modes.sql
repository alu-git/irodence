-- Per-exercise tracking mode: how a set is logged in the active workout.
--   'weighted'   — weight + reps (default, current behavior)
--   'bodyweight' — reps only, no weight field
--   'duration'   — timed sets (planks, cardio), logged in seconds

alter table public.exercises
    add column tracking_mode text not null default 'weighted'
    check (tracking_mode in ('weighted', 'bodyweight', 'duration'));

-- Bodyweight-equipment exercises log reps only. (Weighted variants like
-- weighted pull-ups should stay 'weighted' — they are distinct rows with
-- barbell/machine-style names in the seed.)
update public.exercises set tracking_mode = 'bodyweight' where equipment = 'bodyweight';

-- Static holds are timed, not counted.
update public.exercises set tracking_mode = 'duration'
where name_en in ('Plank', 'Side Plank');

-- A few basic cardio/endurance entries, timed like planks.
insert into public.exercises (name_en, name_zh, primary_muscle, equipment, is_compound, tracking_mode, instructions_zh, instructions_en) values
    ('Running',   '跑步',   'quads',  'bodyweight', true, 'duration', '保持匀速呼吸与稳定配速，前脚掌或全脚掌着地，身体微微前倾。', 'Keep a steady pace and even breathing, land midfoot, slight forward lean.'),
    ('Jump Rope', '跳绳',   'calves', 'bodyweight', true, 'duration', '手腕发力摇绳，前脚掌轻跳，膝盖微屈保持弹性。', 'Turn the rope with your wrists, bounce lightly on the balls of your feet, knees soft.'),
    ('Cycling',   '骑行',   'quads',  'machine',    true, 'duration', '调整坐垫至腿部接近伸直，保持匀速踩踏。', 'Set the saddle so the leg is almost straight at the bottom; keep a smooth, even cadence.'),
    ('Rowing Machine', '划船机', 'back', 'machine',  true, 'duration', '蹬腿—后仰—拉桨按顺序发力，回程反向放松。', 'Drive with legs, lean back, then pull; reverse the sequence on the recovery.')
on conflict (name_en) do update set tracking_mode = excluded.tracking_mode;

-- Duration sets have a time instead of a rep count.
alter table public.workout_sets
    add column duration_seconds integer check (duration_seconds is null or duration_seconds > 0);

alter table public.workout_sets alter column reps drop not null;
alter table public.workout_sets drop constraint workout_sets_reps_check;
alter table public.workout_sets
    add constraint workout_sets_reps_check check (reps is null or reps > 0);
