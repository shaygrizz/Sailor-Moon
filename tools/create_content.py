"""Rebuild the initial authored content and lightweight vector placeholder assets."""
from pathlib import Path
import json
import math

ROOT = Path(__file__).resolve().parents[1]

def write(path, text):
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding='utf-8')

def data(path, value):
    write('data/' + path + '.json', json.dumps(value, ensure_ascii=False, indent=2) + '\n')

for folder in ['assets/audio/music', 'assets/audio/sfx', 'assets/audio/voice', 'assets/fonts',
               'assets/animations', 'assets/characters', 'assets/enemies', 'assets/maps',
               'assets/portraits', 'assets/effects', 'data/shops', 'data/translations',
               'docs/design', 'docs/lore', 'docs/roadmap', 'docs/references', 'mods', 'addons']:
    write(folder + '/.gitkeep', '')

data('manifest', {'schema_version': 1, 'catalogs': {
    'config': 'res://data/balancing/game.json', 'characters': 'res://data/characters/party.json',
    'enemies': 'res://data/characters/enemies.json', 'skills': 'res://data/skills/skills.json',
    'items': 'res://data/items/items.json', 'quests': 'res://data/quests/quests.json',
    'dialogues': 'res://data/dialogues/story.json', 'maps': 'res://data/maps/maps.json',
    'encounters': 'res://data/events/encounters.json'}, 'mods': []})
data('balancing/game', {
    'title': 'MOONVEIL', 'subtitle': 'THE FIRST STAR', 'schema_version': 2,
    'initial_map': 'sanctuary', 'initial_party': ['selene', 'iris'],
    'initial_inventory': {'stardrop': 3}, 'initial_gold': 0,
    'initial_quest': 'first_star', 'save_slots': 3,
    'world': {'speed': 0.28, 'arrival_distance': 0.024, 'interact_distance': 0.09,
              'player_spawn': [0.49, 0.79], 'bounds': [0.13, 0.49, 0.86, 0.9]},
    'battle': {'defense_factor': 0.45, 'minimum_damage': 1, 'variance': [0.93, 1.07],
               'critical_chance': 0.1, 'critical_multiplier': 1.5, 'weakness_multiplier': 1.6,
               'guard_multiplier': 0.45, 'guard_mana': 5, 'ultimate_cost': 100,
               'gauge_per_hit': 17, 'turn_delay': 0.75, 'max_rounds': 100,
               'start_gauge': 0, 'level_thresholds': [0, 25, 65, 130],
               'level_growth': {'max_hp': 12, 'max_mp': 3, 'attack': 3, 'defense': 2, 'speed': 1}},
    'presentation': {'transition_seconds': 0.22, 'particle_count': 28, 'particle_speed': 12,
                     'music_volume_db': -23, 'sfx_volume_db': -16,
                     'palette': {'background': '#0c1025', 'panel': '#151a34', 'gold': '#dfc99c',
                                 'text': '#f5edee', 'muted': '#aaaec9', 'accent': '#e8a7c6'}}})
data('characters/party', {
    'selene': {'name': 'Селена', 'role': 'Хранительница луны', 'element': 'moon',
               'max_hp': 100, 'max_mp': 28, 'attack': 19, 'defense': 10, 'speed': 15,
               'skills': ['strike', 'moonbeam', 'mend', 'guard'], 'ultimate': 'eclipse',
               'portrait': 'res://assets/portraits/selene.svg', 'color': '#efb5d0',
               'equipment': [], 'passives': [], 'relationships': {}, 'talents': [],
               'costumes': ['guardian'], 'unlock': 'start'},
    'iris': {'name': 'Ирис', 'role': 'Проводница звёзд', 'element': 'star',
             'max_hp': 86, 'max_mp': 32, 'attack': 17, 'defense': 8, 'speed': 12,
             'skills': ['strike', 'starfall', 'mend', 'guard'], 'ultimate': 'eclipse',
             'portrait': 'res://assets/portraits/iris.svg', 'color': '#bfb7ef',
             'equipment': [], 'passives': [], 'relationships': {}, 'talents': [],
             'costumes': ['guardian'], 'unlock': 'start'}})
