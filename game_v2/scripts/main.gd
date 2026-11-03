extends Control
## DINO QUEST — a complete small offline mobile idle-RPG prototype.
## Gameplay is controlled here; arena.gd handles animations and hand-drawn battle art.

const ARENA_SCENE = preload("res://scripts/arena.gd")
const COIN_ICON = preload("res://assets/icon_coin.png")
const GEM_ICON = preload("res://assets/icon_gem.png")
const SAVE_FILE = "user://dino_quest_save.json"
const TEXT = Color("f5fbf9")
const MUTED = Color("9cbec6")
const GOLD = Color("ffdc85")
const AQUA = Color("83f5dc")
const PANEL = Color("183645")
const DEEP = Color("102935")
const QUESTS = [
    {"title":"Начало пути", "hint":"Победи 10 врагов", "stat":"kills", "need":10, "gold":200, "gems":5},
    {"title":"Покоритель долины", "hint":"Достигни 15 этапа", "stat":"stage", "need":15, "gold":2000, "gems":12},
    {"title":"Мастер тренировок", "hint":"Достигни 5 уровня", "stat":"level", "need":5, "gold":500, "gems":10},
    {"title":"Гроза титанов", "hint":"Победи 2 боссов", "stat":"bosses", "need":2, "gold":8500, "gems":35},
    {"title":"Большое приключение", "hint":"Достигни 30 этапа", "stat":"stage", "need":30, "gold":15000, "gems":40}
]
const UPGRADES = [
    {"key":"atk", "name":"СИЛА КЛИНКА", "detail":"Больше урона за удар", "base":25, "color":"#f4b17e"},
    {"key":"hp", "name":"ЗДОРОВЬЕ", "detail":"Увеличивает запас HP", "base":25, "color":"#8be2b4"},
    {"key":"speed", "name":"СКОРОСТЬ", "detail":"Чаще автоатаки", "base":50, "color":"#7bd2f2"},
    {"key":"crit", "name":"КРИТ. УДАР", "detail":"Шанс двойного урона", "base":65, "color":"#deacfb"}
]
const PETS = [
    {"name":"ПИКСИ", "detail":"Небесный птенец", "unlock":15, "color":"#9ce9ee"},
    {"name":"ИСКРА", "detail":"Огненный лис", "unlock":30, "color":"#ffc18b"},
    {"name":"МШИСТИК", "detail":"Каменный защитник", "unlock":60, "color":"#b9eda0"}
]
const PET_TEXTURES = [preload("res://assets/pet_bird.png"), preload("res://assets/pet_fox.png"), preload("res://assets/pet_turtle.png")]

var data: Dictionary = {}
var arena: Control
var header: PanelContainer
var panel: PanelContainer
var nav: PanelContainer
var content_holder: Control
var stage_label: Label
var money_label: Label
var gem_label: Label
var level_label: Label
var xp_bar: ProgressBar
var enemy_label: Label
var subtitle_label: Label
var notice: Label
var battle_info: Label
var refs: Dictionary = {}
var nav_buttons: Array[Button] = []
var current_tab: int = 0
var auto_timer: float = 0.0
var enemy_timer: float = 0.0
var pet_timer: float = 0.0
var skill_timer: float = 0.0
var save_timer: float = 0.0
var refresh_timer: float = 0.0
var notice_timer: float = 0.0
var tap_timer: float = 0.0
var wave_kind: int = 0
var max_enemy_hp: float = 1.0
var enemy_hp: float = 1.0
var hero_hp: float = 1.0
var auto_on: bool = true

func _ready() -> void:
    randomize()
    _load_game()
    _build_interface()
    resized.connect(_layout)
    _layout()
    _spawn_wave()
    if data.get("offline_reward", 0) > 0:
        _toast("Пока тебя не было: +%s монет!" % _num(data["offline_reward"]), 5.0)
    _refresh()

