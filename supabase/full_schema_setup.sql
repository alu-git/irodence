-- ============================================================================
-- 铁证 / Irodence — Master Supabase Backend Schema & Migration
-- Project URL: https://bbdhdybcyntwdftahgce.supabase.co
-- Run this in the Supabase SQL Editor to set up all tables, RLS, & triggers.
-- ============================================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 1. Profiles & Users
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL DEFAULT '铁友',
    avatar_url TEXT,
    sex TEXT CHECK (sex IN ('male', 'female', 'other')),
    bodyweight_kg NUMERIC(5, 2),
    height_cm NUMERIC(5, 1),
    age_years INT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public profiles are viewable by everyone" 
ON public.profiles FOR SELECT USING (true);

CREATE POLICY "Users can insert their own profile" 
ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile" 
ON public.profiles FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can delete their own profile" 
ON public.profiles FOR DELETE USING (auth.uid() = id);

-- Trigger on user creation in auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, display_name)
    VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'display_name', '铁友'))
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- 2. Exercises Bank
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name_zh TEXT NOT NULL,
    name_en TEXT NOT NULL,
    primary_muscle TEXT NOT NULL,
    secondary_muscles TEXT[] DEFAULT '{}',
    equipment TEXT NOT NULL,
    is_compound BOOLEAN NOT NULL DEFAULT false,
    instructions_zh TEXT,
    instructions_en TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.exercises ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Exercises are viewable by everyone" 
ON public.exercises FOR SELECT USING (true);

-- ============================================================================
-- 3. Workouts, Exercises & Sets
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.workouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL DEFAULT '自由训练',
    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.workouts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own workouts" 
ON public.workouts FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS public.workout_exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workout_id UUID NOT NULL REFERENCES public.workouts(id) ON DELETE CASCADE,
    exercise_id UUID NOT NULL REFERENCES public.exercises(id) ON DELETE CASCADE,
    order_index INT NOT NULL DEFAULT 0,
    superset_group INT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.workout_exercises ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage exercises in their workouts" 
ON public.workout_exercises FOR ALL 
USING (EXISTS (SELECT 1 FROM public.workouts WHERE id = workout_id AND user_id = auth.uid()))
WITH CHECK (EXISTS (SELECT 1 FROM public.workouts WHERE id = workout_id AND user_id = auth.uid()));

CREATE TABLE IF NOT EXISTS public.workout_sets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workout_exercise_id UUID NOT NULL REFERENCES public.workout_exercises(id) ON DELETE CASCADE,
    set_index INT NOT NULL DEFAULT 1,
    weight_kg NUMERIC(6, 2) NOT NULL DEFAULT 0,
    reps INT NOT NULL DEFAULT 0,
    rpe NUMERIC(3, 1),
    is_warmup BOOLEAN NOT NULL DEFAULT false,
    is_completed BOOLEAN NOT NULL DEFAULT false,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.workout_sets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage sets in their workouts" 
ON public.workout_sets FOR ALL 
USING (
    EXISTS (
        SELECT 1 FROM public.workout_exercises we
        JOIN public.workouts w ON we.workout_id = w.id
        WHERE we.id = workout_exercise_id AND w.user_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.workout_exercises we
        JOIN public.workouts w ON we.workout_id = w.id
        WHERE we.id = workout_exercise_id AND w.user_id = auth.uid()
    )
);

-- ============================================================================
-- 4. Proofs (证词) & Witnessing (见证) — Gate A Safe
-- ============================================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'proof_visibility') THEN
        CREATE TYPE proof_visibility AS ENUM ('crew_only', 'public');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'proof_status') THEN
        CREATE TYPE proof_status AS ENUM ('pending', 'certified', 'under_review', 'rejected');
    END IF;
END$$;

CREATE TABLE IF NOT EXISTS public.proofs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    exercise_id UUID NOT NULL REFERENCES public.exercises(id) ON DELETE CASCADE,
    weight_kg NUMERIC(6, 2) NOT NULL,
    reps INT NOT NULL DEFAULT 1,
    estimated_1rm NUMERIC(6, 2) NOT NULL,
    dots_score NUMERIC(6, 2) NOT NULL DEFAULT 0,
    tier TEXT NOT NULL DEFAULT 'pig_iron',
    video_url TEXT,
    notes TEXT,
    status proof_status NOT NULL DEFAULT 'pending',
    is_certified BOOLEAN NOT NULL DEFAULT false,
    certified_at TIMESTAMPTZ,
    confirm_count INT NOT NULL DEFAULT 0,
    flag_count INT NOT NULL DEFAULT 0,
    visibility proof_visibility NOT NULL DEFAULT 'crew_only',
    moderation_status TEXT NOT NULL DEFAULT 'approved',
    achieved_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.proofs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Proofs insert policy"
ON public.proofs FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Proofs update policy"
ON public.proofs FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Proofs delete policy"
ON public.proofs FOR DELETE
USING (auth.uid() = user_id);

-- Witnesses table
CREATE TABLE IF NOT EXISTS public.witnesses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    proof_id UUID NOT NULL REFERENCES public.proofs(id) ON DELETE CASCADE,
    witness_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    action TEXT NOT NULL CHECK (action IN ('confirm', 'flag')),
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(proof_id, witness_id)
);

ALTER TABLE public.witnesses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Witnesses insert policy"
ON public.witnesses FOR INSERT
WITH CHECK (auth.uid() = witness_id);

CREATE POLICY "Witnesses select policy"
ON public.witnesses FOR SELECT
USING (true);