data('characters/enemies', {
    'wisp': {'name': 'Тень забытой звезды', 'max_hp': 54, 'max_mp': 0, 'attack': 15, 'defense': 5,
             'speed': 9, 'weakness': 'moon', 'skills': ['shadow'], 'color': '#9078d1'},
    'sentinel': {'name': 'Страж затмения', 'max_hp': 160, 'max_mp': 0, 'attack': 22, 'defense': 10,
                 'speed': 11, 'weakness': 'star', 'skills': ['shadow', 'nightfall'], 'color': '#b28cda'}})
data('skills/skills', {
    'strike': {'name': 'Удар', 'description': 'Надёжная атака без затрат маны.', 'kind': 'damage', 'power': 1.0, 'cost': 0, 'element': 'neutral', 'target': 'enemy'},
    'moonbeam': {'name': 'Лунный луч', 'description': 'Лунная магия. Сильна против теней.', 'kind': 'damage', 'power': 1.65, 'cost': 6, 'element': 'moon', 'target': 'enemy'},
    'starfall': {'name': 'Звездопад', 'description': 'Звёздная магия. Слабо место стража.', 'kind': 'damage', 'power': 1.65, 'cost': 7, 'element': 'star', 'target': 'enemy'},
    'mend': {'name': 'Свет надежды', 'description': 'Восстановить здоровье выбранной союзницы.', 'kind': 'heal', 'power': 35, 'cost': 8, 'element': 'moon', 'target': 'ally'},
    'guard': {'name': 'Защита', 'description': 'Уменьшить урон до следующего хода; +5 маны.', 'kind': 'guard', 'power': 0, 'cost': 0, 'element': 'neutral', 'target': 'self'},
    'eclipse': {'name': 'Двойное сияние', 'description': 'Командная атака. Требует обеих хранительниц и 100 резонанса.', 'kind': 'damage', 'power': 4.0, 'cost': 0, 'element': 'star', 'target': 'all_enemies', 'ultimate': True},
    'shadow': {'name': 'Прикосновение тени', 'kind': 'damage', 'power': 1.0, 'cost': 0, 'element': 'dark', 'target': 'enemy'},
    'nightfall': {'name': 'Ночная вуаль', 'kind': 'damage', 'power': 1.3, 'cost': 0, 'element': 'dark', 'target': 'enemy'}})
data('items/items', {'stardrop': {'name': 'Звёздная капля', 'description': 'Восстанавливает 45 HP одной союзнице в бою.', 'kind': 'heal', 'power': 45, 'price': 15},
                     'moonshard': {'name': 'Лунный осколок', 'description': 'Открывает дорогу в сад сновидений.', 'kind': 'key', 'price': 0}})
data('quests/quests', {'first_star': {'name': 'Первая звезда', 'description': 'Верните свет угасшему святилищу.',
    'steps': [{'topic': 'keeper_met', 'text': 'Поговорите с хранительницей у святилища.'},
              {'topic': 'shard_found', 'text': 'Отыщите осколок в ларце у воды.'},
              {'topic': 'battle_won', 'match': 'eclipse', 'text': 'Пройдите через врата и победите Стража затмения.'},
              {'topic': 'light_restored', 'text': 'Вернитесь к хранительнице и зажгите первую звезду.'}],
    'reward': {'gold': 50, 'items': {'stardrop': 2}}}})
