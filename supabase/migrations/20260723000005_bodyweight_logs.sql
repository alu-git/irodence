-- ============================================================================
-- Step 6: bodyweight log — dated entries feed the DOTS calculation.
-- profiles.bodyweight_kg stays as the "current" cached value; the client
-- syncs it from the newest log entry on each insert.
-- ============================================================================

create table public.bodyweight_logs (
    id          uuid primary key default gen_random_uuid(),
    user_id     uuid not null references public.profiles (id) on delete cascade,
    weight_kg   numeric(5,2) not null check (weight_kg > 0 and weight_kg < 500),
    logged_at   timestamptz not null default now(),
    created_at  timestamptz not null default now()
);

create index bodyweight_logs_user_date_idx
    on public.bodyweight_logs (user_id, logged_at desc);

alter table public.bodyweight_logs enable row level security;

create policy "users can view their own bodyweight logs"
    on public.bodyweight_logs for select
    to authenticated
    using (auth.uid() = user_id);

create policy "users can insert their own bodyweight logs"
    on public.bodyweight_logs for insert
    to authenticated
    with check (auth.uid() = user_id);

create policy "users can delete their own bodyweight logs"
    on public.bodyweight_logs for delete
    to authenticated
    using (auth.uid() = user_id);

-- No update policy: a wrong entry is deleted and re-logged, keeping the
-- series append-only (cleaner for charting and DOTS history).
