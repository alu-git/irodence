-- ============================================================================
-- Step 7b: populate English instructions for all existing exercises.
-- Safe to re-run: each UPDATE is keyed by the unique name_en and is
-- idempotent (setting the same value again is a no-op).
-- ============================================================================

update public.exercises set instructions_en = 'Bar rests on the upper back, feet shoulder-width apart. Squat until thighs are below horizontal, keeping the core tight and knees tracking over the toes.' where name_en = 'Barbell Back Squat';
update public.exercises set instructions_en = 'Lie on the bench with a grip slightly wider than shoulder-width. Lower the bar to mid-chest, shoulder blades pinned, feet planted firmly.' where name_en = 'Bench Press';
update public.exercises set instructions_en = 'Keep the bar close to your shins with a neutral spine. Drive through the legs and hips to pull the bar up in a straight line, locking out the hips at the top.' where name_en = 'Deadlift';
update public.exercises set instructions_en = 'Bar rests at collarbone height. Brace the glutes and core, then press straight overhead until the arms are fully extended.' where name_en = 'Overhead Press';
update public.exercises set instructions_en = 'Hinge forward to about 45 degrees with a flat back. Pull the bar toward your lower abdomen, squeezing the shoulder blades at the top.' where name_en = 'Barbell Row';
update public.exercises set instructions_en = 'Grip slightly wider than shoulder-width. Pull from a full hang until your chin clears the bar, avoiding swinging momentum.' where name_en = 'Pull-up';
update public.exercises set instructions_en = 'Bar rests on the front shoulders with elbows high. Keep the torso upright while squatting, core braced throughout.' where name_en = 'Front Squat';
update public.exercises set instructions_en = 'Slight knee bend, hinge the hips back. Lower the bar along the thighs until the hamstrings are fully stretched, then drive the hips forward to return.' where name_en = 'Romanian Deadlift';
update public.exercises set instructions_en = 'Set the bench to 30-45 degrees. Lower the bar to the upper chest, keeping the shoulder blades stable.' where name_en = 'Incline Bench Press';
update public.exercises set instructions_en = 'Upper back rests on a bench, bar over the hips. Drive the hips up until the body forms a straight line, squeezing the glutes hard at the top.' where name_en = 'Hip Thrust';
update public.exercises set instructions_en = 'Lean forward slightly to target chest, stay upright to target triceps. Lower until the shoulders dip below the elbows, then press up until the arms are nearly straight.' where name_en = 'Dip';
update public.exercises set instructions_en = 'Feet shoulder-width apart on the platform. Lower until the knees reach about 90 degrees, avoiding locking the knees out at the top.' where name_en = 'Leg Press';
update public.exercises set instructions_en = 'Wide grip on the bar, chest up. Pull the bar to the upper chest, feeling the lats contract, and control the return.' where name_en = 'Lat Pulldown';
update public.exercises set instructions_en = 'Sit upright and pull the handle toward your abdomen, squeezing the shoulder blades together, keeping tension on the return.' where name_en = 'Seated Cable Row';
update public.exercises set instructions_en = 'Pull explosively from the floor, extend the hips and shrug once the bar passes the knees, then flip the wrists to catch the bar on the front shoulders. Practice with light weight first to learn the pattern.' where name_en = 'Power Clean';
update public.exercises set instructions_en = 'Allows a deeper range of motion than the barbell version. Keep the dumbbell path stable and avoid banging them together for momentum.' where name_en = 'Dumbbell Bench Press';
update public.exercises set instructions_en = 'Seated or standing, press from ear height straight overhead. Keep the core tight to avoid leaning back.' where name_en = 'Dumbbell Shoulder Press';
update public.exercises set instructions_en = 'Slight elbow bend, raise the dumbbells to shoulder height, pause briefly at the top, then lower slowly.' where name_en = 'Lateral Raise';
update public.exercises set instructions_en = 'Keep the upper arms fixed at your sides, palms forward, curl to shoulder height and control the eccentric.' where name_en = 'Bicep Curl';
update public.exercises set instructions_en = 'Hold the dumbbells with a neutral (palms-facing) grip and curl up, keeping the grip neutral throughout to target the brachialis.' where name_en = 'Hammer Curl';
update public.exercises set instructions_en = 'Keep the upper arms pinned to your sides; only the forearms move as you press down to full extension.' where name_en = 'Tricep Pushdown';
update public.exercises set instructions_en = 'Hold a dumbbell overhead with both hands, lower it behind your head by bending the elbows, then extend back to straight arms.' where name_en = 'Overhead Tricep Extension';
update public.exercises set instructions_en = 'Lying face down, curl the pad toward your glutes, squeeze at the top, then lower with control.' where name_en = 'Leg Curl';
update public.exercises set instructions_en = 'Sit securely and extend the legs to horizontal, squeezing the quads at the top, then lower slowly.' where name_en = 'Leg Extension';
update public.exercises set instructions_en = 'Balls of the feet planted, rise onto your toes to the top position, then lower slowly for a full stretch.' where name_en = 'Calf Raise';
update public.exercises set instructions_en = 'Pull the rope toward your face with elbows flared out, targeting the rear delts and upper back to improve posture.' where name_en = 'Face Pull';
update public.exercises set instructions_en = 'Lying down with a slight elbow bend, arc the dumbbells open until the chest stretches, then bring them back together.' where name_en = 'Chest Fly';
update public.exercises set instructions_en = 'Rear foot elevated on a bench, front leg squats down until the thigh is parallel to the floor, torso upright throughout.' where name_en = 'Bulgarian Split Squat';
update public.exercises set instructions_en = 'Hold a dumbbell at chest height with both hands, squat down letting the elbows brush the inside of the knees. Great for learning the squat pattern.' where name_en = 'Goblet Squat';
update public.exercises set instructions_en = 'Forearms on the floor, body in a straight line, brace the abs and glutes to avoid sagging at the hips.' where name_en = 'Plank';
update public.exercises set instructions_en = 'Hang from a pull-up bar and raise the legs with control above horizontal, avoiding any swinging.' where name_en = 'Hanging Leg Raise';

