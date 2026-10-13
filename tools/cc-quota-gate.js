// Command Code quota gate for OpenClaw automation triggers.
// Runs cc-quota --gate before the automation fires:
//   allow -> job runs; the fired message carries current quota levels
//   block -> job skips this slot (no run created), state records why
// Fails OPEN: if the quota API is unreachable or unparseable, the job runs.
// NOTE: yieldMs is required — trigger exec is non-blocking by default and
// would otherwise return status:"running" with no output.
const r = await exec({ command: '/root/.openclaw/workspace/tools/cc-quota --gate', yieldMs: 20000 });
const out = String(r?.aggregated ?? '').trim();
const line = out.split('\n').filter((l) => l.trim().startsWith('{')).pop();
let q = null;
try { q = JSON.parse(line); } catch {}

if (!q || !q.decision || !q.five_hour || !q.weekly || !q.monthly) {
  json({
    fire: true,
    message: 'Quota gate: result unreadable — proceeding, but keep the run lean and do not escalate to paid models.',
    state: { lastCheck: Date.now(), decision: 'unknown', raw: out.slice(0, 300) },
  });
} else {
  const snap = `5h $${(+q.five_hour.used).toFixed(2)}/$${q.five_hour.cap}, weekly $${(+q.weekly.used).toFixed(2)}/$${q.weekly.cap}, monthly $${(+q.monthly.used).toFixed(2)}/$${q.monthly.cap}`;
  json({
    fire: q.decision === 'allow',
    message: q.decision === 'allow'
      ? `Command Code quota at run start: ${snap}. Free models ($0) do NOT draw from this — stay on the pinned free model; only fall back if it errors.`
      : '',
    state: {
      lastCheck: Date.now(),
      decision: q.decision,
      reason: q.reason,
      weeklyUsed: q.weekly.used,
      weeklyCap: q.weekly.cap,
      monthlyUsed: q.monthly.used,
      monthlyCap: q.monthly.cap,
      blocks: (trigger.state?.blocks ?? 0) + (q.decision === 'block' ? 1 : 0),
    },
  });
}
