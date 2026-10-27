#!/usr/bin/env python3
"""Writes en_us.json and ru_ru.json from one table so both stay in sync.  Each entry: key -> (english, russian)."""
import json
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'src', 'main', 'resources', 'assets', 'hideandhunt', 'lang')
os.makedirs(OUT, exist_ok=True)

L = {}


def k(key, en, ru):
    L[key] = (en, ru)


H = 'hideandhunt.'

# ---------------------------------------------------------------- registry names
k('itemGroup.hideandhunt', 'Hide & Hunt', 'Прятки и Охота')
k('item.hideandhunt.game_master_tablet', 'Game Master Tablet', 'Планшет ведущего')
k('item.hideandhunt.game_master_tablet.desc', 'Right-click to edit the arena, teams, timers and rules', 'ПКМ — настроить арену, команды, таймеры и правила')
k('item.hideandhunt.game_master_tablet.op', 'Operators only', 'Только для операторов')
for b, en, ru, den, dru in [
    ('hider_pad', 'Hider Pad', 'Плита прячущихся', 'Step on it to join the Hiders', 'Встань на неё, чтобы стать прячущимся'),
    ('hunter_pad', 'Hunter Pad', 'Плита охотников', 'Step on it to join the Hunters', 'Встань на неё, чтобы стать охотником'),
    ('lobby_pad', 'Lobby Return Pad', 'Плита возврата в лобби', 'Step on it to teleport to the lobby', 'Встань на неё, чтобы вернуться в лобби'),
    ('hider_button', 'Join Hiders Button', 'Кнопка «Прятаться»', 'Press to join the Hiders', 'Нажми, чтобы стать прячущимся'),
    ('hunter_button', 'Join Hunters Button', 'Кнопка «Охотиться»', 'Press to join the Hunters', 'Нажми, чтобы стать охотником'),
    ('leave_button', 'Leave Side Button', 'Кнопка «Выйти из команды»', 'Press to leave your side', 'Нажми, чтобы покинуть команду'),
    ('randomizer_button', 'Randomizer Button', 'Кнопка-рандомайзер', 'Shuffles all lobby players into sides with a slot-machine reveal',
     'Случайно делит всех игроков лобби на команды с анимацией «однорукого бандита»'),
    ('start_button', 'Start Button', 'Кнопка «Старт»', 'Starts the round', 'Запускает раунд'),
]:
    k('block.hideandhunt.' + b, en, ru)
    k('block.hideandhunt.' + b + '.desc', den, dru)

k('key.categories.hideandhunt', 'Hide & Hunt', 'Прятки и Охота')
k('key.hideandhunt.taunt', 'Taunt (hiders)', 'Дразнилка (прячущиеся)')
k('key.hideandhunt.results', 'Show last results', 'Показать последние результаты')

for s, en, ru in [('countdown', 'Countdown beeps', 'Отсчёт'), ('defeat', 'Defeat', 'Поражение'),
                  ('randomizer_pop', 'Randomizer: name revealed', 'Рандомайзер: имя открыто'), ('hide_start', 'Hiding starts', 'Начало пряток'),
                  ('hunt_start', 'Hunting horn', 'Охотничий рог'), ('caught', 'Hider caught', 'Прячущийся пойман'),
                  ('taunt', 'Hider taunts', 'Прячущийся дразнится'), ('randomizer_tick', 'Randomizer clicks', 'Рандомайзер щёлкает'),
                  ('randomizer_reveal', 'Randomizer reveal', 'Рандомайзер: результат'), ('victory', 'Victory fanfare', 'Победные фанфары'),
                  ('hint_ping', 'Hider ping', 'Сигнал прячущегося'), ('join', 'Joined a side', 'Вход в команду')]:
    k('subtitles.hideandhunt.' + s, en, ru)

# ---------------------------------------------------------------- sides / phases
k(H + 'short', 'H&H', 'П&О')
for side, en, enp, ens, ru, rup, rus in [
    ('none', 'Unassigned', 'Unassigned', '-', 'Без команды', 'Без команды', '-'),
    ('hider', 'Hider', 'Hiders', 'H', 'Прячущийся', 'Прячущиеся', 'П'),
    ('hunter', 'Hunter', 'Hunters', 'K', 'Охотник', 'Охотники', 'О'),
    ('spectator', 'Spectator', 'Spectators', 'S', 'Зритель', 'Зрители', 'З'),
]:
    k(H + 'side.' + side, en, ru)
    k(H + 'side.' + side + '.plural', enp, rup)
    k(H + 'side.' + side + '.short', ens, rus)
for ph, en, ru in [('lobby', 'Lobby', 'Лобби'), ('countdown', 'Starting', 'Старт'), ('hiding', 'Hiding', 'Прятки'),
                   ('hunting', 'Hunting', 'Охота'), ('ending', 'Results', 'Итоги')]:
    k(H + 'phase.' + ph, en, ru)

