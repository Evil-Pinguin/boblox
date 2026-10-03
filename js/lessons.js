/* Уроки Lua для маленьких детей: СНАЧАЛА ПРИМЕР → ПОТОМ «ПОВТОРИ ПО ПРИМЕРУ».
   Принцип каждого урока:
     1. learn  — показываем рабочий пример и объясняем простыми словами
     2. fill / type — пример остаётся на экране (example), а ребёнок делает почти то же самое,
        меняя одну маленькую деталь.
   Типы шагов:
     learn  — объяснение + пример кода (кнопка «Понятно»); copy:true — кнопка копирования
     fill   — вставить пропущенные слова из банка слов (в коде ___)
     type   — вписать слово/текст; wrap:[до, после] — код вокруг поля уже написан
     choice — выбрать один вариант из нескольких (code — необязательный код над вариантами)
   order  — собрать строки скрипта в правильном порядке (lines — правильный порядок, scramble — как перемешано)
   example: { code, mark:[номера подсвеченных строк], label } — пример, закреплённый над заданием.
   В code можно писать {{ключ}} — подставится ответ ребёнка (например {{pickupMsg}}).
   outFmt: '+{} очков!' — строка вывода после type-шага, {} заменяется на ответ ребёнка.
   defaults — значения {{ключ}}, если ребёнок ещё ничего не вписал. summary — текст в конце урока.
   Это ТРЕНАЖЁР — не настоящий Roblox. Настоящий код дети запускают в Roblox Studio. */

const PICK = 'local item = script.Parent\n\nitem.Touched:Connect(function(hit)\n  item:Destroy()\n  print("Монетка собрана!")\nend)';
const NAME_RE = '^[^"\']{1,20}$';
const MSG_RE = '^[^"\']{2,30}$';