-- ============================================================================
-- 5. Crews (熔炉) & Crew Heat (炉温)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.crews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    avatar_url TEXT,
    created_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    weekly_heat_target INT NOT NULL DEFAULT 1000,
    member_count INT NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.crews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Crews are viewable by all logged in users"
ON public.crews FOR SELECT USING (true);

CREATE POLICY "Crews can be created by authenticated users"
ON public.crews FOR INSERT WITH CHECK (auth.uid() = created_by);

CREATE TABLE IF NOT EXISTS public.crew_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    crew_id UUID NOT NULL REFERENCES public.crews(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('captain', 'leader', 'member')),
    strikes_count INT NOT NULL DEFAULT 0,
    last_active_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(crew_id, user_id)
);

ALTER TABLE public.crew_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Crew members are viewable by everyone"
ON public.crew_members FOR SELECT USING (true);

CREATE POLICY "Users can join a crew"
ON public.crew_members FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can leave a crew"
ON public.crew_members FOR DELETE USING (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS public.crew_heat (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    crew_id UUID NOT NULL REFERENCES public.crews(id) ON DELETE CASCADE,
    week_start DATE NOT NULL,
    total_heat INT NOT NULL DEFAULT 0,
    target_heat INT NOT NULL DEFAULT 1000,
    is_quenched BOOLEAN NOT NULL DEFAULT false,
    quenched_at TIMESTAMPTZ,
    UNIQUE(crew_id, week_start)
);

ALTER TABLE public.crew_heat ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Crew heat viewable by everyone"
ON public.crew_heat FOR SELECT USING (true);

-- ============================================================================
-- 6. Safety & Moderation (Gate A: Blocks & Reports)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.blocked_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(blocker_id, blocked_id)
);

ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own blocks"
ON public.blocked_users FOR ALL
USING (auth.uid() = blocker_id) WITH CHECK (auth.uid() = blocker_id);

CREATE TABLE IF NOT EXISTS public.moderation_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    target_proof_id UUID REFERENCES public.proofs(id) ON DELETE CASCADE,
    target_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    reason TEXT NOT NULL CHECK (reason IN ('harassment', 'cheating', 'injury', 'minor', 'inappropriate')),
    priority TEXT NOT NULL CHECK (priority IN ('high', 'urgent', 'normal')),
    details TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'under_review', 'resolved', 'dismissed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at TIMESTAMPTZ
);

ALTER TABLE public.moderation_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users submit reports"
ON public.moderation_reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);

CREATE POLICY "Users view own reports"
ON public.moderation_reports FOR SELECT USING (auth.uid() = reporter_id);

-- Proofs visibility & block policy
CREATE POLICY "Proofs select policy"
ON public.proofs FOR SELECT
USING (
    NOT EXISTS (
        SELECT 1 FROM public.blocked_users 
        WHERE (blocker_id = auth.uid() AND blocked_id = proofs.user_id)
           OR (blocker_id = proofs.user_id AND blocked_id = auth.uid())
    )
    AND (
        proofs.user_id = auth.uid()
        OR (proofs.visibility = 'public' AND proofs.moderation_status = 'approved')
        OR (
            proofs.visibility = 'crew_only' 
            AND EXISTS (
                SELECT 1 FROM public.crew_members cm1
                JOIN public.crew_members cm2 ON cm1.crew_id = cm2.crew_id
                WHERE cm1.user_id = auth.uid() AND cm2.user_id = proofs.user_id
            )
        )
    )
);

-- ============================================================================
-- 7. Challenges (比武) & Social
-- ============================================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'challenge_status') THEN
        CREATE TYPE challenge_status AS ENUM ('pending', 'active', 'completed', 'declined');
    END IF;
END$$;

CREATE TABLE IF NOT EXISTS public.challenges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    challenger_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    challenged_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    exercise_id UUID REFERENCES public.exercises(id) ON DELETE SET NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    challenger_baseline NUMERIC(6, 2) NOT NULL DEFAULT 0,
    challenged_baseline NUMERIC(6, 2) NOT NULL DEFAULT 0,
    challenger_gain NUMERIC(6, 2) NOT NULL DEFAULT 0,
    challenged_gain NUMERIC(6, 2) NOT NULL DEFAULT 0,
    status challenge_status NOT NULL DEFAULT 'pending',
    winner_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.challenges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Challenges viewable by involved users"
ON public.challenges FOR SELECT
USING (auth.uid() = challenger_id OR auth.uid() = challenged_id);

CREATE POLICY "Users create challenges"
ON public.challenges FOR INSERT
WITH CHECK (auth.uid() = challenger_id);

CREATE POLICY "Users respond to challenges"
ON public.challenges FOR UPDATE
USING (auth.uid() = challenger_id OR auth.uid() = challenged_id);

-- ============================================================================
-- 8. Storage Buckets (Photos & Proof Videos)
-- ============================================================================
INSERT INTO storage.buckets (id, name, public)
VALUES 
    ('workout_photos', 'workout_photos', true),
    ('progress_photos', 'progress_photos', false),
    ('proof_videos', 'proof_videos', false)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Public Workout Photos Access"
ON storage.objects FOR SELECT
USING (bucket_id = 'workout_photos');

CREATE POLICY "Users upload own workout photos"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'workout_photos' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users upload own progress photos"
ON storage.objects FOR ALL
USING (bucket_id = 'progress_photos' AND auth.uid()::text = (storage.foldername(name))[1])
WITH CHECK (bucket_id = 'progress_photos' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users upload own proof videos"
ON storage.objects FOR ALL
USING (bucket_id = 'proof_videos' AND auth.uid()::text = (storage.foldername(name))[1])
WITH CHECK (bucket_id = 'proof_videos' AND auth.uid()::text = (storage.foldername(name))[1]);