# ---------------------------------------------------------------- settings
S = [
    ('join_mode', 'Join mode', 'Выбор команды', 'How players get a side.', 'Как игроки попадают в команду.'),
    ('mode', 'Game mode', 'Режим игры', 'What happens to caught hiders.', 'Что происходит с пойманными.'),
    ('hunter_ratio', 'Hunter ratio', 'Соотношение охотников', '1 hunter per N players (used by the randomizer and auto-assign).',
     '1 охотник на N игроков (для рандомайзера и автораспределения).'),
    ('min_players', 'Min players', 'Мин. игроков', 'Minimum number of players to start a round.', 'Минимум игроков для старта раунда.'),
    ('max_hiders', 'Max hiders', 'Макс. прячущихся', 'Limit of hiders (0 = unlimited).', 'Лимит прячущихся (0 = без лимита).'),
    ('max_hunters', 'Max hunters', 'Макс. охотников', 'Limit of hunters (0 = unlimited).', 'Лимит охотников (0 = без лимита).'),
    ('auto_assign', 'Auto-assign', 'Автораспределение', 'At start, players without a side are put into sides automatically.',
     'При старте игроки без команды распределяются автоматически.'),
    ('auto_balance', 'Auto-balance', 'Автобаланс', 'At start, fix an empty side or exceeded limits by moving random players.',
     'При старте исправляет пустую команду или превышение лимитов, перемещая случайных игроков.'),
    ('balance_check', 'Balance check', 'Проверка баланса', 'Players cannot join the hunters if there are already enough of them.',
     'Нельзя вступить в охотники, если их уже достаточно.'),
    ('reset_teams', 'Reset sides after round', 'Сброс команд после раунда', 'Everyone becomes unassigned when a round ends.',
     'После раунда все снова без команды.'),
    ('buttons_op_only', 'Start/Random: ops only', 'Старт/рандом: только опы', 'Only operators can use the Start and Randomizer buttons.',
     'Кнопками «Старт» и «Рандомайзер» могут пользоваться только операторы.'),
    ('countdown', 'Countdown', 'Отсчёт', 'Seconds before the round begins.', 'Секунд до начала раунда.'),
    ('hide_time', 'Hide time', 'Время пряток', 'Seconds hiders have to hide while hunters are frozen.', 'Сколько секунд прячутся, пока охотники заморожены.'),
    ('hunt_time', 'Hunt time', 'Время охоты', 'Length of the hunt. Hiders win if someone survives it.', 'Длительность охоты. Если кто-то выжил — победа прячущихся.'),
    ('hint_interval', 'Hint pings', 'Сигналы-подсказки', 'Every N seconds hiders emit a sound (0 = off).', 'Каждые N секунд прячущиеся издают звук (0 = выкл).'),
    ('glow_last', 'Glow in last', 'Свечение в конце', 'Hiders glow during the last N seconds (0 = off).', 'Прячущиеся светятся последние N секунд (0 = выкл).'),
    ('taunt_cooldown', 'Taunt cooldown', 'Перезарядка дразнилки', 'Seconds between taunts.', 'Секунд между дразнилками.'),
    ('results_time', 'Results time', 'Время итогов', 'Seconds of fireworks and results before returning to the lobby.', 'Секунд фейерверков и итогов до возврата в лобби.'),
    ('boundary_grace', 'Border grace', 'Отсрочка у границы', 'Seconds outside the arena border before being teleported back.', 'Сколько секунд можно быть за границей арены до телепорта назад.'),
    ('hunter_speed', 'Hunter speed', 'Скорость охотников', 'Speed effect level for hunters during the hunt (0 = none).', 'Уровень скорости охотников во время охоты (0 = нет).'),
    ('taunt_points', 'Taunt points', 'Очки за дразнилку', 'Bonus points a hider gets for each taunt.', 'Бонусные очки прячущемуся за каждую дразнилку.'),
    ('taunts', 'Taunts', 'Дразнилки', 'Hiders can press the taunt key to make a loud sound for bonus points.', 'Прячущиеся могут нажать клавишу дразнилки: громкий звук и бонусные очки.'),
    ('friendly_fire', 'PvP damage', 'Урон между игроками', 'Allow normal damage between players (tagging always works).', 'Разрешить обычный урон между игроками (ловля работает всегда).'),
    ('keep_inventory', 'Keep own inventory', 'Свой инвентарь', 'Players keep their own items in the round instead of the kit.', 'Игроки играют со своими вещами вместо набора.'),
    ('adventure', 'Adventure mode', 'Режим приключения', 'Players are in adventure mode during the round (can\'t break the map).', 'Во время раунда — режим приключения (карту не сломать).'),
    ('env_damage', 'Environment damage', 'Урон от окружения', 'Players take fall/lava/mob damage. Deaths respawn at the side spawn.', 'Урон от падения/лавы/мобов. После «смерти» — возврат на спавн.'),
    ('freeze_hunters', 'Freeze hunters', 'Заморозка охотников', 'Hunters cannot move while hiders hide.', 'Охотники не могут двигаться, пока прячутся.'),
    ('blind_hunters', 'Blind hunters', 'Ослепление охотников', 'Hunters are blinded while hiders hide.', 'Охотники ослеплены, пока прячутся.'),
    ('hide_nametags', 'Hide hider name tags', 'Скрыть ники прячущихся', 'Hunters cannot see hiders\' name tags through walls.', 'Охотники не видят ники прячущихся.'),
    ('last_hider_glow', 'Last hider glows', 'Последний светится', 'The last remaining hider starts glowing.',
     'Последний оставшийся прячущийся начинает светиться.'),
    ('sidebar', 'Scoreboard sidebar', 'Боковая таблица', 'Show the round sidebar (time, hiders left, hunters).', 'Показывать боковую таблицу (время, осталось, охотники).'),
]
for key, en, ru, den, dru in S:
    k(H + 'setting.' + key, en, ru)
    k(H + 'setting.' + key + '.desc', den, dru)
