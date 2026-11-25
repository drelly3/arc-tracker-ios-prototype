// Arc Tracker iOS prototype shim.
// The tracker calls its backend with root-relative paths (/api/...). Inside the
// native shell those resolve to the shell's own origin, so send them to the live
// backend instead. NOTE: the Worker does not yet allow cross-origin calls from a
// Capacitor origin, so sync/verify fail until a CORS allowlist is added there
// (one small Worker change, needs owner approval).
(() => {
  const API_BASE = 'https://animemindset.com';
  const origFetch = window.fetch.bind(window);
  window.fetch = (input, init) => {
    if (typeof input === 'string' && input.startsWith('/api/')) {
      input = API_BASE + input;
    }
    return origFetch(input, init);
  };
})();

// Arc Tracker iOS prototype: reminders that live on the phone (experimental).
// The web app sends reminders through its server (web push). The native shell has no push
// setup, so this schedules the same reminders as local notifications instead. The wording and
// the quote/review rules below are copied from api/arc-reminders.js, api/arc-quotes.js (dropFor)
// and api/arc-push.js (dueKind, MESSAGES) in the site repo, so the phone says what the server would.
(() => {
  const MAX_PENDING = 60;   // iOS keeps a limited number of pending local notifications (commonly cited as 64)
  const HORIZON_DAYS = 30;  // never schedule further out than this

// What the daily reminder notification says. It only goes out when the member hasn't cleared today,
// so every line is a nudge to go and do it. A different one each day: lines written for the member's
// archetype on some days, lines for everyone on the others. Each row is [title, message].
// Add, remove or reword rows freely; nothing else needs changing.
const EVERYONE = [
  ['Your arc isn’t going to write itself', 'A few habits stand between you and today’s clear.'],
  ['Episode’s almost over', 'Don’t let today end on a cliffhanger. Clear today.'],
  ['Main characters show up', 'Even on filler days. Especially on filler days.'],
  ['The training arc is calling', 'Nobody sees these reps. That’s what makes them count.'],
  ['Don’t break the chain', 'Your streak is still alive. Keep it that way.'],
  ['Two minutes. That’s the ask', 'Start your non-negotiable. The rest follows.'],
  ['Future you is watching', 'Give them something to be proud of today.'],
  ['Still time on the clock', 'Today isn’t over until you say it is. Go clear it.'],
  ['Power-ups aren’t sudden', 'They’re a hundred quiet days like this one. Log today.'],
  ['Never miss twice', 'Whatever yesterday was, today is still yours.'],
  ['You said you would', 'That’s reason enough. Clear today, then rest.'],
  ['Small counts', 'One habit done beats five planned. Open the tracker.'],
];
const BY_ARCHETYPE = {
  strategist: [
    ['The plan only works if you run it', 'You already know the move. Make it.'],
    ['Thinking time is over', 'Today’s habits, in order. Execute.'],
    ['Checkmate takes daily moves', 'Play today’s. The board is waiting.'],
  ],
  'demon-grind': [
    ['Still standing? Then swing', 'Today’s habits are waiting on you.'],
    ['You don’t stop when you’re tired', 'You stop when it’s done. Clear today.'],
    ['One more step forward', 'That’s all today is asking for. Take it.'],
  ],
  prodigy: [
    ['Yesterday’s you set the bar', 'Go beat it. Clear today.'],
    ['Talent is waiting on the reps', 'Put today’s in.'],
    ['One percent better', 'That’s the whole job today. Log it.'],
  ],
  reborn: [
    ['Today is a new page', 'Write it. Your habits are waiting.'],
    ['The old you would have skipped this', 'You’re not them anymore.'],
    ['Proof beats promises', 'Add today’s proof to the pile.'],
  ],
  beacon: [
    ['Fill your own tank first', 'Then go carry everyone else. Clear today.'],
    ['Someone’s watching how you show up', 'Show them. Clear today.'],
    ['Keep the light on', 'It starts with today’s habits.'],
  ],
  'social-commander': [
    ['Leaders go first', 'Clear your own day before you rally anyone else.'],
    ['Give yourself the order', 'Clear today. Advance.'],
    ['Your move, commander', 'The day doesn’t win itself.'],
  ],
  believer: [
    ['The dream is still on', 'Today’s habits keep it alive.'],
    ['Hope with a plan is a promise', 'Keep today’s.'],
    ['Set sail', 'You know where you’re going. Clear today.'],
  ],
  underdog: [
    ['Nobody’s betting on you today', 'Good. Go prove them wrong.'],
    ['No special power needed', 'Just today’s habits.'],
    ['Outwork the odds', 'It starts with one habit. Open the tracker.'],
  ],
  'free-spirit': [
    ['Do it your way', 'Just do it today. Clear your habits.'],
    ['Play first, skip never', 'Today’s habits won’t take long.'],
    ['Keep it light', 'A quick clear, then the day is yours.'],
  ],
  'balanced-master': [
    ['Small corrections, every day', 'Today’s is waiting.'],
    ['Make the tea slowly', 'Then clear today.'],
  ],
};

// One reminder per calendar day ("YYYY-MM-DD"): every other day leans on the member's archetype.
function reminderFor(archetypeKey, dateStr) {
  const [y, m, d] = String(dateStr).split('-').map(Number);
  const day = Math.floor(Date.UTC(y, (m || 1) - 1, d || 1) / 86400000);
  const mine = BY_ARCHETYPE[archetypeKey];
  const list = mine && day % 2 === 0 ? mine : EVERYONE;
  const [title, body] = list[Math.floor(day / 2) % list.length];
  return { title, body };
}

function dropFor(dateStr) {
  const [y, m, d] = String(dateStr).split('-').map(Number);
  const sinceMonday = Math.floor(Date.UTC(y, (m || 1) - 1, d || 1) / 86400000) - 4;
  const week = Math.floor(sinceMonday / 7), dow = sinceMonday - week * 7;
  return { index: week * 2 + (dow >= 3 ? 1 : 0), isDropDay: dow === 0 || dow === 3, isSunday: dow === 6 };
}
const MESSAGES = {
  quote: { title: 'Your new arc quote just dropped', body: 'Tap to reveal it.' },
  report: { title: 'Your Weekly Arc Review is ready', body: 'See your week in numbers, then set up the next one.' },
};
const pad = n => String(n).padStart(2, '0');
const dstr = d => d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate());
const mins = t => { const [h, m] = String(t || '').split(':').map(Number); return (h >= 0 && h < 24 && m >= 0 && m < 60) ? h * 60 + m : null; };

// Which notifications should exist right now. s = { time:'HH:MM', archetype, clearedToday, reminders:[{id,label,note,time,days}] }.
// Same rules as the server: the daily reminder is a quote on Mondays and Thursdays and the Weekly Arc Review on
// Sundays (both go out even when today is cleared); on other days it is the rotating reminder, skipped when today
// is cleared. The member's own and habit reminders ignore "cleared". Nothing in the past is scheduled.
// Only the soonest MAX_PENDING are kept, so many reminders mean fewer days are covered.
function plan(s, now = new Date(), quotes = (typeof window !== 'undefined' ? window.ARC_QUOTES : null)) {
  const items = [], daily = mins(s.time || '08:00');
  for (let off = 0; off < HORIZON_DAYS; off++) {
    const day = new Date(now.getFullYear(), now.getMonth(), now.getDate() + off);
    const date = dstr(day), dow = day.getDay();
    const at = m => new Date(day.getFullYear(), day.getMonth(), day.getDate(), Math.floor(m / 60), m % 60, 0);
    if (daily !== null && at(daily) > now) {
      const dr = dropFor(date);
      let kind = dr.isDropDay ? 'quote' : dr.isSunday ? 'report' : 'reminder';
      if (kind === 'quote' && !(quotes && quotes[s.archetype])) kind = 'reminder';
      if (!(kind === 'reminder' && off === 0 && s.clearedToday)) {
        const msg = kind === 'reminder' ? reminderFor(s.archetype, date) : MESSAGES[kind];
        items.push({ at: at(daily), title: msg.title, body: msg.body, kind });
      }
    }
    for (const r of (s.reminders || []).slice(0, 20)) {
      const m = mins(r.time);
      const days = Array.isArray(r.days) && r.days.length ? r.days.map(Number) : [0, 1, 2, 3, 4, 5, 6];
      if (m === null || !days.includes(dow) || at(m) <= now) continue;
      items.push({ at: at(m), title: String(r.label || 'Reminder').slice(0, 80), body: String(r.note || 'Your reminder from Arc Tracker.').slice(0, 200), kind: 'own' });
    }
  }
  items.sort((a, b) => a.at - b.at);
  return items.slice(0, MAX_PENDING);
}

const LN = () => { const c = window.Capacitor; return c && c.Plugins && c.Plugins.LocalNotifications; };
const R = window.ArcLocalReminders = { last: null, plan, rules: { reminderFor, dropFor } };
R.available = () => !!LN();
R.permission = async () => { const ln = LN(); if (!ln) return 'unsupported'; try { return (await ln.checkPermissions()).display; } catch { return 'unsupported'; } };
R.enable = async () => { const ln = LN(); if (!ln) return 'unsupported'; try { return (await ln.requestPermissions()).display; } catch { return 'unsupported'; } };
async function clearPending(ln) {
  const p = await ln.getPending();
  const mine = (p.notifications || []).filter(n => n.id < 9000);
  if (mine.length) await ln.cancel({ notifications: mine.map(n => ({ id: n.id })) });
}
R.disable = async () => { const ln = LN(); if (ln) { try { await clearPending(ln); } catch {} } R.last = null; };
// ids 9000+ are one-off tests and never counted or cleared by sync
R.pendingCount = async () => { const ln = LN(); if (!ln) return 0; try { return ((await ln.getPending()).notifications || []).filter(n => n.id < 9000).length; } catch { return 0; } };
R.test = async (secs) => { const ln = LN(); if (!ln) return; await ln.schedule({ notifications: [{ id: 9001, title: MESSAGES.quote.title, body: MESSAGES.quote.body, schedule: { at: new Date(Date.now() + (secs || 10) * 1000) }, extra: { kind: 'quote' } }] }); };
R.onTap = cb => { const ln = LN(); if (ln && ln.addListener) ln.addListener('localNotificationActionPerformed', e => { const x = e && e.notification && e.notification.extra; cb(x && x.kind); }); };
R.sync = async s => {
  const ln = LN(); if (!ln) return { ok: false, reason: 'unsupported' };
  try {
    const perm = (await ln.checkPermissions()).display;
    if (perm !== 'granted') return { ok: false, reason: perm === 'denied' ? 'denied' : 'off' };
    await clearPending(ln);
    const items = plan(s);
    if (items.length) await ln.schedule({ notifications: items.map((x, i) => ({ id: i + 1, title: x.title, body: x.body, schedule: { at: x.at }, extra: { kind: x.kind } })) });
    const pending = ((await ln.getPending()).notifications || []).filter(n => n.id < 9000);
    R.last = { count: pending.length, through: items.length ? dstr(items[items.length - 1].at) : '', capped: items.length >= MAX_PENDING };
    return { ok: true, ...R.last };
  } catch (e) { return { ok: false, reason: 'error' }; }
};
})();
