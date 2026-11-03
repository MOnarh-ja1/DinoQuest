#!/usr/bin/env python3
"""Apply DinoQuest 2.0 gameplay + animation update to the illustrated Godot source."""
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
main_path = root / "scripts" / "main.gd"
arena_path = root / "scripts" / "arena.gd"
main = main_path.read_text(encoding="utf-8")
arena = arena_path.read_text(encoding="utf-8")

def sub_function(source, function_name, new_body):
    regex = re.compile(r"(?ms)^func " + re.escape(function_name) + r"\(.*?(?=^func |\Z)")
    updated, count = regex.subn(lambda _: new_body.strip("\n") + "\n\n", source, count=1)
    if count != 1:
        raise ValueError("Missing method: " + function_name)
    return updated

def swap(source, needle, replacement):
    if needle not in source:
        raise ValueError("Missing patch anchor: " + needle[:80])
    return source.replace(needle, replacement, 1)

main = swap(main,
    '"gear_attack": 0, "gear_def": 0, "gear_rank": 0, "chests": 0,',
    '"gear_attack": 0, "gear_def": 0, "gear_rank": 0, "chests": 0,\n'
    '        "equipment": {"weapon":{}, "armor":{}, "charm":{}}, "inventory": [], "next_item_id": 1,')
main = swap(main,
    '    var since: int = maxi(0, int(Time.get_unix_time_from_system()) - int(data["timestamp"]))',
    '    _repair_equipment()\n'
    '    var since: int = maxi(0, int(Time.get_unix_time_from_system()) - int(data["timestamp"]))')
main = swap(main,
    'Каждый 5-й этап — большой босс и награда',
    'Каждый 15-й этап — огромный босс и редкая награда')
main = swap(main,
    'Открывай сундуки и находи оружие',
    'Собери меч, броню и талисман')
main = swap(main,
    '{"title":"Покоритель долины", "hint":"Достигни 5 этапа", "stat":"stage", "need":5, "gold":370, "gems":12}',
    '{"title":"Покоритель долины", "hint":"Достигни 15 этапа", "stat":"stage", "need":15, "gold":2000, "gems":12}')
main = swap(main,
    '{"title":"Гроза титанов", "hint":"Победи 3 боссов", "stat":"bosses", "need":3, "gold":800, "gems":20}',
    '{"title":"Гроза титанов", "hint":"Победи 2 боссов", "stat":"bosses", "need":2, "gold":8500, "gems":35}')
main = swap(main,
    '{"title":"Большое приключение", "hint":"Достигни 20 этапа", "stat":"stage", "need":20, "gold":2000, "gems":40}',
    '{"title":"Большое приключение", "hint":"Достигни 30 этапа", "stat":"stage", "need":30, "gold":15000, "gems":40}')

