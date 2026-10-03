/* Интерфейс урока Lua (в стиле Duolingo). Требует window.JAM из app.js и LESSONS из lessons.js */
(() => {
  'use strict';
  const J = window.JAM;
  const root = document.getElementById('lesson');
  const el = (tag, cls, html) => { const e = document.createElement(tag); if (cls) e.className = cls; if (html != null) e.innerHTML = html; return e; };

  let id = null, L = null, st = null;
  let idx = 0, phase = 'ask', tries = 0, firstTry = true, xp = 0;
  let pick = null;      // choice: номер варианта
  let slots = [];       // fill: слова в пропусках
  let chosen = [];      // order: выбранные строки
  let typed = '';       // type: введённый текст
  let outText = '';

  const stepNow = () => L.steps[idx];
  const norm = (s) => s.replace(/\s+/g, ' ').trim();
  const sub = (code) => code.replace(/\{\{(\w+)\}\}/g, (_, k) => J.state.data[k] || (L.defaults && L.defaults[k]) || '…');
  const fullText = (s) => (s.wrap ? s.wrap[0] + typed.trim() + s.wrap[1] : typed.trim());

  /* ---------- открыть / закрыть ---------- */
  function open(lessonId) {
    id = lessonId; L = LESSONS[id];
    const data = J.state.data;
    st = data['lesson_' + id] = data['lesson_' + id] || { step: 0, xp: 0, done: false };
    if (st.done || st.step >= L.steps.length) { st.step = 0; st.xp = 0; } // повтор урока
    idx = st.step; xp = st.xp;
    resetStep();
    root.hidden = false;
    render();
  }
  function close() {
    root.hidden = true;
    J.save();
    J.refresh();
  }
  function resetStep() { phase = 'ask'; tries = 0; firstTry = true; pick = null; chosen = []; typed = ''; outText = ''; slots = []; }

  /* ---------- проверка ответа ---------- */
  function isReady(s) {
    if (s.type === 'choice') return pick !== null;
    if (s.type === 'fill') return slots.length && slots.every(Boolean);
    if (s.type === 'order') return chosen.length === s.lines.length;
    if (s.type === 'type') return typed.trim().length > 0;
    return true;
  }
  function isCorrect(s) {
    if (s.type === 'choice') return pick === s.answer;
    if (s.type === 'fill') return slots.every((w, k) => w === s.answer[k]);
    if (s.type === 'order') return chosen.every((l, k) => l === s.lines[k]);
    if (s.type === 'type') return new RegExp(s.check).test(typed.trim());
    return true;
  }
  const answerText = (s) => {
    if (s.type === 'choice') return s.options[s.answer];
    if (s.type === 'fill') return s.answer.join('  ·  ');
    if (s.type === 'order') return s.lines.map((l) => l.trim()).join('\n');
    if (s.type === 'type') return s.wrap ? (s.placeholder || '') : s.check === '^end$' ? 'end' : s.check === '^end\\)$' ? 'end)' : (s.placeholder || '');
    return '';
  };

  function check() {
    const s = stepNow();
    if (s.type === 'learn') return next();
    if (!isReady(s)) return;
    if (isCorrect(s)) {
      phase = 'ok';
      if (firstTry) { xp += 10; st.xp = xp; } else { xp += 5; st.xp = xp; }
      if (s.type === 'type' && s.save) J.state.data[s.save] = s.save === 'lua' ? fullText(s) : typed.trim();
      if (s.run) outText = J.runLua(fullText(s)).text;
      else if (s.outFmt) outText = s.outFmt.replace('{}', typed.trim());
      else if (s.showOut) outText = typed.trim();
      else if (s.out) outText = s.out;
      J.burst(14);
    } else {
      tries++; firstTry = false;
      phase = tries >= 2 ? 'reveal' : 'bad';
      if (phase === 'reveal') { if (s.type === 'fill') slots = s.answer.slice(); if (s.type === 'order') chosen = s.lines.slice(); if (s.type === 'choice') pick = s.answer; }
    }
    render();
  }

  function retry() {
    const s = stepNow();
    phase = 'ask';
    if (s.type === 'choice') pick = null;
    if (s.type === 'fill') slots = new Array(s.answer.length).fill(null);
    if (s.type === 'order') chosen = [];
    render();
  }

  function next() {
    idx++;
    st.step = Math.min(idx, L.steps.length); J.save();
    resetStep();
    if (idx >= L.steps.length) { phase = 'summary'; J.burst(120); }
    render();
  }

  function claim() {
    st.done = true; st.step = L.steps.length; J.save();
    root.hidden = true;
    J.refresh();
    J.autoClaim();
  }

  /* ---------- рендер ---------- */
  function render() {
    root.innerHTML = '';
    const total = L.steps.length;
    const head = el('div', 'l-head');
    const x = el('button', 'icon-btn', '✕'); x.title = 'Закрыть (прогресс сохранится)'; x.onclick = close;
    const bar = el('div', 'l-bar');
    for (let k = 0; k < total; k++) bar.appendChild(el('i', k < idx || phase === 'summary' ? 'on' : (k === idx && phase === 'ok' ? 'on' : (k === idx ? 'cur' : ''))));
    head.append(x, bar, el('div', 'l-xp', `⭐ ${xp}`));
    root.appendChild(head);

    const main = el('div', 'l-main');
    root.appendChild(main);
    const foot = el('div', 'l-foot');
    root.appendChild(foot);

    if (phase === 'summary') return renderSummary(main, foot);

    const s = stepNow();
    main.appendChild(el('div', 'l-tag', `🧪 ТРЕНАЖЁР LUA · шаг ${idx + 1} из ${total} · <span>это не Roblox Studio</span>`));
    main.appendChild(el('h2', 'l-title', s.title));
    if (s.text) main.appendChild(el('p', 'l-text', s.text));
    const nl = (t) => (t ? t.split('\n').length : 0);
    if ((s.type === 'choice' && nl(s.code) >= 3) || (s.type === 'order' && s.lines.length >= 4) || (s.example && nl(s.example.code) >= 5) || nl(s.code) >= 5 || nl(s.out) >= 3) main.classList.add('dense');
    if (s.example) { main.classList.add('has-ex'); exampleBox(main, s.example); }

    if (s.type === 'learn') codeBlock(main, sub(s.code), s.copy);
    if (s.type === 'learn' && s.out) outBox(main, s.out);

    if (s.type === 'choice') {
      if (s.code) codeBlock(main, s.code);
      const opts = el('div', 'l-opts');
      s.options.forEach((o, k) => {
        const b = el('button', `l-opt ${pick === k ? 'sel' : ''} ${phase !== 'ask' && k === s.answer && (phase === 'ok' || phase === 'reveal') ? 'right' : ''} ${phase === 'bad' && pick === k ? 'wrong' : ''}`);
        b.append(el('b', '', String(k + 1)), el('span', '', ''));
        b.lastChild.textContent = o;
        b.disabled = phase === 'ok' || phase === 'reveal';
        b.onclick = () => { pick = k; render(); };
        opts.appendChild(b);
      });
      main.appendChild(opts);
    }

    if (s.type === 'fill') {
      if (!slots.length) slots = new Array(s.answer.length).fill(null);
      const locked = phase === 'ok' || phase === 'reveal';
      if (s.example) main.appendChild(el('div', 'l-ex-label mine', '✍️ Твоя очередь'));
      const pre = el('pre', 'l-code mono');
      let bi = 0;
      s.code.split('\n').forEach((line, li) => {
        const parts = line.split('___');
        const row = el('div', 'cl');
        parts.forEach((p, pi) => {
          row.appendChild(document.createTextNode(p));
          if (pi < parts.length - 1) {
            const k = bi++;
            const b = el('button', `blank ${slots[k] ? 'filled' : ''} ${phase === 'bad' ? 'wrong' : ''} ${phase === 'ok' ? 'right' : ''}`);
            b.textContent = slots[k] || '\u00A0\u00A0\u00A0\u00A0';
            b.disabled = locked;
            b.onclick = () => { if (slots[k]) { slots[k] = null; if (phase === 'bad') phase = 'ask'; render(); } };
            row.appendChild(b);
          }
        });
        if (!line) row.innerHTML = '&nbsp;';
        pre.appendChild(row);
      });
      main.appendChild(pre);
      const bank = el('div', 'l-bank');
      s.bank.forEach((w) => {
        const used = slots.includes(w);
        const b = el('button', `word ${used ? 'used' : ''}`); b.textContent = w; b.disabled = used || locked;
        b.onclick = () => { const k = slots.indexOf(null); if (k >= 0) { slots[k] = w; if (phase === 'bad') phase = 'ask'; render(); } };
        bank.appendChild(b);
      });
      main.appendChild(bank);
      if (phase === 'ok' && outText) outBox(main, outText);
    }

    if (s.type === 'order') {
      const locked = phase === 'ok' || phase === 'reveal';
      const ans = el('div', `l-order-ans ${phase === 'bad' ? 'wrong' : ''} ${phase === 'ok' ? 'right' : ''}`);
      for (let k = 0; k < s.lines.length; k++) {
        const line = chosen[k];
        const b = el('button', `ol ${line ? 'filled' : ''}`); b.disabled = !line || locked;
        b.textContent = line || `${k + 1}`;
        if (line) b.onclick = () => { chosen.splice(k, 1); if (phase === 'bad') phase = 'ask'; render(); };
        ans.appendChild(b);
      }
      main.appendChild(ans);
      const pool = el('div', 'l-bank order');
      s.scramble.forEach((si) => {
        const line = s.lines[si];
        const used = chosen.includes(line);
        const b = el('button', `word mono ${used ? 'used' : ''}`); b.textContent = line.trim(); b.disabled = used || locked;
        b.onclick = () => { chosen.push(line); if (phase === 'bad') phase = 'ask'; render(); };
        pool.appendChild(b);
      });
      main.appendChild(pool);
    }

    if (s.type === 'type') {
      const locked = phase === 'ok' || phase === 'reveal';
      const inp = el('input', `l-input mono ${phase === 'bad' ? 'wrong' : ''} ${phase === 'ok' ? 'right' : ''}`);
      inp.type = 'text'; inp.value = typed; inp.placeholder = s.placeholder || ''; inp.spellcheck = false; inp.autocomplete = 'off'; inp.maxLength = 40;
      inp.disabled = locked;
      inp.oninput = () => { typed = inp.value; if (phase === 'bad') phase = 'ask'; syncButton(); };
      if (s.wrap) {
        if (s.example) main.appendChild(el('div', 'l-ex-label mine', '✍️ Твоя очередь'));
        const pre = el('pre', 'l-code mono inline');
        inp.size = Math.max(10, (s.placeholder || '').length + 2);
        pre.append(document.createTextNode(s.wrap[0]), inp, document.createTextNode(s.wrap[1]));
        main.appendChild(pre);
      } else {
        if (s.code) codeBlock(main, s.code, false, true);
        main.appendChild(inp);
      }
      if (phase === 'ok' && outText) outBox(main, outText);
      if (phase === 'ask' && !locked) setTimeout(() => inp.focus(), 30);
    }

    renderFooter(foot, s);
  }

  function codeBlock(parent, code, copy, open) {
    const wrap = el('div', 'l-codewrap');
    const pre = el('pre', 'l-code mono'); pre.textContent = code;
    const nlines = code.split('\n').length;
    if (nlines > 7) pre.classList.add('long');
    if (nlines > 10) pre.classList.add('xlong');
    wrap.appendChild(pre);
    if (open) pre.classList.add('open');
    if (copy) {
      const b = el('button', 'copy-btn', '📋 Копировать скрипт'); b.type = 'button';
      b.onclick = async () => {
        try { await navigator.clipboard.writeText(code); } catch (e) { const t = el('textarea'); t.value = code; document.body.appendChild(t); t.select(); try { document.execCommand('copy'); } catch (_) { /* ignore */ } t.remove(); }
        b.textContent = '✔ Скопировано'; setTimeout(() => (b.textContent = '📋 Копировать скрипт'), 1500);
      };
      wrap.appendChild(b);
    }
    parent.appendChild(wrap);
  }
  function exampleBox(parent, ex) {
    const box = el('div', 'l-example');
    box.appendChild(el('div', 'l-ex-label', `👀 ${ex.label || 'Пример'}`));
    const pre = el('pre', 'l-code mono ex');
    ex.code.split('\n').forEach((line, k) => {
      const row = el('div', `cl ${ex.mark && ex.mark.includes(k) ? 'hl' : ''}`);
      row.textContent = line || '\u00A0';
      pre.appendChild(row);
    });
    box.appendChild(pre);
    parent.appendChild(box);
  }
  function outBox(parent, text) { const o = el('pre', 'l-out mono'); o.textContent = '▶ ' + text; parent.appendChild(o); }

  let mainBtn = null;
  function syncButton() { if (mainBtn && phase === 'ask') mainBtn.disabled = !isReady(stepNow()); }

  function renderFooter(foot, s) {
    foot.className = `l-foot ${phase}`;
    const msg = el('div', 'l-msg');
    const btn = el('button', 'btn l-btn');
    mainBtn = btn;
    if (s.type === 'learn') {
      btn.textContent = 'Понятно ›'; btn.onclick = next;
    } else if (phase === 'ask') {
      btn.textContent = 'Проверить'; btn.disabled = !isReady(s); btn.onclick = check;
    } else if (phase === 'ok') {
      msg.innerHTML = `<b>✅ ${firstTry ? 'Верно! +10 ⭐' : 'Верно! +5 ⭐'}</b>${s.explain ? `<span>${s.explain}</span>` : ''}`;
      btn.textContent = 'Дальше ›'; btn.onclick = next;
    } else if (phase === 'bad') {
      msg.innerHTML = `<b>❌ Почти! Попробуй ещё раз</b><span>💡 ${s.hint || 'Прочитай пример выше ещё раз.'}</span>`;
      btn.textContent = 'Ещё раз'; btn.onclick = retry;
    } else if (phase === 'reveal') {
      msg.innerHTML = `<b>🧠 Правильный ответ:</b><span class="mono ans"></span>`;
      msg.querySelector('.ans').textContent = answerText(s);
      btn.textContent = 'Дальше ›'; btn.onclick = next;
    }
    foot.append(msg, btn);
  }

  function renderSummary(main, foot) {
    foot.className = 'l-foot ok';
    main.classList.add('summary');
    main.appendChild(el('div', 'l-trophy', '🏆'));
    main.appendChild(el('h2', 'l-title', 'Урок пройден!'));
    main.appendChild(el('p', 'l-text', `${L.title}<br>Твои очки: <b>⭐ ${xp}</b> из ${L.steps.filter((s) => s.type !== 'learn').length * 10}`));
    main.appendChild(el('p', 'l-text small', L.summary || 'Скрипт готов. Скопируй его в Roblox Studio и проверь в Play!'));
    const btn = el('button', 'btn l-btn', 'Забрать блок 🎁'); btn.onclick = claim;
    foot.append(el('div', 'l-msg', '<b>🎉 Отличная работа!</b>'), btn);
  }

  root.addEventListener('click', (e) => e.stopPropagation());
  document.addEventListener('keydown', (e) => {
    if (root.hidden) return;
    if (e.key === 'Escape') { close(); e.stopPropagation(); }
    else if (e.key === 'Enter' && mainBtn && !mainBtn.disabled && !e.isComposing) { e.preventDefault(); mainBtn.click(); }
  }, true);

  window.Lesson = { open, progress: (lid) => { const d = J.state.data['lesson_' + lid]; return d || { step: 0, xp: 0, done: false }; } };
})();
