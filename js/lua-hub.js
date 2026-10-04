/* Тренажёр по Lua: отдельный экран со всеми уроками «от простого к сложному».
   Использует те же уроки и тот же прогресс, что и слайды (window.Lesson, window.JAM). */
(() => {
  'use strict';
  const J = window.JAM;
  const root = document.getElementById('luahub');
  const el = (tag, cls, html) => { const e = document.createElement(tag); if (cls) e.className = cls; if (html != null) e.innerHTML = html; return e; };

  const TIERS = [
    { name: '🌱 ЛЕГКО', note: 'первые шаги в коде', stars: 1, ids: ['basics', 'props'] },
    { name: '🌿 СРЕДНЕ', note: 'решения и события', stars: 2, ids: ['cond', 'pickup'] },
    { name: '🌳 СЛОЖНО', note: 'повторы и секреты', stars: 3, ids: ['loop', 'door'] },
  ];
  const DESC = {
    basics: 'print · переменные · числа · склейка слов',
    props: 'цвет · прозрачность · размер · Anchored',
    cond: 'если — то · else · Touched · лава',
    pickup: 'скрипт монетки · Destroy · очки',
    loop: 'for · task.wait · while · мигающая лампа',
    door: 'CanCollide · ClickDetector · not · дверь с ключом',
  };
  const FLAT = TIERS.flatMap((t) => t.ids);

  const prog = (id) => window.Lesson.progress(id);
  const isDone = (id) => !!prog(id).done;
  const unlockedAll = () => !!J.state.data.luaUnlockAll;
  const isOpen = (id) => {
    const k = FLAT.indexOf(id);
    if (k <= 0 || unlockedAll()) return true;
    return isDone(FLAT[k - 1]) || isDone(id) || prog(id).step > 0;
  };

  function render() {
    root.innerHTML = '';
    const doneN = FLAT.filter(isDone).length;
    const stars = FLAT.reduce((a, id) => a + (isDone(id) ? (prog(id).xp || 0) : 0), 0);
    const tasksAll = FLAT.reduce((a, id) => a + LESSONS[id].steps.filter((s) => s.type !== 'learn').length, 0);

    const head = el('div', 'lh-head');
    const x = el('button', 'icon-btn', '✕'); x.title = 'Закрыть (Esc)'; x.onclick = close;
    const ttl = el('div', 'lh-ttl', `<b>⌨️ Тренажёр по Lua</b><span>${FLAT.length} уроков · ${tasksAll} заданий · от простого к сложному</span>`);
    const bar = el('div', 'lh-prog', `<div class="lh-bar"><i style="width:${Math.round(doneN / FLAT.length * 100)}%"></i></div><em>Пройдено уроков: <b>${doneN}</b> из ${FLAT.length}${stars ? ` · ⭐ ${stars}` : ''}</em>`);
    head.append(x, ttl, bar);
    root.appendChild(head);

    const body = el('div', 'lh-body');
    TIERS.forEach((t) => {
      body.appendChild(el('div', 'lh-tier', `<b>${t.name}</b><span>${t.note}</span>`));
      const row = el('div', 'lh-row');
      t.ids.forEach((id) => row.appendChild(card(id, t)));
      body.appendChild(row);
    });
    const foot = el('div', 'lh-foot');
    if (!unlockedAll() && FLAT.some((id) => !isOpen(id))) {
      const u = el('button', 'lh-unlock', '🔓 Открыть все уроки сразу'); u.type = 'button';
      u.onclick = () => { J.state.data.luaUnlockAll = true; J.save(); render(); };
      foot.append(el('span', '', 'Уроки открываются по порядку — так проще учиться.'), u);
    } else foot.appendChild(el('span', '', 'Можно проходить уроки в любом порядке и повторять сколько угодно.'));
    body.appendChild(foot);
    root.appendChild(body);
  }

  function card(id, tier) {
    const L = LESSONS[id], p = prog(id), n = L.steps.length;
    const open = isOpen(id), done = !!p.done;
    const tasks = L.steps.filter((s) => s.type !== 'learn').length;
    const step = done ? n : Math.min(p.step || 0, n);
    const k = FLAT.indexOf(id);
    const c = el('div', `lh-card ${done ? 'done' : ''} ${open ? '' : 'locked'}`);
    const title = (L.title.split(' · ')[1] || L.title);
    const label = done ? '↻ Ещё раз' : step > 0 ? '▶ Продолжить' : '▶ Начать';
    c.innerHTML = `<div class="lh-num">${done ? '✓' : open ? k + 1 : '🔒'}</div>
      <div class="lh-main">
        <div class="lh-t"><span class="lh-ico">${L.icon}</span>${title}</div>
        <div class="lh-d">${DESC[id] || ''}</div>
        <div class="lh-meta"><span class="lh-stars">${'⭐'.repeat(tier.stars)}${'☆'.repeat(3 - tier.stars)}</span><span>${tasks} заданий</span><span>${done ? '✅ пройден' : open ? `шаг ${step} из ${n}` : `сначала урок ${k}`}</span></div>
        <div class="lh-bar"><i style="width:${Math.round(step / n * 100)}%"></i></div>
      </div>`;
    const b = el('button', 'btn lh-btn', open ? label : '🔒'); b.type = 'button'; b.disabled = !open;
    b.onclick = () => window.Lesson.open(id, { onExit: render });
    c.appendChild(b);
    return c;
  }

  function open() { render(); root.hidden = false; }
  function close() { root.hidden = true; J.refresh && J.refresh(); }

  root.addEventListener('click', (e) => e.stopPropagation());
  document.addEventListener('keydown', (e) => {
    if (root.hidden || !document.getElementById('lesson').hidden) return;
    if (e.key === 'Escape') close();
    e.stopPropagation();
  }, true);
  document.addEventListener('keydown', (e) => {
    if (!root.hidden || !document.getElementById('lesson').hidden) return;
    if (e.metaKey || e.ctrlKey || e.altKey || e.target.matches('input, textarea, select')) return;
    if (!document.getElementById('final').hidden || !document.getElementById('modal').hidden || !document.getElementById('confirm').hidden) return;
    if (e.key === 'l' || e.key === 'L' || e.key === 'д' || e.key === 'Д') { open(); e.stopPropagation(); }
  }, true);
  document.getElementById('btnLua').onclick = open;

  window.LuaHub = { open, close, isOpen: () => !root.hidden };
})();
