-- ============================================================================
-- Step 2: seed the exercise library.
-- Idempotent (ON CONFLICT name_en DO NOTHING) so it's safe to re-run.
-- Runs as the service role via migrations, which bypasses the read-only RLS.
-- ============================================================================

insert into public.exercises (name_en, name_zh, primary_muscle, equipment, is_compound, instructions)
values
    -- Core compounds (DOTS-scored lifts are squat/bench/deadlift/ohp)
    ('Barbell Back Squat',   '杠铃深蹲',       'quads',      'barbell',    true,  '杠铃置于上背，双脚与肩同宽。下蹲至大腿低于水平面，保持核心收紧、膝盖与脚尖同向。'),
    ('Bench Press',          '杠铃卧推',       'chest',      'barbell',    true,  '仰卧于卧推凳，握距略宽于肩。下放杠铃至胸部中段，肩胛收紧，双脚踩实地面。'),
    ('Deadlift',             '硬拉',           'back',       'barbell',    true,  '杠铃贴近小腿，背部保持中立。用腿和髋部发力将杠沿身体直线拉起，顶端锁髋。'),
    ('Overhead Press',       '站姿杠铃推举',   'shoulders',  'barbell',    true,  '杠铃置于锁骨上方，收紧臀部与核心，垂直向上推至手臂完全伸直。'),
    ('Barbell Row',          '杠铃划船',       'back',       'barbell',    true,  '俯身约45度，背部平直。将杠铃拉向下腹部，顶峰收缩肩胛。'),
    ('Pull-up',              '引体向上',       'back',       'bodyweight', true,  '正握略宽于肩，从完全悬垂拉起至下巴过杠，避免摆动借力。'),
    ('Front Squat',          '颈前深蹲',       'quads',      'barbell',    true,  '杠铃置于前肩，手肘抬高。保持躯干直立下蹲，核心持续收紧。'),
    ('Romanian Deadlift',    '罗马尼亚硬拉',   'hamstrings', 'barbell',    true,  '膝盖微屈，髋部后推，杠铃沿大腿下放至腘绳肌充分拉伸，再用髋部发力回位。'),
    ('Incline Bench Press',  '上斜杠铃卧推',   'chest',      'barbell',    true,  '卧推凳调至30–45度，下放至上胸部，注意肩胛保持稳定。'),
    ('Hip Thrust',           '杠铃臀推',       'glutes',     'barbell',    true,  '上背靠凳，杠铃置于髋部。顶髋至身体成一直线，顶峰用力收缩臀部。'),
    ('Dip',                  '双杠臂屈伸',     'chest',      'bodyweight', true,  '身体略前倾练胸、直立练三头。下放至肩低于肘，推起至手臂接近伸直。'),
    ('Leg Press',            '腿举',           'quads',      'machine',    true,  '双脚与肩同宽踩在踏板上，下放至膝盖约90度，不要锁死膝关节。'),
    ('Lat Pulldown',         '高位下拉',       'back',       'cable',      true,  '宽握横杆，挺胸，将杆拉向上胸，感受背阔肌收缩，控制回放。'),
    ('Seated Cable Row',     '坐姿划船',       'back',       'cable',      true,  '坐直，将把手拉向腹部，肩胛后夹，回放时保持张力。'),
    ('Power Clean',          '高翻',           'back',       'barbell',    true,  '从地面爆发拉起，杠铃过膝后伸髋耸肩，翻腕接杠于前肩。建议先轻重量练习动作模式。'),

    -- Accessories
    ('Dumbbell Bench Press', '哑铃卧推',       'chest',      'dumbbell',   false, '比杠铃更大的下放幅度，注意哑铃轨迹稳定，不要互碰借力。'),
    ('Dumbbell Shoulder Press', '哑铃推举',    'shoulders',  'dumbbell',   false, '坐姿或站姿，从耳侧推至头顶上方，核心收紧避免后仰。'),
    ('Lateral Raise',        '哑铃侧平举',     'shoulders',  'dumbbell',   false, '微屈肘，将哑铃抬至肩高，顶峰略停，慢速下放。'),
    ('Bicep Curl',           '哑铃弯举',       'biceps',     'dumbbell',   false, '大臂固定贴身，掌心向前弯举至肩前，控制离心。'),
    ('Hammer Curl',          '锤式弯举',       'biceps',     'dumbbell',   false, '掌心相对握哑铃，弯举时保持中立握法，刺激肱肌。'),
    ('Tricep Pushdown',      '绳索下压',       'triceps',    'cable',      false, '大臂夹紧固定，仅前臂下压至完全伸直。'),
    ('Overhead Tricep Extension', '颈后臂屈伸', 'triceps',   'dumbbell',   false, '双手持哑铃举过头顶，屈肘下放至颈后，再伸直手臂。'),
    ('Leg Curl',             '俯卧腿弯举',     'hamstrings', 'machine',    false, '俯卧，将滚垫勾向臀部，顶峰收缩后慢放。'),
    ('Leg Extension',        '坐姿腿屈伸',     'quads',      'machine',    false, '坐稳，伸直双腿至水平，顶峰收缩股四头肌，慢速下放。'),
    ('Calf Raise',           '站姿提踵',       'calves',     'machine',    false, '前脚掌踩实，提踵至最高点后缓慢下放至充分拉伸。'),
    ('Face Pull',            '绳索面拉',       'shoulders',  'cable',      false, '绳索拉向面部，手肘外展，强化肩后束与上背，改善体态。'),
    ('Chest Fly',            '哑铃飞鸟',       'chest',      'dumbbell',   false, '仰卧，微屈肘，哑铃弧线打开至胸部拉伸，再合拢。'),
    ('Bulgarian Split Squat', '保加利亚分腿蹲', 'quads',     'dumbbell',   false, '后脚搭在凳上，前腿下蹲至大腿平行地面，躯干保持直立。'),
    ('Goblet Squat',         '高脚杯深蹲',     'quads',      'dumbbell',   false, '双手持哑铃于胸前，下蹲时手肘触膝内侧，适合学习深蹲模式。'),
    ('Plank',                '平板支撑',       'core',       'bodyweight', false, '前臂撑地，身体成一直线，收紧腹部与臀部，避免塌腰。'),
    ('Hanging Leg Raise',    '悬垂举腿',       'core',       'bodyweight', false, '悬垂于单杠，控制地将腿抬至水平以上，避免摆动。')
on conflict (name_en) do nothing;