func _default_data() -> Dictionary:
    return {
        "gold": 160, "gems": 30, "stage": 1, "kills": 0, "bosses": 0,
        "level": 1, "xp": 0, "atk": 0, "hp": 0, "speed": 0, "crit": 0,
        "pets": [false, false, false], "pet_levels": [1, 1, 1],
        "gear_attack": 0, "gear_def": 0, "gear_rank": 0, "chests": 0,
        "equipment": {"weapon":{}, "armor":{}, "charm":{}}, "inventory": [], "next_item_id": 1,
        "quests": [false, false, false, false, false],
        "auto": true, "timestamp": 0, "offline_reward": 0
    }

func _load_game() -> void:
    data = _default_data()
    if FileAccess.file_exists(SAVE_FILE):
        var file: FileAccess = FileAccess.open(SAVE_FILE, FileAccess.READ)
        if file != null:
            var parsed: Variant = JSON.parse_string(file.get_as_text())
            if parsed is Dictionary:
                for key in data.keys():
                    if parsed.has(key):
                        data[key] = parsed[key]
    # Repair outdated/corrupted save fields.
    if typeof(data["pets"]) != TYPE_ARRAY or data["pets"].size() != 3:
        data["pets"] = [false, false, false]
    if typeof(data["pet_levels"]) != TYPE_ARRAY or data["pet_levels"].size() != 3:
        data["pet_levels"] = [1, 1, 1]
    if typeof(data["quests"]) != TYPE_ARRAY or data["quests"].size() != QUESTS.size():
        data["quests"] = [false, false, false, false, false]
    data["stage"] = maxi(1,int(data["stage"]))
    data["level"] = maxi(1,int(data["level"]))
    data["gold"] = maxi(0,int(data["gold"]))
    data["gems"] = maxi(0,int(data["gems"]))
    _repair_equipment()
    var since: int = maxi(0, int(Time.get_unix_time_from_system()) - int(data["timestamp"]))
    if int(data["timestamp"]) > 0 and since > 30:
        var secs: int = mini(since, 21600)
        var reward: int = int(secs * (.25 + float(data["stage"]) * .15))
        data["gold"] += reward
        data["offline_reward"] = reward
    else:
        data["offline_reward"] = 0
    auto_on = bool(data["auto"])
    hero_hp = _max_hp()

func _save_game() -> void:
    data["timestamp"] = int(Time.get_unix_time_from_system())
    data["auto"] = auto_on
    data["offline_reward"] = 0
    var f: FileAccess = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
    if f != null:
        f.store_string(JSON.stringify(data))

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == MainLoop.NOTIFICATION_APPLICATION_PAUSED:
        if not data.is_empty():
            _save_game()

func _max_hp() -> float:
    return 95.0 + float(data["hp"]) * 23.0 + (float(data["level"]) - 1.0) * 8.0 + float(data["gear_def"]) * 2.0 + _gear_health()

func _attack_power() -> int:
    return int(12 + int(data["atk"]) * 5 + (int(data["level"]) - 1) * 3 + int(data["gear_attack"]))

func _attack_interval() -> float:
    return maxf(.37, 1.13 - float(data["speed"]) * .045)

func _crit_chance() -> float:
    return minf(.6, .08 + float(data["crit"]) * .027)

func _wave_hp() -> float:
    var n: int = int(data["stage"])
    return (45.0 + n * 18.0) * pow(1.10, n - 1) * (5.0 if _is_boss() else 1.0)

func _is_boss() -> bool:
    return int(data["stage"]) % 15 == 0

func _spawn_wave() -> void:
    wave_kind = (int(data["stage"]) - 1) % 3
    max_enemy_hp = _wave_hp()
    enemy_hp = max_enemy_hp
    hero_hp = minf(hero_hp + _max_hp() * .3, _max_hp())
    enemy_timer = 0.0
    _sync_arena()
    _refresh()

func _process(delta: float) -> void:
    if data.is_empty() or arena == null:
        return
    save_timer += delta
    refresh_timer += delta
    skill_timer = maxf(0,skill_timer-delta)
    tap_timer = maxf(0,tap_timer-delta)
    notice_timer = maxf(0, notice_timer-delta)
    if notice_timer <= 0.0 and notice != null:
        notice.visible = false
    if save_timer >= 18.0:
        save_timer = 0
        _save_game()
    if auto_on:
        auto_timer += delta
        if auto_timer >= _attack_interval():
            auto_timer = 0
            _strike(1.0)
    enemy_timer += delta
    if enemy_timer >= 2.3:
        enemy_timer = 0
        _enemy_strike()
    pet_timer += delta
    if pet_timer >= 2.7:
        pet_timer = 0.0
        _pet_strike()
    if refresh_timer >= .17:
        refresh_timer = 0
        _sync_arena()
        _refresh()

