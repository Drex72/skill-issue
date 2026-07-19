-- ============================================================
-- Skill Issue: migration 0006_fix_pair_guard
-- Fixes login breaking with already paired: sk_login adopts an
-- account by MOVING its pair row to the new session id. The 0005
-- guard saw the rows own old values as a conflicting pair and
-- rejected the move. An UPDATE now ignores the row it is itself
-- modifying.
-- ============================================================

create or replace function sk_pair_guard() returns trigger
language plpgsql security definer as $$
begin
  if exists (
    select 1 from sk_pairs p
    where p.status = 'accepted'
      and (p.a in (new.a, new.b) or p.b in (new.a, new.b))
      and not (p.a = new.a and p.b = new.b)
      and (tg_op = 'INSERT' or not (p.a = old.a and p.b = old.b))
  ) then
    raise exception 'already paired';
  end if;
  return new;
end;
$$;
