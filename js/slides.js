/* Данные презентации: 25 слайдов (День 1 = слайды 1–16, День 2 = 17–25).
   ВАЖНО: переключатель DAYS_ENABLED ниже. 1 = только День 1 (+ итоговый слайд), 2 = полная презентация.
   У каждого слайда: section, title, body (HTML), action (что сделать), reward (какую часть игры получишь).

   Типы полей действия (action.fields):
     text      — одна строка            {key, label, placeholder, min}
     area      — несколько строк        {key, label, placeholder, words}
     select    — выпадающий список      {key, label, options}
     chips     — выбор кнопками         {key, options, min, max}
     checklist — список галочек         {key, items}
     code      — мини-редактор Lua      {key}
   field.slot — если указан, поле рисуется внутри тела слайда в <div data-slot="...">.
   data-bind="key" в теле слайда — подставляет ответы ребёнка прямо в слайд. */

const DAYS_ENABLED = 1;   // ← поставь 2, чтобы вернуть День 2

/* Порядок слайдов (по id). Прогресс хранится по id, поэтому слайды можно вставлять и менять местами. */
const DAY1_IDS = ['cover', 'mission', 'howto', 'plan', 'team', 'concept', 'title', 'genre', 'inspiration', 'aisafe', 'aicoauthor', 'prompt',
  'world', 'map', 'style', 'studio', 'windows', 'parts', 'build', 'robloxai', 'scriptwhere', 'lua', 'ailua'];
const DAY2_IDS = ['day2', 'cutscene', 'mechanic', 'feature', 'secret', 'final', 'devstand', 'test', 'finale'];
const ORDER = DAYS_ENABLED >= 2 ? [...DAY1_IDS, ...DAY2_IDS] : [...DAY1_IDS, 'day1finale'];
const TOTAL = ORDER.length;

const SECTIONS = {
  day1end: { name: '🏁 ИТОГ ДНЯ 1',                color: '#ffc531' },
  intro:  { name: 'СТАРТ',                       color: '#ffc531' },
  day1:   { name: '🟦 ДЕНЬ 1 — СОЗДАЁМ',          color: '#3b8cff' },
  studio: { name: '🟩 ПЕРЕХОД В ROBLOX STUDIO',   color: '#27d96b' },
  day2:   { name: '🟪 ДЕНЬ 2 — ЗАПУСКАЕМ',        color: '#b05cff' },
  end:    { name: '🏁 ФИНАЛ',                     color: '#ffc531' },
};

const vplan = (arr) => `<div class="vplan">${arr.map(([n, t, d]) => `<div class="vp-item"><b>${n}</b><span>${t}</span><em>${d}</em></div>`).join('<div class="vp-arrow"></div>')}</div>`;
/* ИИ-помощники: Алиса и ГигаЧат */
const AI_LINKS = [
  { name: 'Алиса', url: 'https://alice.yandex.ru', show: 'alice.yandex.ru', img: 'assets/ai/alice.png', cls: 'alice' },
  { name: 'ГигаЧат', url: 'https://giga.chat', show: 'giga.chat', img: 'assets/ai/gigachat.jpg', cls: 'giga' },
];
const aiCards = () => `<div class="ai-cards">${AI_LINKS.map((a) => `<a class="ai-card ${a.cls}" href="${a.url}" target="_blank" rel="noopener"><span class="ai-logo"><img src="${a.img}" alt="${a.name}"></span><span class="ai-t"><b>${a.name}</b><span class="mono">${a.show}</span></span><span class="ai-go">Открыть ↗</span></a>`).join('')}</div>`;
const aiMini = (text) => `<p class="ai-mini">${text} ${AI_LINKS.map((a) => `<a href="${a.url}" target="_blank" rel="noopener"><img src="${a.img}" alt="">${a.name}</a>`).join('')}</p>`;
const q = (t) => `<div class="quote copyable">${t}</div>`;
const tiles = (arr, cls = '') => `<div class="tiles ${cls}">${arr.map(([i, t]) => `<div class="tile"><span class="ti">${i}</span><span>${t}</span></div>`).join('')}</div>`;