func _strike(multiplier: float = 1.0) -> void:
    if enemy_hp <= 0:
        return
    var crit: bool = randf() < _crit_chance()
    var amount: int = maxi(1, int(_attack_power() * multiplier * (2.0 if crit else 1.0) * randf_range(.9,1.1)))
    enemy_hp -= amount
    arena.call("hit_enemy",amount,crit)
    if enemy_hp <= 0:
        _enemy_defeated()

func _enemy_strike() -> void:
    if enemy_hp <= 0:
        return
    var n: int = int(data["stage"])
    var amount: int = maxi(1, int((4.0 + n * 1.35) * (1.5 if _is_boss() else 1.0) * randf_range(.85,1.13) - int(data["gear_def"]) * .17))
    hero_hp -= amount
    arena.call("hit_hero",amount)
    if hero_hp <= 0:
        hero_hp = _max_hp()
        enemy_hp = max_enemy_hp
        _toast("Герой отдохнул и вернулся в бой!")

func _pet_strike() -> void:
    var pets: Array = data["pets"]
    var pet_levels: Array = data["pet_levels"]
    var amount: int = 0
    for i in range(3):
        if bool(pets[i]):
            amount += (2 + int(pet_levels[i]) * (3+i*2))
    if amount > 0 and enemy_hp > 0:
        enemy_hp -= amount
        arena.call("hit_enemy",amount,false)
        if enemy_hp <= 0:
            _enemy_defeated()

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

func _gain_xp(amount: int) -> void:
    data["xp"] += amount
    while int(data["xp"]) >= _xp_required():
        data["xp"] -= _xp_required()
        data["level"] += 1
        hero_hp += 14.0
        _toast("НОВЫЙ УРОВЕНЬ! %s" % str(data["level"]))

func _xp_required() -> int:
    return int(65 + int(data["level"]) * 28)

func _upgrade_cost(key: String) -> int:
    var base: int = 25
    for item in UPGRADES:
        if item["key"] == key:
            base = int(item["base"])
    return int(base * pow(1.51,int(data[key])))

func _upgrade_cap(key: String) -> int:
    if key == "crit": return 18
    if key == "speed": return 17
    return 999

func _buy_upgrade(key: String) -> void:
    if int(data[key]) >= _upgrade_cap(key):
        return
    var cost: int = _upgrade_cost(key)
    if int(data["gold"]) < cost:
        _toast("Не хватает монет")
        return
    data["gold"] -= cost
    data[key] += 1
    if key == "hp": hero_hp += 23
    _toast("Улучшение куплено!")
    _refresh()
    _save_game()

func _pet_cost(i: int) -> int:
    if not bool(data["pets"][i]):
        return int(PETS[i]["unlock"])
    return int((70+i*55) * pow(1.56,int(data["pet_levels"][i])-1))

func _buy_pet(i: int) -> void:
    var cost: int = _pet_cost(i)
    var pets: Array = data["pets"]
    var levels: Array = data["pet_levels"]
    if not bool(pets[i]):
        if int(data["gems"]) < cost:
            _toast("Нужно больше кристаллов")
            return
        data["gems"] -= cost
        pets[i] = true
        data["pets"] = pets
        _toast("Новый друг: %s!" % PETS[i]["name"])
    else:
        if int(data["gold"]) < cost:
            _toast("Нужно больше монет")
            return
        data["gold"] -= cost
        levels[i] += 1
        data["pet_levels"] = levels
        _toast("%s стал сильнее!" % PETS[i]["name"])
    _sync_arena()
    _refresh()
    _save_game()

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

func _quest_progress(index: int) -> int:
    return int(data[QUESTS[index]["stat"]])

