-- ============================================================================
-- Step 7: expand the exercise library.
-- Idempotent (ON CONFLICT name_en DO NOTHING) so it's safe to re-run.
-- Fills gaps from the initial seed: machine variants, arm isolation,
-- rear delts, more core, and bodyweight staples.
-- ============================================================================

insert into public.exercises (name_en, name_zh, primary_muscle, equipment, is_compound, instructions)
values
    -- 胸 Chest
    ('Incline Dumbbell Press', '上斜哑铃卧推',  'chest',      'dumbbell',   false, '凳子调至30–45度，哑铃下放至胸部两侧，推起时不要互碰。'),
    ('Machine Chest Press',    '器械坐姿推胸',  'chest',      'machine',    false, '调整座椅使把手对准胸中部，推起时肩胛保持收紧。'),
    ('Cable Fly',              '绳索夹胸',      'chest',      'cable',      false, '滑轮调至肩高，微屈肘，双手在体前合拢时顶峰收缩胸肌。'),
    ('Push-up',                '俯卧撑',        'chest',      'bodyweight', true,  '身体成一直线，下放至胸近地面，核心收紧避免塌腰。'),
    ('Pec Deck',               '蝴蝶机夹胸',    'chest',      'machine',    false, '前臂贴垫，肘部微屈，缓慢合拢至顶峰收缩，控制回放。'),

    -- 背 Back
    ('Single-Arm Dumbbell Row', '单臂哑铃划船', 'back',       'dumbbell',   false, '一手一膝撑凳，背部平直，将哑铃拉向髋部，顶峰夹紧肩胛。'),
    ('T-Bar Row',              'T杠划船',       'back',       'barbell',    true,  '俯身背部平直，将杠铃拉向胸部下方，避免耸肩借力。'),
    ('Chest-Supported Row',    '上斜凳哑铃划船', 'back',      'dumbbell',   false, '胸部贴紧上斜凳，划起哑铃时肩胛后收，消除下肢借力。'),
    ('Straight-Arm Pulldown',  '直臂下压',      'back',       'cable',      false, '手臂基本伸直，以肩为轴将杆下压至大腿前侧，感受背阔发力。'),
    ('Chin-up',                '反手引体向上',  'back',       'bodyweight', true,  '反握与肩同宽，拉起至下巴过杠，肱二头参与更多。'),

    -- 肩 Shoulders
    ('Arnold Press',           '阿诺德推举',    'shoulders',  'dumbbell',   false, '从掌心朝自己起始，推起过程中旋转手腕至掌心向前。'),
    ('Rear Delt Fly',          '俯身哑铃飞鸟',  'shoulders',  'dumbbell',   false, '俯身背部平直，微屈肘向两侧打开至肩高，专注肩后束。'),
    ('Barbell Shrug',          '杠铃耸肩',      'shoulders',  'barbell',    false, '双手持杠自然下垂，耸肩向耳朵方向提起，顶峰略停。'),
    ('Machine Shoulder Press', '器械推举',      'shoulders',  'machine',    false, '调整座椅使把手与肩同高，推起至手臂接近伸直，不要锁死。'),

    -- 股四头肌 Quads
    ('Hack Squat',             '哈克深蹲',      'quads',      'machine',    true,  '背靠靠垫，双脚略前置，下蹲至大腿低于水平，膝盖跟随脚尖方向。'),
    ('Walking Lunge',          '箭步蹲行走',    'quads',      'dumbbell',   true,  '手持哑铃，向前跨步下蹲至双膝约90度，交替前行，躯干直立。'),
    ('Smith Machine Squat',    '史密斯深蹲',    'quads',      'machine',    true,  '杠铃置于上背，双脚略前置，下蹲轨迹固定，注意膝盖不内扣。'),

    -- 腘绳肌 Hamstrings
    ('Seated Leg Curl',        '坐姿腿弯举',    'hamstrings', 'machine',    false, '坐稳贴紧靠垫，将滚垫勾向小腿后侧，顶峰收缩后慢放。'),
    ('Good Morning',           '早安式',        'hamstrings', 'barbell',    false, '杠铃置于上背，膝盖微屈，髋部后推俯身至躯干接近水平，核心收紧。'),

    -- 臀 Glutes
    ('Hip Abductor Machine',   '坐姿髋外展',    'glutes',     'machine',    false, '双腿贴垫向外打开至最大幅度，顶峰略停，控制回放。'),
    ('Cable Kickback',         '绳索后踢',      'glutes',     'cable',      false, '脚踝套绳，扶稳支撑，向后上方踢腿，顶峰收缩臀部。'),

    -- 肱二头肌 Biceps
    ('Barbell Curl',           '杠铃弯举',      'biceps',     'barbell',    false, '大臂固定贴身，弯举至肩前，下放时控制离心不要甩动。'),
    ('Preacher Curl',          '牧师凳弯举',    'biceps',     'barbell',    false, '大臂贴紧斜垫，下放至手臂接近伸直，避免完全锁死。'),
    ('Cable Curl',             '绳索弯举',      'biceps',     'cable',      false, '大臂固定，绳索全程保持张力，顶峰收缩肱二头肌。'),

    -- 肱三头肌 Triceps
    ('Skullcrusher',           '仰卧臂屈伸',    'triceps',    'barbell',    false, '仰卧持杠，仅屈肘将杠下放至额头附近，大臂保持不动。'),
    ('Close-Grip Bench Press', '窄距卧推',      'triceps',    'barbell',    true,  '握距与肩同宽，手肘贴近身体下放，推起时专注三头发力。'),
    ('Overhead Cable Extension', '绳索颈后臂屈伸', 'triceps', 'cable',      false, '背对滑轮，双手持绳举过头顶，屈肘下放后伸直，大臂固定。'),

    -- 小腿 Calves
    ('Seated Calf Raise',      '坐姿提踵',      'calves',     'machine',    false, '前脚掌踩实，提踵至最高点后缓慢下放至充分拉伸。'),

    -- 核心 Core
    ('Cable Crunch',           '绳索卷腹',      'core',       'cable',      false, '跪姿持绳于头侧，以脊柱卷曲带动下放，不要用手臂拉。'),
    ('Ab Wheel Rollout',       '健腹轮',        'core',       'bodyweight', false, '跪姿推出至身体接近水平，核心全程收紧，避免塌腰。'),
    ('Russian Twist',          '俄罗斯转体',    'core',       'bodyweight', false, '坐姿后仰，双脚离地，手持负重左右转体，控制节奏。'),
    ('Side Plank',             '侧平板支撑',    'core',       'bodyweight', false, '单前臂撑地，身体成一直线，髋部不要下沉，换边进行。'),
    ('Dead Bug',               '死虫式',        'core',       'bodyweight', false, '仰卧，对侧手脚同时缓慢伸展，腰部全程贴紧地面。')
on conflict (name_en) do nothing;
