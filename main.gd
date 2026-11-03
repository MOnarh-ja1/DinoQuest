extends Control
# DinoQuest: an original offline idle RPG for Godot 4.4.

const SAVE_PATH := "user://dinoquest_save.json"
const INK := Color("#eafdf5")
const GOLD := Color("#ffdf82")
const CYAN := Color("#79eadb")
const DARK := Color("#122a37")
const QUEST_NAMES := ["Победи 10 врагов", "Дойди до этапа 5", "Достигни 5 уровня", "Победи 3 боссов"]
const QUEST_NEED := [10, 5, 5, 3]
const QUEST_PAY := [150, 280, 400, 700]

var game: Dictionary = {}
var enemy_hp: float = 40.0
var enemy_max: float = 40.0
var hero_hp: float = 100.0
var time_attack: float = 0.0
var time_enemy: float = 0.0
var time_pet: float = 0.0
var time_save: float = 0.0
var flame_cooldown: float = 0.0
var active_tab: int = 0
var info: Label
var stage_text: Label
var currency: Label
var enemy_text: Label
var hero_text: Label
var tip: Label
var arena: Control
var options: VBoxContainer
var nav_buttons: Array[Button] = []
var auto_button: Button
var flame_button: Button
var title: Label

func _ready() -> void:
    randomize()
    _load()
    _make_ui()
    _spawn()
    _update_ui()

func _defaults() -> Dictionary:
    return {"stage":1, "gold":175, "gems":15, "level":1, "xp":0, "kills":0,
        "bosses":0, "atk":0, "health":0, "speed":0, "crit":0,
        "weapon":0, "pet":0, "pet_level":1, "chests":0,
        "auto":true, "quests":[false,false,false,false], "last":0}

func _load() -> void:
    game = _defaults()
    if FileAccess.file_exists(SAVE_PATH):
        var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
        if file != null:
            var result: Variant = JSON.parse_string(file.get_as_text())
            if result is Dictionary:
                for key in game.keys():
                    if result.has(key):
                        game[key] = result[key]
    if not game["quests"] is Array or game["quests"].size() != 4:
        game["quests"] = [false,false,false,false]
    game["stage"] = maxi(1, int(game["stage"]))
    game["level"] = maxi(1, int(game["level"]))
    var elapsed := maxi(0, int(Time.get_unix_time_from_system()) - int(game["last"]))
    if int(game["last"]) > 0 and elapsed > 30:
        game["gold"] = int(game["gold"]) + mini(elapsed,21600) * (1 + int(game["stage"]) / 5)
    hero_hp = _max_hp()

func _save() -> void:
    if game.is_empty():
        return
    game["last"] = int(Time.get_unix_time_from_system())
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(game))

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == MainLoop.NOTIFICATION_APPLICATION_PAUSED:
        _save()

func _max_hp() -> float:
    return 105.0 + float(game["health"]) * 28.0 + float(game["level"]) * 9.0

func _attack() -> int:
    return 12 + int(game["atk"]) * 5 + int(game["level"]) * 3 + int(game["weapon"]) * 8

func _is_boss() -> bool:
    return int(game["stage"]) % 5 == 0

func _spawn() -> void:
    var n := int(game["stage"])
    enemy_max = (38.0 + n * 16.0) * pow(1.12, n - 1)
    if _is_boss():
        enemy_max *= 3.5
    enemy_hp = enemy_max
    hero_hp = minf(hero_hp + _max_hp() * 0.35, _max_hp())
    if is_instance_valid(arena):
        arena.queue_redraw()