func _claim_quest(index: int) -> void:
    var flags: Array = data["quests"]
    if bool(flags[index]) or _quest_progress(index) < int(QUESTS[index]["need"]):
        return
    flags[index] = true
    data["quests"] = flags
    data["gold"] += int(QUESTS[index]["gold"])
    data["gems"] += int(QUESTS[index]["gems"])
    _toast("НАГРАДА! +%s монет, +%s кристаллов" % [str(QUESTS[index]["gold"]),str(QUESTS[index]["gems"])],4.0)
    _refresh()
    _save_game()

func _use_skill() -> void:
    if skill_timer > 0:
        return
    skill_timer = 14.0
    _strike(4.2)
    _toast("ОГНЕННЫЙ РЫВОК!",1.5)
    _refresh()

func _use_heal() -> void:
    var price: int = maxi(15,int(data["stage"]) * 4)
    if hero_hp >= _max_hp() - 1:
        _toast("Здоровье уже полное")
        return
    if int(data["gold"]) < price:
        _toast("Не хватает монет")
        return
    data["gold"] -= price
    var amount: int = int(_max_hp() * .5)
    hero_hp = minf(_max_hp(),hero_hp + amount)
    arena.call("heal_hero",amount)
    _refresh()

func _manual_attack() -> void:
    if tap_timer > 0:
        return
    tap_timer = .18
    _strike(1.1)

func _sync_arena() -> void:
    if arena != null:
        arena.call("set_battle", int(data["stage"]),wave_kind,_is_boss(),hero_hp / _max_hp(),enemy_hp / max_enemy_hp,data["pets"], int(data["gear_rank"]))

func _num(n: Variant) -> String:
    var amount: int = int(n)
    if amount >= 1000000:
        return "%.1fM" % (float(amount) / 1000000.0)
    if amount >= 10000:
        return "%.1fK" % (float(amount) / 1000.0)
    return str(amount)

func _style(color: Color, radius: int = 18, border: Color = Color.TRANSPARENT, border_size: int = 0) -> StyleBoxFlat:
    var s: StyleBoxFlat = StyleBoxFlat.new()
    s.bg_color = color
    s.set_corner_radius_all(radius)
    s.border_color = border
    s.set_border_width_all(border_size)
    s.content_margin_left = 12
    s.content_margin_right = 12
    s.content_margin_top = 10
    s.content_margin_bottom = 10
    return s

func _label(parent: Node, value: String, font_size: int = 22, color: Color = TEXT) -> Label:
    var lab: Label = Label.new()
    lab.text = value
    lab.add_theme_font_size_override("font_size",font_size)
    lab.add_theme_color_override("font_color",color)
    lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    parent.add_child(lab)
    return lab

func _button(parent: Node, txt: String, accent: Color = Color("326c7a")) -> Button:
    var b: Button = Button.new()
    b.text = txt
    b.custom_minimum_size = Vector2(0,65)
    b.add_theme_font_size_override("font_size",20)
    b.add_theme_color_override("font_color",Color("f8ffff"))
    b.add_theme_color_override("font_disabled_color",Color("96a6ae"))
    b.add_theme_stylebox_override("normal",_style(accent,16))
    b.add_theme_stylebox_override("hover",_style(accent.lightened(.15),16))
    b.add_theme_stylebox_override("pressed",_style(accent.darkened(.18),16))
    b.add_theme_stylebox_override("disabled",_style(Color("34505a"),16))
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.focus_mode = Control.FOCUS_NONE
    parent.add_child(b)
    return b

func _space(parent: Node, px: float = 10) -> void:
    var space: Control = Control.new()
    space.custom_minimum_size.y = px
    parent.add_child(space)