const LESSONS = {
  /* ───────── Урок 1: print, переменные, числа, склейка ───────── */
  basics: {
    title: 'Урок 1 · Привет, Lua!',
    icon: '⌨️',
    summary: 'Теперь ты знаешь print, переменные, числа и склейку слов. Дальше — урок про цвет и размер блока!',
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
        wrap: ['print("', '")'], placeholder: 'твоё имя', check: NAME_RE, save: 'lua', run: true,
        hint: 'Напиши имя буквами, без кавычек.',
        explain: 'Ты написал свою первую команду на Lua!' },

      { type: 'choice', title: 'Что напишет print?',
        text: 'Посмотри на код и выбери, что появится на экране.',
        code: 'print("Я строю игру")',
        options: ['Я строю игру', 'print', 'кавычки'], answer: 0,
        hint: 'print пишет то, что стоит внутри кавычек.', explain: 'Да! Кавычки не показываются — только слова внутри.' },

      { type: 'learn', title: 'Команды идут по порядку',
        text: 'Компьютер читает код <b>сверху вниз</b>, как книжку. Каждый print пишет своё слово.',
        code: 'print("Раз")\nprint("Два")\nprint("Три")', out: 'Раз\nДва\nТри' },

      { type: 'order', title: 'Поставь по порядку',
        text: 'Нужен отсчёт: <b>3, 2, 1, Старт!</b> Нажимай строки в правильном порядке.',
        lines: ['print("3")', 'print("2")', 'print("1")', 'print("Старт!")'], scramble: [3, 1, 0, 2],
        hint: 'Сначала 3, потом 2, потом 1 и в конце «Старт!».', explain: 'Отсчёт готов! Код читается сверху вниз.' },

      { type: 'learn', title: 'Переменная — это коробка',
        text: 'Переменная — коробка с названием. Мы кладём в неё слово или число. Слово <b>local</b> создаёт коробку.',
        code: 'local name = "Макс"\nprint(name)', out: 'Макс' },

      { type: 'type', title: 'Положи в коробку своё имя',
        text: 'Впиши своё имя в коробку <b>name</b>. Команда print покажет то, что внутри.',
        example: { code: 'local name = "Макс"\nprint(name)', label: 'Пример', mark: [0] },
        wrap: ['local name = "', '"\nprint(name)'], placeholder: 'твоё имя', check: NAME_RE, run: false, showOut: 'name',
        hint: 'Впиши имя, как в предыдущем шаге.',
        explain: 'Теперь в коробке name лежит твоё имя.' },

      { type: 'fill', title: 'Покажи, что в коробке',
        text: 'Чтобы показать, что лежит в коробке, пишем её <b>название без кавычек</b>.',
        example: { code: 'local name = "Макс"\nprint(name)', label: 'Пример', mark: [1] },
        code: 'local color = "красный"\nprint(___)', bank: ['color', '"color"', 'name'], answer: ['color'],
        out: 'красный', hint: 'Коробка называется color, значит пишем color — без кавычек.' },

      { type: 'choice', title: 'Что покажет код?',
        text: 'Подумай, что лежит в коробке <b>pet</b>.',
        code: 'local pet = "Кот"\nprint(pet)',
        options: ['Кот', 'pet', '"Кот"'], answer: 0,
        hint: 'print показывает то, что лежит в коробке pet.', explain: 'Верно! В коробке pet лежит слово Кот.' },

      { type: 'type', title: 'Придумай героя',
        text: 'Впиши, кто будет героем твоей игры. Например: <b>Ниндзя</b>, <b>Робот</b> или <b>Дракон</b>.',
        example: { code: 'local pet = "Кот"\nprint(pet)', label: 'Пример', mark: [0] },
        wrap: ['local hero = "', '"\nprint(hero)'], placeholder: 'Ниндзя', check: NAME_RE, run: false, showOut: 'name',
        hint: 'Впиши любое слово без кавычек.',
        explain: 'Герой готов! Запомни его — пригодится в игре.' },

      { type: 'learn', title: 'Числа и плюс',
        text: 'В коробке может лежать число. Знак <b>+</b> добавляет к нему ещё.',
        code: 'local coins = 5\ncoins = coins + 1\nprint(coins)', out: '6' },

      { type: 'fill', title: 'Повтори по примеру',
        text: 'У игрока 3 монеты, он нашёл ещё 2. Должно получиться <b>5</b>. Какой знак нужен?',
        example: { code: 'local coins = 5\ncoins = coins + 1\nprint(coins)', label: 'Пример', mark: [1] },
        code: 'local coins = 3\ncoins = coins ___ 2\nprint(coins)', bank: ['+', '-'], answer: ['+'],
        out: '5', hint: 'Мы добавляем монеты — значит, нужен плюс.' },

      { type: 'learn', title: 'Минус тоже есть',
        text: 'Знак <b>−</b> забирает. Потратил монеты — их стало меньше.',
        code: 'local coins = 10\ncoins = coins - 3\nprint(coins)', out: '7' },

      { type: 'fill', title: 'Повтори по примеру',
        text: 'У игрока 10 монет, он купил меч за 4. Должно остаться <b>6</b>. Какой знак нужен?',
        example: { code: 'local coins = 10\ncoins = coins - 3\nprint(coins)', label: 'Пример', mark: [1] },
        code: 'local coins = 10\ncoins = coins ___ 4\nprint(coins)', bank: ['+', '-'], answer: ['-'],
        out: '6', hint: 'Монеты потратили — их меньше. Нужен минус.' },

      { type: 'type', title: 'Сколько добавить?',
        text: 'Сейчас 5 монет. Чтобы стало <b>8</b>, впиши число, которое нужно добавить.',
        example: { code: 'local coins = 5\ncoins = coins + 1\nprint(coins)', label: 'Пример', mark: [1] },
        wrap: ['local coins = 5\ncoins = coins + ', '\nprint(coins)'], placeholder: '3', check: '^3$', out: '8',
        hint: '5 и ещё сколько будет 8? Посчитай на пальцах.',
        explain: '5 + 3 = 8. Ты умеешь считать кодом!' },

      { type: 'learn', title: 'Заметки для людей',
        text: 'Две чёрточки <b>--</b> делают строку заметкой. Компьютер её пропускает, а людям она помогает понять код.',
        code: '-- это заметка для людей\nprint("Привет!")', out: 'Привет!' },

      { type: 'choice', title: 'Что делают две чёрточки?',
        text: 'Вспомни пример выше.',
        options: ['Это заметка — компьютер её пропускает', 'Стирают всю программу', 'Печатают слово на экране'], answer: 0,
        hint: 'Это заметка для людей. Компьютер её не читает.', explain: 'Верно! Заметки помогают не запутаться в коде.' },

      { type: 'learn', title: 'Склеиваем слова',
        text: 'Две точки <b>..</b> склеивают слова вместе. Так можно приветствовать игрока по имени!',
        code: 'local name = "Макс"\nprint("Привет, " .. name)', out: 'Привет, Макс' },

      { type: 'fill', title: 'Повтори по примеру',
        text: 'Склей слово «Привет, » с коробкой <b>name</b>. Какой знак клеит слова?',
        example: { code: 'local name = "Макс"\nprint("Привет, " .. name)', label: 'Пример', mark: [1] },
        code: 'local name = "Лина"\nprint("Привет, " ___ name)', bank: ['..', '+', '-'], answer: ['..'],
        out: 'Привет, Лина', hint: 'Слова клеит знак из двух точек.' },

      { type: 'type', title: 'Поздоровайся со всем миром',
        text: 'Впиши <b>своё имя</b> — игра поздоровается с тобой по имени!',
        example: { code: 'local name = "Макс"\nprint("Привет, " .. name)', label: 'Пример', mark: [0] },
        wrap: ['local name = "', '"\nprint("Привет, " .. name)'], placeholder: 'твоё имя', check: NAME_RE, run: false, outFmt: 'Привет, {}',
        hint: 'Впиши своё имя без кавычек.',
        explain: 'Игра знает твоё имя! Так делают настоящие приветствия.' },
    ],
  },

  /* ───────── Урок 2: свойства блока ───────── */
  props: {
    title: 'Урок 2 · Раскрась блок',
    icon: '🎨',
    defaults: { blockColor: 'Bright yellow' },
    summary: 'Теперь ты умеешь менять цвет, прозрачность, размер и Anchored. Скопируй скрипт в Studio и посмотри!',
    steps: [
      { type: 'learn', title: 'Свойства блока',
        text: 'У каждого блока (<b>Part</b>) есть <b>свойства</b>: цвет, размер, прозрачность. Их видно в окне <b>Properties</b>. Код умеет их менять — пишем <b>блок.Свойство = значение</b>.',
        code: 'local part = script.Parent\npart.BrickColor = BrickColor.new("Bright red")' },

      { type: 'learn', title: 'Что значат строки',
        text: '• <b>script.Parent</b> — «вот этот блок»<br>• <b>part.BrickColor</b> — «цвет блока»<br>• <b>BrickColor.new("…")</b> — «возьми краску с таким именем»<br>Блок станет <b>красным</b>.',
        code: 'local part = script.Parent\npart.BrickColor = BrickColor.new("Bright red")' },

      { type: 'fill', title: 'Покрась в синий',
        text: 'Сделай блок <b>синим</b>. Выбери краску с нужным именем.',
        example: { code: 'local part = script.Parent\npart.BrickColor = BrickColor.new("Bright red")', label: 'Пример', mark: [1] },
        code: 'local part = script.Parent\npart.BrickColor = BrickColor.new("___")', bank: ['Bright red', 'Bright blue', 'Lime green'], answer: ['Bright blue'],
        hint: 'Blue по-английски — «синий».' },

      { type: 'type', title: 'Выбери свой цвет',
        text: 'Впиши название краски: <b>Bright yellow</b>, <b>Lime green</b> или <b>Hot pink</b>.',
        example: { code: 'local part = script.Parent\npart.BrickColor = BrickColor.new("Bright red")', label: 'Пример', mark: [1] },
        wrap: ['part.BrickColor = BrickColor.new("', '")'], placeholder: 'Bright yellow', check: '^(Bright yellow|Lime green|Hot pink)$', save: 'blockColor', run: false,
        hint: 'Впиши одно из трёх: Bright yellow, Lime green или Hot pink. Буквы — как в подсказке.',
        explain: 'Блок будет твоего цвета!' },

      { type: 'learn', title: 'Прозрачность',
        text: '<b>Transparency</b> — насколько блок прозрачный. <b>0</b> — видно полностью, <b>1</b> — блок невидим, <b>0.5</b> — как стекло.',
        code: 'local part = script.Parent\npart.Transparency = 0.5' },

      { type: 'choice', title: 'Что значит ноль?',
        text: 'Что будет с блоком, если написать <b>part.Transparency = 0</b>?',
        options: ['Блок виден полностью', 'Блок исчез', 'Блок стал синим'], answer: 0,
        hint: '0 прозрачности — это совсем не прозрачный блок.', explain: 'Верно! 0 — всё видно, 1 — ничего не видно.' },

      { type: 'fill', title: 'Сделай невидимку',
        text: 'Сделай блок <b>совсем невидимым</b>. Какое число нужно?',
        example: { code: 'local part = script.Parent\npart.Transparency = 0.5', label: 'Пример', mark: [1] },
        code: 'local part = script.Parent\npart.Transparency = ___', bank: ['0', '0.5', '1'], answer: ['1'],
        hint: '1 — это полностью прозрачный блок.' },

      { type: 'learn', title: 'Anchored — приклеить',
        text: '<b>Anchored = true</b> приклеивает блок на месте. Если не приклеить — блок упадёт вниз, как только начнётся игра.',
        code: 'local part = script.Parent\npart.Anchored = true' },

      { type: 'choice', title: 'Блок упал вниз!',
        text: 'Игрок нажал Play, и платформа упала. Что мы забыли написать?',
        options: ['part.Anchored = true', 'part.Transparency = 1', 'print("Привет!")'], answer: 0,
        hint: 'Чтобы блок не падал, его надо приклеить.', explain: 'Да! Anchored держит блок на месте.' },

      { type: 'fill', title: 'Приклей платформу',
        text: 'Приклей блок, чтобы он <b>не падал</b>.',
        example: { code: 'local part = script.Parent\npart.Anchored = true', label: 'Пример', mark: [1] },
        code: 'local part = script.Parent\npart.Anchored = ___', bank: ['true', 'false'], answer: ['true'],
        hint: 'true — «да, приклеить».' },

      { type: 'learn', title: 'Размер блока',
        text: '<b>Size</b> — размер из трёх чисел: <b>длина, высота, ширина</b>. Куб 4 × 4 × 4 — это Vector3.new(4, 4, 4).',
        code: 'local part = script.Parent\npart.Size = Vector3.new(4, 4, 4)' },

      { type: 'type', title: 'Сделай платформу тонкой',
        text: 'Платформа должна быть <b>тонкой</b>: высота — <b>1</b>. Впиши это число.',
        example: { code: 'local part = script.Parent\npart.Size = Vector3.new(4, 4, 4)', label: 'Пример', mark: [1] },
        wrap: ['part.Size = Vector3.new(4, ', ', 4)'], placeholder: '1', check: '^1$',
        hint: 'Высота — это второе число. Нужна единица.',
        explain: 'Теперь это тонкая платформа 4 × 1 × 4.' },

      { type: 'choice', title: 'Прочитай размер',
        text: 'Какой высоты будет блок?',
        code: 'part.Size = Vector3.new(10, 2, 6)',
        options: ['2', '10', '6'], answer: 0,
        hint: 'Порядок такой: длина, высота, ширина. Высота — в середине.', explain: 'Верно! Высота — второе число.' },

      { type: 'order', title: 'Собери скрипт блока',
        text: 'Собери скрипт: сначала берём блок, потом красим, потом приклеиваем.',
        lines: ['local part = script.Parent', 'part.BrickColor = BrickColor.new("Bright red")', 'part.Anchored = true'], scramble: [2, 0, 1],
        hint: 'Сначала local part = script.Parent — без этого блока нет.', explain: 'Скрипт собран по порядку!' },

      { type: 'learn', title: 'Готово! Вот твой скрипт',
        text: 'Скопируй его, вставь в <b>Script</b> внутри блока в Roblox Studio и нажми Play. Блок станет твоего цвета, чуть прозрачным и не упадёт.',
        copy: true,
        code: 'local part = script.Parent\n\npart.BrickColor = BrickColor.new("{{blockColor}}")\npart.Transparency = 0.3\npart.Anchored = true' },
    ],
  },

  /* ───────── Урок 3: если — то ───────── */
  cond: {
    title: 'Урок 3 · Если — то',
    icon: '🤔',
    defaults: { lavaMsg: 'Ой, горячо!' },
    summary: 'Ты научился решать «если — то» и ловить касания. Скрипт лавы готов — проверь его в Studio!',
    steps: [
      { type: 'learn', title: 'Если — то',
        text: 'Код умеет принимать решения. <b>if</b> значит «если», <b>then</b> — «то», <b>end</b> — «конец». Если условие верное, код внутри выполнится.',
        code: 'local score = 7\nif score > 5 then\n  print("Победа!")\nend', out: 'Победа!' },

      { type: 'learn', title: 'Знаки сравнения',
        text: '<b>&gt;</b> — больше<br><b>&lt;</b> — меньше<br><b>==</b> — равно (две палочки!)<br><b>&gt;=</b> — больше или равно',
        code: 'if score > 5 then   -- очков больше 5?\nif lives == 0 then  -- жизней ровно 0?' },

      { type: 'fill', title: 'Повтори по примеру',
        text: 'У игрока 9 очков. Победа, если очков <b>больше</b> 5. Какой знак нужен?',
        example: { code: 'local score = 7\nif score > 5 then\n  print("Победа!")\nend', label: 'Пример', mark: [1] },
        code: 'local score = 9\nif score ___ 5 then\n  print("Победа!")\nend', bank: ['>', '<'], answer: ['>'],
        out: 'Победа!', hint: '9 больше 5 — нужен знак «больше».' },

      { type: 'fill', title: 'Допиши слова',
        text: 'Допиши два слова: после условия нужно <b>then</b>, а в конце — <b>end</b>.',
        example: { code: 'local score = 7\nif score > 5 then\n  print("Победа!")\nend', label: 'Пример', mark: [1, 3] },
        code: 'local score = 9\nif score > 5 ___\n  print("Победа!")\n___', bank: ['then', 'end', 'do'], answer: ['then', 'end'],
        out: 'Победа!', hint: 'Сначала then — «то», а в самом конце end — «конец».' },

      { type: 'choice', title: 'Что напечатает код?',
        text: 'Две палочки <b>==</b> значат «равно». Подумай, что будет.',
        code: 'local lives = 0\nif lives == 0 then\n  print("Игра окончена")\nend',
        options: ['Игра окончена', 'Ничего', 'Победа!'], answer: 0,
        hint: 'lives равно 0 — условие верное.', explain: 'Верно! Жизней 0, значит игра окончена.' },

      { type: 'choice', title: 'А тут что?',
        text: 'Условие может быть неверным. Тогда код внутри не выполнится.',
        code: 'local coins = 2\nif coins > 5 then\n  print("Богач!")\nend',
        options: ['Ничего — условие не верное', 'Богач!', 'coins'], answer: 0,
        hint: '2 не больше 5. Значит, условие не сработает.', explain: 'Да! 2 не больше 5, поэтому print не запустился.' },

      { type: 'learn', title: 'Иначе — else',
        text: '<b>else</b> значит «иначе». Если условие неверное — выполнится то, что после else.',
        code: 'local coins = 3\nif coins >= 5 then\n  print("Открываем дверь!")\nelse\n  print("Нужно больше монет")\nend', out: 'Нужно больше монет' },

      { type: 'fill', title: 'Повтори по примеру',
        text: 'Допиши слово, которое значит «иначе».',
        example: { code: 'local coins = 3\nif coins >= 5 then\n  print("Открываем дверь!")\nelse\n  print("Нужно больше монет")\nend', label: 'Пример', mark: [3] },
        code: 'local coins = 3\nif coins >= 5 then\n  print("Открываем дверь!")\n___\n  print("Нужно больше монет")\nend', bank: ['else', 'then', 'end'], answer: ['else'],
        out: 'Нужно больше монет', hint: 'Это слово стоит в четвёртой строке примера.' },

      { type: 'type', title: 'Открой дверь',
        text: 'Дверь открывается, если монет <b>5 или больше</b>. Впиши число от <b>5</b> до 99, чтобы дверь открылась.',
        example: { code: 'local coins = 3\nif coins >= 5 then\n  print("Открываем дверь!")\nelse\n  print("Нужно больше монет")\nend', label: 'Пример', mark: [0] },
        wrap: ['local coins = ', '\nif coins >= 5 then\n  print("Открываем дверь!")\nend'], placeholder: '5', check: '^([5-9]|[1-9][0-9])$', out: 'Открываем дверь!',
        hint: 'Нужно число, которое не меньше 5. Например, 5 или 7.',
        explain: 'Дверь открыта! Монет хватило.' },

      { type: 'learn', title: 'Событие Touched',
        text: '<b>Touched</b> — «когда дотронулись». Код внутри выполнится каждый раз, когда кто-то коснётся блока. Так работают ловушки и подбор предметов.',
        code: 'local lava = script.Parent\n\nlava.Touched:Connect(function(hit)\n  print("Кто-то дотронулся!")\nend)' },

      { type: 'fill', title: 'Повтори по примеру',
        text: 'Найди слово, которое значит «когда дотронулись».',
        example: { code: 'local lava = script.Parent\n\nlava.Touched:Connect(function(hit)\n  print("Кто-то дотронулся!")\nend)', label: 'Пример', mark: [2] },
        code: 'lava.___:Connect(function(hit)', bank: ['Touched', 'Jump', 'Print'], answer: ['Touched'],
        hint: 'Это слово стоит в третьей строке примера.' },

      { type: 'order', title: 'Собери лаву',
        text: 'Собери скрипт лавы. Подсказка: сначала берём блок, потом ждём касания, потом пишем, потом закрываем.',
        lines: ['local lava = script.Parent', 'lava.Touched:Connect(function(hit)', '  print("Ой, горячо!")', 'end)'], scramble: [3, 1, 0, 2],
        hint: 'Первая строка — local lava = script.Parent, последняя — end).', explain: 'Лава собрана!' },

      { type: 'type', title: 'Придумай крик лавы',
        text: 'Что скажет игрок, когда коснётся лавы? Впиши своё сообщение. Например: <b>Ой, горячо!</b>',
        example: { code: 'local lava = script.Parent\n\nlava.Touched:Connect(function(hit)\n  print("Кто-то дотронулся!")\nend)', label: 'Пример', mark: [3] },
        wrap: ['  print("', '")'], placeholder: 'Ой, горячо!', check: MSG_RE, save: 'lavaMsg', run: false, showOut: 'text',
        hint: 'Впиши любые слова без кавычек.',
        explain: 'Отлично! Это сообщение появится в игре.' },

      { type: 'learn', title: 'Лава, которая жжёт',
        text: 'Скопируй скрипт в <b>Script</b> внутри блока-лавы. Здесь мы используем всё из урока: <b>Touched</b>, <b>if</b> и <b>Humanoid</b> — это игрок. Если Humanoid найден, пишем сообщение и ставим <b>Health = 0</b> (здоровье ноль).',
        copy: true,
        code: 'local lava = script.Parent\n\nlava.Touched:Connect(function(hit)\n  local humanoid = hit.Parent:FindFirstChild("Humanoid")\n  if humanoid then\n    print("{{lavaMsg}}")\n    humanoid.Health = 0\n  end\nend)' },
    ],
  },

  /* ───────── Урок 4: скрипт подбора предмета ───────── */
  pickup: {
    title: 'Урок 4 · Подбери предмет',
    icon: '🔧',
    defaults: { pickupMsg: 'Предмет собран!', pickupPts: '5' },
    summary: 'Скрипт готов. Скопируй его в Roblox Studio и проверь в Play!',
    steps: [
      { type: 'learn', title: 'Готовый скрипт-пример',
        text: 'Этот скрипт кладут внутрь предмета (например, монетки). Когда игрок дотронулся — предмет исчезает.',
        code: PICK },

      { type: 'learn', title: 'Что делает каждая строка',
        text: '• <b>script.Parent</b> — «вот этот предмет»<br>• <b>Touched</b> — «когда до него дотронулись»<br>• <b>Destroy</b> — «убрать предмет»<br>• <b>print</b> — «написать сообщение»',
        code: PICK },

      { type: 'fill', title: 'Кто «этот предмет»?',
        text: 'Допиши первую строку: как скрипт узнаёт, что предмет — это он?',
        example: { code: PICK, mark: [0], label: 'Пример' },
        code: 'local item = ___', bank: ['script.Parent', 'Workspace', 'print'], answer: ['script.Parent'],
        hint: 'Это слово стоит в первой строке примера. Parent — «родитель», то есть предмет.' },

      { type: 'fill', title: 'Повтори по примеру',
        text: 'Найди в примере слово, которое значит «дотронулись».',
        example: { code: PICK, mark: [2], label: 'Пример' },
        code: 'item.___:Connect(function(hit)', bank: ['Touched', 'Clicked', 'Moved'], answer: ['Touched'],
        hint: 'Это слово стоит в третьей строке примера.' },

      { type: 'fill', title: 'Повтори по примеру',
        text: 'Найди в примере команду, которая убирает предмет.',
        example: { code: PICK, mark: [3], label: 'Пример' },
        code: '  item:___()', bank: ['Destroy', 'Open', 'Jump'], answer: ['Destroy'],
        hint: 'Это слово стоит в четвёртой строке примера.' },

      { type: 'choice', title: 'А если убрать строку?',
        text: 'Представь, что мы стёрли строку <b>item:Destroy()</b>. Что случится с монеткой?',
        options: ['Монетка не исчезнет', 'Монетка станет синей', 'Игра сломается'], answer: 0,
        hint: 'Destroy убирает предмет. Без него предмет остаётся на месте.', explain: 'Верно! Без Destroy монетка осталась бы лежать.' },

      { type: 'fill', title: 'Закрой скрипт',
        text: 'Скрипт нужно <b>закрыть</b>. Как заканчивается функция?',
        example: { code: PICK, mark: [5], label: 'Пример' },
        code: '  print("Монетка собрана!")\n___)', bank: ['end', 'stop', 'done'], answer: ['end'],
        hint: 'Это слово стоит в последней строке примера.' },

      { type: 'order', title: 'Собери скрипт монетки',
        text: 'Собери скрипт: сначала предмет, потом касание, потом убрать, потом написать, потом закрыть.',
        lines: ['local item = script.Parent', 'item.Touched:Connect(function(hit)', '  item:Destroy()', '  print("Монетка собрана!")', 'end)'], scramble: [4, 2, 0, 3, 1],
        hint: 'Первая строка — local item = script.Parent, последняя — end).', explain: 'Скрипт собран по порядку!' },

      { type: 'type', title: 'Сделай своё сообщение',
        text: 'Придумай, какой предмет собирает игрок, и впиши сообщение. Например: <b>Ключ собран!</b>',
        example: { code: PICK, mark: [4], label: 'Пример' },
        wrap: ['  print("', '")'], placeholder: 'Ключ собран!', check: MSG_RE, save: 'pickupMsg', run: false, showOut: 'text',
        hint: 'Впиши любое сообщение, без кавычек.',
        explain: 'Отлично! Это сообщение появится в игре.' },

      { type: 'learn', title: 'Добавим очки',
        text: 'Пусть предмет даёт очки. Положим число в коробку <b>points</b> и покажем его через <b>..</b>.',
        code: 'local item = script.Parent\nlocal points = 5\n\nitem.Touched:Connect(function(hit)\n  item:Destroy()\n  print("+" .. points .. " очков!")\nend)', out: '+5 очков!' },

      { type: 'type', title: 'Сколько очков даёт предмет?',
        text: 'Впиши, сколько очков получит игрок. Любое число от <b>1</b> до 99. Например: <b>10</b>.',
        example: { code: 'local item = script.Parent\nlocal points = 5\n\nitem.Touched:Connect(function(hit)\n  item:Destroy()\n  print("+" .. points .. " очков!")\nend)', mark: [1], label: 'Пример' },
        wrap: ['local points = ', ''], placeholder: '10', check: '^[1-9][0-9]?$', save: 'pickupPts', outFmt: '+{} очков!',
        hint: 'Впиши одно число, без слов.',
        explain: 'Теперь предмет даёт столько очков!' },

      { type: 'fill', title: 'Добавь очки к счёту',
        text: 'Игрок собрал предмет. К его очкам нужно <b>добавить</b> points. Какой знак нужен?',
        example: { code: 'local coins = 5\ncoins = coins + 1\nprint(coins)', mark: [1], label: 'Пример из урока 1' },
        code: 'local score = 0\nlocal points = 5\nscore = score ___ points\nprint(score)', bank: ['+', '-'], answer: ['+'],
        out: '5', hint: 'Очки добавляются — нужен плюс.' },

      { type: 'learn', title: 'Готово! Вот твой скрипт',
        text: 'Скопируй его, вставь в <b>Script</b> внутри предмета в Roblox Studio и нажми Play. У предмета включи галочку <b>Anchored</b>.',
        copy: true,
        code: 'local item = script.Parent\nlocal points = {{pickupPts}}\n\nitem.Touched:Connect(function(hit)\n  item:Destroy()\n  print("{{pickupMsg}} +" .. points)\nend)' },
    ],
  },

  /* ───────── Урок 5: повторяем и ждём ───────── */
  loop: {
    title: 'Урок 5 · Повторяй и жди',
    icon: '⏱️',
    defaults: { lampColor: 'Hot pink' },
    summary: 'Теперь ты умеешь повторять команды, ждать и считать назад. Скопируй мигающую лампу в Studio!',
    steps: [
      { type: 'learn', title: 'Повторяем: for',
        text: 'Чтобы не писать одно и то же много раз, есть <b>for</b>. Он повторяет команды. Цифры показывают: <b>с какого раза и до какого</b>.',
        code: 'for i = 1, 3 do\n  print("Привет!")\nend', out: 'Привет!\nПривет!\nПривет!' },

      { type: 'fill', title: 'Повтори по примеру',
        text: 'Сделай так, чтобы слово напечаталось <b>5 раз</b>. Какое число поставить в конце?',
        example: { code: 'for i = 1, 3 do\n  print("Привет!")\nend', label: 'Пример', mark: [0] },
        code: 'for i = 1, ___ do\n  print("Привет!")\nend', bank: ['3', '5', '10'], answer: ['5'],
        out: 'Привет!\nПривет!\nПривет!\nПривет!\nПривет!', hint: 'Нужно 5 раз — значит, считаем от 1 до 5.' },

      { type: 'choice', title: 'Сколько раз?',
        text: 'Сколько раз напечатается слово?',
        code: 'for i = 1, 4 do\n  print("Ура!")\nend',
        options: ['4 раза', '1 раз', '5 раз'], answer: 0,
        hint: 'От 1 до 4 — это 1, 2, 3, 4. Четыре раза.', explain: 'Верно! Считаем: 1, 2, 3, 4.' },

      { type: 'learn', title: 'Ждём: task.wait',
        text: '<b>task.wait(1)</b> значит «подожди 1 секунду». Так можно делать паузы в игре.',
        code: 'print("Раз")\ntask.wait(1)\nprint("Два")', out: 'Раз\n(пауза 1 секунда)\nДва' },

      { type: 'fill', title: 'Повтори по примеру',
        text: 'Нужна пауза в <b>2 секунды</b>. Какое число поставить?',
        example: { code: 'print("Раз")\ntask.wait(1)\nprint("Два")', label: 'Пример', mark: [1] },
        code: 'print("Раз")\ntask.wait(___)\nprint("Два")', bank: ['1', '2', '60'], answer: ['2'],
        hint: 'В скобках — сколько секунд ждать. Нужны 2.' },

      { type: 'learn', title: 'Отсчёт назад',
        text: 'Хочешь считать <b>назад</b>? Добавь третье число <b>-1</b>: «шагай на минус один». Так делают отсчёт перед стартом игры.',
        code: 'for i = 3, 1, -1 do\n  print(i)\n  task.wait(1)\nend\nprint("Старт!")', out: '3\n2\n1\nСтарт!' },

      { type: 'fill', title: 'Повтори по примеру',
        text: 'Допиши число, которое заставляет считать <b>назад</b>.',
        example: { code: 'for i = 3, 1, -1 do\n  print(i)\n  task.wait(1)\nend\nprint("Старт!")', label: 'Пример', mark: [0] },
        code: 'for i = 3, 1, ___ do\n  print(i)\n  task.wait(1)\nend', bank: ['-1', '+1', '0'], answer: ['-1'],
        out: '3\n2\n1', hint: 'Считаем назад — значит, шагаем на минус один.' },

      { type: 'order', title: 'Собери отсчёт',
        text: 'Собери скрипт отсчёта: сначала цикл, потом число, пауза, конец цикла, и в конце — «Старт!».',
        lines: ['for i = 3, 1, -1 do', '  print(i)', '  task.wait(1)', 'end', 'print("Старт!")'], scramble: [3, 0, 4, 2, 1],
        hint: 'Цикл начинается с for и закрывается словом end. «Старт!» — после end.', explain: 'Отсчёт собран!' },

      { type: 'type', title: 'Начни отсчёт с пяти',
        text: 'Хочешь отсчёт подлиннее? Начни его с числа <b>5</b>.',
        example: { code: 'for i = 3, 1, -1 do\n  print(i)\n  task.wait(1)\nend', label: 'Пример', mark: [0] },
        wrap: ['for i = ', ', 1, -1 do\n  print(i)\n  task.wait(1)\nend'], placeholder: '5', check: '^5$', out: '5\n4\n3\n2\n1',
        hint: 'Впиши цифру 5.', explain: 'Теперь отсчёт идёт с пяти!' },

      { type: 'learn', title: 'Повторяем всегда: while',
        text: '<b>while true do</b> значит «пока правда» — то есть <b>всегда</b>. Так работает мигающая лампа: красный, пауза, зелёный, пауза — и по кругу.',
        code: 'local lamp = script.Parent\n\nwhile true do\n  lamp.BrickColor = BrickColor.new("Bright red")\n  task.wait(1)\n  lamp.BrickColor = BrickColor.new("Lime green")\n  task.wait(1)\nend' },

      { type: 'choice', title: 'Как долго мигает лампа?',
        text: 'Что делает <b>while true do</b>?',
        options: ['Повторяет всегда, пока идёт игра', 'Выполняется один раз', 'Выполняется ровно 3 раза'], answer: 0,
        hint: 'true — «правда». Правда всегда правда, поэтому цикл не заканчивается.', explain: 'Верно! Лампа мигает, пока идёт игра.' },

      { type: 'type', title: 'Выбери цвет мигания',
        text: 'Впиши цвет для второй вспышки: <b>Hot pink</b>, <b>Bright blue</b> или <b>Bright yellow</b>.',
        example: { code: 'while true do\n  lamp.BrickColor = BrickColor.new("Bright red")\n  task.wait(1)\nend', label: 'Пример', mark: [1] },
        wrap: ['  lamp.BrickColor = BrickColor.new("', '")'], placeholder: 'Hot pink', check: '^(Hot pink|Bright blue|Bright yellow)$', save: 'lampColor', run: false,
        hint: 'Впиши один из трёх цветов, буквы — как в подсказке.', explain: 'Лампа будет мигать красным и твоим цветом!' },

      { type: 'order', title: 'Собери мигалку',
        text: 'Собери основу лампы: берём блок, запускаем вечный цикл, красим, ждём, закрываем.',
        lines: ['local lamp = script.Parent', 'while true do', '  lamp.BrickColor = BrickColor.new("Bright red")', '  task.wait(1)', 'end'], scramble: [4, 2, 0, 3, 1],
        hint: 'Сначала local lamp = script.Parent, а в конце end.', explain: 'Лампа готова мигать!' },

      { type: 'learn', title: 'Готово! Вот твоя лампа',
        text: 'Скопируй скрипт в <b>Script</b> внутри блока-лампы в Roblox Studio и нажми Play. Лампа мигает красным и твоим цветом.',
        copy: true,
        code: 'local lamp = script.Parent\n\nwhile true do\n  lamp.BrickColor = BrickColor.new("Bright red")\n  task.wait(1)\n  lamp.BrickColor = BrickColor.new("{{lampColor}}")\n  task.wait(1)\nend' },
    ],
  },

  /* ───────── Урок 6: секретная дверь ───────── */
  door: {
    title: 'Урок 6 · Секретная дверь',
    icon: '🚪',
    defaults: { doorMsg: 'Секретная дверь открыта!' },
    summary: 'Ты собрал дверь с ключом! Не забудь добавить в дверь ClickDetector — и проверь в Play.',
    steps: [
      { type: 'learn', title: 'Сквозь блок',
        text: '<b>CanCollide</b> — «можно ли удариться о блок». Если поставить <b>false</b> — игрок пройдёт сквозь блок, как сквозь призрака.',
        code: 'local wall = script.Parent\nwall.CanCollide = false' },

      { type: 'choice', title: 'Что случится?',
        text: 'Что будет с игроком, если написать <b>CanCollide = false</b>?',
        options: ['Пройдёт сквозь блок', 'Упрётся в стену', 'Блок станет красным'], answer: 0,
        hint: 'Collide значит «сталкиваться». false — столкновения нет.', explain: 'Да! Блок станет «призраком» для игрока.' },

      { type: 'fill', title: 'Сделай проход',
        text: 'Сделай так, чтобы игрок мог <b>пройти</b> сквозь стену.',
        example: { code: 'local wall = script.Parent\nwall.CanCollide = false', label: 'Пример', mark: [1] },
        code: 'local wall = script.Parent\nwall.CanCollide = ___', bank: ['true', 'false'], answer: ['false'],
        hint: 'Чтобы пройти, столкновения быть не должно — false.' },

      { type: 'learn', title: 'Щёлкни по двери',
        text: '<b>ClickDetector</b> — «ловец щелчков». Положи его в дверь (Explorer → <b>+</b> рядом с дверью → ClickDetector). Тогда код внутри <b>MouseClick</b> сработает, когда по двери щёлкнут мышкой.',
        code: 'local door = script.Parent\nlocal detector = door.ClickDetector\n\ndetector.MouseClick:Connect(function()\n  print("Щёлк!")\nend)', out: 'Щёлк!  (когда щёлкнули по двери)' },

      { type: 'choice', title: 'Когда сработает код?',
        text: 'Когда выполнится код внутри <b>MouseClick</b>?',
        options: ['Когда щёлкнули мышкой по двери', 'Сразу, когда игра началась', 'Никогда'], answer: 0,
        hint: 'MouseClick — это щелчок мышкой.', explain: 'Верно! Код ждёт щелчка.' },

      { type: 'fill', title: 'Повтори по примеру',
        text: 'Найди слово, которое значит «щёлкнули мышкой».',
        example: { code: 'local door = script.Parent\nlocal detector = door.ClickDetector\n\ndetector.MouseClick:Connect(function()\n  print("Щёлк!")\nend)', label: 'Пример', mark: [3] },
        code: 'detector.___:Connect(function()', bank: ['MouseClick', 'Touched', 'Destroy'], answer: ['MouseClick'],
        hint: 'Это слово стоит в четвёртой строке примера.' },

      { type: 'learn', title: 'Дверь открывается',
        text: 'Чтобы дверь «открылась», сделаем её почти прозрачной и уберём столкновение. Это два свойства, которые ты уже знаешь!',
        code: 'detector.MouseClick:Connect(function()\n  door.Transparency = 0.8\n  door.CanCollide = false\n  print("Дверь открыта!")\nend)', out: 'Дверь открыта!' },

      { type: 'order', title: 'Собери открывание',
        text: 'Собери скрипт открывания двери по порядку.',
        lines: ['detector.MouseClick:Connect(function()', '  door.Transparency = 0.8', '  door.CanCollide = false', 'end)'], scramble: [3, 2, 0, 1],
        hint: 'Первая строка — detector.MouseClick…, последняя — end).', explain: 'Дверь открывается по порядку!' },

      { type: 'type', title: 'Придумай сообщение',
        text: 'Что напишет игра, когда дверь откроется? Например: <b>Секретная дверь открыта!</b>',
        example: { code: 'detector.MouseClick:Connect(function()\n  door.Transparency = 0.8\n  door.CanCollide = false\n  print("Дверь открыта!")\nend)', label: 'Пример', mark: [3] },
        wrap: ['  print("', '")'], placeholder: 'Секретная дверь открыта!', check: '^[^"\']{2,30}$', save: 'doorMsg', run: false, showOut: 'text',
        hint: 'Впиши любые слова без кавычек.', explain: 'Отлично! Это сообщение появится в игре.' },

      { type: 'learn', title: 'Нужен ключ: not',
        text: 'Слово <b>not</b> значит «НЕ». Если ключа нет — написать «Нужен ключ!». Так дверь не откроется без ключа.',
        code: 'local hasKey = false\n\nif not hasKey then\n  print("Нужен ключ!")\nend', out: 'Нужен ключ!' },

      { type: 'choice', title: 'Что напечатает код?',
        text: 'У героя ключ <b>есть</b> (hasKey = true). Что напечатает код?',
        code: 'local hasKey = true\n\nif not hasKey then\n  print("Нужен ключ!")\nend',
        options: ['Ничего', 'Нужен ключ!', 'Дверь открыта!'], answer: 0,
        hint: 'not hasKey — «ключа НЕТ». Но ключ есть, значит, условие неверное.', explain: 'Верно! Ключ есть, поэтому предупреждения нет.' },

      { type: 'fill', title: 'Повтори по примеру',
        text: 'Допиши слово: «если ключа <b>НЕТ</b>».',
        example: { code: 'local hasKey = false\n\nif not hasKey then\n  print("Нужен ключ!")\nend', label: 'Пример', mark: [2] },
        code: 'local hasKey = false\n\nif ___ hasKey then\n  print("Нужен ключ!")\nend', bank: ['not', 'and', 'end'], answer: ['not'],
        out: 'Нужен ключ!', hint: 'Слово «не» по-английски — not.' },

      { type: 'type', title: 'Выдай герою ключ',
        text: 'Дай герою ключ: впиши <b>true</b> («да, есть»). Тогда дверь откроется.',
        example: { code: 'local hasKey = false\n\nif hasKey then\n  print("Дверь открыта!")\nend', label: 'Пример', mark: [0] },
        wrap: ['local hasKey = ', '\n\nif hasKey then\n  print("Дверь открыта!")\nend'], placeholder: 'true', check: '^true$', out: 'Дверь открыта!',
        hint: 'Впиши слово true маленькими буквами.', explain: 'Ключ есть — дверь открыта!' },

      { type: 'learn', title: 'Готово! Дверь с ключом',
        text: 'Скопируй скрипт в <b>Script</b> внутри двери. Не забудь добавить в дверь <b>ClickDetector</b>. Сначала проверь с ключом (<b>hasKey = true</b>), потом поменяй на <b>false</b> — дверь не откроется!',
        copy: true,
        code: 'local door = script.Parent\nlocal detector = door.ClickDetector\nlocal hasKey = true\n\ndetector.MouseClick:Connect(function()\n  if hasKey then\n    door.Transparency = 0.8\n    door.CanCollide = false\n    print("{{doorMsg}}")\n  else\n    print("Нужен ключ!")\n  end\nend)' },
    ],
  },
};