main = sub_function(main, "_is_boss", '''
func _is_boss() -> bool:
    return int(data["stage"]) % 15 == 0
''')
main = sub_function(main, "_wave_hp", '''
func _wave_hp() -> float:
    var n: int = int(data["stage"])
    return (45.0 + n * 18.0) * pow(1.10, n - 1) * (5.0 if _is_boss() else 1.0)
''')
main = sub_function(main, "_max_hp", '''
func _max_hp() -> float:
    return 95.0 + float(data["hp"]) * 23.0 + (float(data["level"]) - 1.0) * 8.0 + float(data["gear_def"]) * 2.0 + _gear_health()
''')
main = sub_function(main, "_enemy_defeated", '''
func _enemy_defeated() -> void:
    var boss: bool = _is_boss()
    var stage_n: int = int(data["stage"])
    var base_reward: int = 110 + stage_n * 35 + stage_n * stage_n * 4
    var gold_won: int = base_reward * (7 if boss else 1)
    data["gold"] += gold_won
    data["kills"] += 1
    if boss:
        data["bosses"] += 1
        data["gems"] += 15 + int(stage_n / 15) * 3
    elif randi_range(1, 6) == 1:
        data["gems"] += 1
    _gain_xp(17 + stage_n * 6 + (85 if boss else 0))
    data["stage"] += 1
    arena.call("victory_effect")
    _spawn_wave()
    if boss:
        _toast("БОСС ПОВЕРЖЕН! +%s монет и кристаллы!" % _num(gold_won), 4.0)
    else:
        _toast("Этап %s пройден! +%s монет" % [str(stage_n), _num(gold_won)], 2.8)
    _save_game()
''')
main = sub_function(main, "_roll_chest", '''
func _roll_chest(epic: bool) -> void:
    var cost: int = 30 if epic else 180 + int(data["stage"]) * 22
    var currency: String = "gems" if epic else "gold"
    var items: Array = data["inventory"]
    if items.size() >= 30:
        _toast("Рюкзак заполнен! Разбери ненужные вещи.")
        return
    if int(data[currency]) < cost:
        _toast("Недостаточно ресурсов")
        return
    data[currency] -= cost
    data["chests"] += 1
    var chance: float = randf()
    var rarity: int = 3 if chance > .94 else (2 if chance > .68 else (1 if chance > .30 else 0))
    if epic:
        rarity = maxi(2, rarity)
    var slots: Array = ["weapon", "armor", "charm"]
    var slot: String = str(slots[randi_range(0, 2)])
    var names: Dictionary = {"weapon":"КЛИНОК", "armor":"ДОСПЕХ", "charm":"ТАЛИСМАН"}
    var grades: Array = ["ЛЕСНОЙ", "ЛУННЫЙ", "ГРОЗОВОЙ", "ДРАКОНИЙ"]
    var power: int = int((18 + int(data["stage"]) * 4) * (1.0 + rarity * 0.55))
    var item: Dictionary = {
        "id":int(data["next_item_id"]), "slot":slot, "rarity":rarity,
        "name":str(grades[rarity]) + " " + str(names[slot]),
        "atk":(power if slot == "weapon" else int(power * 0.16)),
        "def":(power if slot == "armor" else int(power * 0.10)),
        "hp":(power * 3 if slot == "charm" else 0)
    }
    data["next_item_id"] = int(data["next_item_id"]) + 1
    items.append(item)
    data["inventory"] = items
    _toast("НАХОДКА: " + str(item["name"]), 4.0)
    if current_tab == 3:
        _change_tab(3)
    _save_game()
''')
main = sub_function(main, "_build_gear_tab", '''
func _build_gear_tab() -> void:
    var v: VBoxContainer = _scroll_vbox()
    _section_title(v,"МАСТЕРСКАЯ","Три ячейки снаряжения и рюкзак с добычей")
    var summary: Label = _label(v,"",20,GOLD)
    refs["gear_name"] = summary
    var stats: Label = _label(v,"",17,MUTED)
    refs["gear_stats"] = stats
    var chest_buttons: HBoxContainer = HBoxContainer.new()
    chest_buttons.add_theme_constant_override("separation",7)
    v.add_child(chest_buttons)
    var first: Button = _button(chest_buttons,"СУНДУК ●",Color("9c7249"))
    var second: Button = _button(chest_buttons,"ЭПИК ◆",Color("8050a7"))
    first.add_theme_font_size_override("font_size",17)
    second.add_theme_font_size_override("font_size",17)
    first.pressed.connect(func(): _roll_chest(false))
    second.pressed.connect(func(): _roll_chest(true))
    refs["chest_gold"] = first
    refs["chest_gems"] = second

    _label(v,"НАДЕТО",23,AQUA)
    var gear: Dictionary = data["equipment"]
    var slots: Array = ["weapon", "armor", "charm"]
    var slot_names: Array = ["⚔ ОРУЖИЕ", "◈ БРОНЯ", "✦ ТАЛИСМАН"]
    for i in range(3):
        var item: Dictionary = gear[slots[i]]
        var equipped_name: String = "Пусто" if item.is_empty() else str(item.get("name", "Предмет"))
        var desc: Label = _label(v,str(slot_names[i]) + ": " + equipped_name,18,Color("dceef0"))
        desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _label(v,"РЮКЗАК · " + str(data["inventory"].size()) + "/30",23,GOLD)
    if data["inventory"].is_empty():
        _label(v,"Открой сундук, чтобы получить предметы.",17,MUTED)
    else:
        var inventory: Array = data["inventory"]
        for i in range(inventory.size() - 1, -1, -1):
            var item: Dictionary = inventory[i]
            var card: PanelContainer = PanelContainer.new()
            card.add_theme_stylebox_override("panel",_style(Color("254757"),14,Color("385b69"),1))
            v.add_child(card)
            var line: VBoxContainer = VBoxContainer.new()
            line.add_theme_constant_override("separation",5)
            card.add_child(line)
            var rarity_colors: Array = ["#c9d7e1","#7ed9f4","#d2a5ff","#ffd374"]
            var rarity: int = clampi(int(item.get("rarity",0)),0,3)
            _label(line,str(item["name"]),19,Color(rarity_colors[rarity]))
            var details: String = "АТК +%s · БРОНЯ +%s · HP +%s" % [str(item["atk"]),str(item["def"]),str(item["hp"])]
            _label(line,details,16,MUTED)
            var row: HBoxContainer = HBoxContainer.new()
            row.add_theme_constant_override("separation",6)
            line.add_child(row)
            var equip: Button = _button(row,"НАДЕТЬ",Color("368b7a"))
            equip.custom_minimum_size.y = 48
            var recycle: Button = _button(row,"РАЗОБРАТЬ",Color("865d53"))
            recycle.custom_minimum_size.y = 48
            equip.pressed.connect(_equip_item.bind(int(item["id"])))
            recycle.pressed.connect(_recycle_item.bind(int(item["id"])))
''')

