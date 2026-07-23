-- ============================================================================
-- Step 3: workout templates ("start from a template").
-- A template is an ordered list of exercises (+ superset grouping); sets are
-- NOT stored on templates — starting from a template pre-fills 3 empty sets
-- per exercise, and previous-session values appear as placeholders anyway.
-- ============================================================================

create table public.workout_templates (
    id          uuid primary key default gen_random_uuid(),
    user_id     uuid not null references public.profiles (id) on delete cascade,
    name        text not null,
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now()
);

alter table public.workout_templates enable row level security;

create policy "users can view their own templates"
    on public.workout_templates for select
    to authenticated
    using (auth.uid() = user_id);

create policy "users can create their own templates"
    on public.workout_templates for insert
    to authenticated
    with check (auth.uid() = user_id);

create policy "users can update their own templates"
    on public.workout_templates for update
    to authenticated
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

create policy "users can delete their own templates"
    on public.workout_templates for delete
    to authenticated
    using (auth.uid() = user_id);

create table public.workout_template_exercises (
    id              uuid primary key default gen_random_uuid(),
    template_id     uuid not null references public.workout_templates (id) on delete cascade,
    exercise_id     uuid not null references public.exercises (id),
    order_index     integer not null,
    superset_group  integer,
    created_at      timestamptz not null default now(),

    unique (template_id, order_index)
);

alter table public.workout_template_exercises enable row level security;

create policy "users can view exercises in their own templates"
    on public.workout_template_exercises for select
    to authenticated
    using (exists (
        select 1 from public.workout_templates t
        where t.id = template_id and t.user_id = auth.uid()
    ));

create policy "users can add exercises to their own templates"
    on public.workout_template_exercises for insert
    to authenticated
    with check (exists (
        select 1 from public.workout_templates t
        where t.id = template_id and t.user_id = auth.uid()
    ));

create policy "users can delete exercises from their own templates"
    on public.workout_template_exercises for delete
    to authenticated
    using (exists (
        select 1 from public.workout_templates t
        where t.id = template_id and t.user_id = auth.uid()
    ));