data('dialogues/story', {
    'intro': [{'speaker': 'Селена', 'text': 'Когда последняя звезда погасла, море перестало отражать небо.'},
              {'speaker': 'Ирис', 'text': 'Но я всё ещё слышу её. Где-то здесь… в саду лунных снов.'},
              {'speaker': 'Селена', 'text': 'Тогда мы вернём ей свет. Вместе.'}],
    'keeper': [{'speaker': 'Хранительница', 'text': 'Вы пришли на зов первой звезды. Её осколок спит в ларце у воды.'},
               {'speaker': 'Хранительница', 'text': 'Возьмите его. Он откроет врата в сад сновидений. Но за вратами ждёт Страж затмения.'},
               {'speaker': 'Ирис', 'text': 'Лунный свет рассеет его тени, а звёздная магия пробьёт защиту самого стража.'}],
    'reminder': [{'speaker': 'Хранительница', 'text': 'Пусть луна направляет вас. Ларец у воды хранит ключ к вратам.'}],
    'locked': [{'speaker': 'Ирис', 'text': 'Врата ещё спят. Сначала поговорим с хранительницей и найдём лунный осколок.'}],
    'chest_locked': [{'speaker': 'Селена', 'text': 'На крышке — незнакомое созвездие. Хранительница наверняка знает, как его открыть.'}],
    'ending': [{'speaker': 'Хранительница', 'text': 'Посмотрите наверх. Первая звезда снова сияет.'},
               {'speaker': 'Ирис', 'text': 'А за ней — ещё тысячи. Думаешь, мы сможем вернуть их все?'},
               {'speaker': 'Селена', 'text': 'Не сегодня. Но с каждой ночью небо будет становиться светлее.'}],
    'complete': [{'speaker': 'Хранительница', 'text': 'Святилище помнит ваше добро. Первая звезда будет освещать дальнейший путь.'}]})
data('maps/maps', {
    'sanctuary': {'name': 'Лунное святилище', 'region': 'САДЫ СЕРЕБРЯНОГО ТЫСЯЧЕЛЕТИЯ',
                  'background': 'res://assets/maps/sanctuary.svg',
                  'points': [{'id': 'keeper', 'name': 'Хранительница', 'icon': '✦', 'position': [0.49, 0.57], 'action': 'keeper'},
                             {'id': 'chest', 'name': 'Лунный ларец', 'icon': '◇', 'position': [0.76, 0.73], 'action': 'chest'},
                             {'id': 'gate', 'name': 'Врата сновидений', 'icon': '☾', 'position': [0.22, 0.62], 'action': 'travel', 'destination': 'dream'}]},
    'dream': {'name': 'Сад сновидений', 'region': 'ПО ТУ СТОРОНУ ЛУННОГО СВЕТА',
              'background': 'res://assets/maps/dream.svg',
              'points': [{'id': 'boss', 'name': 'Страж затмения', 'icon': '✧', 'position': [0.52, 0.56], 'action': 'battle', 'encounter': 'eclipse'},
                         {'id': 'return', 'name': 'В святилище', 'icon': '☾', 'position': [0.24, 0.76], 'action': 'travel', 'destination': 'sanctuary'}]}})
data('events/encounters', {'eclipse': {'name': 'Страж затмения', 'enemies': ['wisp', 'sentinel'], 'xp': 30, 'gold': 25}})

write('assets/ui/moon.svg', '''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect width="128" height="128" rx="28" fill="#151a34"/><path d="M83 20A46 46 0 1 0 108 89 41 41 0 0 1 83 20Z" fill="#e8cfa3"/><path d="m87 37 4 12 12 4-12 4-4 12-4-12-12-4 12-4Z" fill="#efb5d0"/></svg>''')