func _build_interface() -> void:
    var bg: ColorRect = ColorRect.new()
    bg.color = Color("0b2632")
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    arena = Control.new()
    arena.set_script(ARENA_SCENE)
    add_child(arena)

    var over: ColorRect = ColorRect.new()
    over.color = Color("152e3e")
    over.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(over)
    refs["arena_footer"] = over

    header = PanelContainer.new()
    header.add_theme_stylebox_override("panel",_style(PANEL,22,Color("426776"),1))
    add_child(header)
    var header_margin: MarginContainer = MarginContainer.new()
    for side in ["left","right"]:
        header_margin.add_theme_constant_override("margin_" + side,15)
    header_margin.add_theme_constant_override("margin_top",8)
    header_margin.add_theme_constant_override("margin_bottom",6)
    header.add_child(header_margin)
    var header_v: VBoxContainer = VBoxContainer.new()
    header_v.add_theme_constant_override("separation",5)
    header_margin.add_child(header_v)
    var header_h: HBoxContainer = HBoxContainer.new()
    header_h.add_theme_constant_override("separation",10)
    header_v.add_child(header_h)
    var logo: TextureRect = TextureRect.new()
    logo.texture = preload("res://assets/hero.png")
    logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    logo.custom_minimum_size = Vector2(66,66)
    header_h.add_child(logo)
    var names: VBoxContainer = VBoxContainer.new()
    names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header_h.add_child(names)
    _label(names,"DINO QUEST",29,GOLD)
    stage_label = _label(names,"ЭТАП 1",18,MUTED)
    var money_box: VBoxContainer = VBoxContainer.new()
    header_h.add_child(money_box)
    money_box.alignment = BoxContainer.ALIGNMENT_CENTER
    money_label = _label(money_box,"М 160",20,GOLD)
    gem_label = _label(money_box,"К 30",19,AQUA)
    var xp_h: HBoxContainer = HBoxContainer.new()
    xp_h.add_theme_constant_override("separation",12)
    header_v.add_child(xp_h)
    level_label = _label(xp_h,"УР. 1",15,GOLD)
    xp_bar = ProgressBar.new()
    xp_bar.custom_minimum_size = Vector2(0,12)
    xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    xp_bar.show_percentage = false
    xp_bar.add_theme_stylebox_override("background",_style(Color("284657"),5))
    xp_bar.add_theme_stylebox_override("fill",_style(Color("76e3ba"),5))
    xp_h.add_child(xp_bar)

    enemy_label = Label.new()
    enemy_label.add_theme_font_size_override("font_size",32)
    enemy_label.add_theme_color_override("font_color",Color("fff2bf"))
    enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    enemy_label.add_theme_color_override("font_shadow_color",Color("1b3443"))
    enemy_label.add_theme_constant_override("shadow_offset_y",3)
    add_child(enemy_label)
    subtitle_label = Label.new()
    subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle_label.add_theme_color_override("font_color",Color("e6fff4"))
    subtitle_label.add_theme_font_size_override("font_size",20)
    add_child(subtitle_label)

    panel = PanelContainer.new()
    panel.add_theme_stylebox_override("panel",_style(Color("173647"),22,Color("456777"),1))
    add_child(panel)
    content_holder = Control.new()
    panel.add_child(content_holder)
    content_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
    content_holder.offset_left = 14
    content_holder.offset_top = 12
    content_holder.offset_right = -14
    content_holder.offset_bottom = -12

    nav = PanelContainer.new()
    nav.add_theme_stylebox_override("panel",_style(Color("173a48"),20,Color("446775"),1))
    add_child(nav)
    var nav_h: HBoxContainer = HBoxContainer.new()
    nav_h.add_theme_constant_override("separation",6)
    nav.add_child(nav_h)
    for t in ["БОЙ","ГЕРОЙ","ДРУЗЬЯ","СОКРОВ.","КВЕСТЫ"]:
        var b: Button = _button(nav_h,t,Color("254e5a"))
        b.custom_minimum_size.y = 60
        b.add_theme_font_size_override("font_size",15)
        nav_buttons.append(b)
        var tab_index: int = nav_buttons.size() - 1
        b.pressed.connect(_change_tab.bind(tab_index))

    notice = Label.new()
    notice.visible = false
    notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    notice.add_theme_font_size_override("font_size",21)
    notice.add_theme_color_override("font_color",Color("ffe9a3"))
    notice.add_theme_color_override("font_shadow_color",Color("103544"))
    notice.add_theme_constant_override("shadow_offset_y",3)
    add_child(notice)
    _change_tab(0)

