-- ============================================================
-- Skill Issue: migration 0009_push_subs
-- Stores Web Push subscriptions per device so a Supabase Edge
-- Function can notify users while the app is closed.
-- ============================================================

create table if not exists sk_push_subs (
  endpoint text primary key,
  user_id uuid not null,
  p256dh text not null,
  auth text not null,
  created_at timestamptz not null default now()
);

alter table sk_push_subs enable row level security;

drop policy if exists "sk_push_subs own" on sk_push_subs;
create policy "sk_push_subs own" on sk_push_subs
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
