"""Author declarative interactions and original synthesized audio placeholders."""
from pathlib import Path
import json, math, struct, wave
ROOT = Path(__file__).resolve().parents[1]
def read(path):
    return json.loads((ROOT / path).read_text(encoding='utf-8'))
def write(path, value):
    (ROOT / path).parent.mkdir(parents=True, exist_ok=True)
    (ROOT / path).write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
def dialogue(id, topic=''):
    return {'type': 'dialogue', 'id': id, 'topic': topic}
def condition(path, value):
    return {'path': path, 'equals': value}
def branch(conditions, commands):
    return {'when': conditions, 'commands': commands}
interactions = {
    'keeper': [branch([condition('quest_steps.first_star', 0)], [dialogue('keeper', 'keeper_met')]),
               branch([condition('quest_steps.first_star', 3)], [{'type': 'restore_party'}, dialogue('ending', 'light_restored')]),
               branch([condition('quest_steps.first_star', 4)], [{'type': 'restore_party'}, dialogue('complete')]),
               branch([], [{'type': 'restore_party'}, dialogue('reminder')])],
    'chest': [branch([condition('flags.chest_open', True)], [{'type': 'notice', 'text': 'Ларец пуст. Осколок уже у вас.'}]),
              branch([condition('quest_steps.first_star', 0)], [dialogue('chest_locked')]),
              branch([], [{'type': 'flag', 'id': 'chest_open', 'value': True}, {'type': 'item', 'id': 'moonshard', 'amount': 1},
                          {'type': 'event', 'topic': 'shard_found'}, {'type': 'notice', 'text': 'Получен лунный осколок. Врата сновидений открыты.'}])],
    'gate': [branch([condition('inventory.moonshard', 1)], [{'type': 'travel', 'id': 'dream'}]), branch([], [dialogue('locked')])],
    'return': [branch([], [{'type': 'travel', 'id': 'sanctuary'}])],
    'boss': [branch([condition('flags.won_eclipse', True)], [{'type': 'notice', 'text': 'Сад свободен от теней. Вернитесь к хранительнице.'}]), branch([], [{'type': 'battle', 'id': 'eclipse'}])]
}
write('data/events/interactions.json', interactions)
manifest = read('data/manifest.json')
manifest['catalogs']['interactions'] = 'res://data/events/interactions.json'
write('data/manifest.json', manifest)
maps = read('data/maps/maps.json')
for location in maps.values():
    for point in location['points']:
        point['interaction'] = point['id']
        for field in ['action', 'destination', 'encounter']:
            point.pop(field, None)
write('data/maps/maps.json', maps)
score = {'sample_rate': 22050, 'gain': 0.19, 'tracks': {
    'exploration': {'beat_seconds': 0.75, 'notes': [69,76,81,76,72,79,84,79,65,72,77,72,67,74,79,74]},
    'battle': {'beat_seconds': 0.3, 'notes': [57,64,69,64,60,67,72,67,53,60,65,60,55,62,67,62]},
    'chime': {'beat_seconds': 0.12, 'notes': [81,88,93]}}}
write('data/audio/score.json', score)
for name, track in score['tracks'].items():
    rate, beat = score['sample_rate'], track['beat_seconds']
    samples = []
    duration = beat * len(track['notes'])
    for index in range(int(rate * duration)):
        t = index / rate
        note_index, offset = int(t / beat), t % beat
        frequency = 440 * 2 ** ((track['notes'][note_index]-69)/12)
        envelope = min(offset / 0.015, 1) * math.exp(-offset * 4 / beat) * min((beat-offset)/0.02, 1)
        signal = (math.sin(math.tau*frequency*t) + 0.2*math.sin(math.tau*frequency*2*t)) * envelope
        if name != 'chime':
            bass = 440 * 2 ** ((track['notes'][(note_index//4)*4]-24-69)/12)
            signal += 0.22 * math.sin(math.tau*bass*t) * min(t/.1, 1) * min((duration-t)/.1, 1)
        samples.append(struct.pack('<h', int(max(-1, min(1, signal*score['gain']))*32767)))
    path = ROOT / ('assets/audio/sfx/chime.wav' if name == 'chime' else f'assets/audio/music/{name}.wav')
    with wave.open(str(path), 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes(b''.join(samples))
print('Declarative interactions and original synthesized audio created.')
