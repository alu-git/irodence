-- Add English instructions field to exercises table
alter table public.exercises
    add column instructions_en text;

-- Rename existing instructions to instructions_zh for clarity
alter table public.exercises
    rename column instructions to instructions_zh;

comment on column public.exercises.instructions_zh is 'Exercise instructions in Chinese';
comment on column public.exercises.instructions_en is 'Exercise instructions in English';