for key, val, en, ru, den, dru in [
    ('join_mode', 'free', 'Free choice', 'Свободный', 'Pads, buttons and /hh join.', 'Плиты, кнопки и /hh join.'),
    ('join_mode', 'pads', 'Pads & buttons', 'Плиты и кнопки', 'Only the pads and join buttons on the map.', 'Только плиты и кнопки на карте.'),
    ('join_mode', 'random', 'Random', 'Случайно', 'Sides are only assigned by the Randomizer (Start runs it automatically).',
     'Команды назначает только рандомайзер (кнопка «Старт» запустит его сама).'),
    ('join_mode', 'admin', 'Admin assigns', 'Ведущий', 'Only operators assign sides (/hh team or the tablet).', 'Команды назначают только операторы (/hh team или планшет).'),
    ('mode', 'classic', 'Classic', 'Классика', 'Caught hiders become spectators.', 'Пойманные становятся зрителями.'),
    ('mode', 'infection', 'Infection', 'Заражение', 'Caught hiders become hunters.', 'Пойманные становятся охотниками.'),
]:
    k(H + 'choice.' + key + '.' + val, en, ru)
    k(H + 'choice.' + key + '.' + val + '.desc', den, dru)

# ---------------------------------------------------------------- titles / boss bar / sidebar
k(H + 'title.round_starts', 'Round starts in...', 'Раунд начнётся через...')
k(H + 'title.wait', 'WAIT...', 'ЖДИ...')
k(H + 'title.wait_sub', 'Hiders are hiding (%s s)', 'Прячущиеся прячутся (%s с)')
k(H + 'title.hide', 'HIDE!', 'ПРЯЧЬСЯ!')
k(H + 'title.hide_sub', 'You have %s seconds', 'У тебя %s секунд')
k(H + 'title.release_in', 'Release in...', 'Выпуск через...')
k(H + 'title.hunt', 'HUNT!', 'ОХОТА!')
k(H + 'title.hunt_sub', 'Find %s hiders', 'Найди прячущихся: %s')
k(H + 'title.released', 'Hunters released!', 'Охотники выпущены!')
k(H + 'title.released_sub', 'Stay hidden...', 'Не высовывайся...')
k(H + 'title.caught', 'CAUGHT!', 'ПОЙМАН!')
k(H + 'title.caught_sub', 'You can fly through walls — no hints!', 'Можно летать сквозь стены — не подсказывай!')
k(H + 'title.last_hider', 'LAST HIDER!', 'ПОСЛЕДНИЙ ПРЯЧУЩИЙСЯ!')
k(H + 'title.infected', 'INFECTED!', 'ЗАРАЖЁН!')
k(H + 'title.infected_sub', 'Now you hunt them', 'Теперь ты охотник')
k(H + 'title.victory', 'VICTORY!', 'ПОБЕДА!')
k(H + 'title.defeat', 'DEFEAT', 'ПОРАЖЕНИЕ')
k(H + 'title.hiders_win', 'The hiders win', 'Победили прячущиеся')
k(H + 'title.hunters_win', 'The hunters win', 'Победили охотники')
k(H + 'title.you_are', 'You are: %s', 'Ты: %s')
k(H + 'title.you_are.hider_sub', 'Get ready to hide!', 'Готовься прятаться!')
k(H + 'title.you_are.hunter_sub', 'Get ready to hunt!', 'Готовься охотиться!')
k(H + 'title.you_are.spect_sub', 'The teams are full, you will watch', 'Команды заполнены — ты смотришь')
k(H + 'boss.hiding', 'Hiding — %s', 'Прятки — %s')
k(H + 'boss.hunting', 'Hunt — %s — hiders left: %s', 'Охота — %s — осталось: %s')
k(H + 'boss.hiders_win', 'The hiders win!', 'Победа прячущихся!')
k(H + 'boss.hunters_win', 'The hunters win!', 'Победа охотников!')
k(H + 'sidebar.time', 'Time', 'Время')
k(H + 'sidebar.hiders', 'Hiders left', 'Прячущихся')
k(H + 'sidebar.hunters', 'Hunters', 'Охотников')
k(H + 'sidebar.caught', 'Caught', 'Поймано')