main = swap(main,
    '        arena.call("set_battle", int(data["stage"]),wave_kind,_is_boss(),hero_hp / _max_hp(),enemy_hp / max_enemy_hp,data["pets"])',
    '        arena.call("set_battle", int(data["stage"]),wave_kind,_is_boss(),hero_hp / _max_hp(),enemy_hp / max_enemy_hp,data["pets"], int(data["gear_rank"]))')
main = swap(main,
    'refs["gear_name"].text = grades[mini(3,int(data["gear_rank"]))] + " МЕЧ"',
    'refs["gear_name"].text = "СНАРЯЖЕНИЕ · " + str(data["inventory"].size()) + " в рюкзаке"')
main = swap(main,
    'refs["gear_stats"].text = "Урон +%s  ·  Броня +%s  ·  сундуков %s" % [str(data["gear_attack"]),str(data["gear_def"]),str(data["chests"])]',
    'refs["gear_stats"].text = "АТК +%s · БРОНЯ +%s · HP +%s" % [str(data["gear_attack"]),str(data["gear_def"]),str(int(_gear_health()))]')
main = swap(main,
    'refs["chest_gold"].text = "ОБЫЧНЫЙ СУНДУК  ·  %s ●" % _num(175 + int(data["stage"]) * 12)',
    'refs["chest_gold"].text = "СУНДУК %s ●" % _num(180 + int(data["stage"]) * 22)')
main = swap(main,
    'refs["chest_gold"].disabled = int(data["gold"]) < 175 + int(data["stage"]) * 12',
    'refs["chest_gold"].disabled = int(data["gold"]) < 180 + int(data["stage"]) * 22')
main = swap(main,
    'refs["chest_gems"].text = "ЭПИЧЕСКИЙ СУНДУК  ·  25 ◆"',
    'refs["chest_gems"].text = "ЭПИК 30 ◆"')
