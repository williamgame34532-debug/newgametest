#!/usr/bin/env python3
"""Writes en_us.json and ru_ru.json for Echoes of Sleep."""
import json, os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'src', 'main', 'resources', 'assets', 'echoesofsleep', 'lang')
P = 'echoesofsleep'

# key: (english, russian)
L = {}


def add(key, en, ru):
    L[key] = (en, ru)


add(f'itemGroup.{P}', 'Echoes of Sleep', 'Эхо Сна')

ITEMS = {
    'dream_shard': ('Dream Shard', 'Осколок сна'),
    'dawn_ingot': ('Dawn Ingot', 'Слиток рассвета'),
    'nightmare_heart': ('Nightmare Heart', 'Сердце кошмара'),
    'dawn_tincture': ('Dawn Tincture', 'Настойка рассвета'),
    'dream_totem': ('Dream Totem', 'Тотем сна'),
    'dawn_blade': ('Dawn Blade', 'Клинок рассвета'),
    'echo_scythe': ('Echo Scythe', 'Коса эха'),
    'lullaby_staff': ('Lullaby Staff', 'Посох колыбельной'),
    'insomnia_lantern': ('Insomnia Lantern', 'Фонарь бессонницы'),
    'echo_doppelganger_spawn_egg': ('Echo Doppelganger Spawn Egg', 'Яйцо призыва эхо-двойника'),
    'stitcher_spawn_egg': ('Stitcher Spawn Egg', 'Яйцо призыва сборщика'),
    'sleepless_spawn_egg': ('Sleepless Spawn Egg', 'Яйцо призыва бессонника'),
    'hollow_villager_spawn_egg': ('Hollow Villager Spawn Egg', 'Яйцо призыва пустого жителя'),
    'deep_mother_spawn_egg': ('Deep Mother Spawn Egg', 'Яйцо призыва глубинной матери'),
    'the_dreamer_spawn_egg': ('The Dreamer Spawn Egg', 'Яйцо призыва Того, кто снится'),
}
SETS = {'dreamcatcher': ('Dreamcatcher', 'Ловца снов'), 'wakeful': ('Wakeful', 'Бодрствующего'),
        'nightmare_eater': ('Nightmare Eater', 'Пожирателя кошмаров')}
PIECES = {'helmet': ('Helmet', 'Шлем'), 'chestplate': ('Chestplate', 'Нагрудник'), 'leggings': ('Leggings', 'Поножи'), 'boots': ('Boots', 'Ботинки')}
for s, (sen, sru) in SETS.items():
    for p, (pen, pru) in PIECES.items():
        ITEMS[f'{s}_{p}'] = (f'{sen} {pen}', f'{pru} {sru}')
for k, (en, ru) in ITEMS.items():
    add(f'item.{P}.{k}', en, ru)

BLOCKS = {
    'dream_shard_ore': ('Dream Shard Ore', 'Руда осколков сна'),
    'deepslate_dream_shard_ore': ('Deepslate Dream Shard Ore', 'Глубинносланцевая руда осколков сна'),
    'ashen_grass': ('Ashen Grass', 'Пепельная трава'),
    'dreamrot': ('Dreamrot', 'Сногниль'),
    'weeping_leaves': ('Weeping Leaves', 'Плачущая листва'),
}
for k, (en, ru) in BLOCKS.items():
    add(f'block.{P}.{k}', en, ru)

ENTITIES = {
    'echo_doppelganger': ('Echo Doppelganger', 'Эхо-двойник'),
    'stitcher': ('Stitcher', 'Сборщик'),
    'sleepless': ('The Sleepless', 'Бессонник'),
    'hollow_villager': ('Hollow Villager', 'Пустой житель'),
    'deep_mother': ('Deep Mother', 'Глубинная мать'),
    'mother_hand': ("Mother's Hand", 'Рука Матери'),
    'the_dreamer': ('The Dreamer', 'Тот, кто снится'),
    'reality_fragment': ('Reality Fragment', 'Осколок реальности'),
}
for k, (en, ru) in ENTITIES.items():
    add(f'entity.{P}.{k}', en, ru)