# ---------------------------------------------------------------- chat / action bar messages
M = [
    ('join_random', 'Sides are chosen by the Randomizer on this map', 'На этой карте команды выбирает рандомайзер'),
    ('join_admin', 'Sides are assigned by the game master', 'Команды назначает ведущий'),
    ('join_pads', 'Use the pads or buttons on the map to choose a side', 'Выбирай команду плитами или кнопками на карте'),
    ('already_side', 'You are already: %s', 'Ты уже: %s'),
    ('game_running', 'A round is in progress', 'Идёт раунд'),
    ('side_full', '%s are full (max %s)', '%s: мест нет (макс. %s)'),
    ('side_unbalanced', 'There are enough %s already', '%s уже достаточно'),
    ('left_side', 'You left your side', 'Ты покинул команду'),
    ('joined', 'You joined: %s (%s) • %s: %s', 'Ты в команде: %s (%s) • %s: %s'),
    ('joined_spectator', 'You will watch the next round', 'Следующий раунд ты смотришь'),
    ('last_hider', '%s is the last hider!', '%s — последний прячущийся!'),
    ('last_hider_glow', '%s is the last hider — and now glows!', '%s — последний прячущийся! Теперь он светится!'),
    ('test_need_player', 'A test round must be started by a player', 'Тестовый раунд запускает игрок'),
    ('test_starting', 'Test round for %s: you are the only hider, no hunters, nothing is counted', 'Тестовый раунд для %s: ты единственный прячущийся, охотников нет, ничего не засчитывается'),
    ('test_over', 'Test round over', 'Тестовый раунд окончен'),
    ('results_link', '[Show results]', '[Показать итоги]'),
    ('results_link.hover', 'Open the results screen again', 'Снова открыть экран итогов'),
    ('no_results', 'No round has finished yet', 'Ещё ни один раунд не закончился'),
    ('show_on', 'Showing spawns and the border for %s s (only you see them)', 'Спавны и граница видны %s с (только тебе)'),
    ('show_other_dim', 'The arena is in %s — go there to see the markers', 'Арена в измерении %s — перейди туда, чтобы увидеть метки'),
    ('spawn_removed', '%s spawn #%s (%s) removed, %s left', 'Спавн «%s» №%s (%s) удалён, осталось %s'),
    ('spawns_cleared_all', 'Hider and hunter spawns cleared (lobby and spectator spawns are kept)', 'Спавны прячущихся и охотников удалены (лобби и спавн зрителей остались)'),
    ('locked_in_round', 'Can\'t move the lobby or the arena dimension during a round', 'Нельзя менять лобби и измерение арены во время раунда'),
    ('bounds_set_flat', 'Arena border: %s -> %s (%s blocks, whole height: the corners are at about the same height)',
     'Граница арены: %s -> %s (%s блоков, на всю высоту: углы примерно на одной высоте)'),
    ('assigned', 'The game master put you in: %s', 'Ведущий назначил тебя: %s'),
    ('no_lobby', 'The lobby spawn is not set (/hh setspawn lobby)', 'Спавн лобби не задан (/hh setspawn lobby)'),
    ('randomizer_busy', 'Wait — the randomizer is spinning', 'Подожди — крутится рандомайзер'),
    ('randomizer_need', 'Need at least %s players in the lobby (now %s)', 'Нужно минимум %s игроков в лобби (сейчас %s)'),
    ('randomizing', '%s pulled the randomizer lever!', '%s дёрнул рычаг рандомайзера!'),
    ('randomized', 'Hiders: %s | Hunters: %s', 'Прячущиеся: %s | Охотники: %s'),
    ('already_running', 'A game is already running', 'Игра уже идёт'),
    ('need_hider_spawn', 'No hider spawn set (/hh addspawn hiders)', 'Нет спавна прячущихся (/hh addspawn hiders)'),
    ('need_hunter_spawn', 'No hunter spawn set (/hh addspawn hunters)', 'Нет спавна охотников (/hh addspawn hunters)'),
    ('start_after_randomizer', 'The round starts right after the randomizer!', 'Раунд начнётся сразу после рандомайзера!'),
    ('too_many', 'Too many %s (max %s)', 'Слишком много: %s (макс. %s)'),
    ('need_players', 'Need at least %s players (now %s)', 'Нужно минимум %s игроков (сейчас %s)'),
    ('need_side', 'Nobody is in: %s', 'Никого в команде: %s'),
    ('starting', 'Round starts in %s s! Hiders: %s, hunters: %s', 'Раунд через %s с! Прячущихся: %s, охотников: %s'),
    ('start_cancelled', 'Not enough players — start cancelled', 'Недостаточно игроков — старт отменён'),
    ('hiding_started', '%s hiders are hiding from %s hunters for %s s!', '%s прячущихся прячутся от %s охотников (%s с)!'),
    ('hide_left', '%s seconds to hide!', 'Осталось %s секунд, чтобы спрятаться!'),
    ('hunt_started', 'The hunt is on! Survive %s', 'Охота началась! Продержитесь %s'),
    ('glowing', 'The hiders are glowing now!', 'Прячущиеся теперь светятся!'),
    ('hint_ping', 'You made a noise...', 'Ты издал звук...'),
    ('time_left', 'Time left: %s', 'Осталось: %s'),
    ('reason_time', '(time is up)', '(время вышло)'),
    ('reason_all_caught', '(everyone was caught)', '(всех поймали)'),
    ('reason_no_hunters', '(all hunters left)', '(все охотники вышли)'),
    ('returned', 'You were returned to the arena', 'Тебя вернули на арену'),
    ('out_of_bounds', 'Go back into the arena! %s', 'Вернись на арену! %s'),
    ('you_caught', 'You caught %s!', 'Ты поймал: %s!'),
    ('caught', '%s was caught by %s! Hiders left: %s', '%s пойман игроком %s! Осталось прячущихся: %s'),
    ('respawned', 'You were sent back to your spawn', 'Тебя вернули на спавн'),
    ('taunt_only_hiders', 'Only hiding players can taunt during the hunt', 'Дразниться могут только прячущиеся во время охоты'),
    ('taunts_disabled', 'Taunts are disabled', 'Дразнилки отключены'),
    ('taunt_cooldown', 'Taunt ready in %s s', 'Дразнилка через %s с'),
    ('taunted', 'Taunt! +%s points', 'Дразнилка! +%s очков'),
    ('hiders_win', 'The hiders win!', 'Победили прячущиеся!'),
    ('hunters_win', 'The hunters win!', 'Победили охотники!'),
    ('best_hider', 'Best hider: %s (%s)', 'Лучший прячущийся: %s (%s)'),
    ('top_hunter', 'Top hunter: %s (%s caught)', 'Лучший охотник: %s (поймано: %s)'),
    ('restored', 'Your items and game mode were restored after the round', 'Твои вещи и режим игры восстановлены после раунда'),
    ('rejoined', 'You are back in the round as: %s', 'Ты вернулся в раунд: %s'),
    ('hider_left', '%s left the game. Hiders left: %s', '%s вышел из игры. Осталось прячущихся: %s'),
    ('player_left', '%s left the game', '%s вышел из игры'),
    ('no_permission', 'Only operators can do that', 'Это могут только операторы'),
    ('bad_value', 'Invalid value for %s: %s', 'Неверное значение %s: %s'),
    ('bad_key', 'Unknown setting: %s', 'Неизвестная настройка: %s'),
    ('bad_side', 'Unknown side: %s (hiders, hunters, none, spectator)', 'Неизвестная команда: %s (hiders, hunters, none, spectator)'),
    ('renamed', 'Arena renamed to %s', 'Арена переименована: %s'),
    ('bounds_set', 'Arena border: %s -> %s (%s blocks)', 'Граница арены: %s -> %s (%s блоков)'),
    ('bounds_partial', 'Border corner saved — set the other corner too', 'Угол границы сохранён — задай второй угол'),
    ('bounds_cleared', 'Arena border removed', 'Граница арены удалена'),
    ('stopped_by', 'The round was stopped by %s', 'Раунд остановил %s'),
    ('stopped', 'Game stopped', 'Игра остановлена'),
    ('not_running', 'No game is running', 'Игра не идёт'),
    ('teams_reset', 'All sides were reset', 'Все команды сброшены'),
    ('kit_saved', 'Kit for %s saved (%s stacks)', 'Набор для «%s» сохранён (стаков: %s)'),
    ('kit_cleared', 'Kit for %s cleared', 'Набор для «%s» очищен'),
    ('spawn_set', '%s set at %s', '%s: установлен в %s'),
    ('spawn_added', '%s spawn added at %s (total %s)', 'Спавн «%s» добавлен в %s (всего %s)'),
    ('spawns_cleared', 'Spawns cleared: %s', 'Спавны очищены: %s'),
    ('dim_warning', 'Warning: the arena is in %s, all spawns should be in one dimension!', 'Внимание: арена в %s, все спавны должны быть в одном измерении!'),
    ('single_spawn', 'Lobby and spectator have one spawn — use /hh setspawn', 'У лобби и зрителей один спавн — используй /hh setspawn'),
    ('start_ok', 'Starting!', 'Старт!'),
    ('settings_reset', 'Settings reset to defaults', 'Настройки сброшены'),
    ('arena_reset', 'The arena was wiped', 'Арена полностью сброшена'),
    ('team_set', '%s player(s) moved to: %s', 'Игроков перемещено: %s → %s'),
    ('setting_set', '%s = %s', '%s = %s'),
    ('tablet_given', 'Here is your Game Master Tablet', 'Держи планшет ведущего'),
    ('no_spawn', 'Spawn not set: %s', 'Спавн не задан: %s'),
]
for key, en, ru in M:
    k(H + 'msg.' + key, en, ru)

