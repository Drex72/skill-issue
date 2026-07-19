-- ============================================================
-- Skill Issue: migration 0005_one_pair
-- A person can be in at most one pair (pending or accepted).
-- Blocks requests to people who are already locked in.
-- ============================================================

create or replace function sk_pair_guard() returns trigger
language plpgsql security definer as $$
begin
  if exists (
    select 1 from sk_pairs
    where status = 'accepted'
      and (a in (new.a, new.b) or b in (new.a, new.b))
      and not (a = new.a and b = new.b)
  ) then
    raise exception 'already paired';
  end if;
  return new;
end;
$$;

drop trigger if exists sk_pair_guard_t on sk_pairs;
create trigger sk_pair_guard_t
  before insert or update on sk_pairs
  for each row execute function sk_pair_guard();
