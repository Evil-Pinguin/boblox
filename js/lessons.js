/* Уроки Lua для маленьких детей: СНАЧАЛА ПРИМЕР → ПОТОМ «ПОВТОРИ ПО ПРИМЕРУ».
   Принцип каждого урока:
     1. learn  — показываем рабочий пример и объясняем простыми словами
     2. fill / type — пример остаётся на экране (example), а ребёнок делает почти то же самое,
        меняя одну маленькую деталь.
   Типы шагов:
     learn  — объяснение + пример кода (кнопка «Понятно»); copy:true — кнопка копирования
     fill   — вставить пропущенные слова из банка слов (в коде ___)
     type   — вписать слово/текст; wrap:[до, после] — код вокруг поля уже написан
     choice, order — запасные типы (сейчас не используются)
   example: { code, mark:[номера подсвеченных строк], label } — пример, закреплённый над заданием.
   В code можно писать {{ключ}} — подставится ответ ребёнка (например {{pickupMsg}}).
   Это ТРЕНАЖЁР — не настоящий Roblox. Настоящий код дети запускают в Roblox Studio. */

const LESSONS = {
  /* ───────── Урок 1: print и переменные ───────── */
  basics: {
    title: 'Урок 1 · Привет, Lua!',
    icon: '⌨️',
    steps: [
      { type: 'learn', title: 'Команда print',
        text: 'Компьютер выполняет команды. <b>print</b> значит «напиши на экране». Что писать — кладём в <b>кавычки</b>.',
        code: 'print("Привет!")', out: 'Привет!' },

      { type: 'fill', title: 'Повтори по примеру',
        text: 'Сделай так, чтобы на экране появилось слово <b>Пока!</b> — просто нажми на нужное слово.',
        example: { code: 'print("Привет!")', label: 'Пример' },
        code: 'print("___")', bank: ['Привет!', 'Пока!', 'Lua'], answer: ['Пока!'],
        out: 'Пока!', hint: 'Нужно слово «Пока!».' },

      { type: 'type', title: 'Теперь с твоим именем',
        text: 'Впиши <b>своё имя</b> между кавычками. Остальное уже готово!',
        example: { code: 'print("Привет!")', label: 'Пример' },
        wrap: ['print("', '")'], placeholder: 'твоё имя', check: '^[^"\']{1,20}$', save: 'lua', run: true,
        hint: 'Напиши имя буквами, без кавычек.',
        explain: 'Ты написал свою первую команду на Lua!' },

      { type: 'learn', title: 'Переменная — это коробка',
        text: 'Переменная — коробка с названием. Мы кладём в неё слово или число. Слово <b>local</b> создаёт коробку.',
        code: 'local name = "Макс"\nprint(name)', out: 'Макс' },

      { type: 'type', title: 'Положи в коробку своё имя',
        text: 'Впиши своё имя в коробку <b>name</b>. Команда print покажет то, что внутри.',
        example: { code: 'local name = "Макс"\nprint(name)', label: 'Пример', mark: [0] },
        wrap: ['local name = "', '"\nprint(name)'], placeholder: 'твоё имя', check: '^[^"\']{1,20}$', run: false, showOut: 'name',
        hint: 'Впиши имя, как в предыдущем шаге.',
        explain: 'Теперь в коробке name лежит твоё имя.' },

      { type: 'learn', title: 'Числа и плюс',
        text: 'В коробке может лежать число. Знак <b>+</b> добавляет к нему ещё.',
        code: 'local coins = 5\ncoins = coins + 1\nprint(coins)', out: '6' },

      { type: 'fill', title: 'Повтори по примеру',
        text: 'У игрока 3 монеты, он нашёл ещё 2. Должно получиться <b>5</b>. Какой знак нужен?',
        example: { code: 'local coins = 5\ncoins = coins + 1\nprint(coins)', label: 'Пример', mark: [1] },
        code: 'local coins = 3\ncoins = coins ___ 2\nprint(coins)', bank: ['+', '-'], answer: ['+'],
        out: '5', hint: 'Мы добавляем монеты — значит, нужен плюс.' },
    ],
  },

  /* ───────── Урок 2: скрипт подбора предмета ───────── */
  pickup: {
    title: 'Урок 2 · Подбери предмет',
    icon: '🔧',
    steps: [
      { type: 'learn', title: 'Готовый скрипт-пример',
        text: 'Этот скрипт кладут внутрь предмета (например, монетки). Когда игрок дотронулся — предмет исчезает.',
        code: 'local item = script.Parent\n\nitem.Touched:Connect(function(hit)\n  item:Destroy()\n  print("Монетка собрана!")\nend)' },

      { type: 'learn', title: 'Что делает каждая строка',
        text: '• <b>script.Parent</b> — «вот этот предмет»<br>• <b>Touched</b> — «когда до него дотронулись»<br>• <b>Destroy</b> — «убрать предмет»<br>• <b>print</b> — «написать сообщение»',
        code: 'local item = script.Parent\n\nitem.Touched:Connect(function(hit)\n  item:Destroy()\n  print("Монетка собрана!")\nend)' },

      { type: 'fill', title: 'Повтори по примеру',
        text: 'Найди в примере слово, которое значит «дотронулись».',
        example: { code: 'local item = script.Parent\n\nitem.Touched:Connect(function(hit)\n  item:Destroy()\n  print("Монетка собрана!")\nend)', mark: [2], label: 'Пример' },
        code: 'item.___:Connect(function(hit)', bank: ['Touched', 'Clicked', 'Moved'], answer: ['Touched'],
        hint: 'Это слово стоит во второй строке примера.' },

      { type: 'fill', title: 'Повтори по примеру',
        text: 'Найди в примере команду, которая убирает предмет.',
        example: { code: 'local item = script.Parent\n\nitem.Touched:Connect(function(hit)\n  item:Destroy()\n  print("Монетка собрана!")\nend)', mark: [3], label: 'Пример' },
        code: '  item:___()', bank: ['Destroy', 'Open', 'Jump'], answer: ['Destroy'],
        hint: 'Это слово стоит в четвёртой строке примера.' },

      { type: 'type', title: 'Сделай своё сообщение',
        text: 'Придумай, какой предмет собирает игрок, и впиши сообщение. Например: <b>Ключ собран!</b>',
        example: { code: 'local item = script.Parent\n\nitem.Touched:Connect(function(hit)\n  item:Destroy()\n  print("Монетка собрана!")\nend)', mark: [4], label: 'Пример' },
        wrap: ['  print("', '")'], placeholder: 'Ключ собран!', check: '^[^"\']{2,30}$', save: 'pickupMsg', run: false, showOut: 'text',
        hint: 'Впиши любое сообщение, без кавычек.',
        explain: 'Отлично! Это сообщение появится в игре.' },

      { type: 'learn', title: 'Готово! Вот твой скрипт',
        text: 'Скопируй его, вставь в <b>Script</b> внутри предмета в Roblox Studio и нажми Play. У предмета включи галочку <b>Anchored</b>.',
        copy: true,
        code: 'local item = script.Parent\n\nitem.Touched:Connect(function(hit)\n  item:Destroy()\n  print("{{pickupMsg}}")\nend)' },
    ],
  },
};