func _layout() -> void:
    if header == null or arena == null or panel == null or nav == null:
        return
    var w: float = size.x
    var h: float = size.y
    var edge: float = 11.0
    var header_height: float = 126.0
    var nav_height: float = 86.0
    var panel_height: float = clampf(h*.315,355.0,430.0)
    header.position = Vector2(edge,12)
    header.size = Vector2(w-edge*2,header_height)
    nav.position = Vector2(edge,h-nav_height-9)
    nav.size = Vector2(w-edge*2,nav_height)
    panel.position = Vector2(edge,nav.position.y-panel_height-7)
    panel.size = Vector2(w-edge*2,panel_height)
    arena.position = Vector2(0,140)
    arena.size = Vector2(w, maxf(220,panel.position.y-140+10))
    var footer: ColorRect = refs.get("arena_footer")
    if footer:
        footer.position = Vector2(0, panel.position.y-3)
        footer.size = Vector2(w,16)
    enemy_label.position = Vector2(10,arena.position.y+18)
    enemy_label.size = Vector2(w-20,43)
    subtitle_label.position = Vector2(10,arena.position.y+59)
    subtitle_label.size = Vector2(w-20,33)
    notice.position = Vector2(w*.07,arena.position.y+arena.size.y*.79)
    notice.size = Vector2(w*.86,65)

func _toast(value: String, duration: float = 2.4) -> void:
    if notice == null:
        return
    notice.text = value
    notice.visible = true
    notice_timer = duration

func _change_tab(index: int) -> void:
    current_tab = index
    for i in range(nav_buttons.size()):
        var chosen: bool = i == index
        nav_buttons[i].add_theme_stylebox_override("normal",_style(Color("33897f") if chosen else Color("254e5a"),13))
        nav_buttons[i].add_theme_color_override("font_color",Color("ffffff") if chosen else Color("aec2c9"))
    for child in content_holder.get_children():
        content_holder.remove_child(child)
        child.queue_free()
    refs = {"arena_footer": refs.get("arena_footer")}
    if index == 0: _build_battle_tab()
    elif index == 1: _build_upgrade_tab()
    elif index == 2: _build_pets_tab()
    elif index == 3: _build_gear_tab()
    else: _build_quest_tab()
    _refresh()

func _vbox() -> VBoxContainer:
    var v: VBoxContainer = VBoxContainer.new()
    v.set_anchors_preset(Control.PRESET_FULL_RECT)
    v.add_theme_constant_override("separation",11)
    content_holder.add_child(v)
    return v

func _scroll_vbox() -> VBoxContainer:
    var scroll: ScrollContainer = ScrollContainer.new()
    scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    content_holder.add_child(scroll)
    var v: VBoxContainer = VBoxContainer.new()
    v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    v.add_theme_constant_override("separation",11)
    scroll.add_child(v)
    return v

func _section_title(v: Node,title: String,subtitle: String) -> void:
    var title_h: HBoxContainer = HBoxContainer.new()
    v.add_child(title_h)
    var name: Label = _label(title_h,title,27,GOLD)
    name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _label(v,subtitle,17,MUTED)