main = swap(main,
    'refs["chest_gems"].disabled = int(data["gems"]) < 25',
    'refs["chest_gems"].disabled = int(data["gems"]) < 30')

main += '''
func _repair_equipment() -> void:
    if typeof(data["equipment"]) != TYPE_DICTIONARY:
        data["equipment"] = {"weapon":{}, "armor":{}, "charm":{}}
    if typeof(data["inventory"]) != TYPE_ARRAY:
        data["inventory"] = []
    var gear: Dictionary = data["equipment"]
    for slot in ["weapon", "armor", "charm"]:
        if not gear.has(slot) or typeof(gear[slot]) != TYPE_DICTIONARY:
            gear[slot] = {}
    data["equipment"] = gear
    data["next_item_id"] = maxi(1,int(data["next_item_id"]))
    if gear["weapon"].is_empty() and int(data["gear_attack"]) > 0:
        gear["weapon"] = {"id":0,"slot":"weapon", "rarity":int(data["gear_rank"]),
            "name":"СТАРЫЙ КЛИНОК","atk":int(data["gear_attack"]),
            "def":int(data["gear_def"]), "hp":0}
    _recalculate_equipment()

func _recalculate_equipment() -> void:
    var attack: int = 0
    var armor: int = 0
    var best: int = 0
    var gear: Dictionary = data["equipment"]
    for slot in ["weapon", "armor", "charm"]:
        var item: Dictionary = gear[slot]
        if not item.is_empty():
            attack += int(item.get("atk",0))
            armor += int(item.get("def",0))
            best = maxi(best,int(item.get("rarity",0)))
    data["gear_attack"] = attack
    data["gear_def"] = armor
    data["gear_rank"] = best

func _gear_health() -> float:
    var total: float = 0.0
    var gear: Dictionary = data.get("equipment",{})
    for slot in ["weapon", "armor", "charm"]:
        if gear.has(slot) and gear[slot] is Dictionary:
            var item: Dictionary = gear[slot]
            total += float(item.get("hp",0))
    return total

func _equip_item(wanted_id: int) -> void:
    var inventory: Array = data["inventory"]
    for index in range(inventory.size()):
        var item: Dictionary = inventory[index]
        if int(item.get("id",-1)) != wanted_id:
            continue
        var slot: String = str(item["slot"])
        var gear: Dictionary = data["equipment"]
        var previous: Dictionary = gear[slot]
        inventory.remove_at(index)
        if not previous.is_empty():
            inventory.append(previous)
        gear[slot] = item
        data["equipment"] = gear
        data["inventory"] = inventory
        _recalculate_equipment()
        hero_hp = minf(_max_hp(),hero_hp + 25.0)
        _toast("НАДЕТО: " + str(item["name"]),2.5)
        _change_tab(3)
        _sync_arena()
        _save_game()
        return

func _recycle_item(wanted_id: int) -> void:
    var inventory: Array = data["inventory"]
    for index in range(inventory.size()):
        var item: Dictionary = inventory[index]
        if int(item.get("id",-1)) != wanted_id:
            continue
        var coins: int = 35 + (int(item["atk"]) + int(item["def"]) + int(item["hp"]) / 3) * (1 + int(item["rarity"]))
        data["gold"] += coins
        inventory.remove_at(index)
        data["inventory"] = inventory
        _toast("Переплавлено: +%s монет" % _num(coins))
        _change_tab(3)
        _save_game()
        return
'''
main_path.write_text(main, encoding="utf-8")

arena = swap(arena, 'var sparks: Array = []', 'var sparks: Array = []\nvar gear_rank: int = 0\nvar victory_glow: float = 0.0')
arena = swap(arena, '    clock += delta\n', '    clock += delta\n    victory_glow = maxf(0.0,victory_glow - delta * 1.1)\n')
arena = swap(arena, '    for i in range(10):', '    for i in range(18):')
arena = swap(arena,
    'func set_battle(stage_number: int, kind: int, is_boss: bool, hero_ratio: float, mob_ratio: float, pets: Array) -> void:',
    'func set_battle(stage_number: int, kind: int, is_boss: bool, hero_ratio: float, mob_ratio: float, pets: Array, rank: int = 0) -> void:')