update public.exercises set instructions_en = 'Set the bench to 30-45 degrees. Lower the dumbbells to the sides of the chest, avoiding clanging them together on the press.' where name_en = 'Incline Dumbbell Press';
update public.exercises set instructions_en = 'Adjust the seat so the handles align with mid-chest, keep the shoulder blades pinned as you press.' where name_en = 'Machine Chest Press';
update public.exercises set instructions_en = 'Set the pulleys to shoulder height, keep a slight elbow bend, and bring your hands together in front for a peak chest contraction.' where name_en = 'Cable Fly';
update public.exercises set instructions_en = 'Keep the body in a straight line, lower until the chest nearly touches the floor, and brace the core to avoid sagging the lower back.' where name_en = 'Push-up';
update public.exercises set instructions_en = 'Forearms against the pads, slight elbow bend, slowly bring the arms together for a peak contraction, then control the return.' where name_en = 'Pec Deck';

update public.exercises set instructions_en = 'One hand and knee on the bench, keep the back flat, and row the dumbbell toward your hip, squeezing the shoulder blade at the top.' where name_en = 'Single-Arm Dumbbell Row';
update public.exercises set instructions_en = 'Hinge forward with a flat back, pull the bar toward the lower chest, avoiding shrugging to cheat the weight up.' where name_en = 'T-Bar Row';
update public.exercises set instructions_en = 'Chest pressed against the incline bench, row the dumbbells up while retracting the shoulder blades, eliminating any lower-body momentum.' where name_en = 'Chest-Supported Row';
update public.exercises set instructions_en = 'Keep the arms mostly straight, hinge at the shoulder to pull the bar down to the front of the thighs, feeling the lats engage.' where name_en = 'Straight-Arm Pulldown';
update public.exercises set instructions_en = 'Underhand grip about shoulder-width, pull up until your chin clears the bar; this variation recruits more of the biceps.' where name_en = 'Chin-up';