const ALL_SLIDES = [
  /* 1 */ {
    id: 'cover',
    section: 'intro', cover: true, title: 'Обложка',
    body: `
      <div class="cover-wrap">
        <div class="cover">
          <div class="cover-logo">ROBLOX<br><span>GAME JAM</span></div>
          <div class="cover-sub">СОЗДАЙ СВОЮ ИГРУ ЗА 2 ДНЯ</div>
          <div class="pill mono">Roblox Studio × Lua × AI</div>
          <div class="cover-days">
            <div class="day-card d1"><b>День 1</b><span>СОЗДАЁМ</span></div>
            <div class="day-card d2 ${DAYS_ENABLED >= 2 ? '' : 'soon'}"><b>День 2</b><span>ЗАПУСКАЕМ${DAYS_ENABLED >= 2 ? '' : ' · скоро'}</span></div>
          </div>
        </div>
        <div class="cover-right">
        <div class="license" data-done="cover">
          <div class="lic-head"><span>▣ ROBLOX GAME JAM</span><b>DEVELOPER LICENSE</b></div>
          <div class="lic-body">
            <div class="lic-chip"><i></i><i></i><i></i></div>
            <div class="lic-info">
              <div class="lic-label">ИМЯ РАЗРАБОТЧИКА</div>
              <div class="lic-name" data-bind="creator" data-fallback="ТВОЁ ИМЯ"></div>
              <div class="lic-row"><i>УРОВЕНЬ</i><span>JUNIOR DEVELOPER</span></div>
              <div class="lic-row"><i>НОМЕР</i><span class="mono" data-bind="licId"></span></div>
              <div class="lic-row"><i>ДАТА</i><span data-bind="licDate"></span></div>
            </div>
          </div>
          <div class="lic-stripe"></div>
          <div class="lic-pending">🔒 НЕ АКТИВИРОВАНА — впиши имя внизу</div>
          <div class="lic-stamp">АКТИВИРОВАНА ✔</div>
        </div>
          <div class="cover-form">
            <div class="cf-row">
              <div class="cf-label"><b>✍</b> ВПИШИ СВОЁ ИМЯ <u>— оно появится в лицензии ☝</u></div>
              <div data-slot="name"></div>
            </div>
          </div>
        </div>
      </div>`,
    action: {
      text: 'Представься! Впиши своё имя в жёлтое поле — оно появится в твоей лицензии разработчика, а потом и в титрах игры.',
      fields: [
        { type: 'text', slot: 'name', key: 'creator', placeholder: 'Нажми сюда и напиши имя', min: 2 },
      ],
    },
    reward: { icon: '🪪', name: 'Лицензия разработчика' },
  },

  /* 2 */ {
    id: 'mission',
    section: 'intro', title: 'Твоя миссия',
    body: `
      <h2>🎯 ТВОЯ МИССИЯ</h2>
      <div class="m-goal">Создать <b>собственную игру</b> за 2 дня</div>
      <div class="mpath">
        ${[['💡', 'Придумать'], ['🎨', 'Спроектировать'], ['💻', 'Создать'], ['🤖', 'Позвать ИИ'], ['🧪', 'Проверить'], ['🚀', 'Опубликовать']]
          .map(([i, t], k) => `<div class="mnode${k >= 4 && DAYS_ENABLED < 2 ? ' later' : ''}${k === 5 ? ' last' : ''}"><div class="mc"><i>${k + 1}</i>${i}</div><span>${t}</span></div>`).join('')}
        <div class="mday d1">ДЕНЬ 1 · СОЗДАЁМ</div>
        <div class="mday d2${DAYS_ENABLED < 2 ? ' later' : ''}">ДЕНЬ 2 · ЗАПУСКАЕМ</div>
      </div>
      <div class="m-now">Собрано блоков: <b data-bind="blocks"></b></div>`,
    action: {
      text: `Прочитай миссию вслух. Принимаешь вызов? Тогда нажми кнопку — это твой первый шаг к ${TOTAL}/${TOTAL}.`,
      button: 'Принимаю миссию!',
      fields: [],
    },
    reward: { icon: '📜', name: 'Миссия принята' },
  },

  /* 3 */ {
    id: 'plan',
    section: 'day1', title: 'План дня',
    body: `
      <h2>План дня</h2>
      ${vplan([['01', 'Концепция', 'придумываем идею игры'], ['02', 'Поиск вдохновения', 'смотрим, как делают другие'], ['03', 'Дизайн мира', 'решаем, как всё выглядит'],
        ['04', 'Roblox Studio', 'открываем программу и строим'], ['05', 'Первая механика', 'игрок что-то делает в игре'], ['06', 'AI + Lua', 'пишем код вместе с ИИ']])}`,
    action: {
      text: 'Прочитай 6 шагов вслух сверху вниз и скажи: «Я готов!»',
      button: 'Я готов!',
      fields: [],
    },
    reward: { icon: '🧭', name: 'Компас дня' },
  },

  /* 4 */ {
    id: 'concept',
    section: 'day1', title: 'Что такое концепт?',
    body: `
      <h2>Концепт — это идея игры до её создания.</h2>
      <p class="lead">Ответь на 7 вопросов:</p>
      <div class="qa">
        ${[['Что?', 'что за игра?'], ['Где?', 'где происходит действие?'], ['Кто?', 'кто главный герой?'], ['Зачем?', 'что нужно сделать?'], ['Как?', 'как игрок играет?'], ['Почему?', 'зачем ему продолжать?'], ['Что особенного?', 'твоя фишка.']].map(([a, b]) => `<div class="qa-item"><b>${a}</b><span>— ${b}</span></div>`).join('')}
      </div>`,
    action: {
      text: 'Ответь на первый вопрос «Что?» — одним предложением опиши свою игру.',
      fields: [{ type: 'text', key: 'what', label: 'Моя игра — это…', placeholder: 'Хоррор-приключение в заброшенной лаборатории', min: 6 }],
    },
    reward: { icon: '🧠', name: 'Ядро идеи' },
  },

  /* 5 */ {
    id: 'title',
    section: 'day1', title: 'Создаём концепт',
    body: `
      <h2>📝 Создаём концепт <small>РАБОТА НА ЛИСТЕ</small></h2>
      <p class="lead">Запиши:</p>
      <ol class="nlist two">
        <li>🎮 Название</li><li>🕹 Жанр</li><li>📖 Сюжет</li><li>🌍 Место действия</li>
        <li>🎯 Главную цель</li><li>⭐ Уникальную механику</li><li>🔐 Секретку</li>
      </ol>
      <div class="timer-row"><b>Время: 30 минут</b>
        <button class="btn small" id="timerBtn" data-timer="1800">⏱ Запустить таймер <span class="mono" id="timerVal">30:00</span></button>
      </div>`,
    action: {
      text: 'Придумай название своей игры — оно появится на обложке и в Dev Stand.',
      fields: [{ type: 'text', key: 'title', label: 'Название игры', placeholder: 'Например: Побег из Лаборатории 13', min: 2 }],
    },
    reward: { icon: '🎮', name: 'Название игры' },
  },

  /* 6 */ {
    id: 'genre',
    section: 'day1', title: 'Жанр',
    body: `
      <h2>Жанр</h2>
      <p class="lead">Примеры — посмотри на игры, которые тебя вдохновят, и <b>нажми на карточки</b>:</p>
      <div data-slot="genres"></div>
      <p class="callout genre-sel"><b>Можно смешать несколько жанров.</b> Твой выбор: <span class="sel" data-bind="genre" data-fallback="пока ничего"></span></p>`,
    action: {
      text: 'Прочитай примеры и нажми на карточки: выбери от 1 до 3 жанров. Смешивай!',
      fields: [{
        type: 'cards', slot: 'genres', key: 'genre', min: 1, max: 3,
        options: [
          { icon: '🏃', name: 'Obby', img: 'assets/genres/obby.jpg', shot: 'Tower of Hell', desc: 'Прыгай и обходи ловушки', roblox: 'Tower of Hell, Mega Easy Obby', other: 'Super Mario' },
          { icon: '🔎', name: 'Adventure', img: 'assets/genres/adventure.jpg', shot: 'Piggy', desc: 'Исследуй мир и секреты', roblox: 'Piggy, Jailbreak', other: 'The Legend of Zelda' },
          { icon: '👻', name: 'Horror', img: 'assets/genres/horror.jpg', shot: 'Doors', desc: 'Страшно, тёмно, интересно', roblox: 'Doors, The Mimic', other: 'Five Nights at Freddy\'s' },
          { icon: '🧩', name: 'Puzzle', img: 'assets/genres/puzzle.jpg', shot: 'Terminal Escape Room', desc: 'Думай, ищи, разгадывай', roblox: 'Escape Room, Flood Escape 2', other: 'Portal' },
          { icon: '⚔️', name: 'Action', img: 'assets/genres/action.jpg', shot: 'Rivals', desc: 'Бои и быстрая реакция', roblox: 'Rivals, Arsenal', other: 'Super Smash Bros.' },
          { icon: '🏗', name: 'Simulator', img: 'assets/genres/simulator.jpg', shot: 'Pet Simulator 99', desc: 'Собирай и прокачивайся', roblox: 'Pet Simulator 99, Bee Swarm', other: 'Stardew Valley' },
          { icon: '🌎', name: 'Survival', img: 'assets/genres/survival.jpg', shot: 'Natural Disaster Survival', desc: 'Выживи любой ценой', roblox: 'Natural Disaster Survival, 99 Nights in the Forest', other: 'Minecraft' },
          { icon: '🎭', name: 'Story', img: 'assets/genres/story.jpg', shot: 'Barry\'s Prison Run', desc: 'Игра как кино с сюжетом', roblox: 'Barry\'s Prison Run', other: 'Undertale' },
        ],
      }],
    },
    reward: { icon: '🕹', name: 'Жанр игры' },
  },

  /* 7 */ {
    id: 'inspiration',
    section: 'day1', title: 'Где взять идею?',
    body: `
      <h2>💡 Где взять идею?</h2>
      <p class="lead">Ищи вдохновение:</p>
      <div class="chips-static">${['Roblox', 'YouTube', 'Pinterest', 'игры', 'фильмы', 'мультфильмы', 'реальный мир'].map((t) => `<span>${t}</span>`).join('')}</div>
      <p class="warn">⚠️ Не копируй — комбинируй.</p>
      ${q('«Что будет, если соединить X + Y + Z?»')}`,
    action: {
      text: 'Соедини 3 вещи в одну идею: игру + фильм + место, например.',
      fields: [{ type: 'text', key: 'mix', label: 'X + Y + Z', placeholder: 'Лаборатория + Побег + Неон', min: 5 }],
    },
    reward: { icon: '💡', name: 'Искра идеи' },
  },

  /* 8 */ {
    id: 'aicoauthor',
    section: 'day1', title: 'AI как соавтор',
    body: `
      <h2>🤖 AI как соавтор</h2>
      <p class="lead"><b>Зайди к ИИ</b> — выбери Алису или ГигаЧат и открой в новой вкладке:</p>
      ${aiCards()}
      <p class="lead">Спроси:</p>
      ${q('«Придумай 5 идей игр для Roblox в жанре хоррор, где главная механика связана с поиском предметов.»')}
      <div class="flow"><span>Идея</span>→<span>меняем</span>→<span>добавляем своё</span>→<span class="gold">получаем уникальную игру</span></div>`,
    action: {
      text: 'Зайди в Алису или ГигаЧат, спроси ИИ (скопируй промпт кнопкой 📋). Запиши одну идею, которую ты изменишь.',
      fields: [{ type: 'text', key: 'aiIdea', label: 'Идея от ИИ, которую я улучшу', placeholder: 'Найти 5 ключей в тёмном подвале', min: 5 }],
    },
    reward: { icon: '🤖', name: 'ИИ-соавтор' },
  },

  /* 9 */ {
    id: 'prompt',
    section: 'day1', title: 'Учимся писать промпт',
    body: `
      <h2>✍️ Учимся писать промпт</h2>
      <div class="vs">
        <div class="vs-card bad"><h3>❌ Плохой промпт</h3>${q('«Придумай игру»')}</div>
        <div class="vs-card good"><h3>✅ Хороший промпт</h3>${q('«Придумай концепцию игры Roblox для подростков 12+, жанр приключение + хоррор. Игрок исследует заброшенную лабораторию и собирает 5 предметов. Добавь необычную механику и секретную комнату.»')}</div>
      </div>
      <div class="formula mono">КТО + ЧТО + ЖАНР + УСЛОВИЯ + РЕЗУЛЬТАТ</div>
      ${aiMini('Проверь свой промпт в:')}`,
    action: {
      text: 'Напиши СВОЙ хороший промпт по формуле (минимум 10 слов).',
      fields: [{ type: 'area', key: 'prompt', label: 'Мой промпт', placeholder: 'Придумай концепцию игры Roblox для …', words: 10 }],
    },
    reward: { icon: '✍️', name: 'Промпт-заклинание' },
  },

  /* 10 */ {
    id: 'world',
    section: 'day1', title: 'Дизайн мира',
    body: `
      <h2>🌍 Дизайн мира</h2>
      <p class="lead">Теперь решаем: <b>что игрок увидит?</b></p>
      ${tiles([['🏠', 'здания'], ['🌲', 'природа'], ['🛣', 'дороги'], ['💡', 'освещение'], ['🎨', 'цвета'], ['🪑', 'декор'], ['🚪', 'секретные места']], 'cols4')}`,
    action: {
      text: 'Выбери 3 или больше вещей, которые точно будут в твоём мире.',
      fields: [{ type: 'chips', key: 'world', min: 3, max: 7, options: ['🏠 здания', '🌲 природа', '🛣 дороги', '💡 освещение', '🎨 цвета', '🪑 декор', '🚪 секретные места'] }],
    },
    reward: { icon: '🌍', name: 'Мир игры' },
  },

  /* 11 */ {
    id: 'map',
    section: 'day1', title: 'Нарисуй карту',
    body: `
      <h2>🗺 Нарисуй карту</h2>
      <p class="lead">На листе:</p>
      <div class="route"><span class="r-start">START</span>→<span>ЗОНА 1</span>→<span>ЗОНА 2</span>→<span class="r-end">ФИНАЛ</span></div>
      <p class="lead">Добавь:</p>
      ${tiles([['⭐', 'предмет'], ['⚠️', 'препятствие'], ['🔐', 'секретку'], ['🏁', 'финальную точку']], 'cols4')}
      <p class="callout"><b>Не нужна красивая картинка. Нужен план.</b></p>`,
    action: {
      text: 'Нарисуй карту на листе: START → ЗОНА 1 → ЗОНА 2 → ФИНАЛ. Готово? Жми!',
      button: 'Карта нарисована',
      fields: [],
    },
    reward: { icon: '🗺', name: 'Карта уровня' },
  },

  /* 12 */ {
    id: 'style',
    section: 'day1', title: 'Стиль игры',
    body: `
      <h2>🎨 Стиль игры</h2>
      <p class="lead">Выбери:</p>
      <div class="style-form">
        <div><b>Цвет:</b> <span data-slot="s-color"></span></div>
        <div><b>Атмосфера:</b> <span data-slot="s-mood"></span></div>
        <div><b>Освещение:</b> <span data-slot="s-light"></span></div>
        <div><b>Стиль:</b> <span data-slot="s-style"></span></div>
      </div>
      <p class="lead">Например:</p>
      ${q('Dark + Blue + Neon + Cyberpunk')}
      <div class="style-result mono" data-bind="styleLine" data-fallback="Твой стиль появится здесь"></div>`,
    action: {
      text: 'Выбери все 4 пункта стиля прямо в слайде. Нет подходящего? Выбери «✏️ Свой вариант…» и придумай свой стиль!',
      fields: [
        { type: 'select', custom: true, slot: 's-color', key: 'color', options: ['Синий', 'Красный', 'Зелёный', 'Фиолетовый', 'Жёлтый', 'Чёрно-белый'] },
        { type: 'select', custom: true, slot: 's-mood', key: 'mood', options: ['Таинственная', 'Страшная', 'Весёлая', 'Космическая', 'Уютная', 'Тревожная'] },
        { type: 'select', custom: true, slot: 's-light', key: 'light', options: ['Тусклое', 'Неоновое', 'Лунное', 'Фонарик', 'Яркое'] },
        { type: 'select', custom: true, slot: 's-style', key: 'style', options: ['Киберпанк', 'Фэнтези', 'Хоррор', 'Мультяшный', 'Ретро', 'Sci-Fi'] },
      ],
    },
    reward: { icon: '🎨', name: 'Стиль игры' },
  },

  /* 13 */ {
    id: 'studio',
    section: 'studio', title: 'Roblox Studio',
    body: `
      <h2>Roblox Studio</h2>
      <p class="lead"><b>Что это?</b> Инструмент, в котором мы:</p>
      ${tiles([['🌍', 'строим мир'], ['🎨', 'создаём объекты'], ['⌨️', 'пишем код'], ['🎮', 'создаём механику'], ['🎬', 'делаем катсцены']], 'cols3')}`,
    action: {
      text: 'Открой Roblox Studio → New → Baseplate. Сохрани проект под названием своей игры.',
      button: 'Studio открыта',
      fields: [],
    },
    reward: { icon: '🧰', name: 'Рабочая студия' },
  },

  /* 14 */ {
    id: 'build',
    section: 'studio', title: 'Создаём карту',
    body: `
      <h2>🧱 Создаём карту</h2>
      <p class="lead">По своему эскизу создаём:</p>
      <div class="vflow">
        <div class="vbox start">START</div><div class="arrow">↓</div>
        <div class="vbox">ИГРОВАЯ ЗОНА</div><div class="arrow">↓</div>
        <div class="vbox end">ФИНАЛ</div>
      </div>
      <p class="callout side"><b>Добавляем декор и атмосферу.</b></p>`,
    action: {
      text: 'В Studio поставь три блока: START, игровую зону и ФИНАЛ. Добавь немного декора.',
      button: 'Карта построена',
      fields: [],
    },
    reward: { icon: '🧱', name: 'Карта в 3D' },
  },

  /* 15 */ {
    id: 'lua',
    section: 'studio', title: 'Что такое Lua?',
    body: `
      <h2>⌨️ Что такое Lua? <small>ТРЕНАЖЁР LUA</small></h2>
      <p class="lead"><b>Lua — язык программирования, который используется в Roblox.</b></p>
      <div class="split">
        <div>
          <pre class="demo-code mono">print("Hello!")</pre>
          <div data-slot="lua1"></div>
        </div>
        <div>
          <p class="lead">Мы будем использовать код, чтобы:</p>
          <ul class="ilist"><li>🎯 собирать предметы</li><li>🚪 открывать двери</li><li>⚠️ создавать препятствия</li><li>🎬 запускать события</li></ul>
          <p class="callout trainer-note"><b>Это тренажёр.</b> Настоящий код ты применишь в <b>Roblox Studio</b>.</p>
        </div>
      </div>`,
    action: {
      text: 'Пройди урок Lua. Сначала смотри на пример — потом повтори по примеру. Это легко!',
      fields: [{ type: 'lesson', slot: 'lua1', key: 'lua1', lesson: 'basics' }],
    },
    reward: { icon: '⌨️', name: 'Первая строка кода' },
  },

  /* 16 */ {
    id: 'ailua',
    section: 'studio', title: 'AI + Lua',
    body: `
      <h2>🤖 AI + Lua</h2>
      <p class="lead"><b>Не знаешь, как написать код?</b> Не просто копируй ответ ИИ. Спроси:</p>
      ${q('«Напиши Lua-код для Roblox Studio, который позволяет игроку подобрать предмет. Объясни каждую часть кода простыми словами.»')}
      <div data-slot="lua2"></div>
      ${aiMini('Спрашивай у:')}
      <p class="lead">Потом в Studio: <b>получил → проверил → понял → изменил.</b></p>`,
    action: {
      text: 'Пройди урок 2: смотри на пример и повтори. Потом в Studio отмечай шаги ниже.',
      fields: [
        { type: 'lesson', slot: 'lua2', key: 'lua2', lesson: 'pickup' },
        { type: 'checklist', key: 'luaSteps', inline: true, items: ['Получил', 'Проверил', 'Понял', 'Изменил'] },
      ],
    },
    reward: { icon: '🔧', name: 'Скрипт подбора предмета' },
  },

  /* 17 */ {
    id: 'day2',
    section: 'day2', title: 'День 2',
    body: `
      <h2>🚀 День 2</h2>
      <div class="vs">
        <div class="vs-card"><h3>ВЧЕРА:</h3><div class="flow col"><span>идея</span>→<span>карта</span>→<span>механика</span></div></div>
        <div class="vs-card good"><h3>СЕГОДНЯ:</h3>
          <ul class="ilist"><li>🎬 сюжет</li><li>🎯 геймплей</li><li>⭐ фишка</li><li>🔐 секрет</li><li>🏁 финал</li><li>🚀 публикация</li></ul>
        </div>
      </div>`,
    action: {
      text: 'Открой вчерашний проект в Studio и нажми Play — убедись, что всё на месте.',
      button: 'Проект открыт',
      fields: [],
    },
    reward: { icon: '🚀', name: 'Старт Дня 2' },
  },

  /* 18 */ {
    id: 'cutscene',
    section: 'day2', title: 'Катсцена',
    body: `
      <h2>🎬 Катсцена</h2>
      <p class="lead">Создаём начало:</p>
      <div class="vflow h">
        <div class="vbox start">START</div><div class="arrow">→</div>
        <div class="vbox cine">🎬 КАТСЦЕНА</div><div class="arrow">→</div>
        <div class="vbox end">🎮 ИГРОК НАЧИНАЕТ ИГРАТЬ</div>
      </div>
      <p class="lead">Пример:</p>
      ${q('«Ты просыпаешься в неизвестном месте. Перед тобой дверь...»')}`,
    action: {
      text: 'Напиши текст своей катсцены — 2–3 предложения (минимум 5 слов).',
      fields: [{ type: 'area', key: 'cutscene', label: 'Текст катсцены', placeholder: 'Ты просыпаешься…', words: 5 }],
    },
    reward: { icon: '🎬', name: 'Начальная катсцена' },
  },

  /* 19 */ {
    id: 'mechanic',
    section: 'day2', title: 'Главная механика',
    body: `
      <h2>🎯 Главная механика</h2>
      <p class="lead">Игрок должен что-то делать:</p>
      ${tiles([['🔎', 'искать'], ['🏃', 'убегать'], ['🧩', 'решать'], ['🎯', 'собирать'], ['⚔️', 'сражаться'], ['🔑', 'открывать']], 'cols3')}
      <p class="lead">Твоя игра должна отвечать:</p>
      ${q('«Что игрок делает большую часть времени?»')}`,
    action: {
      text: 'Что игрок делает большую часть времени в твоей игре? Выбери одно.',
      fields: [{ type: 'chips', key: 'mechanic', min: 1, max: 1, options: ['🔎 искать', '🏃 убегать', '🧩 решать', '🎯 собирать', '⚔️ сражаться', '🔑 открывать'] }],
    },
    reward: { icon: '🎯', name: 'Главная механика' },
  },

  /* 20 */ {
    id: 'feature',
    section: 'day2', title: 'Фишка игры',
    body: `
      <h2>⭐ Фишка игры</h2>
      <p class="lead"><b>Что отличает твою игру от других?</b> Примеры:</p>
      <ul class="ilist big">
        <li>🔦 свет привлекает монстра</li><li>🕐 время постоянно уменьшается</li><li>👻 мир меняется после каждого предмета</li>
        <li>🪞 игрок встречает свою копию</li><li>🔐 секретная концовка</li>
      </ul>
      <p class="callout"><b>Придумай свою.</b></p>`,
    action: {
      text: 'Придумай фишку, которой нет ни в одной другой игре.',
      fields: [{ type: 'text', key: 'feature', label: 'Моя фишка', placeholder: 'Тень игрока оживает и преследует его', min: 6 }],
    },
    reward: { icon: '⭐', name: 'Уникальная фишка' },
  },

  /* 21 */ {
    id: 'secret',
    section: 'day2', title: 'Секретка',
    body: `
      <h2>🔐 Секретка</h2>
      <p class="lead">Добавь то, что игрок может <b>не заметить</b>:</p>
      ${tiles([['🔑', 'секретная комната'], ['👀', 'пасхалка'], ['🎁', 'скрытый предмет'], ['🕵️', 'секретный персонаж'], ['🏆', 'альтернативный финал']], 'cols3')}`,
    action: {
      text: 'Выбери тип секретки и спрячь её на карте в Studio.',
      fields: [{ type: 'chips', key: 'secret', min: 1, max: 1, options: ['🔑 комната', '👀 пасхалка', '🎁 предмет', '🕵️ персонаж', '🏆 финал'] }],
    },
    reward: { icon: '🔐', name: 'Секретка' },
  },

  /* 22 */ {
    id: 'final',
    section: 'day2', title: 'Финал',
    body: `
      <h2>🏁 Финал</h2>
      <div class="flow big"><span>ИГРА</span>→<span>ЦЕЛЬ</span>→<span class="gold">ФИНАЛЬНАЯ КАТСЦЕНА</span></div>
      <p class="lead">Игрок должен понимать:</p>
      <div class="bigquote">«Я прошёл игру».</div>`,
    action: {
      text: 'Какую фразу увидит игрок в самом конце игры?',
      fields: [{ type: 'text', key: 'ending', label: 'Финальная фраза', placeholder: 'Ты выбрался из лаборатории. Свобода!', min: 4 }],
    },
    reward: { icon: '🏁', name: 'Финальная сцена' },
  },

  /* 23 */ {
    id: 'devstand',
    section: 'day2', title: 'Стенд разработчиков',
    body: `
      <h2>👩‍💻 Стенд разработчиков</h2>
      <div class="split">
        <div class="devstand">
          <div class="ds-head">DEV STAND</div>
          <div class="ds-row"><b>GAME:</b> <span data-bind="title" data-fallback="Название"></span></div>
          <div class="ds-row"><b>CREATOR:</b> <span data-bind="creator" data-fallback="Имя"></span></div>
          <div class="ds-row"><b>DESIGN:</b> <span data-bind="design" data-fallback="Имя"></span></div>
          <div class="ds-row"><b>CODE:</b> <span data-bind="codeBy" data-fallback="Имя"></span></div>
          <div class="ds-row"><b>AI:</b> <span data-bind="ai" data-fallback="GigaChat / Алиса"></span></div>
        </div>
        <div><p class="lead">Создай свой Dev Stand и поставь его на карте.</p><p class="callout"><b>Можно добавить логотип игры.</b></p></div>
      </div>`,
    action: {
      text: 'Заполни стенд: кто сделал игру. Он сразу появится слева.',
      fields: [
        { type: 'text', key: 'title', label: 'GAME', placeholder: 'Название', min: 2 },
        { type: 'text', key: 'creator', label: 'CREATOR', placeholder: 'Имя', min: 2 },
        { type: 'text', key: 'design', label: 'DESIGN', placeholder: 'Имя', min: 2, optional: true },
        { type: 'text', key: 'codeBy', label: 'CODE', placeholder: 'Имя', min: 2, optional: true },
        { type: 'select', key: 'ai', label: 'AI', options: ['GigaChat', 'Алиса', 'GigaChat / Алиса'] },
      ],
    },
    reward: { icon: '👩‍💻', name: 'Dev Stand' },
  },

  /* 24 */ {
    id: 'test',
    section: 'day2', title: 'Тестирование',
    body: `
      <h2>🧪 Тестирование</h2>
      <p class="lead">Перед публикацией:</p>
      <div data-slot="tests"></div>
      <p class="callout"><b>Поиграй в свою игру как обычный игрок.</b></p>`,
    action: {
      text: 'Проверь игру в Studio и отметь все 8 пунктов — честно!',
      fields: [{ type: 'checklist', slot: 'tests', key: 'tests', cols: 2, items: ['Игра запускается', 'Меню работает', 'Катсцена работает', 'Предмет собирается', 'Препятствие работает', 'Есть секретка', 'Есть финал', 'Нет критических ошибок'] }],
    },
    reward: { icon: '🧪', name: 'Печать качества' },
  },

  /* 25 */ {
    id: 'finale',
    section: 'end', title: 'Финал', final: true,
    finalCfg: {
      head: '🎉 GAME COMPLETE', rank: '12+ GAME DEVELOPER', quote: 'Ты прошёл путь от идеи до игры.',
      cells: [['🎮 Жанр', 'genre'], ['🎨 Стиль', 'styleLine'], ['⭐ Фишка', 'feature'], ['🔐 Секретка', 'secret'], ['⌨️ Lua', 'luaLine', 'mono'], ['🤖 AI', 'ai']],
    },
    body: `
      <div class="final-wrap">
        <div class="final-left">
          <div class="cover-sub">ТЫ СОЗДАЛ ИГРУ</div>
          <div class="formula mono">IDEA → DESIGN → CODE → TEST → GAME</div>
          <p class="final-big">🎮 Теперь ты не просто игрок.<br><b>Ты — разработчик.</b></p>
          <button class="btn open-final" id="openFinal" disabled>🎉 Открыть финальный экран</button>
        </div>
        <div class="gamecard" id="gameCard">
          <div class="gc-top">ТВОЯ ИГРА</div>
          <div class="gc-title" data-bind="title" data-fallback="Без названия"></div>
          <div class="gc-by">by <span data-bind="creator" data-fallback="Разработчик"></span></div>
          <div class="gc-grid">
            <div><i>Жанр</i><span data-bind="genre" data-fallback="—"></span></div>
            <div><i>Стиль</i><span data-bind="styleLine" data-fallback="—"></span></div>
            <div><i>Механика</i><span data-bind="mechanic" data-fallback="—"></span></div>
            <div><i>Фишка</i><span data-bind="feature" data-fallback="—"></span></div>
          </div>
          <div class="gc-bar"><div class="gc-fill" id="gcFill"></div></div>
          <div class="gc-blocks">ТВОЯ ИГРА СОБРАНА НА <span data-bind="pct"></span></div>
        </div>
      </div>`,
    action: {
      text: 'Собери все блоки и опубликуй игру — откроется твой финальный экран.',
      button: '🚀 ОПУБЛИКОВАТЬ',
      fields: [{ type: 'gate', key: 'gate' }],
    },
    reward: { icon: '🏆', name: 'Готовая игра' },
  },
];