func _build_battle_tab() -> void:
    var v: VBoxContainer = _vbox()
    _section_title(v,"ПРИКЛЮЧЕНИЕ","Герой атакует даже без нажатий")
    var status: HBoxContainer = HBoxContainer.new()
    status.add_theme_constant_override("separation",12)
    v.add_child(status)
    battle_info = _label(status,"УРОН 12  ·  HP 95",18,Color("c6edf1"))
    battle_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var switch: Button = _button(status,"АВТО: ВКЛ",Color("267b71"))
    switch.custom_minimum_size = Vector2(155,50)
    switch.add_theme_font_size_override("font_size",17)
    switch.pressed.connect(func():
        auto_on = not auto_on
        _refresh()
        _save_game()
    )
    refs["auto_button"] = switch
    var actions: HBoxContainer = HBoxContainer.new()
    actions.add_theme_constant_override("separation",9)
    v.add_child(actions)
    var hit: Button = _button(actions,"УДАР",Color("d28b4c"))
    var power: Button = _button(actions,"ПЛАМЯ",Color("a35478"))
    var heal: Button = _button(actions,"ЛЕЧИТЬ",Color("398976"))
    hit.pressed.connect(_manual_attack)
    power.pressed.connect(_use_skill)
    heal.pressed.connect(_use_heal)
    refs["power_button"] = power
    refs["heal_button"] = heal
    _space(v,2)
    var tip: Label = _label(v,"Побеждай монстров, улучшай меч и собирай друзей!",18,Color("a9e1db"))
    tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var nxt: Label = _label(v,"Каждый 15-й этап — огромный босс и редкая награда",17,MUTED)
    nxt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _stat_row(v: Node, title: String, detail: String, accent: Color) -> Dictionary:
    var card: PanelContainer = PanelContainer.new()
    card.add_theme_stylebox_override("panel",_style(Color("254757"),13,Color("3b6371"),1))
    v.add_child(card)
    var h: HBoxContainer = HBoxContainer.new()
    h.add_theme_constant_override("separation",10)
    card.add_child(h)
    var text_box: VBoxContainer = VBoxContainer.new()
    text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    h.add_child(text_box)
    var heading: Label = _label(text_box,title,19,accent)
    heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var info: Label = _label(text_box,detail,16,MUTED)
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var btn: Button = _button(h,"КУПИТЬ",Color("388377"))
    btn.custom_minimum_size = Vector2(180,60)
    btn.size_flags_horizontal = Control.SIZE_SHRINK_END
    return {"info":info,"button":btn}

func _build_upgrade_tab() -> void:
    var v: VBoxContainer = _scroll_vbox()
    _section_title(v,"УСИЛЕНИЕ ГЕРОЯ","Трать монеты для роста характеристик")
    for entry in UPGRADES:
        var key: String = entry["key"]
        var widgets: Dictionary = _stat_row(v,entry["name"],entry["detail"],Color(entry["color"]))
        var b: Button = widgets["button"]
        b.pressed.connect(_buy_upgrade.bind(key))
        refs["up_"+key] = widgets

func _build_pets_tab() -> void:
    var v: VBoxContainer = _scroll_vbox()
    _section_title(v,"КОМАНДА ДИНО","Друзья автоматически помогают в бою")
    for i in range(3):
        var idx: int = i
        var row: PanelContainer = PanelContainer.new()
        row.add_theme_stylebox_override("panel",_style(Color("254757"),16,Color("3b6371"),1))
        v.add_child(row)
        var h: HBoxContainer = HBoxContainer.new()
        h.add_theme_constant_override("separation",10)
        row.add_child(h)
        var photo: TextureRect = TextureRect.new()
        photo.texture = PET_TEXTURES[i]
        photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        photo.custom_minimum_size = Vector2(91,88)
        h.add_child(photo)
        var textv: VBoxContainer = VBoxContainer.new()
        textv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        h.add_child(textv)
        _label(textv,PETS[i]["name"],21,Color(PETS[i]["color"]))
        var info: Label = _label(textv,PETS[i]["detail"],16,MUTED)
        var b: Button = _button(textv,"ОТКРЫТЬ",Color("397c84"))
        b.custom_minimum_size.y = 50
        b.pressed.connect(_buy_pet.bind(idx))
        refs["pet_%s"%i] = {"info":info,"button":b}

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

func _build_quest_tab() -> void:
    var v: VBoxContainer = _scroll_vbox()
    _section_title(v,"ЗАДАНИЯ","Выполняй цели и забирай награды")
    for i in range(QUESTS.size()):
        var idx: int = i
        var widgets: Dictionary = _stat_row(v,QUESTS[i]["title"],QUESTS[i]["hint"],Color("b1f1dc"))
        var b: Button = widgets["button"]
        b.pressed.connect(_claim_quest.bind(idx))
        refs["quest_%s"%i] = widgets

