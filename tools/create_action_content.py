"""Author initial Windows action-mode catalogs. Not part of the normal build."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
def put(name,value):
    p=ROOT/'data/action'/f'{name}.json'
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
characters=[
 ('moon','Усаги Цукино','Сейлор Мун','#ff4c98','inner',0,'tiara','heart','Любовь и справедливость'),
 ('mercury','Ами Мидзуно','Сейлор Меркурий','#58dcff','inner',1,'mist','ice','Вода и мудрость'),
 ('mars','Рэй Хино','Сейлор Марс','#ff593e','inner',2,'fire','fire','Огонь и страсть'),
 ('jupiter','Макото Кино','Сейлор Юпитер','#68ee96','inner',3,'thunder','thunder','Гром и мужество'),
 ('venus','Минако Айно','Сейлор Венера','#ffcf62','inner',4,'chain','chain','Любовь и красота'),
 ('chibimoon','Чибиуса','Сейлор Чиби Мун','#ff9fd8','outer',0,'sugar','sugar','Маленькая хранительница'),
 ('uranus','Харука Тэно','Сейлор Уран','#e7bc63','outer',1,'earth','earth','Небо и ветер'),
 ('neptune','Мичиру Кайо','Сейлор Нептун','#4de0c4','outer',2,'ocean','ocean','Глубины океана'),
 ('pluto','Сэцуна Мэйо','Сейлор Плутон','#d394ef','outer',3,'scream','scream','Врата пространства и времени'),
 ('saturn','Хотару Томоэ','Сейлор Сатурн','#ba94ff','outer',4,'glaive','glaive','Тишина и возрождение')]
put('characters',{id:{'id':id,'name':name,'title':title,'color':color,'sheet':f'res://assets/sprites/{sheet}_guardians.png','row':row,'columns':12,'rows':5,'primary':primary,'special':special,'tagline':tagline,'hp':100,'energy':100,'portrait_frame':0,'story_unlock':'act_1' if id=='moon' else 'later_arc'} for id,name,title,color,sheet,row,primary,special,tagline in characters})
skills={
 'tiara':('Moon Tiara Boomerang','Лунная тиара','boomerang','#ffd977',18,10,0.45,720,1.05,0,'Dark Kingdom'),
 'heart':('Moon Spiral Heart Attack','Спираль сердец','hearts','#ff72ba',44,32,1.2,540,1.4,0,'Infinity'),
 'mist':('Mercury Aqua Mist','Водяной туман','mist','#77eaff',10,18,1.0,290,2.0,2.5,'Dark Kingdom'),
 'ice':('Shine Aqua Illusion','Ледяная иллюзия','ice','#b0f1ff',30,28,1.1,630,1.2,1.4,'Black Moon'),
 'fire':('Burning Mandala','Огненная мандала','fire','#ff623d',28,22,0.75,560,1.3,0,'Black Moon'),
 'thunder':('Supreme Thunder','Высший гром','lightning','#adff7d',34,24,0.9,900,0.55,0.4,'Dark Kingdom'),
 'chain':('Venus Love-Me Chain','Цепь любви','chain','#ffd176',25,18,0.8,680,0.85,0.8,'Dark Kingdom'),
 'sugar':('Pink Sugar Heart Attack','Розовые сердца','hearts','#ffa6d8',18,14,0.6,480,1.25,0,'Infinity'),
 'earth':('World Shaking','Сотрясение мира','ground','#e4c777',38,28,1.0,640,1.35,0.4,'Infinity'),
 'ocean':('Deep Submerge','Глубокое погружение','wave','#62ecd8',30,22,0.85,520,1.5,0.5,'Infinity'),
 'scream':('Dead Scream','Мёртвый крик','orb','#d49cff',42,30,1.2,460,1.8,0,'Infinity'),
 'glaive':('Silence Glaive Surprise','Удар глефы тишины','glaive','#c0a0ff',48,34,1.3,0,0.65,0.8,'Dream')}
put('skills',{id:{'id':id,'canonical_name':v[0],'name':v[1],'effect':v[2],'color':v[3],'damage':v[4],'cost':v[5],'cooldown':v[6],'speed':v[7],'lifetime':v[8],'slow_seconds':v[9],'arc':v[10],'radius':30 if id!='mist' else 84,'piercing':id in ['chain','thunder','glaive','mist']} for id,v in skills.items()})
put('config',{'version':1,'title':'SAILOR MOON','subtitle':'IN THE NAME OF THE MOON','initial_character':'moon','initial_level':'azabu','menu_art':'res://assets/art/main_menu.png',
 'movement':{'speed':310,'acceleration':2400,'friction':2100,'gravity':1520,'jump_speed':565,'jump_release_factor':0.48,'coyote_seconds':0.11,'jump_buffer_seconds':0.13,'max_fall_speed':850,'dash_speed':820,'dash_seconds':0.16,'dash_cooldown':0.6,'dash_invulnerability':True,'wall_slide_speed':110,'wall_jump_x':420,'wall_jump_y':520,'air_jumps':1},
 'combat':{'melee_damage':16,'melee_range':108,'melee_cooldown':0.27,'melee_seconds':0.24,'combo_window':0.7,'combo_multipliers':[1,1.2,1.6],'hurt_invulnerability':0.85,'hurt_seconds':0.22,'knockback_x':290,'knockback_y':230,'energy_regen':14,'contact_damage':12,'hitstop':0.045,'effect_budget':32,'enemy_damage':14,'enemy_speed':88,'enemy_hp':70,'boss_hp':280,'enemy_attack_interval':1.5,'enemy_attack_range':90,'boss_projectile_speed':270,'boss_attack_interval':1.8,'projectile_radius':14},
 'visual':{'sprite_height':108,'camera_smoothing':7,'screen_shake':7,'idle_sway':1.5,'idle_fps':3,'run_fps':12,'cast_fps':10,'hurt_fps':5,'fade_seconds':0.22,'menu_slide_seconds':0.35},
 'animation':{'idle':[0,1],'run':[2,3,4,5],'jump':[6,7],'fall':[8],'attack':[9,10],'cast':[9,10],'hurt':[11],'dash':[5]},
 'bindings':{'left':['A','Left'],'right':['D','Right'],'jump':['Space','W','Up'],'dash':['Shift'],'attack':['J'],'primary':['K','Q'],'special':['L','E'],'roster':['Tab'],'pause':['Escape']}})
put('levels',{'azabu':{'name':'АДЗАБУ-ДЗЮБАН','subtitle':'ACT 1 / УСАГИ — SAILOR MOON','background':'res://assets/art/azabu_night.png','size':[3840,720],'ground_y':612,'spawn':[180,580],'checkpoint':[1810,580],'exit_x':3630,
 'platforms':[[0,612,3840,180],[390,510,180,22],[690,420,180,22],[1050,490,200,22],[1390,390,170,22],[1720,505,180,22],[2050,450,180,22],[2380,350,200,22],[2680,465,180,22],[3140,470,160,22]],
 'practice_enemies':[[850,580],[1460,580],[2220,580]],'boss_position':[3260,580],'luna_position':[310,595],
 'pickups':[[500,468],[785,378],[1480,348],[2140,408],[2490,308]],'pickup_energy':22,'pickup_heal':12}})
put('story',{'intro':[{'speaker':'Луна','text':'Усаги Цукино, ты — Сейлор Мун. Эта брошь позволит тебе преобразиться.'},{'speaker':'Усаги','text':'Говорящая кошка… Я всё ещё думаю, что сплю!'},{'speaker':'Луна','text':'Твоя подруга Нару в опасности. Отправляйся в ювелирный магазин и доверься своей силе.'}],
 'boss':[{'speaker':'Усаги','text':'Это не мама Нару… Ты забираешь энергию у людей!'},{'speaker':'Луна','text':'Усаги, используй тиару. Не позволяй страху остановить тебя.'}],
 'ending':[{'speaker':'Усаги','text':'Нару в безопасности. Но кто был тот человек в маске?'},{'speaker':'Луна','text':'Сегодня ты впервые сражалась как Сейлор Мун. Это только начало.'}],
 'canon_note':'Адаптация событий Act 1. Реплики — краткий авторский пересказ. Поздние персонажи и приёмы доступны только в тренировке.'})
put('audio',{'master_volume':0.65,'music_volume':0.75,'sfx_volume':0.6,'crossfade_seconds':0.55,'tracks':{
 'menu':{'path':'res://assets/audio/music/exploration.wav','external':'Music/menu.ogg','loop':True,'gain_db':-9},
 'exploration':{'path':'res://assets/audio/music/exploration.wav','external':'Music/exploration.ogg','loop':True,'gain_db':-9},
 'battle':{'path':'res://assets/audio/music/battle.wav','external':'Music/battle.ogg','loop':True,'gain_db':-8},
 'victory':{'path':'res://assets/audio/music/exploration.wav','external':'Music/victory.ogg','loop':True,'gain_db':-9}},
 'sfx':{'menu':{'path':'res://assets/audio/sfx/chime.wav','external':'Music/menu_click.wav','gain_db':-10},'attack':{'path':'res://assets/audio/sfx/chime.wav','external':'Music/attack.wav','gain_db':-15},'magic':{'path':'res://assets/audio/sfx/chime.wav','external':'Music/magic.wav','gain_db':-8},'hurt':{'path':'res://assets/audio/sfx/chime.wav','external':'Music/hurt.wav','gain_db':-12}}})
print('Windows action catalogs written.')