/* Итоговый слайд для режима «только День 1» */
const DAY1_FINALE = {
  id: 'day1finale',
  section: 'day1end', title: 'Итог Дня 1', final: true,
  finalCfg: {
    head: '🎉 DAY 1 COMPLETE', rank: '12+ GAME DEVELOPER · LEVEL 1', quote: 'Ты прошёл путь от идеи до первого кода.',
    cells: [['🕹 Жанр', 'genre'], ['🎨 Стиль', 'styleLine'], ['🌍 Мир', 'world'], ['💡 Идея', 'mix'], ['⌨️ Lua', 'luaLine', 'mono'], ['🤖 Идея от ИИ', 'aiIdea']],
  },
  body: `
    <div class="final-wrap">
      <div class="final-left">
        <div class="cover-sub">ДЕНЬ 1 ПРОЙДЕН!</div>
        <div class="formula mono">ИДЕЯ → МИР → КОД</div>
        <p class="final-big">Ты уже придумал игру, нарисовал карту и написал <b>первый код.</b></p>
        <button class="btn open-final" id="openFinal" disabled>🎉 Открыть итоговый экран</button>
      </div>
      <div class="gamecard" id="gameCard">
        <div class="gc-top">ТВОЯ ИГРА</div>
        <div class="gc-title" data-bind="title" data-fallback="Без названия"></div>
        <div class="gc-by">by <span data-bind="creator" data-fallback="Разработчик"></span></div>
        <div class="gc-grid">
          <div><i>Жанр</i><span data-bind="genre" data-fallback="—"></span></div>
          <div><i>Стиль</i><span data-bind="styleLine" data-fallback="—"></span></div>
          <div><i>Мир</i><span data-bind="world" data-fallback="—"></span></div>
          <div><i>Lua</i><span class="mono" data-bind="luaLine" data-fallback="—"></span></div>
        </div>
        <div class="gc-bar"><div class="gc-fill" id="gcFill"></div></div>
        <div class="gc-blocks">ТВОЯ ИГРА СОБРАНА НА <span data-bind="pct"></span></div>
      </div>
    </div>`,
  action: {
    text: 'Собери все блоки Дня 1 и заверши день — откроется твой итоговый экран.',
    button: '🏁 ЗАВЕРШИТЬ ДЕНЬ 1',
    fields: [{ type: 'gate', key: 'gate' }],
  },
  reward: { icon: '🏅', name: 'Значок Дня 1' },
};


