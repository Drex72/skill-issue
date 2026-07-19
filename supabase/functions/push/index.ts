// Skill Issue push sender. Wire this to Database Webhooks on:
//   sk_pings  INSERT
//   sk_pairs  INSERT and UPDATE
// Secrets required: VAPID_PUBLIC, VAPID_PRIVATE, SB_URL, SB_SERVICE_KEY
import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";

const sb = createClient(Deno.env.get("SB_URL")!, Deno.env.get("SB_SERVICE_KEY")!);
webpush.setVapidDetails("mailto:davidokunoye003@gmail.com",
  Deno.env.get("VAPID_PUBLIC")!, Deno.env.get("VAPID_PRIVATE")!);

async function nameOf(id: string) {
  const { data } = await sb.from("sk_profiles").select("display").eq("id", id).maybeSingle();
  return data?.display ?? "Your partner";
}

Deno.serve(async (req) => {
  const hook = await req.json();
  const row = hook.record;
  let to = "", title = "Skill Issue 💀", body = "", tag = "sk";

  if (hook.table === "sk_pings" && hook.type === "INSERT") {
    to = row.to_id; tag = "ping-" + row.id;
    const from = await nameOf(row.from_id);
    let task = "your task";
    if (row.item_id) {
      const { data: it } = await sb.from("sk_items").select("text").eq("id", row.item_id).maybeSingle();
      if (it?.text) task = '"' + it.text + '"';
    }
    body = from + ": " + task + (row.msg ? " - " + row.msg : "");
  } else if (hook.table === "sk_pairs" && hook.type === "INSERT" && row.status === "pending") {
    to = row.b; tag = "pair-" + row.a;
    body = (await nameOf(row.a)) + " wants to pair with you 🤝";
  } else if (hook.table === "sk_pairs" && hook.type === "UPDATE" && row.status === "accepted") {
    to = row.a; tag = "pair-ok-" + row.b;
    body = (await nameOf(row.b)) + " accepted. You are locked in 🔒";
  } else {
    return new Response("ignored", { status: 200 });
  }

  const { data: subs } = await sb.from("sk_push_subs").select("*").eq("user_id", to);
  const payload = JSON.stringify({ title, body, tag });
  let sent = 0;
  for (const s of subs ?? []) {
    try {
      await webpush.sendNotification(
        { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, payload);
      sent++;
    } catch (e) {
      if (e?.statusCode === 404 || e?.statusCode === 410)
        await sb.from("sk_push_subs").delete().eq("endpoint", s.endpoint);
    }
  }
  return new Response(JSON.stringify({ sent }), { status: 200 });
});