func _process(delta: float) -> void:
    if game.is_empty():
        return
    time_attack += delta
    time_enemy += delta
    time_pet += delta
    time_save += delta
    flame_cooldown = maxf(0.0, flame_cooldown - delta)
    if bool(game["auto"]) and time_attack >= maxf(0.38, 1.1 - float(game["speed"]) * 0.05):
        time_attack = 0.0
        _hit(1.0)
    if time_enemy >= 2.3:
        time_enemy = 0.0
        hero_hp -= maxf(1.0, float(game["stage"]) * 2.2 - float(game["health"]) * 0.45)
        if hero_hp <= 0.0:
            hero_hp = _max_hp()
            game["gold"] = maxi(0, int(game["gold"]) - 8)
            _toast("Герой восстановился!")
    if int(game["pet"]) > 0 and time_pet >= 2.9:
        time_pet = 0.0
        _hit(0.25 * float(game["pet_level"]))
    if time_save > 18.0:
        time_save = 0.0
        _save()
    _update_header()
    if is_instance_valid(arena):
        arena.queue_redraw()

func _hit(multiplier: float) -> void:
    var critical := randf() < minf(0.55, 0.08 + float(game["crit"]) * 0.04)
    var damage := maxi(1, int(_attack() * multiplier * (2.0 if critical else 1.0)))
    enemy_hp -= damage
    if enemy_hp <= 0.0:
        _win()
    elif critical:
        _toast("КРИТ! -" + str(damage))

func _win() -> void:
    var reward := 15 + int(game["stage"]) * 7
    if _is_boss():
        reward *= 5
        game["bosses"] = int(game["bosses"]) + 1
        game["gems"] = int(game["gems"]) + 3
        _toast("БОСС ПОБЕЖДЁН! +" + str(reward))
    game["kills"] = int(game["kills"]) + 1
    game["gold"] = int(game["gold"]) + reward
    game["xp"] = int(game["xp"]) + 12 + int(game["stage"]) * 3
    while int(game["xp"]) >= int(game["level"]) * 60:
        game["xp"] = int(game["xp"]) - int(game["level"]) * 60
        game["level"] = int(game["level"]) + 1
        hero_hp = _max_hp()
        _toast("НОВЫЙ УРОВЕНЬ!")
    game["stage"] = int(game["stage"]) + 1
    _spawn()
    _update_options()
    _save()

func _click_hit() -> void:
    _hit(1.7)

func _flame() -> void:
    if flame_cooldown > 0.0:
        return
    flame_cooldown = 14.0
    _hit(5.0)
    _toast("ОГНЕННОЕ ДЫХАНИЕ!")

func _toggle_auto() -> void:
    game["auto"] = not bool(game["auto"])
    _update_ui()
    _save()

func _heal() -> void:
    if int(game["gold"]) >= 25:
        game["gold"] = int(game["gold"]) - 25
        hero_hp = minf(_max_hp(), hero_hp + _max_hp() * 0.6)
        _toast("Здоровье восстановлено")
    else:
        _toast("Не хватает монет!")

func _upgrade(kind: int) -> void:
    var keys := ["atk", "health", "speed", "crit"]
    var key: String = keys[kind]
    var level := int(game[key])
    var price := int((24 + kind * 20) * pow(1.32, level))
    if int(game["gold"]) < price:
        _toast("Не хватает монет")
        return
    game["gold"] = int(game["gold"]) - price
    game[key] = level + 1
    if kind == 1:
        hero_hp += 28.0
    _toast("Улучшение приобретено!")
    _update_options()
    _save()

func _buy_chest() -> void:
    if int(game["gems"]) < 10:
        _toast("Нужно 10 кристаллов")
        return
    game["gems"] = int(game["gems"]) - 10
    game["chests"] = int(game["chests"]) + 1
    var power := randi_range(1, 3)
    game["weapon"] = int(game["weapon"]) + power
    _toast("НОВОЕ ОРУЖИЕ! +" + str(power * 8) + " силы")
    _update_options()
    _save()

