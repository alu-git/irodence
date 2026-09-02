-- ============================================================================
-- Irodence Safety & Moderation Migration (Gate A)
-- Reference: IRODENCE_SAFETY.md
-- ============================================================================

-- 1. Blocked Users Table (Section 4: One-tap block)
CREATE TABLE IF NOT EXISTS public.blocked_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(blocker_id, blocked_id)
);

ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own blocks"
ON public.blocked_users
FOR ALL
USING (auth.uid() = blocker_id)
WITH CHECK (auth.uid() = blocker_id);

-- 2. Moderation Reports Table (Section 4 & 5: Prioritized Human Review Queue)
CREATE TABLE IF NOT EXISTS public.moderation_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    target_proof_id UUID REFERENCES public.proofs(id) ON DELETE CASCADE,
    target_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reason TEXT NOT NULL CHECK (reason IN ('harassment', 'cheating', 'injury', 'minor', 'inappropriate')),
    priority TEXT NOT NULL CHECK (priority IN ('high', 'urgent', 'normal')),
    details TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'under_review', 'resolved', 'dismissed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at TIMESTAMPTZ
);

ALTER TABLE public.moderation_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can submit reports"
ON public.moderation_reports
FOR INSERT
WITH CHECK (auth.uid() = reporter_id);

CREATE POLICY "Users can read own submitted reports"
ON public.moderation_reports
FOR SELECT
USING (auth.uid() = reporter_id);

-- 3. Proofs Table Extensions (Section 2 & 3: Crew Only default & Status)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'proof_visibility') THEN
        CREATE TYPE proof_visibility AS ENUM ('crew_only', 'public');
    END IF;
END$$;

ALTER TABLE public.proofs 
ADD COLUMN IF NOT EXISTS visibility proof_visibility NOT NULL DEFAULT 'crew_only',
ADD COLUMN IF NOT EXISTS moderation_status TEXT NOT NULL DEFAULT 'approved';

-- 4. RLS for Proofs: Block Filter & Visibility Enforcement (Section 2 & 4)
DROP POLICY IF EXISTS "Proofs select policy" ON public.proofs;
CREATE POLICY "Proofs select policy"
ON public.proofs
FOR SELECT
USING (
    -- 1. Must not be blocked by viewer, and author has not blocked viewer
    NOT EXISTS (
        SELECT 1 FROM public.blocked_users 
        WHERE (blocker_id = auth.uid() AND blocked_id = proofs.user_id)
           OR (blocker_id = proofs.user_id AND blocked_id = auth.uid())
    )
    AND (
        -- 2. Author can always see their own proofs
        proofs.user_id = auth.uid()
        -- 3. Public proofs are visible to all non-blocked users
        OR (proofs.visibility = 'public' AND proofs.moderation_status = 'approved')
        -- 4. Crew-only proofs are visible only to fellow crew members
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

-- 5. Witnesses Anti-Collusion & Integrity Constraints (Section 3)
-- Rule: Max 1 witness per lifter per 30 days
CREATE OR REPLACE FUNCTION public.check_witness_eligibility()
RETURNS TRIGGER AS $$
DECLARE
    lifter_user_id UUID;
    last_witnessed TIMESTAMPTZ;
BEGIN
    SELECT user_id INTO lifter_user_id FROM public.proofs WHERE id = NEW.proof_id;

    -- Cannot witness self
    IF NEW.witness_id = lifter_user_id THEN
        RAISE EXCEPTION 'A lifter cannot witness their own proof.';
    END IF;

    -- Check 30-day throttle between witness and lifter
    SELECT MAX(w.created_at) INTO last_witnessed
    FROM public.witnesses w
    JOIN public.proofs p ON w.proof_id = p.id
    WHERE w.witness_id = NEW.witness_id AND p.user_id = lifter_user_id;

    IF last_witnessed IS NOT NULL AND last_witnessed > (now() - INTERVAL '30 days') THEN
        RAISE EXCEPTION 'You have already witnessed this lifter in the past 30 days.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_witness_throttle ON public.witnesses;
CREATE TRIGGER trg_witness_throttle
BEFORE INSERT ON public.witnesses
FOR EACH ROW
EXECUTE FUNCTION public.check_witness_eligibility();

-- 6. Two-Flag Freeze Trigger (Section 3)
CREATE OR REPLACE FUNCTION public.handle_witness_action()
RETURNS TRIGGER AS $$
DECLARE
    total_confirms INT;
    total_flags INT;
BEGIN
    SELECT COUNT(*) INTO total_confirms FROM public.witnesses WHERE proof_id = NEW.proof_id AND action = 'confirm';
    SELECT COUNT(*) INTO total_flags FROM public.witnesses WHERE proof_id = NEW.proof_id AND action = 'flag';

    IF total_flags >= 2 THEN
        UPDATE public.proofs 
        SET status = 'under_review', is_certified = false, flag_count = total_flags, confirm_count = total_confirms
        WHERE id = NEW.proof_id;
    ELSIF total_confirms >= 3 AND total_flags < 2 THEN
        UPDATE public.proofs 
        SET status = 'certified', is_certified = true, certified_at = now(), confirm_count = total_confirms, flag_count = total_flags
        WHERE id = NEW.proof_id;
    ELSE
        UPDATE public.proofs 
        SET confirm_count = total_confirms, flag_count = total_flags
        WHERE id = NEW.proof_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_witness_count ON public.witnesses;
CREATE TRIGGER trg_witness_count
AFTER INSERT ON public.witnesses
FOR EACH ROW
EXECUTE FUNCTION public.handle_witness_action();
