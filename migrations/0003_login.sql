-- ============================================================
-- Skill Issue: migration 0003_login
-- Lets the same username "log in" from a new device or browser
-- by adopting the existing account into the new anonymous session.
--
-- HONEST WARNING: with no passcode, anyone who knows a username can
-- claim that account. Acceptable for two friends; the planned fix is
-- a passcode column checked inside this same function.
-- ============================================================

create or replace function sk_login(p_username text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  old_id uuid;
  new_id uuid := auth.uid();
begin
  if new_id is null then
    raise exception 'not signed in';
  end if;

  select id into old_id from sk_profiles where username = p_username;

  if old_id is null then
    return json_build_object('status','new');
  end if;

  if old_id = new_id then
    return json_build_object('status','ok');
  end if;

  -- adopt: move the whole account to the new auth identity
  insert into sk_profiles(id, username, display, tz)
    select new_id, username || '#migrating', display, tz
    from sk_profiles where id = old_id;

  update sk_categories set user_id = new_id where user_id = old_id;
  update sk_items      set user_id = new_id where user_id = old_id;
  update sk_pings      set from_id = new_id where from_id = old_id;
  update sk_pings      set to_id   = new_id where to_id   = old_id;
  update sk_proofs     set from_id = new_id where from_id = old_id;
  update sk_proofs     set to_id   = new_id where to_id   = old_id;
  update sk_pairs      set a = new_id where a = old_id;
  update sk_pairs      set b = new_id where b = old_id;

  delete from sk_profiles where id = old_id;
  update sk_profiles set username = p_username where id = new_id;

  return json_build_object('status','adopted');
end;
$$;

grant execute on function sk_login(text) to authenticated;