func _pet() -> void:
    if int(game["pet"]) == 0:
        if int(game["gems"]) < 15:
            _toast("Нужно 15 кристаллов")
            return
        game["gems"] = int(game["gems"]) - 15
        game["pet"] = 1
        _toast("ПИКСИ присоединился!")
    else:
        var cost := int(game["pet_level"]) * 90
        if int(game["gold"]) < cost:
            _toast("Нужно " + str(cost) + " монет")
            return
        game["gold"] = int(game["gold"]) - cost
        game["pet_level"] = int(game["pet_level"]) + 1
        _toast("Спутник стал сильнее")
    _update_options()
    _save()

func _claim_quest(index: int) -> void:
    if bool(game["quests"][index]):
        return
    if _quest_progress(index) < QUEST_NEED[index]:
        _toast("Задание ещё не выполнено")
        return
    game["quests"][index] = true
    game["gold"] = int(game["gold"]) + QUEST_PAY[index]
    game["gems"] = int(game["gems"]) + 3
    _toast("Задание выполнено! +3 кристалла")
    _update_options()
    _save()

func _quest_progress(index: int) -> int:
    if index == 0:
        return int(game["kills"])
    if index == 1:
        return int(game["stage"])
    if index == 2:
        return int(game["level"])
    return int(game["bosses"])

func _toast(message: String) -> void:
    if is_instance_valid(tip):
        tip.text = message

func _color_button(button: Button, color: Color) -> void:
    button.add_theme_font_size_override("font_size", 23)
    button.add_theme_color_override("font_color", INK)
    var box := StyleBoxFlat.new()
    box.bg_color = color
    box.set_corner_radius_all(15)
    box.content_margin_left = 10
    box.content_margin_right = 10
    button.add_theme_stylebox_override("normal", box)
    var pressed := box.duplicate()
    pressed.bg_color = color.lightened(0.15)
    button.add_theme_stylebox_override("pressed", pressed)

func _label(text: String, size_pt: int, color: Color = INK) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size_pt)
    label.add_theme_color_override("font_color", color)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    return label

func _make_button(text: String, color: Color, height: float = 60.0) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size = Vector2(0, height)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _color_button(button, color)
    return button

func _make_ui() -> void:
    var margins := MarginContainer.new()
    margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margins.add_theme_constant_override("margin_left", 17)
    margins.add_theme_constant_override("margin_right", 17)
    margins.add_theme_constant_override("margin_top", 20)
    margins.add_theme_constant_override("margin_bottom", 18)
    add_child(margins)
    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 9)
    margins.add_child(layout)
    title = _label("DINO QUEST  •  ДОЛИНА ГЕРОЕВ", 31, GOLD)
    layout.add_child(title)
    currency = _label("", 27, CYAN)
    layout.add_child(currency)
    stage_text = _label("", 29, GOLD)
    layout.add_child(stage_text)
    arena = Control.new()
    arena.set_script(preload("res://battle.gd"))
    arena.custom_minimum_size.y = 320
    arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
    layout.add_child(arena)
    enemy_text = _label("", 23, GOLD)
    layout.add_child(enemy_text)
    hero_text = _label("", 23, CYAN)
    layout.add_child(hero_text)
    var controls := HBoxContainer.new()
    controls.add_theme_constant_override("separation", 7)
    layout.add_child(controls)
    var hit := _make_button("УДАР", Color("#e16c68"), 68)
    hit.pressed.connect(_click_hit)
    controls.add_child(hit)
    flame_button = _make_button("ПЛАМЯ", Color("#bb6f45"), 68)
    flame_button.pressed.connect(_flame)
    controls.add_child(flame_button)
    auto_button = _make_button("АВТО", Color("#287e8c"), 68)
    auto_button.pressed.connect(_toggle_auto)
    controls.add_child(auto_button)
    tip = _label("Побеждай врагов, усиливай героя!", 20, GOLD)
    layout.add_child(tip)
    var tabs := HBoxContainer.new()
    tabs.add_theme_constant_override("separation", 6)
    layout.add_child(tabs)
    var tab_names := ["ГЕРОЙ", "ДОБЫЧА", "ЗАДАНИЯ"]
    for i in range(3):
        var button := _make_button(tab_names[i], Color("#2e5466"), 50)
        button.pressed.connect(_tab.bind(i))
        tabs.add_child(button)
        nav_buttons.append(button)
    options = VBoxContainer.new()
    options.add_theme_constant_override("separation", 6)
    options.custom_minimum_size.y = 280
    layout.add_child(options)
    _update_options()