/* ───────── Новые слайды-объяснения (каждый — с мини-проверкой и наградой) ───────── */
const EXTRA_SLIDES = [
  {
    id: 'howto', section: 'intro', title: 'Как это работает',
    body: `
      <h2>🎮 Как работает джем</h2>
      <div class="hsteps">
        <div class="hs"><span class="hs-i">👀</span><b>1. СМОТРИ</b><em>на слайд и читай</em></div>
        <div class="hs-arrow"></div>
        <div class="hs"><span class="hs-i">✋</span><b>2. ДЕЛАЙ</b><em>действие внизу</em></div>
        <div class="hs-arrow"></div>
        <div class="hs"><span class="hs-i">🧱</span><b>3. ПОЛУЧАЙ</b><em>блок своей игры</em></div>
      </div>
      <div class="mini-wrap">
        <div class="mini-bricks"><i class="on"></i><i class="on"></i><i class="on"></i><i class="on"></i><i></i><i></i><i></i><i></i><i></i><i></i></div>
        <span>Полоска вверху экрана — твоя игра. Каждый блок делает её больше!</span>
      </div>`,
    action: {
      text: 'Проверь себя: что ты получаешь, когда выполнил действие на слайде?',
      fields: [{ type: 'quiz', key: 'quizHowto', answer: 1, options: ['Ничего', 'Блок своей игры', 'Домашнее задание'], hint: 'Загляни на полоску вверху: она заполняется блоками.' }],
    },
    reward: { icon: '📖', name: 'Правила джема' },
  },

  {
    id: 'team', section: 'day1', title: 'Команда разработчиков',
    body: `
      <h2>👥 Кто делает игры?</h2>
      <p class="lead">В студии работает целая команда:</p>
      ${tiles([['💡', 'Геймдизайнер — придумывает игру'], ['🌍', 'Дизайнер мира — строит карту'], ['💻', 'Программист — пишет код на Lua'], ['🧪', 'Тестировщик — ищет ошибки'], ['🤖', 'ИИ — помогает и подсказывает']], 'cols3')}
      <p class="callout"><b>В этой игре ты — вся команда сразу!</b></p>`,
    action: {
      text: 'Проверь себя: кто в команде пишет код?',
      fields: [{ type: 'quiz', key: 'quizTeam', answer: 2, options: ['Тестировщик', 'Дизайнер мира', 'Программист'], hint: 'Код — это программа, а программы пишет программист.' }],
    },
    reward: { icon: '👥', name: 'Роль в команде' },
  },

  {
    id: 'robloxai', section: 'studio', title: 'ИИ внутри Roblox Studio',
    body: `
      <h2>✨ ИИ прямо в Roblox Studio</h2>
      <p class="lead">В Studio есть свой помощник — <b>Assistant</b>. Он сам ставит объекты и пишет код.</p>
      <div class="ra-grid">
        <div class="ra-mock">
          <div class="ra-bar"><span>Home</span><span>Model</span><span>View</span><span class="sp"></span><span class="ra-btn">✨ Assistant<i>нажми сюда</i></span></div>
          <div class="ra-chat">
            <div class="bub me">Поставь 5 деревьев вокруг START</div>
            <div class="bub ai">Готово! Я добавил 5 деревьев ✔</div>
          </div>
        </div>
        ${vplan([['1', 'Нажми Assistant', 'справа вверху в Studio'], ['2', 'Напиши просьбу', 'коротко: что и где'], ['3', 'Проверь и поправь', 'ИИ может ошибиться']])}
      </div>
      <p class="callout"><b>Алиса и ГигаЧат</b> советуют в браузере. <b>Assistant</b> делает это прямо в твоей игре.</p>`,
    action: {
      text: 'Открой Studio, нажми Assistant и попроси добавить что-то на твою карту. Сначала запиши просьбу здесь.',
      fields: [{ type: 'area', key: 'assistantAsk', label: 'Моя просьба для Assistant', placeholder: 'Поставь деревья вокруг START', words: 4 }],
    },
    reward: { icon: '✨', name: 'Помощник в Studio' },
  },

  {
    id: 'aisafe', section: 'day1', title: 'ИИ — помощник',
    body: `
      <h2>🤖 ИИ — твой помощник</h2>
      <p class="lead">ИИ отвечает по тому, что ты написал. Понятный вопрос — хороший ответ.</p>
      ${tiles([['✅', 'Проверяй: ИИ может ошибаться'], ['✍️', 'Меняй: добавь своё в ответ'], ['🔒', 'Не пиши личное: фамилию, адрес, телефон, школу']], 'cols3 big')}
      <p class="callout"><b>ИИ — помощник, а решаешь всё ты.</b></p>`,
    action: {
      text: 'Проверь себя: что НЕЛЬЗЯ писать ИИ?',
      fields: [{ type: 'quiz', key: 'quizAi', answer: 0, options: ['Свой адрес и телефон', 'Идею для игры', 'Жанр игры'], hint: 'Личные данные — только для тебя и родителей.' }],
    },
    reward: { icon: '🛡', name: 'Щит безопасности' },
  },

  {
    id: 'windows', section: 'studio', title: 'Окна Roblox Studio',
    body: `
      <h2>🪟 Окна Roblox Studio</h2>
      <div class="studio-mock">
        <div class="sm-bar"><span>Home</span><span>Model</span><span>View</span><span class="sm-play">▶ Play</span></div>
        <div class="sm-main">
          <div class="sm-box tb"><b>1</b><strong>Toolbox</strong><small>готовые предметы</small></div>
          <div class="sm-box vp"><b>2</b><strong>Viewport</strong><small>твой мир — здесь строим</small>
            <div class="sm-scene"><i></i><i></i><i></i></div></div>
          <div class="sm-side">
            <div class="sm-box ex"><b>3</b><strong>Explorer</strong><small>список всего в игре</small></div>
            <div class="sm-box pr"><b>4</b><strong>Properties</strong><small>цвет, размер, Anchored</small></div>
          </div>
        </div>
        <div class="sm-box out"><b>5</b><strong>Output</strong><small>— сюда пишет команда print()</small></div>
      </div>`,
    action: {
      text: 'Проверь себя: в каком окне появятся слова из команды print()?',
      fields: [{ type: 'quiz', key: 'quizWin', answer: 1, options: ['Toolbox', 'Output', 'Properties'], hint: 'Это окно внизу — оно «выводит» сообщения.' }],
    },
    reward: { icon: '🪟', name: 'Карта окон Studio' },
  },

  {
    id: 'parts', section: 'studio', title: 'Part — кирпичик мира',
    body: `
      <h2>🔨 Part — кирпичик мира</h2>
      <p class="lead"><b>Part</b> — любой блок в мире: стена, пол, дверь, монетка. Что с ним можно делать:</p>
      ${tiles([['↔️', 'Move — двигать'], ['📐', 'Scale — менять размер'], ['🔄', 'Rotate — вращать'], ['🎨', 'Color — красить'], ['🧱', 'Material — материал'], ['⚓', 'Anchored — приклеить к месту']], 'cols3')}`,
    action: {
      text: 'Проверь себя: что делает галочка Anchored?',
      fields: [{ type: 'quiz', key: 'quizPart', answer: 2, options: ['Красит блок', 'Удаляет блок', 'Приклеивает блок, чтобы он не падал'], hint: 'Anchored по-английски — «закреплён, как якорь».' }],
    },
    reward: { icon: '🔨', name: 'Умение строить' },
  },

  {
    id: 'scriptwhere', section: 'studio', title: 'Куда класть Script',
    body: `
      <h2>📂 Куда класть Script</h2>
      ${vplan([['1', 'Explorer', 'нажми на свой предмет (Part)'], ['2', '+', 'нажми плюс рядом с предметом'], ['3', 'Script', 'выбери Script в списке'],
        ['4', 'Вставь код', 'Ctrl + V — вставить'], ['5', '▶ Play', 'запусти игру и проверь'], ['6', 'Output', 'смотри сообщения']])}`,
    action: {
      text: 'Проверь себя: куда кладём Script, чтобы предмет исчезал, когда его трогают?',
      fields: [{ type: 'quiz', key: 'quizScript', answer: 0, options: ['Внутрь самого предмета', 'В окно Output', 'В Toolbox'], hint: 'Скрипт живёт там, где лежит. Вспомни script.Parent — «мой предмет».' }],
    },
    reward: { icon: '📂', name: 'Script на месте' },
  },
];

const BY_ID = {};
[...ALL_SLIDES, ...EXTRA_SLIDES, DAY1_FINALE].forEach((sl) => { BY_ID[sl.id] = sl; });
const SLIDES = ORDER.map((id) => BY_ID[id]);