k(H + 'spawn.lobby', 'Lobby', 'Лобби')
k(H + 'spawn.spectator', 'Spectator spawn', 'Спавн зрителей')
k(H + 'spawn.hiders', 'Hiders', 'Прячущиеся')
k(H + 'spawn.hunters', 'Hunters', 'Охотники')
k(H + 'spawn.bounds', 'Border', 'Граница')
k(H + 'spawns.hover', 'Click to teleport\n%s, yaw %s', 'Нажми, чтобы телепортироваться\n%s, поворот %s')
k(H + 'spawns.tip', 'Click coordinates to teleport. /hh show — see all spawns in the world', 'Нажми на координаты для телепорта. /hh show — увидеть спавны в мире')
k(H + 'spawns.header', 'Spawns of "%s" (%s):', 'Спавны «%s» (%s):')
k(H + 'settings.header', 'Settings (/hh settings <key> <value>):', 'Настройки (/hh settings <ключ> <значение>):')
k(H + 'status.phase', 'Phase: %s  %s', 'Фаза: %s  %s')
k(H + 'status.mode', 'Mode: %s, joining: %s', 'Режим: %s, выбор команды: %s')
k(H + 'status.round', 'Hiders left: %s/%s, hunters: %s', 'Осталось прячущихся: %s/%s, охотников: %s')
k(H + 'status.lobby', 'In lobby — hiders: %s, hunters: %s, unassigned: %s', 'В лобби — прячущихся: %s, охотников: %s, без команды: %s')
k(H + 'status.spawns', 'Lobby %s | hider spawns %s | hunter spawns %s | spectator %s | border %s',
  'Лобби %s | спавны прячущихся %s | спавны охотников %s | зрители %s | граница %s')