def environment(dream=False):
    sky = '#262042' if dream else '#162941'
    parts = [f'''<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="900" viewBox="0 0 1600 900">
    <defs><linearGradient id="sky" x2="0" y2="1"><stop stop-color="#0d1027"/><stop offset="1" stop-color="{sky}"/></linearGradient>
    <linearGradient id="water" x2="0" y2="1"><stop stop-color="#4a416c"/><stop offset="1" stop-color="#151c35"/></linearGradient>
    <linearGradient id="stone" x2="0" y2="1"><stop stop-color="#9b8da8"/><stop offset="1" stop-color="#4f4968"/></linearGradient>
    <radialGradient id="glow"><stop stop-color="#c7b9ed" stop-opacity=".2"/><stop offset="1" stop-color="#c7b9ed" stop-opacity="0"/></radialGradient></defs>
    <rect width="1600" height="900" fill="url(#sky)"/><circle cx="800" cy="235" r="295" fill="url(#glow)"/>
    <circle cx="800" cy="211" r="100" fill="none" stroke="#b9a3c9" stroke-opacity=".2"/>
    <path d="M845 124 A88 88 0 1 0 872 273 A79 79 0 0 1 845 124Z" fill="#eee1c3"/>
    <path d="M0 440 130 309 237 362 341 259 489 383 639 322 762 433 936 326 1068 387 1220 261 1366 376 1480 288 1600 402V620H0Z" fill="#292f4d"/>
    <path d="M0 496 183 393 380 472 526 398 681 488 878 404 1090 485 1328 384 1600 500V700H0Z" fill="#34364f"/>
    <rect y="490" width="1600" height="410" fill="url(#water)"/>
    <ellipse cx="800" cy="650" rx="234" ry="136" fill="url(#glow)"/>
    <path d="M500 509H1100L1570 900H20Z" fill="#37364f"/>
    <path d="M510 500H1090L1520 900H70Z" fill="url(#stone)"/>
    <path d="M540 516H1060L1470 900H130Z" fill="none" stroke="#c0adc0" stroke-opacity=".5" stroke-width="2"/>
    <path d="M702 494H898L959 538H641Z" fill="#b2a0b9"/>
    <path d="M712 480H888L921 514H679Z" fill="#706481"/>
    <path d="M722 463H878L904 492H696Z" fill="#b2a0b9"/>
    <path d="M725 325H875V465H725Z" fill="#69657f"/>
    <path d="M710 326 800 269 890 326Z" fill="#b5a0b1" stroke="#dfc99c" stroke-width="2"/>
    <path d="M755 460V365Q800 310 845 365V460Z" fill="#292842"/>
    <path d="M778 457V372Q800 346 822 372V457Z" fill="#bda6d5" opacity=".25"/>
    <path d="m800 377 17 25-17 33-17-33Z" fill="#f0c8e2"/>
    <path d="M716 330H734V465H716ZM866 330H884V465H866Z" fill="#c4b4c9"/>
    <ellipse cx="800" cy="734" rx="144" ry="57" fill="none" stroke="#c5acc4" stroke-width="2"/>
    <ellipse cx="800" cy="734" rx="122" ry="46" fill="none" stroke="#c5acc4" stroke-opacity=".5"/>
    <path d="m800 699 18 29 77 6-77 7-18 28-18-28-77-7 77-6Z" fill="#baa7be" opacity=".55"/>
    ''']
    for i in range(90):
        x, y = (i * 373 + 71) % 1600, (i * 127 + 37) % 425
        r = 1 if i % 4 else 2
        parts.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#e5d5ee" opacity="{0.2+(i%5)*.13}"/>')
    for y in [558, 610, 680, 775, 880]:
        parts.append(f'<path d="M{510-(y-500)*1.13} {y}H{1090+(y-500)*1.13}" stroke="#433d5b" stroke-opacity=".5"/>')
    for i in range(25):
        y = 528 + i * 15
        x = (i * 173) % 440
        parts.append(f'<path d="M{x} {y}h{30+i%5*18}M{1160+x} {y}h{50+i%3*12}" stroke="#bba1d1" stroke-opacity=".15"/>')
    for x, y in [(390, 594), (1180, 609), (193, 787), (1400, 797)]:
        parts.append(f'<path d="M{x-14} {y}h28v-65h-28Z" fill="#706780"/><path d="M{x-23} {y-66}h46l-7-26h-32Z" fill="#eac8b0"/><circle cx="{x}" cy="{y-77}" r="65" fill="url(#glow)"/>')
    for side in [0, 1]:
        transform = 'translate(1600 0) scale(-1 1)' if side else ''
        parts.append(f'<g transform="{transform}"><path d="M0 750Q133 488 70 260Q105 180 247 111M66 334Q172 215 392 190M80 280Q-22 156 36 42" fill="none" stroke="#30233f" stroke-width="35"/>')
        for i in range(64):
            x, y = (i * 79) % 420 - 40, (i * 43) % 240 + 20
            color = ['#6b4264', '#925a7f', '#b37797', '#d299af'][i % 4]
            parts.append(f'<ellipse cx="{x}" cy="{y}" rx="{23+i%4*7}" ry="{15+i%5*4}" fill="{color}" opacity=".76"/>')
        parts.append('</g>')
    if dream:
        parts.append('<rect width="1600" height="900" fill="#582457" opacity=".17"/><path d="m800 403 28 44-28 44-28-44Z" fill="#af74df" stroke="#ecd1ff" stroke-width="2"/>')
    parts.append('</svg>')
    return ''.join(parts)