arena = swap(arena, '    stage = stage_number\n', '    stage = stage_number\n    gear_rank = rank\n')
arena = swap(arena, '    # soft floor + ground shadows', '''
    if victory_glow > 0.0:
        draw_rect(Rect2(Vector2.ZERO, size),Color(1.0,.82,.39,victory_glow*.22))
    # soft floor + ground shadows''')
arena = swap(arena,
    '    # enemy attack recoil\n', '''
    # glowing blade and animated sword swing reflect the best equipped rarity
    var blade_colors: Array = [Color("d7eaf2"),Color("9ce9ff"),Color("dfabff"),Color("ffe08c")]
    var blade: Color = blade_colors[clampi(gear_rank,0,3)]
    var hand: Vector2 = Vector2(hx + hsize * .20,hy + hsize * .07)
    var sword_tip: Vector2 = hand + Vector2(hsize * (.30 + attacking * .3),-hsize * (.62 - attacking * .28))
    draw_line(hand,sword_tip,Color("233441"),17.0,true)
    draw_line(hand,sword_tip,blade,10.0,true)
    draw_circle(hand,8.0,Color("f8cc85"))
    draw_line(hand + Vector2(-12,-8),hand + Vector2(12,8),Color("ffdfae"),6.0,true)
    # enemy attack recoil
''')
arena = swap(arena,
    '    # attack slash (brief)\n', '''
    if enemy_is_boss:
        var aura_radius: float = esize * (.45 + .025 * sin(clock * 4.0))
        draw_arc(Vector2(ex,ey),aura_radius,0,TAU,48,Color(.96,.31,.56,.45),6.0,true)
        for orb in range(3):
            var ang: float = clock * (.7 + orb * .11) + orb * TAU / 3
            draw_circle(Vector2(ex,ey) + Vector2(cos(ang),sin(ang)) * aura_radius,8.0,Color("ffab7d"))
    # attack slash (brief)
''')
arena = swap(arena,
    '    if attacking > .43:\n', '''
    if attacking > .43:
        draw_arc(Vector2(w*.62,h*.55),w*.17,-1.0,1.55,28,Color(1.0,.86,.49,.4*attacking),17.0,true)
''')
arena += '''
func victory_effect() -> void:
    victory_glow = 1.0
    for i in range(36):
        var angle: float = randf() * TAU
        sparks.append({"pos":Vector2(size.x*.74,size.y*.59),
            "velocity":Vector2(cos(angle),sin(angle))*randf_range(80.0,270.0),
            "life":randf_range(.35,1.0),"color":Color("ffe194")})
'''
arena_path.write_text(arena, encoding="utf-8")

project_path = root / "project.godot"
project = project_path.read_text(encoding="utf-8")
if "textures/vram_compression/import_etc2_astc=true" not in project:
    project = project.replace("[rendering]\n", "[rendering]\ntextures/vram_compression/import_etc2_astc=true\n")
project = project.replace('window/size/window_width_override=540','window/size/window_width_override=580')
project = project.replace('window/size/window_height_override=960','window/size/window_height_override=960')
project_path.write_text(project,encoding="utf-8")
preset_path = root / "export_presets.cfg"
if preset_path.exists():
    presets = preset_path.read_text(encoding="utf-8")
    presets = presets.replace('version/code=1','version/code=2').replace('version/name="0.9.0"','version/name="2.0.0"')
    preset_path.write_text(presets,encoding="utf-8")
print("DinoQuest V2 applied: boss every 15 stages, increased rewards, 3 gear slots, animated effects")
