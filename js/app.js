(() => {
  'use strict';

  const KEY = 'boblox-game-jam-v2';
  const OLD_KEY = 'boblox-game-jam-v1';
  const OLD_IDS = ['cover', 'mission', 'plan', 'concept', 'title', 'genre', 'inspiration', 'aicoauthor', 'prompt', 'world', 'map', 'style', 'studio', 'build', 'lua', 'ailua'];
  const W = 1280, H = 720;
  const $ = (s, r = document) => r.querySelector(s);
  const el = (tag, cls, html) => { const e = document.createElement(tag); if (cls) e.className = cls; if (html != null) e.innerHTML = html; return e; };

  /* ---------- состояние ---------- */
  let state = { done: {}, data: {}, i: 0 };
  try {
    const cur = localStorage.getItem(KEY);
    if (cur) Object.assign(state, JSON.parse(cur));
    else {                                   // перенос ответов и блоков из старой версии (прогресс хранился по номерам слайдов)
      const old = JSON.parse(localStorage.getItem(OLD_KEY) || 'null');
      if (old) {
        state.data = old.data || {};
        Object.keys(old.done || {}).forEach((k) => { if (OLD_IDS[+k]) state.done[OLD_IDS[+k]] = true; });
      }
    }
  } catch (e) { /* ignore */ }
  const save = () => { try { localStorage.setItem(KEY, JSON.stringify(state)); } catch (e) { /* ignore */ } };
  const total = SLIDES.length;
  const isDone = (i) => !!state.done[SLIDES[i].id];
  const doneCount = () => SLIDES.filter((x) => state.done[x.id]).length;
  const pct = () => Math.round(doneCount() / total * 100);

  /* ---------- производные значения для data-bind ---------- */
  function derived(key) {
    const d = state.data;
    if (key === 'styleLine') {
      const p = [d.color, d.mood, d.light, d.style].filter(Boolean);
      return p.length ? p.join(' + ') : '';
    }
    if (key === 'blocks') return `${doneCount()}/${total}`;
    if (key === 'pct') return `${pct()}%`;
    if (key === 'licDate') return new Date().toLocaleDateString('ru-RU');
    if (key === 'licId') {
      const n = (d.creator || '').trim();
      if (!n) return 'GJ-????';
      let h = 7; for (const c of n.toLowerCase()) h = (h * 31 + c.charCodeAt(0)) % 9000;
      return `GJ-${1000 + h}`;
    }
    if (key === 'luaLine') return (d.lua || '').split('\n').map((x) => x.trim()).find((x) => x && !x.startsWith('--')) || '';
    const v = d[key];
    return Array.isArray(v) ? v.join(', ') : (v || '');
  }
  function refreshBinds(root = document) {
    root.querySelectorAll('[data-bind]').forEach((n) => {
      const v = derived(n.dataset.bind);
      n.textContent = v || n.dataset.fallback || '___';
      n.classList.toggle('empty', !v);
    });
    document.querySelectorAll('[data-done]').forEach((n) => n.classList.toggle('on', !!state.done[n.dataset.done]));
    const fill = $('#gcFill');
    if (fill) fill.style.width = `${pct()}%`;
    const ft = $('#fnTitle'); if (ft && ft.textContent) ft.style.fontSize = (ft.textContent.length > 22 ? 44 : ft.textContent.length > 14 ? 58 : 72) + 'px';
  }

  /* ---------- проверка действия ---------- */
  const words = (s) => (s || '').trim().split(/\s+/).filter(Boolean).length;
  function fieldOk(f) {
    const v = state.data[f.key];
    if (f.optional) return true;
    switch (f.type) {
      case 'text': return (v || '').trim().length >= (f.min || 1);
      case 'area': return words(v) >= (f.words || 1);
      case 'select': return !!v;
      case 'cards':
      case 'chips': return Array.isArray(v) && v.length >= (f.min || 1) && v.length <= (f.max || 99);
      case 'checklist': return Array.isArray(v) && f.items.every((_, k) => v[k]);
      case 'lesson': return !!(state.data['lesson_' + f.lesson] && state.data['lesson_' + f.lesson].done);
      case 'gate': return SLIDES.slice(0, state.i).every((x) => state.done[x.id]);
      case 'quiz': return state.data[f.key] === true;
      default: return true;
    }
  }
  const actionOk = (s) => s.action.fields.every(fieldOk);

  /* ---------- рендер слайда ---------- */
  const area = $('#slideArea'), panel = $('#panel'), stage = $('#stage');
  let currentBtn = null;
  let refreshers = [];

  function render(i, dir = 1) {
    i = Math.max(0, Math.min(total - 1, i));
    state.i = i; save();
    if (location.hash !== `#${i + 1}`) history.replaceState(null, '', `#${i + 1}`);
    const s = SLIDES[i];
    const sec = SECTIONS[s.section];
    stage.style.setProperty('--accent', sec.color);
    $('#sectionTag').textContent = sec.name;
    $('#counter').textContent = `${i + 1} / ${total}`;
    document.title = `${i + 1}. ${s.title} — ROBLOX GAME JAM`;

    area.innerHTML = '';
    const slide = el('section', `slide ${s.cover ? 'is-cover' : ''} ${dir > 0 ? 'in-right' : 'in-left'}`, s.body);
    area.appendChild(slide);
    if (document.documentElement.classList.contains('m')) window.scrollTo(0, 0);
    slide.querySelectorAll('[data-goto]').forEach((b) => {
      b.onclick = () => { const k = SLIDES.findIndex((x) => x.id === b.dataset.goto); if (k >= 0) go(k); };
    });
    slide.prepend(el('div', 'slide-no', String(i + 1).padStart(2, '0')));

    renderPanel(s, slide);
    addCopyButtons(slide);
    initTimer(slide);
    const of = $('#openFinal', slide);
    if (of) { of.disabled = !isDone(i); of.onclick = () => openFinal(s); }
    refreshBinds();
    renderBricks();
    $('#prev').style.visibility = i === 0 ? 'hidden' : 'visible';
    $('#next').style.visibility = i === total - 1 ? 'hidden' : 'visible';
    $('#next').classList.toggle('ready', isDone(i));
  }

  function renderPanel(s, slide) {
    const i = SLIDES.indexOf(s);
    panel.innerHTML = '';
    refreshers = [];
    const info = el('div', 'p-info', `<div class="p-label">⚡ ТВОЁ ДЕЙСТВИЕ</div><div class="p-text"></div>`);
    $('.p-text', info).textContent = s.action.text;
    const fieldsBox = el('div', 'p-fields');
    const rew = el('div', 'p-reward');
    const btn = el('button', 'btn go', '');
    currentBtn = btn;

    s.action.fields.forEach((f) => {
      const node = buildField(f, () => onChange(s, i));
      const slot = f.slot && slide.querySelector(`[data-slot="${f.slot}"]`);
      if (slot) slot.appendChild(node); else fieldsBox.appendChild(node);
    });
    const allSlotted = s.action.fields.length && s.action.fields.every((f) => f.slot);
    if (!fieldsBox.children.length) {
      fieldsBox.classList.add('empty');
      fieldsBox.dataset.msg = allSlotted ? '👆 Сделай это прямо на слайде — и кнопка справа загорится' : '👉 Сделай это — и кнопка справа загорится';
    }

    rew.innerHTML = `<div class="r-label">🎁 ПОЛУЧИШЬ:</div><div class="r-item"><span class="r-icon">${s.reward.icon}</span><span class="r-name">${s.reward.name}</span></div>`;
    rew.appendChild(btn);
    panel.append(info, fieldsBox, rew);
    btn.onclick = () => claim(i);
    updateButton(s, i);
  }

  function updateButton(s, i) {
    const ok = actionOk(s), done = isDone(i);
    const btn = currentBtn;
    if (!btn) return;
    panel.classList.toggle('is-done', done);
    btn.disabled = !ok && !done;
    btn.classList.toggle('ready', ok && !done);
    if (done) { btn.textContent = '✅ Блок получен'; btn.disabled = true; }
    else btn.textContent = s.action.button || (ok ? 'ГОТОВО — забрать блок!' : 'Выполни действие');
  }

  function onChange(s, i) {
    save();
    refreshBinds();
    updateButton(s, i);
  }

  /* ---------- поля ---------- */
  function buildField(f, change) {
    const d = state.data;
    const wrap = el('label', `field f-${f.type}`);
    if (f.label && !['chips', 'checklist', 'code'].includes(f.type) && !f.slot) wrap.appendChild(el('span', 'f-label', f.label));

    if (f.type === 'text' || f.type === 'area') {
      const inp = f.type === 'text' ? el('input') : el('textarea');
      if (f.type === 'text') inp.type = 'text'; else inp.rows = 3;
      inp.placeholder = f.placeholder || '';
      inp.value = d[f.key] || '';
      inp.maxLength = 300;
      const hint = f.type === 'area' ? el('span', 'f-hint') : null;
      const upd = () => { if (hint) hint.textContent = `${words(inp.value)} / ${f.words} слов`; };
      inp.addEventListener('input', () => { d[f.key] = inp.value; upd(); change(); });
      wrap.appendChild(inp); if (hint) { wrap.appendChild(hint); upd(); }
    }

    if (f.type === 'select') {
      const sel = el('select');
      sel.appendChild(new Option(f.label ? `${f.label}…` : '— выбери —', ''));
      f.options.forEach((o) => sel.appendChild(new Option(o, o)));
      const cur = d[f.key] || '';
      const isCustom = !!f.custom && cur && !f.options.includes(cur);
      if (f.custom) sel.appendChild(new Option('✏️ Свой вариант…', '__custom__'));
      sel.value = isCustom ? '__custom__' : cur;
      wrap.appendChild(sel);
      if (f.slot) wrap.classList.add('inline');
      if (f.custom) {
        const row = el('div', 'custom-row');
        const inp = el('input'); inp.type = 'text'; inp.maxLength = 24; inp.placeholder = 'Напиши свой вариант…';
        inp.value = isCustom ? cur : '';
        const back = el('button', 'custom-back', '↩'); back.type = 'button'; back.title = 'Вернуться к списку';
        row.append(inp, back);
        const showCustom = (on) => { row.style.display = on ? 'flex' : 'none'; sel.style.display = on ? 'none' : ''; };
        showCustom(isCustom || false);
        inp.addEventListener('input', () => { d[f.key] = inp.value.trim(); change(); });
        back.addEventListener('click', () => { d[f.key] = ''; sel.value = ''; showCustom(false); change(); });
        sel.addEventListener('change', () => {
          if (sel.value === '__custom__') { showCustom(true); d[f.key] = inp.value.trim(); inp.focus(); }
          else d[f.key] = sel.value;
          change();
        });
        wrap.appendChild(row);
      } else {
        sel.addEventListener('change', () => { d[f.key] = sel.value; change(); });
      }
    }

    if (f.type === 'cards') {
      const box = el('div', 'cards');
      d[f.key] = Array.isArray(d[f.key]) ? d[f.key] : [];
      f.options.forEach((o) => {
        const c = el('button', 'gcard');
        c.type = 'button'; c.dataset.name = o.name;
        c.innerHTML = `${o.img ? `<span class="gc-img" style="background-image:url(${o.img})"><em>${o.shot || ''}</em></span>` : ''}<span class="gc-h"><i>${o.icon}</i>${o.name}</span><span class="gc-d">${o.desc}</span><span class="gc-ex"><b>Roblox:</b> ${o.roblox}</span><span class="gc-tick">✔</span>`;
        c.classList.toggle('on', d[f.key].includes(o.name));
        c.addEventListener('click', () => {
          let arr = d[f.key];
          if (arr.includes(o.name)) arr = arr.filter((x) => x !== o.name);
          else if (arr.length < f.max) arr = [...arr, o.name];
          else return shake(c);
          d[f.key] = arr;
          box.querySelectorAll('.gcard').forEach((x) => x.classList.toggle('on', arr.includes(x.dataset.name)));
          change();
        });
        box.appendChild(c);
      });
      return box;
    }

    if (f.type === 'quiz') {
      const box = el('div', 'quiz');
      const row = el('div', 'chips');
      const msg = el('div', 'quiz-msg', '');
      const solved = d[f.key] === true;
      f.options.forEach((o, k) => {
        const c = el('button', 'chip'); c.type = 'button'; c.textContent = o;
        if (solved && k === f.answer) c.classList.add('on', 'ok');
        c.addEventListener('click', () => {
          if (d[f.key] === true) return;
          if (k === f.answer) {
            d[f.key] = true; c.classList.add('on', 'ok'); msg.textContent = '✅ Верно!'; msg.className = 'quiz-msg good'; change();
          } else {
            shake(c); c.classList.add('no'); msg.textContent = '🤔 Подумай ещё. ' + (f.hint || ''); msg.className = 'quiz-msg bad';
          }
        });
        row.appendChild(c);
      });
      if (solved) { msg.textContent = '✅ Верно!'; msg.className = 'quiz-msg good'; }
      box.append(row, msg);
      return box;
    }

    if (f.type === 'lesson') {
      const lesson = LESSONS[f.lesson];
      const box = el('div', 'lesson-card');
      const paint = () => {
        const p = window.Lesson ? window.Lesson.progress(f.lesson) : { step: 0, done: false };
        const n = lesson.steps.length, step = p.done ? n : Math.min(p.step, n);
        const label = p.done ? '↻ Пройти ещё раз' : step > 0 ? '▶ Продолжить урок' : '▶ Начать урок';
        box.classList.toggle('done', !!p.done);
        box.innerHTML = `<div class="lc-ico">${lesson.icon}</div>
          <div class="lc-body"><b>${lesson.title}</b><span>${lesson.steps.filter((x) => x.type !== 'learn').length} заданий · как в Duolingo</span>
            <div class="lc-bar"><i style="width:${Math.round(step / n * 100)}%"></i></div>
            <em>${p.done ? '✅ Урок пройден' : `Пройдено шагов: ${step} из ${n}`}</em></div>
          <button class="btn lc-btn" type="button">${label}</button>`;
        box.querySelector('.lc-btn').onclick = () => window.Lesson.open(f.lesson);
      };
      paint();
      refreshers.push(paint);
      return box;
    }

    if (f.type === 'chips') {
      const box = el('div', 'chips');
      d[f.key] = Array.isArray(d[f.key]) ? d[f.key] : [];
      f.options.forEach((o) => {
        const c = el('button', 'chip'); c.type = 'button'; c.textContent = o;
        c.classList.toggle('on', d[f.key].includes(o));
        c.addEventListener('click', () => {
          let arr = d[f.key];
          if (arr.includes(o)) arr = arr.filter((x) => x !== o);
          else if (f.max === 1) arr = [o];
          else if (arr.length < f.max) arr = [...arr, o];
          else return shake(c);
          d[f.key] = arr;
          box.querySelectorAll('.chip').forEach((x) => x.classList.toggle('on', arr.includes(x.textContent)));
          change();
        });
        box.appendChild(c);
      });
      const hint = f.max > 1 ? el('div', 'f-hint', f.min > 1 ? `выбери минимум ${f.min}` : `можно до ${f.max}`) : null;
      wrap.appendChild(box); if (hint) wrap.appendChild(hint);
      return retag(wrap);
    }

    if (f.type === 'checklist') {
      const box = el('div', `checks ${f.inline ? 'inline' : ''} ${f.cols === 2 ? 'cols2' : ''}`);
      d[f.key] = Array.isArray(d[f.key]) ? d[f.key] : [];
      f.items.forEach((t, k) => {
        const row = el('label', 'check');
        const cb = el('input'); cb.type = 'checkbox'; cb.checked = !!d[f.key][k];
        cb.addEventListener('change', () => { d[f.key][k] = cb.checked; row.classList.toggle('on', cb.checked); change(); });
        row.classList.toggle('on', cb.checked);
        row.append(cb, el('span', 'box', '✔'), el('span', 'txt', t));
        box.appendChild(row);
      });
      return retag(box);
    }

    if (f.type === 'gate') {
      const before = SLIDES.slice(0, state.i);
      const left = before.filter((x) => !state.done[x.id]).length;
      const box = el('div', `gate ${left ? 'locked' : 'open'}`);
      box.innerHTML = left
        ? `<b>🔒 Осталось собрать блоков: ${left}</b><span>Открой «Моя игра» — там видно, какие слайды пропущены.</span>`
        : `<b>✅ Все ${before.length} блоков собраны!</b><span>Осталось нажать кнопку справа.</span>`;
      if (left) { const b = el('button', 'btn small', '🧱 Показать пропущенные'); b.type = 'button'; b.onclick = openBuild; box.appendChild(b); }
      return box;
    }

    return wrap;
  }
  const retag = (n) => { if (n.tagName === 'LABEL' && n.classList.contains('field')) { const d = el('div', n.className); while (n.firstChild) d.appendChild(n.firstChild); return d; } return n; };
  const shake = (n) => { n.classList.remove('shake'); void n.offsetWidth; n.classList.add('shake'); };

  /* Крошечный «интерпретатор» Lua: умеет только print("...") */
  function runLua(src) {
    const out = []; let ok = true;
    src.split('\n').forEach((raw, n) => {
      const line = raw.trim();
      if (!line || line.startsWith('--')) return;
      const m = line.match(/^print\s*\(\s*(?:"(.*)"|'(.*)'|(-?\d+(?:\.\d+)?))\s*\)\s*;?$/);
      if (m) out.push(m[1] ?? m[2] ?? m[3]);
      else { ok = false; out.push(`Ошибка в строке ${n + 1}: ожидается print("текст")`); }
    });
    if (!out.length) return { ok: false, text: 'Напиши print("...")' };
    return { ok, text: out.join('\n') };
  }

  /* ---------- получение награды ---------- */
  function claim(i) {
    const s = SLIDES[i];
    if (isDone(i) || !actionOk(s)) return;
    state.done[s.id] = true; save();
    updateButton(s, i);
    refreshBinds();
    renderBricks(i);
    $('#next').classList.add('ready');
    const of = $('#openFinal'); if (of) of.disabled = false;
    if (s.final) { openFinal(s); return; }
    showToast(s, doneCount());
    burst(40);
  }

  function showToast(s, n) {
    const t = $('#toast');
    const all = n === total;
    t.innerHTML = `<div class="t-card ${all ? 'all' : ''}">
      <div class="t-brick">${s.reward.icon}</div>
      <div class="t-body"><b>${all ? '🏆 ИГРА СОБРАНА!' : '+1 БЛОК ТВОЕЙ ИГРЫ!'}</b><span>${s.reward.name}</span><small>ТВОЯ ИГРА СОБРАНА НА ${pct()}% · ${n}/${total}</small></div>
    </div>`;
    t.classList.remove('show'); void t.offsetWidth; t.classList.add('show');
    clearTimeout(showToast.tm);
    showToast.tm = setTimeout(() => t.classList.remove('show'), 2400);
  }

  function burst(n) {
    const c = $('#confetti');
    const colors = ['#ffc531', '#3b8cff', '#27d96b', '#b05cff', '#ff4d6d', '#fff'];
    for (let k = 0; k < n; k++) {
      const p = el('i');
      p.style.cssText = `left:${50 + (Math.random() - .5) * 20}%;background:${colors[k % colors.length]};--dx:${(Math.random() - .5) * 900}px;--dy:${-200 - Math.random() * 380}px;--r:${Math.random() * 720}deg;animation-delay:${Math.random() * .15}s`;
      c.appendChild(p); setTimeout(() => p.remove(), 1800);
    }
  }

  /* ---------- блоки наверху ---------- */
  function renderBricks(pop) {
    $('#pgPct').textContent = `${pct()}%`;
    $('#pgNow').textContent = doneCount();
    $('#pgTotal').textContent = total;
    $('#progress').classList.toggle('full', doneCount() === total);
    const box = $('#bricks');
    if (!box.children.length) {
      SLIDES.forEach((s, i) => {
        const b = el('button', 'brick'); b.type = 'button';
        b.style.setProperty('--c', SECTIONS[s.section].color);
        b.title = `${i + 1}. ${s.title} → ${s.reward.name}`;
        b.addEventListener('click', () => go(i));
        box.appendChild(b);
      });
    }
    [...box.children].forEach((b, i) => {
      const done = isDone(i);
      b.classList.toggle('done', done);
      b.classList.toggle('cur', i === state.i);
      b.textContent = done ? SLIDES[i].reward.icon : '';
      if (pop === i) { b.classList.remove('pop'); void b.offsetWidth; b.classList.add('pop'); }
    });
  }

  /* ---------- финальный экран ---------- */
  function openFinal(slide) {
    const cfg = (slide || SLIDES[state.i]).finalCfg;
    $('#final').innerHTML = `<div class="final-box">
      <div class="fn-head">${cfg.head}</div>
      <div class="fn-title" id="fnTitle" data-bind="title" data-fallback="МОЯ ИГРА"></div>
      <div class="fn-rank mono">${cfg.rank}</div>
      <div class="fn-grid">${cfg.cells.map(([l, k, m]) => `<div><i>${l}</i><span class="${m || ''}" data-bind="${k}" data-fallback="—"></span></div>`).join('')}</div>
      <div class="fn-by">CREATED BY: <b data-bind="creator" data-fallback="РАЗРАБОТЧИК"></b></div>
      <div class="fn-quote">${cfg.quote}</div>
      <div class="fn-foot"><span>📸 Сделай скриншот — это твой диплом разработчика</span><button class="btn small ghost" id="fnClose">← Назад к слайдам</button></div>
    </div>`;
    $('#fnClose').onclick = closeFinal;
    refreshBinds($('#final'));
    $('#final').hidden = false;
    const box = $('.final-box'); box.classList.remove('in'); void box.offsetWidth; box.classList.add('in');
    burst(180); setTimeout(() => burst(100), 600);
  }
  const closeFinal = () => { $('#final').hidden = true; };

  /* ---------- «Моя игра» ---------- */
  function openBuild() {
    $('#mCount').textContent = `${doneCount()} / ${total}`;
    const g = $('#buildGrid'); g.innerHTML = '';
    SLIDES.forEach((s, i) => {
      const done = isDone(i);
      const c = el('button', `bcell ${done ? 'done' : ''}`, `<span class="bn">${i + 1}</span><span class="bi">${done ? s.reward.icon : '🔒'}</span><span class="bt">${done ? s.reward.name : '???'}</span>`);
      c.style.setProperty('--c', SECTIONS[s.section].color);
      c.onclick = () => { closeBuild(); go(i); };
      g.appendChild(c);
    });
    $('#modal').hidden = false;
  }
  const closeBuild = () => { $('#modal').hidden = true; };

  /* ---------- копирование промптов ---------- */
  function addCopyButtons(root) {
    root.querySelectorAll('.copyable').forEach((q) => {
      const text = q.textContent.trim().replace(/^[«"]|[»"]$/g, '');
      const b = el('button', 'copy-btn', '📋 Копировать'); b.type = 'button';
      b.onclick = async () => {
        try { await navigator.clipboard.writeText(text); }
        catch (e) { const t = el('textarea'); t.value = text; document.body.appendChild(t); t.select(); try { document.execCommand('copy'); } catch (_) { /* ignore */ } t.remove(); }
        b.textContent = '✔ Скопировано'; setTimeout(() => (b.textContent = '📋 Копировать'), 1500);
      };
      q.appendChild(b);
    });
  }

  /* ---------- таймер (слайд 5) ---------- */
  let timerId = null;
  function initTimer(root) {
    clearInterval(timerId); timerId = null;
    const btn = $('#timerBtn', root), val = $('#timerVal', root);
    if (!btn) return;
    let left = +btn.dataset.timer;
    const fmt = () => { val.textContent = `${String(Math.floor(left / 60)).padStart(2, '0')}:${String(left % 60).padStart(2, '0')}`; };
    btn.onclick = () => {
      if (timerId) { clearInterval(timerId); timerId = null; btn.classList.remove('run'); return; }
      btn.classList.add('run');
      timerId = setInterval(() => {
        left--; fmt();
        if (left <= 0) { clearInterval(timerId); timerId = null; btn.textContent = '⏰ Время вышло!'; }
      }, 1000);
    };
  }

  /* ---------- навигация ---------- */
  const go = (i) => { if (i === state.i && area.children.length) return; render(i, i >= state.i ? 1 : -1); };
  $('#prev').onclick = () => go(state.i - 1);
  $('#next').onclick = () => go(state.i + 1);
  $('#btnBuild').onclick = openBuild;
  $('#mClose').onclick = closeBuild;
  $('#modal').addEventListener('click', (e) => { if (e.target.id === 'modal') closeBuild(); });
  const askReset = () => { $('#confirm').hidden = false; $('#cfNo').focus(); };
  const doReset = () => {
    state = { done: {}, data: {}, i: 0 }; save();
    $('#confirm').hidden = true; closeBuild(); closeFinal();
    $('#lesson').hidden = true;
    history.replaceState(null, '', '#1');
    render(0, -1);
  };
  $('#btnReset').onclick = askReset;
  $('#btnResetTop').onclick = askReset;
  $('#cfNo').onclick = () => { $('#confirm').hidden = true; };
  $('#cfYes').onclick = doReset;
  $('#confirm').addEventListener('click', (e) => { if (e.target.id === 'confirm') $('#confirm').hidden = true; });
  const toggleFull = () => { if (document.fullscreenElement) document.exitFullscreen(); else document.documentElement.requestFullscreen?.(); };
  $('#btnFull').onclick = toggleFull;
  const toggleTheme = () => {
    const next = document.documentElement.dataset.theme === 'light' ? 'dark' : 'light';
    document.documentElement.dataset.theme = next;
    try { localStorage.setItem('boblox-theme', next); } catch (e) {}
  };
  $('#btnTheme').onclick = toggleTheme;

  document.addEventListener('keydown', (e) => {
    if (!$('#confirm').hidden) { if (e.key === 'Escape') $('#confirm').hidden = true; return; }
    if (!$('#lesson').hidden) return;
    if (e.target.matches('input, textarea, select')) { if (e.key === 'Escape') e.target.blur(); return; }
    if (e.metaKey || e.ctrlKey || e.altKey) return;
    if (!$('#final').hidden) { if (e.key === 'Escape') closeFinal(); return; }
    if (e.key === 'ArrowRight' || e.key === 'PageDown' || e.key === ' ') { e.preventDefault(); go(state.i + 1); }
    else if (e.key === 'ArrowLeft' || e.key === 'PageUp') go(state.i - 1);
    else if (e.key === 'Home') go(0);
    else if (e.key === 'End') go(total - 1);
    else if (e.key === 'Enter' && !e.target.matches('button')) { if (currentBtn && !currentBtn.disabled) currentBtn.click(); }
    else if (e.key === 'g' || e.key === 'G' || e.key === 'п' || e.key === 'П') $('#modal').hidden ? openBuild() : closeBuild();
    else if (e.key === 'f' || e.key === 'F' || e.key === 'а' || e.key === 'А') toggleFull();
    else if (e.key === 't' || e.key === 'T' || e.key === 'е' || e.key === 'Е') toggleTheme();
    else if (e.key === 'Escape') { closeBuild(); closeFinal(); }
  });

  // свайпы
  let tx = null, ty = null;
  document.addEventListener('touchstart', (e) => { tx = e.touches[0].clientX; ty = e.touches[0].clientY; }, { passive: true });
  document.addEventListener('touchend', (e) => {
    if (tx == null || e.target.closest('input, textarea, select, .modal')) return;
    const dx = e.changedTouches[0].clientX - tx, dy = e.changedTouches[0].clientY - ty;
    if (Math.abs(dx) > 70 && Math.abs(dx) > Math.abs(dy) * 1.5) go(state.i + (dx < 0 ? 1 : -1));
    tx = null;
  }, { passive: true });

  window.addEventListener('hashchange', () => { const n = parseInt(location.hash.slice(1), 10); if (n >= 1 && n <= total && n - 1 !== state.i) go(n - 1); });

  /* ---------- масштабирование сцены 1280×720 ---------- */
  // Телефон / планшет вертикально: обычная адаптивная вёрстка (css/mobile.css). Широкий экран: сцена 1280×720 с масштабом.
  const isMobile = () => innerWidth < 640 || innerWidth / innerHeight < 1.1;
  function fit() {
    const m = isMobile();
    document.documentElement.classList.toggle('m', m);
    if (m) { stage.style.transform = ''; return; }
    const sc = Math.min(innerWidth / W, innerHeight / H);
    stage.style.transform = `translate(-50%, -50%) scale(${sc})`;
  }
  addEventListener('resize', fit); fit();

  /* ---------- API для урока Lua ---------- */
  window.JAM = {
    get state() { return state; },
    save, burst, runLua,
    refresh() { refreshers.forEach((f) => f()); updateButton(SLIDES[state.i], state.i); },
    autoClaim() { if (actionOk(SLIDES[state.i]) && !isDone(state.i)) claim(state.i); },
  };

  /* ---------- старт ---------- */
  const fromHash = parseInt(location.hash.slice(1), 10);
  const startRender = () => render(fromHash >= 1 && fromHash <= total ? fromHash - 1 : state.i || 0);
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', startRender); else startRender();
})();
