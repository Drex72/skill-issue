-- ============================================================
-- Skill Issue: migration 0004_pair_requests
-- Pairing becomes consent-based: requester creates a pending row,
-- the receiver accepts or declines. Existing pairs stay accepted.
-- ============================================================

alter table sk_pairs add column if not exists status text not null default 'accepted';

-- data visibility now requires an ACCEPTED pair
create or replace function sk_paired_with(u uuid) returns boolean
language sql stable security definer as $$
  select exists(
    select 1 from sk_pairs
    where ((a = auth.uid() and b = u) or (b = auth.uid() and a = u))
      and status = 'accepted'
  );
$$;

-- receiver can accept (update) a request addressed to them
create policy "sk_pairs accept" on sk_pairs for update to authenticated using (auth.uid() = b);

-- realtime so requests and acceptances arrive live
alter publication supabase_realtime add table sk_pairs;