DESC = {
    'dream_shard': ('A splinter of someone\'s nightmare. Still warm.', 'Осколок чьего-то кошмара. Ещё тёплый.'),
    'dawn_ingot': ('Forged from a dream and the first light of morning.', 'Выкован из сна и первого утреннего света.'),
    'nightmare_heart': ('It is still beating. Not in your rhythm.', 'Оно всё ещё бьётся. Не в твоём ритме.'),
    'dawn_tincture': ('Drink: Dread -30, clears darkness from your eyes.', 'Выпить: Страх -30, снимает тьму с глаз.'),
    'dream_totem': ('Use on the ground during a Nightmare (level 3) to summon The Dreamer.',
                    'Используй на земле во время Кошмара (3 уровень), чтобы призвать Того, кто снится.'),
    'dawn_blade': ('Double damage to nightmares. Its light blinds them.', 'Двойной урон кошмарам. Его свет ослепляет их.'),
    'echo_scythe': ('Every hit is repeated a second later by a ghostly slash.', 'Каждый удар через секунду повторяет призрачный взмах.'),
    'lullaby_staff': ('Use: nightmares within 10 blocks fall asleep for 5 s (15 s cooldown).',
                      'Использовать: кошмары в радиусе 10 блоков засыпают на 5 с (перезарядка 15 с).'),
    'insomnia_lantern': ('Hold it (offhand works): the Sleepless cannot come within 14 blocks.',
                         'Держи в руке (подойдёт левая): Бессонник не подойдёт ближе 14 блоков.'),
}
for k, (en, ru) in DESC.items():
    add(f'item.{P}.{k}.desc', en, ru)

add(f'tooltip.{P}.set_bonus', 'Full set bonus:', 'Бонус полного комплекта:')
add(f'tooltip.{P}.set.dreamcatcher', 'Night vision during a Distortion; nightmares nearby glow.',
    'Ночное зрение во время Искажения; кошмары поблизости подсвечиваются.')
add(f'tooltip.{P}.set.wakeful', '-30% damage taken from nightmares.', '-30% урона от кошмаров.')
add(f'tooltip.{P}.set.nightmare_eater', 'Heal on killing a nightmare; sneak + jump to dash.',
    'Лечение при убийстве кошмара; присесть + прыжок — рывок.')

for i, (en, ru) in enumerate([('None', 'Нет'), ('Unease', 'Тревога'), ('Warped', 'Искажение'), ('Nightmare', 'Кошмар')]):
    add(f'distortion.{P}.level.{i}', en, ru)
add(f'message.{P}.level.1', 'The world feels... uneasy.', 'Мир кажется... тревожным.')
add(f'message.{P}.level.2', 'The world has warped while you slept.', 'Пока ты спал, мир исказился.')
add(f'message.{P}.level.3', 'You never woke up. This is the Nightmare.', 'Ты так и не проснулся. Это Кошмар.')
add(f'message.{P}.wake.sleeper', 'You wake up in a cold sweat. Something followed you out of the dream.',
    'Ты просыпаешься в холодном поту. Что-то вышло вслед за тобой из сна.')
add(f'message.{P}.wake.other', 'Someone slept. The world shudders, as if remembering.',
    'Кто-то уснул. Мир вздрагивает, будто вспоминая.')
add(f'message.{P}.fade', 'The dream fades... for now.', 'Сон отступает... пока что.')
add(f'message.{P}.insomnia', 'Nights without sleep: %s. Something tall has noticed.',
    'Ночей без сна: %s. Что-то высокое тебя заметило.')
add(f'message.{P}.mother_wakes', 'The walls breathe. Something enormous is waking beneath you.',
    'Стены дышат. Под тобой просыпается что-то огромное.')
add(f'message.{P}.dreamer_summoned', 'The Dreamer opens its eye.', 'Тот, кто снится, открывает глаз.')
add(f'message.{P}.dreamer_slain', 'The Dreamer is gone. For the first time in nights, you feel awake.',
    'Того, кто снится, больше нет. Впервые за много ночей ты чувствуешь, что проснулся.')
add(f'message.{P}.totem.not_deep', 'The dream is not deep enough. It needs the Nightmare.',
    'Сон недостаточно глубок. Нужен Кошмар.')
add(f'message.{P}.totem.already', 'It is already here.', 'Оно уже здесь.')
add(f'message.{P}.tincture', 'Morning light washes over you. Dread: %s', 'Утренний свет омывает тебя. Страх: %s')
add(f'message.{P}.lullaby.none', 'The lullaby echoes into empty dark.', 'Колыбельная растворяется в пустой тьме.')

