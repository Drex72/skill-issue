-- ============================================================
-- Skill Issue: migration 0007_login_unblock
-- Login was still failing with "already paired". Root cause: the
-- old pairing flow let BOTH partners insert their own direction,
-- leaving mirror rows (a,b) and (b,a). Moving one during account
-- adoption made the guard see the mirror as a second pair.
--
-- This migration:
--   1. deletes mirror duplicates everywhere (keeps the accepted
--      one; if both match, keeps the a < b row)
--   2. rewrites sk_login so pair moves dedupe first and can never
--      block a login even if the data is weird
-- ============================================================

-- 1) one-time global cleanup of mirror rows
delete from sk_pairs p
using sk_pairs q
where p.a = q.b and p.b = q.a
  and (case
         when p.status = q.status then p.a > p.b
         else p.status <> 'accepted'
       end);

-- 2) login that cannot be blocked by pair rows
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

  -- pairs: dedupe mirrors touching this account, then move.
  -- wrapped so pair weirdness can NEVER block a login.
  begin
    delete from sk_pairs p
    using sk_pairs q
    where p.a = q.b and p.b = q.a
      and (p.a = old_id or p.b = old_id)
      and (case
             when p.status = q.status then p.a > p.b
             else p.status <> 'accepted'
           end);
    update sk_pairs set a = new_id where a = old_id;
    update sk_pairs set b = new_id where b = old_id;
  exception when others then
    -- drop unmovable pair rows rather than fail the login
    begin
      delete from sk_pairs where a = old_id or b = old_id;
    exception when others then null;
    end;
  end;

  delete from sk_profiles where id = old_id;
  update sk_profiles set username = p_username where id = new_id;

  return json_build_object('status','adopted');
end;
$$;

grant execute on function sk_login(text) to authenticated;