k(H + 'help.header', 'Hide & Hunt commands', 'Команды «Прятки и Охота»')
for key, en, ru in [
    ('join', '<side> — join hiders / hunters / none / spectator', '<команда> — вступить: hiders / hunters / none / spectator'),
    ('leave', '— leave your side', '— покинуть команду'),
    ('taunt', '— taunt (hiders, for points)', '— дразнилка (прячущиеся, за очки)'),
    ('status', '— arena status', '— состояние арены'),
    ('start', '[test] — start the round; "test" = solo test round (op)', '[test] — начать раунд; «test» — тестовый раунд в одиночку (оп)'),
    ('show', '[seconds] — show spawns and the border with particles (op)', '[секунды] — показать спавны и границу частицами (оп)'),
    ('removespawn', '<hiders|hunters> <#|nearest> — remove one spawn (op)', '<hiders|hunters> <№|nearest> — удалить один спавн (оп)'),
    ('results', '— show the last results again', '— снова показать последние итоги'),
    ('stop', '— stop the round (op)', '— остановить раунд (оп)'),
    ('randomize', '— shuffle lobby players into sides (op)', '— случайно распределить игроков (оп)'),
    ('reset', '[teams|settings|arena] — reset (op)', '[teams|settings|arena] — сброс (оп)'),
    ('team', '<players> <side> — assign a side (op)', '<игроки> <команда> — назначить команду (оп)'),
    ('setspawn', '<lobby|hiders|hunters|spectator> [pos] — set a spawn (op)', '<lobby|hiders|hunters|spectator> [поз] — задать спавн (оп)'),
    ('addspawn', '<hiders|hunters> [pos] — add one more spawn (op)', '<hiders|hunters> [поз] — добавить ещё спавн (оп)'),
    ('clearspawns', '<hiders|hunters|all> — remove spawns; lobby/spectator are kept (op)', '<hiders|hunters|all> — удалить спавны; лобби и зрители остаются (оп)'),
    ('spawns', '— list spawns (op)', '— список спавнов (оп)'),
    ('tp', '<lobby|hiders|hunters|spectator> [#] — teleport to a spawn (op)', '<lobby|hiders|hunters|spectator> [№] — телепорт к спавну (оп)'),
    ('setbounds', '<pos1> <pos2> — arena border (op)', '<поз1> <поз2> — граница арены (оп)'),
    ('clearbounds', '— remove the border (op)', '— убрать границу (оп)'),
    ('joinmode', '<free|pads|random|admin> — how sides are chosen (op)', '<free|pads|random|admin> — способ выбора команды (оп)'),
    ('mode', '<classic|infection> — game mode (op)', '<classic|infection> — режим игры (оп)'),
    ('name', '<name> — rename the arena (op)', '<имя> — переименовать арену (оп)'),
    ('settings', '[key] [value] — view / change settings (op)', '[ключ] [значение] — смотреть / менять настройки (оп)'),
    ('kit', '<hiders|hunters> <set|clear> — kit from your inventory (op)', '<hiders|hunters> <set|clear> — набор из твоего инвентаря (оп)'),
    ('tablet', '— get the Game Master Tablet (op)', '— получить планшет ведущего (оп)'),
]:
    k(H + 'help.' + key, en, ru)