update public.exercises set instructions_en = 'Start with palms facing you, and rotate your wrists to face forward as you press overhead.' where name_en = 'Arnold Press';
update public.exercises set instructions_en = 'Hinge forward with a flat back, slight elbow bend, and raise the dumbbells out to shoulder height, focusing on the rear delts.' where name_en = 'Rear Delt Fly';
update public.exercises set instructions_en = 'Hold the bar with arms hanging naturally, shrug the shoulders up toward your ears, pausing briefly at the top.' where name_en = 'Barbell Shrug';
update public.exercises set instructions_en = 'Adjust the seat so the handles are level with the shoulders, press until the arms are nearly straight without locking out.' where name_en = 'Machine Shoulder Press';

update public.exercises set instructions_en = 'Back against the pad, feet slightly forward, squat until the thighs go below horizontal, letting the knees track with the toes.' where name_en = 'Hack Squat';
update public.exercises set instructions_en = 'Holding dumbbells, step forward and lower until both knees reach about 90 degrees, alternating legs while keeping the torso upright.' where name_en = 'Walking Lunge';
update public.exercises set instructions_en = 'Bar racked on the upper back, feet slightly forward, follow the fixed bar path down while keeping the knees from caving inward.' where name_en = 'Smith Machine Squat';

update public.exercises set instructions_en = 'Sit back firmly against the pad and curl the roller toward the back of your calves, squeezing at the top before releasing slowly.' where name_en = 'Seated Leg Curl';
update public.exercises set instructions_en = 'Bar on the upper back, slight knee bend, hinge the hips back until the torso is near horizontal, keeping the core braced.' where name_en = 'Good Morning';

update public.exercises set instructions_en = 'Legs pressed against the pads, open them outward to the maximum range, pause briefly at the top, and control the return.' where name_en = 'Hip Abductor Machine';
update public.exercises set instructions_en = 'Strap the cable to your ankle, brace yourself on the support, and kick back and up, squeezing the glutes at the top.' where name_en = 'Cable Kickback';

update public.exercises set instructions_en = 'Keep the upper arms fixed at your sides, curl up to shoulder level, and control the eccentric instead of swinging the weight.' where name_en = 'Barbell Curl';
update public.exercises set instructions_en = 'Rest the upper arms against the preacher pad, lower until the arms are nearly straight without locking out completely.' where name_en = 'Preacher Curl';
update public.exercises set instructions_en = 'Keep the upper arms fixed, maintain tension on the cable throughout, and squeeze the biceps at the top.' where name_en = 'Cable Curl';

update public.exercises set instructions_en = 'Lying down holding the bar, bend only at the elbows to lower it near your forehead, keeping the upper arms still throughout.' where name_en = 'Skullcrusher';
update public.exercises set instructions_en = 'Grip about shoulder-width, keep the elbows tucked close to your body on the way down, and focus on driving through the triceps as you press.' where name_en = 'Close-Grip Bench Press';
update public.exercises set instructions_en = 'Face away from the pulley, hold the rope overhead with both hands, bend the elbows to lower behind the head, then extend back up while keeping the upper arms fixed.' where name_en = 'Overhead Cable Extension';

update public.exercises set instructions_en = 'Balls of the feet planted firmly, rise to the highest point of the calf raise, then lower slowly for a full stretch.' where name_en = 'Seated Calf Raise';

update public.exercises set instructions_en = 'Kneel and hold the rope beside your head, curl the spine to bring your torso down, without pulling with the arms.' where name_en = 'Cable Crunch';
update public.exercises set instructions_en = 'From a kneeling position, roll the wheel out until the body is nearly horizontal, keeping the core braced throughout to avoid sagging the lower back.' where name_en = 'Ab Wheel Rollout';
update public.exercises set instructions_en = 'Lean back with feet off the floor, hold a weight and rotate side to side with control.' where name_en = 'Russian Twist';
update public.exercises set instructions_en = 'Support on one forearm with the body in a straight line, keep the hips from sagging, and repeat on the other side.' where name_en = 'Side Plank';
update public.exercises set instructions_en = 'Lying on your back, slowly extend the opposite arm and leg together, keeping your lower back pressed to the floor throughout.' where name_en = 'Dead Bug';