write('assets/maps/sanctuary.svg', environment())
write('assets/maps/dream.svg', environment(True))

def portrait(hair, accent):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="320" height="400" viewBox="0 0 320 400">
    <defs><linearGradient id="bg" x2="0" y2="1"><stop stop-color="#3b345c"/><stop offset="1" stop-color="#171c35"/></linearGradient></defs>
    <rect width="320" height="400" rx="22" fill="url(#bg)"/><circle cx="160" cy="162" r="115" fill="none" stroke="#dfc99c" opacity=".3"/>
    <path d="M64 374Q55 231 69 154Q76 49 164 55Q263 54 258 174L278 378Z" fill="{hair}"/>
    <path d="M143 254H177V294H143Z" fill="#f1c2bd"/><path d="M49 400 61 325Q71 285 139 284L160 302 181 284Q249 285 259 325L276 400Z" fill="#ece6f0"/>
    <path d="M81 300 159 350 239 300 218 287 160 313 103 287Z" fill="{accent}"/>
    <path d="m160 348-40-22-14 32 44 8-17 34h54l-18-34 46-8-15-32Z" fill="{accent}"/>
    <path d="M95 140Q88 262 160 277Q232 262 226 140Q154 92 95 140Z" fill="#f8d4cc"/>
    <path d="M77 165Q76 53 164 66Q246 63 245 171L215 131 200 157 161 107 139 158 121 124 97 174Z" fill="{hair}"/>
    <path d="M112 191Q125 180 141 190M180 190Q195 180 209 190" fill="none" stroke="#3d3257" stroke-width="5" stroke-linecap="round"/>
    <ellipse cx="129" cy="199" rx="9" ry="15" fill="#655284"/><ellipse cx="194" cy="199" rx="9" ry="15" fill="#655284"/>
    <circle cx="132" cy="194" r="4" fill="white"/><circle cx="197" cy="194" r="4" fill="white"/>
    <path d="m158 209-4 16h7M149 242q11 7 22-1" fill="none" stroke="#ca8994" stroke-width="2" stroke-linecap="round"/>
    <ellipse cx="112" cy="224" rx="13" ry="5" fill="#e9a0ad" opacity=".45"/><ellipse cx="210" cy="224" rx="13" ry="5" fill="#e9a0ad" opacity=".45"/>
    <path d="m123 133 37 14 37-14-37 28Z" fill="#e7c799"/><path d="m160 142 6 9-6 8-6-8Z" fill="{accent}"/>
    <circle cx="160" cy="352" r="10" fill="#dfc99c"/><path d="m160 345 5 7-5 7-5-7Z" fill="#f5d0e5"/>
    <path d="m270 62 4 12 12 4-12 4-4 12-4-12-12-4 12-4ZM43 97l3 9 9 3-9 3-3 9-3-9-9-3 9-3Z" fill="#dfc99c"/></svg>'''

write('assets/portraits/selene.svg', portrait('#c6b3ce', '#ce8bb0'))
write('assets/portraits/iris.svg', portrait('#756997', '#9892d3'))
print('Content and vector assets created.')