add(f'chat.{P}.hollow_whisper', '...%s... we remember what you did...', '...%s... мы помним, что ты сделал...')
WHISPERS = [('wake up', 'проснись'), ('it is behind you', 'оно у тебя за спиной'), ('you left the door open', 'ты оставил дверь открытой'),
            ('we walked your path today', 'мы сегодня прошли твоим путём'), ('do not sleep', 'не спи'), ('we see you', 'мы тебя видим')]
for i, (en, ru) in enumerate(WHISPERS):
    add(f'chat.{P}.whisper.{i}', en, ru)

add(f'command.{P}.distort', 'Distortion set to %s in %s', 'Искажение %s установлено в %s')
add(f'command.{P}.dread.set', 'Dread of %s set to %s', 'Страх игрока %s установлен на %s')
add(f'command.{P}.dread.show', 'Dread of %s: %s / 100', 'Страх игрока %s: %s / 100')
add(f'command.{P}.info.header', '— Echoes of Sleep —', '— Эхо Сна —')
add(f'command.{P}.info.distortion', 'Distortion: %s (%s s left), nights slept in a row: %s, dream blocks: %s',
    'Искажение: %s (осталось %s с), ночей сна подряд: %s, блоков сна: %s')
add(f'command.{P}.info.player', 'Your Dread: %s, nights without sleep: %s, kills: %s, deaths: %s, echoes slain: %s, villagers harmed: %s, minutes underground: %s',
    'Твой Страх: %s, ночей без сна: %s, убийств: %s, смертей: %s, убито эхо: %s, обижено жителей: %s, минут под землёй: %s')

SUBS = {
    'whisper': ('Something whispers', 'Кто-то шепчет'), 'heartbeat': ('Heartbeat', 'Сердцебиение'),
    'drone': ('The world hums', 'Мир гудит'), 'footsteps': ('Footsteps behind you', 'Шаги за спиной'),
    'wake_scream': ('A scream wakes you', 'Крик будит тебя'), 'glitch': ('Reality skips', 'Реальность сбоит'),
    'creak': ('A door creaks open', 'Скрипит дверь'),
    'doppelganger_ambient': ('Doppelganger breathes', 'Двойник дышит'), 'doppelganger_hurt': ('Doppelganger hurts', 'Двойник ранен'),
    'doppelganger_death': ('Doppelganger fades', 'Двойник исчезает'), 'doppelganger_scream': ('Doppelganger screams', 'Двойник кричит'),
    'stitcher_ambient': ('Stitcher groans', 'Сборщик стонет'), 'stitcher_hurt': ('Stitches tear', 'Рвутся швы'),
    'stitcher_death': ('Stitcher falls apart', 'Сборщик распадается'),
    'sleepless_ambient': ('Slow breathing, close', 'Медленное дыхание рядом'), 'sleepless_hurt': ('Sleepless hurts', 'Бессонник ранен'),
    'sleepless_death': ('Sleepless dies', 'Бессонник умирает'), 'sleepless_sting': ('It is closer', 'Оно ближе'),
    'hollow_ambient': ('Hollow Villager whispers', 'Пустой житель шепчет'), 'hollow_hurt': ('Hollow Villager hurts', 'Пустой житель ранен'),
    'hollow_death': ('Hollow Villager dies', 'Пустой житель умирает'),
    'mother_ambient': ('Deep Mother groans', 'Глубинная мать стонет'), 'mother_hurt': ('Deep Mother hurts', 'Глубинная мать ранена'),
    'mother_death': ('Deep Mother wails', 'Глубинная мать воет'), 'mother_emerge': ('Stone breaks', 'Ломается камень'),
    'dreamer_ambient': ('The Dreamer hums', 'Тот, кто снится, гудит'), 'dreamer_hurt': ('The Dreamer flickers', 'Тот, кто снится, мерцает'),
    'dreamer_death': ('The Dreamer screams', 'Тот, кто снится, кричит'), 'dreamer_pulse': ('Dream pulse', 'Волна сна'),
    'lullaby': ('A lullaby plays', 'Звучит колыбельная'), 'ghost_slash': ('Ghostly slash', 'Призрачный взмах'),
}
for k, (en, ru) in SUBS.items():
    add(f'subtitles.{P}.{k}', en, ru)

os.makedirs(ROOT, exist_ok=True)
for idx, lang in ((0, 'en_us'), (1, 'ru_ru')):
    with open(os.path.join(ROOT, lang + '.json'), 'w', encoding='utf-8') as f:
        json.dump({k: v[idx] for k, v in L.items()}, f, indent=2, ensure_ascii=False)
        f.write('\n')
print(len(L), 'keys')
