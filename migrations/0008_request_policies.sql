-- ============================================================
-- Skill Issue: migration 0008_request_policies
-- Requesters can manage (resend/cancel) their own requests, and
-- both participants can delete a pair row. Fixes "could not send
-- the request" when a stale request already existed: the resend
-- path deletes then re-inserts, which needs these policies.
-- ============================================================

drop policy if exists "sk_pairs requester manage" on sk_pairs;
create policy "sk_pairs requester manage" on sk_pairs
  for update to authenticated using (auth.uid() = a);

drop policy if exists "sk_pairs participant delete" on sk_pairs;
create policy "sk_pairs participant delete" on sk_pairs
  for delete to authenticated using (auth.uid() = a or auth.uid() = b);