# ---------------------------------------------------------------- HUD
k(H + 'hud.side', 'Side:', 'Команда:')
k(H + 'hud.eliminated', 'Eliminated', 'Выбыл')
k(H + 'hud.lobby_counts', 'Hiders %s  Hunters %s  Free %s', 'Прячутся %s  Охотники %s  Без %s')
for jm, en, ru in [('free', 'Choose a side: pads, buttons, /hh join', 'Выбор: плиты, кнопки, /hh join'),
                   ('pads', 'Choose a side with the pads/buttons', 'Выбор: плиты и кнопки'),
                   ('random', 'Sides are picked by the Randomizer', 'Команды выбирает рандомайзер'),
                   ('admin', 'The game master assigns sides', 'Команды назначает ведущий')]:
    k(H + 'hud.join.' + jm, en, ru)
k(H + 'hud.starting_in', 'Starting in %s s', 'Старт через %s с')
k(H + 'hud.hide_left', 'to hide', 'на прятки')
k(H + 'hud.hunt_left', 'to survive', 'продержаться')
k(H + 'hud.hiders_left', 'Hiders %s', 'Прячутся %s')
k(H + 'hud.hunters', 'Hunters %s', 'Охотники %s')
k(H + 'hud.taunt_cd', 'Taunt in %s s', 'Дразнилка через %s с')
k(H + 'hud.taunt_ready', '[%s] Taunt for points!', '[%s] Подразнить за очки!')
k(H + 'hud.round_over', 'Round over — lobby in %s s', 'Раунд окончен — лобби через %s с')

# ---------------------------------------------------------------- randomizer
k(H + 'randomizer.title', '? RANDOMIZER ?', '? РАНДОМАЙЗЕР ?')
k(H + 'randomizer.you', 'You are: %s', 'Ты: %s')
k(H + 'randomizer.watching', 'You are watching', 'Ты наблюдаешь')
k(H + 'randomizer.spinning', 'Spinning...', 'Крутим...')
k(H + 'randomizer.summary', 'Hiders: %s • Hunters: %s', 'Прячущихся: %s • Охотников: %s')

# ---------------------------------------------------------------- results
k(H + 'results.title', 'Round results', 'Итоги раунда')
k(H + 'results.hiders_win', 'HIDERS WIN!', 'ПОБЕДА ПРЯЧУЩИХСЯ!')
k(H + 'results.hunters_win', 'HUNTERS WIN!', 'ПОБЕДА ОХОТНИКОВ!')
k(H + 'results.sub', '%s • hunt lasted %s • %s', '%s • охота длилась %s • %s')
k(H + 'results.best_hider', 'Best hider', 'Лучший прячущийся')
k(H + 'results.top_hunter', 'Top hunter', 'Лучший охотник')
k(H + 'results.mvp', 'MVP', 'MVP')
k(H + 'results.catches_n', '%s caught', 'поймано: %s')
k(H + 'results.infected', 'Infected', 'Заражён')
k(H + 'results.left', '(left)', '(вышел)')
k(H + 'results.you_won', 'You won!', 'Ты победил!')
k(H + 'results.you_lost', 'You lost', 'Ты проиграл')
k(H + 'results.taunts_hint', '\u266A = taunts', '\u266A = дразнилки')
for c, en, ru in [('player', 'Player', 'Игрок'), ('role', 'Role', 'Роль'), ('catches', 'Caught', 'Поймал'),
                  ('survived', 'Time', 'Время'), ('caught_by', 'Caught by', 'Кем пойман'), ('points', 'Points', 'Очки')]:
    k(H + 'results.col.' + c, en, ru)

