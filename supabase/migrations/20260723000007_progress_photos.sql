-- ============================================================================
-- Step 8: progress photos.
-- Metadata rows live in public.progress_photos; the images themselves live
-- in a PRIVATE storage bucket 'progress-photos', one folder per user
-- (<user_id>/<uuid>.jpg). Clients fetch time-limited signed URLs to view.
-- ============================================================================

create table public.progress_photos (
    id           uuid primary key default gen_random_uuid(),
    user_id      uuid not null references public.profiles (id) on delete cascade,
    storage_path text not null,            -- e.g. '<user_id>/<uuid>.jpg'
    note         text,
    taken_at     timestamptz not null default now(),
    created_at   timestamptz not null default now()
);

create index progress_photos_user_idx
    on public.progress_photos (user_id, taken_at desc);

alter table public.progress_photos enable row level security;

create policy "users can view their own progress photos"
    on public.progress_photos for select
    to authenticated
    using (auth.uid() = user_id);

create policy "users can add their own progress photos"
    on public.progress_photos for insert
    to authenticated
    with check (auth.uid() = user_id);

create policy "users can delete their own progress photos"
    on public.progress_photos for delete
    to authenticated
    using (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- Storage: private bucket + per-user folder isolation.
-- storage.foldername(name)[1] is the first path segment, which we require to
-- be the owner's uid both on write and on read.
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('progress-photos', 'progress-photos', false)
on conflict (id) do nothing;

create policy "users can read their own photo objects"
    on storage.objects for select
    to authenticated
    using (
        bucket_id = 'progress-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

create policy "users can upload their own photo objects"
    on storage.objects for insert
    to authenticated
    with check (
        bucket_id = 'progress-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
    );

create policy "users can delete their own photo objects"
    on storage.objects for delete
    to authenticated
    using (
        bucket_id = 'progress-photos'
        and (storage.foldername(name))[1] = auth.uid()::text
    );