func _refresh() -> void:
    if header == null:
        return
    stage_label.text = "ЭТАП %s · УР. %s" % [str(data["stage"]),str(data["level"])]
    money_label.text = "● " + _num(data["gold"])
    gem_label.text = "◆ " + _num(data["gems"])
    level_label.text = "УРОВЕНЬ %s" % str(data["level"])
    xp_bar.value = clampf(100.0*float(data["xp"])/float(_xp_required()),0,100)
    var names: Array = ["ЛИПУН", "РАЗБОЙНИК", "КАМНЕГРОМ"]
    enemy_label.text = "БОСС · КОРОЛЬ ТЕНЕЙ" if _is_boss() else names[wave_kind]
    subtitle_label.text = "ЭТАП %s  •  %s / %s HP" % [str(data["stage"]),_num(maxi(0,int(enemy_hp))),_num(int(max_enemy_hp))]
    if current_tab == 0:
        if battle_info != null:
            battle_info.text = "СИЛА %s  ·  HP %s/%s" % [str(_attack_power()),_num(int(hero_hp)),_num(int(_max_hp()))]
        if refs.has("auto_button"):
            refs["auto_button"].text = "АВТО: ВКЛ" if auto_on else "АВТО: ВЫКЛ"
        if refs.has("power_button"):
            refs["power_button"].text = "ПЛАМЯ %.0fс" % ceilf(skill_timer) if skill_timer > 0 else "ПЛАМЯ"
            refs["power_button"].disabled = skill_timer > 0
        if refs.has("heal_button"):
            refs["heal_button"].text = "ЛЕЧИТЬ %s" % str(maxi(15,int(data["stage"]) * 4))
    elif current_tab == 1:
        for item in UPGRADES:
            var key: String = item["key"]
            var widget: Dictionary = refs.get("up_"+key,{})
            if widget.is_empty(): continue
            widget["info"].text = "Уровень %s  ·  %s" % [str(data[key]),item["detail"]]
            var b: Button = widget["button"]
            b.text = "МАКС." if int(data[key])>=_upgrade_cap(key) else "%s ●" % _num(_upgrade_cost(key))
            b.disabled = int(data[key]) >= _upgrade_cap(key) or int(data["gold"]) < _upgrade_cost(key)
    elif current_tab == 2:
        for i in range(3):
            var widget: Dictionary = refs.get("pet_%s"%i,{})
            if widget.is_empty(): continue
            var owned: bool = bool(data["pets"][i])
            widget["info"].text = "Уровень %s · помогает в бою" % str(data["pet_levels"][i]) if owned else PETS[i]["detail"]
            var b: Button = widget["button"]
            b.text = ("УЛУЧШ. %s ●" if owned else "НАНЯТЬ %s ◆") % _num(_pet_cost(i))
            b.disabled = int(data["gold" if owned else "gems"]) < _pet_cost(i)
    elif current_tab == 3:
        var grades: Array = ["ОБЫЧНЫЙ", "РЕДКИЙ", "ЭПИЧЕСКИЙ", "ЛЕГЕНДАРНЫЙ"]
        if refs.has("gear_name"):
            refs["gear_name"].text = "СНАРЯЖЕНИЕ · " + str(data["inventory"].size()) + " в рюкзаке"
            refs["gear_stats"].text = "АТК +%s · БРОНЯ +%s · HP +%s" % [str(data["gear_attack"]),str(data["gear_def"]),str(int(_gear_health()))]
            refs["chest_gold"].text = "СУНДУК %s ●" % _num(180 + int(data["stage"]) * 22)
            refs["chest_gold"].disabled = int(data["gold"]) < 180 + int(data["stage"]) * 22
            refs["chest_gems"].text = "ЭПИК 30 ◆"
            refs["chest_gems"].disabled = int(data["gems"]) < 30
    else:
        for i in range(QUESTS.size()):
            var widget: Dictionary = refs.get("quest_%s"%i,{})
            if widget.is_empty(): continue
            var q: Dictionary = QUESTS[i]
            var claimed: bool = bool(data["quests"][i])
            var progress: int = mini(_quest_progress(i),int(q["need"]))
            widget["info"].text = "%s/%s  ·  +%s ●  +%s ◆" % [str(progress),str(q["need"]),str(q["gold"]),str(q["gems"])]
            var b: Button = widget["button"]
            b.text = "ГОТОВО" if claimed else ("ЗАБРАТЬ" if progress >= int(q["need"]) else "В ПРОЦЕССЕ")
            b.disabled = claimed or progress < int(q["need"])

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