func _tab(index: int) -> void:
    active_tab = index
    _update_options()

func _update_options() -> void:
    if not is_instance_valid(options):
        return
    for child in options.get_children():
        options.remove_child(child)
        child.queue_free()
    for i in range(nav_buttons.size()):
        _color_button(nav_buttons[i], Color("#43877f") if i == active_tab else Color("#2e5466"))
    if active_tab == 0:
        var labels := ["СИЛА", "ЗДОРОВЬЕ", "СКОРОСТЬ", "КРИТ. УДАР"]
        var keys := ["atk", "health", "speed", "crit"]
        for i in range(4):
            var level := int(game[keys[i]])
            var price := int((24 + i * 20) * pow(1.32, level))
            var button := _make_button(labels[i] + "  •  ур. " + str(level) + "  •  " + str(price) + " монет", Color("#274b5d"), 59)
            button.pressed.connect(_upgrade.bind(i))
            options.add_child(button)
    elif active_tab == 1:
        var chest := _make_button("СУНДУК  •  10 кристаллов", Color("#624b81"), 65)
        chest.pressed.connect(_buy_chest)
        options.add_child(chest)
        var buddy := _make_button("СПУТНИК ПИКСИ  •  " + ("15 кристаллов" if int(game["pet"]) == 0 else str(int(game["pet_level"]) * 90) + " монет"), Color("#30655e"), 65)
        buddy.pressed.connect(_pet)
        options.add_child(buddy)
        var heal := _make_button("ЛЕЧЕНИЕ  •  25 монет", Color("#3a775a"), 65)
        heal.pressed.connect(_heal)
        options.add_child(heal)
        options.add_child(_label("Оружие +" + str(int(game["weapon"]) * 8) + "   •   Сундуков: " + str(game["chests"]), 23, GOLD))
    else:
        for i in range(4):
            var complete := _quest_progress(i) >= QUEST_NEED[i]
            var claimed := bool(game["quests"][i])
            var status := "ПОЛУЧЕНО" if claimed else ("ЗАБРАТЬ" if complete else str(_quest_progress(i)) + "/" + str(QUEST_NEED[i]))
            var button := _make_button(QUEST_NAMES[i] + "  •  " + status, Color("#356e67") if complete else Color("#294959"), 59)
            button.pressed.connect(_claim_quest.bind(i))
            options.add_child(button)

func _update_header() -> void:
    if not is_instance_valid(currency):
        return
    currency.text = "МОНЕТЫ  " + str(game["gold"]) + "     КРИСТАЛЛЫ  " + str(game["gems"])
    stage_text.text = ("БОСС  •  " if _is_boss() else "ЭТАП  •  ") + str(game["stage"]) + "     УРОВЕНЬ " + str(game["level"])
    enemy_text.text = "ВРАГ  " + str(maxi(0, int(enemy_hp))) + " / " + str(int(enemy_max)) + " HP"
    hero_text.text = "ГЕРОЙ  " + str(maxi(0, int(hero_hp))) + " / " + str(int(_max_hp())) + " HP"
    auto_button.text = "АВТО: ВКЛ" if bool(game["auto"]) else "АВТО: ВЫКЛ"
    flame_button.text = "ПЛАМЯ " + str(int(ceil(flame_cooldown))) if flame_cooldown > 0.0 else "ПЛАМЯ"

func _update_ui() -> void:
    _update_header()
    _update_options()