# ---------------------------------------------------------------- tablet GUI
G = H + 'gui.'
for key, en, ru in [
    ('title', 'Game Master Tablet', 'Планшет ведущего'),
    ('tab.arena', 'Arena', 'Арена'), ('tab.players', 'Players', 'Игроки'), ('tab.teams', 'Teams', 'Команды'),
    ('tab.timers', 'Timers', 'Таймеры'), ('tab.rules', 'Rules', 'Правила'),
    ('start', '▶ Start', '▶ Старт'), ('stop', '■ Stop', '■ Стоп'),
    ('randomize', '? Randomize', '? Рандом'), ('randomize.desc', 'Shuffle everyone in the lobby into sides', 'Случайно распределить всех в лобби'),
    ('close', 'Close', 'Закрыть'), ('name', 'Arena name', 'Название арены'), ('rename', 'Rename', 'Переименовать'),
    ('set_lobby', 'Set lobby here', 'Лобби — здесь'), ('set_spectator', 'Spectator spawn here', 'Спавн зрителей — здесь'),
    ('add_hider', '+ Hider spawn here (%s)', '+ Спавн прячущихся (%s)'), ('add_hunter', '+ Hunter spawn here (%s)', '+ Спавн охотников (%s)'),
    ('add_spawn.desc', 'Adds a spawn at your position and view direction. Several spawns are used in turn.',
     'Добавляет спавн в твоей позиции и направлении взгляда. Несколько спавнов используются по очереди.'),
    ('clear_hiders', 'Clear hider spawns', 'Очистить спавны прячущихся'), ('clear_hunters', 'Clear hunter spawns', 'Очистить спавны охотников'),
    ('bounds1', 'Border corner 1 here', 'Угол границы 1 — здесь'), ('bounds2', 'Border corner 2 here', 'Угол границы 2 — здесь'),
    ('bounds_clear', 'Remove border', 'Убрать границу'), ('tp_lobby', 'Teleport to lobby', 'Телепорт в лобби'),
    ('current', 'Current: %s', 'Сейчас: %s'), ('not_set', 'not set', 'не задано'),
    ('info', 'Dimension: %s • rounds played: %s', 'Измерение: %s • сыграно раундов: %s'),
    ('reset_teams', 'Reset all sides', 'Сбросить все команды'), ('reset_teams.desc', 'Everyone becomes unassigned', 'Все станут без команды'),
    ('page', 'Page %s/%s', 'Стр. %s/%s'), ('roster_empty', 'Nobody online', 'Никого нет онлайн'),
    ('other_dim', '(other dimension)', '(другое измерение)'),
    ('side_btn.hider', 'Hide', 'Пряч'), ('side_btn.hunter', 'Hunt', 'Охот'), ('side_btn.none', '—', '—'), ('side_btn.spectator', 'Spec', 'Зрит'),
    ('side_btn.desc', 'Put into: %s', 'Назначить: %s'),
    ('kit_hider_set', 'Hider kit \u2190 my inv. (%s)', 'Набор пряч. \u2190 мой инв. (%s)'),
    ('kit_hunter_set', 'Hunter kit \u2190 my inv. (%s)', 'Набор охот. \u2190 мой инв. (%s)'),
    ('kit_set.desc', 'Copies your whole inventory (incl. armour) as the kit. Used when "Keep own inventory" is off.',
     'Копирует весь твой инвентарь (вместе с бронёй) как набор. Используется, если «Свой инвентарь» выключен.'),
    ('kit_hider_clear', 'Clear hider kit', 'Очистить набор прячущихся'), ('kit_hunter_clear', 'Clear hunter kit', 'Очистить набор охотников'),
    ('on', 'ON', 'ВКЛ'), ('off', 'Off', 'Выкл'), ('unlimited', 'Unlimited', 'Без лимита'),
    ('ratio', '1 per %s', '1 на %s'), ('speed_level', 'Level %s', 'Ур. %s'),
    ('seconds', '%ss', '%s с'),
    ('confirm', 'Sure? Click again', 'Точно? Ещё раз'), ('confirm.desc', 'Click twice to confirm', 'Нажми дважды для подтверждения'),
    ('rmb_reset', 'Right-click: reset to default (%s)', 'ПКМ — сбросить (по умолч.: %s)'),
    ('show', 'Show spawns (30 s)', 'Показать спавны (30 с)'),
    ('show.desc', 'Particle markers at every spawn and along the border, visible only to you',
     'Метки-частицы на всех спавнах и вдоль границы, видны только тебе'),
    ('test', 'Solo test round', 'Тестовый раунд'),
    ('test.desc', 'Play a round alone as a hider to check spawns and timers. Nothing is counted.',
     'Сыграть раунд одному за прячущегося, чтобы проверить спавны и таймеры. Ничего не засчитывается.'),
    ('bounds.desc', 'Corners are diagonal: one low, one high. If they are at about the same height, the border covers the whole height.',
     'Углы по диагонали: один внизу, другой вверху. Если они примерно на одной высоте, граница действует на всю высоту.'),
]:
    k(G + key, en, ru)

for lang, idx in (('en_us', 0), ('ru_ru', 1)):
    with open(os.path.join(OUT, lang + '.json'), 'w', encoding='utf-8') as f:
        json.dump({key: v[idx] for key, v in L.items()}, f, ensure_ascii=False, indent=2)
        f.write('\n')
print(len(L), 'keys written')
