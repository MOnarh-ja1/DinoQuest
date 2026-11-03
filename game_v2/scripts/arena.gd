extends Control
## Animated hand-drawn battle scene. All drawings and sprites are original.

const HERO = preload("res://assets/hero.png")
const SLIME = preload("res://assets/slime.png")
const RAIDER = preload("res://assets/raider.png")
const GOLEM = preload("res://assets/golem.png")
const BOSS = preload("res://assets/boss.png")
const BIRD = preload("res://assets/pet_bird.png")
const FOX = preload("res://assets/pet_fox.png")
const TURTLE = preload("res://assets/pet_turtle.png")
const FOREST = preload("res://assets/bg_forest.png")
const SUNSET = preload("res://assets/bg_sunset.png")
const CAVE = preload("res://assets/bg_cave.png")

var clock: float = 0.0
var stage: int = 1
var enemy_kind: int = 0
var enemy_is_boss: bool = false
var hero_health: float = 1.0
var enemy_health: float = 1.0
var unlocked_pets: Array = [false, false, false]
var attacking: float = 0.0
var enemy_attacking: float = 0.0
var enemy_flash: float = 0.0
var hero_flash: float = 0.0
var sparks: Array = []
var gear_rank: int = 0
var victory_glow: float = 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    clip_contents = true

func _process(delta: float) -> void:
    clock += delta
    victory_glow = maxf(0.0,victory_glow - delta * 1.1)
    attacking = maxf(0.0, attacking - delta * 3.5)
    enemy_attacking = maxf(0.0, enemy_attacking - delta * 3.2)
    enemy_flash = maxf(0.0, enemy_flash - delta * 5.0)
    hero_flash = maxf(0.0, hero_flash - delta * 5.0)
    for i in range(sparks.size() - 1, -1, -1):
        var s: Dictionary = sparks[i]
        s["pos"] += s["velocity"] * delta
        s["velocity"] *= 0.97
        s["life"] -= delta
        if s["life"] <= 0.0:
            sparks.remove_at(i)
        else:
            sparks[i] = s
    queue_redraw()

func set_battle(stage_number: int, kind: int, is_boss: bool, hero_ratio: float, mob_ratio: float, pets: Array, rank: int = 0) -> void:
    stage = stage_number
    gear_rank = rank
    enemy_kind = kind
    enemy_is_boss = is_boss
    hero_health = clampf(hero_ratio, 0.0, 1.0)
    enemy_health = clampf(mob_ratio, 0.0, 1.0)
    unlocked_pets = pets.duplicate()

func hit_enemy(amount: int, critical: bool = false) -> void:
    attacking = 1.0
    enemy_flash = 1.0
    _damage_label(amount, true, critical)
    _burst(Vector2(size.x * .77, size.y * .58), Color("ffe59b") if critical else Color("d5fcf9"))

func hit_hero(amount: int) -> void:
    enemy_attacking = 1.0
    hero_flash = 1.0
    _damage_label(amount, false, false)
    _burst(Vector2(size.x * .29, size.y * .63), Color("ff8594"))

func heal_hero(amount: int) -> void:
    var txt: Label = Label.new()
    txt.text = "+" + str(amount)
    txt.add_theme_font_size_override("font_size", 36)
    txt.add_theme_color_override("font_color", Color("75ffa8"))
    add_child(txt)
    txt.position = Vector2(size.x * .28, size.y * .46)
    var tween: Tween = create_tween()
    tween.tween_property(txt, "position:y", txt.position.y - 90, .95)
    tween.parallel().tween_property(txt, "modulate:a", 0.0, .95)
    tween.tween_callback(txt.queue_free)

func _damage_label(amount: int, to_enemy: bool, critical: bool) -> void:
    var txt: Label = Label.new()
    txt.text = ("КРИТ! " if critical else "-") + str(amount)
    txt.add_theme_font_size_override("font_size", 43 if critical else 33)
    txt.add_theme_color_override("font_color", Color("ffdb64") if critical else (Color("f9feff") if to_enemy else Color("ff9caa")))
    txt.add_theme_color_override("font_shadow_color", Color("1d293b"))
    txt.add_theme_constant_override("shadow_offset_x", 3)
    txt.add_theme_constant_override("shadow_offset_y", 4)
    add_child(txt)
    txt.position = Vector2(size.x * (.66 if to_enemy else .18), size.y * .45)
    var tween: Tween = create_tween()
    tween.tween_property(txt, "position:y", txt.position.y - 104, .85)
    tween.parallel().tween_property(txt, "modulate:a", 0.0, .85)
    tween.tween_callback(txt.queue_free)

func _burst(center: Vector2, color: Color) -> void:
    for i in range(18):
        var a: float = randf() * TAU
        var v: float = randf_range(65.0, 180.0)
        sparks.append({"pos": center, "velocity": Vector2(cos(a), sin(a)) * v, "life": randf_range(.3, .65), "color": color})

func _draw() -> void:
    var w: float = size.x
    var h: float = size.y
    if w < 1 or h < 1:
        return
    var background: Texture2D = FOREST
    if stage >= 11 and stage % 15 < 5:
        background = CAVE
    elif stage >= 6 and stage % 15 < 10:
        background = SUNSET
    draw_texture_rect(background, Rect2(0, 0, w, h), false)

    if victory_glow > 0.0:
        draw_rect(Rect2(Vector2.ZERO, size),Color(1.0,.82,.39,victory_glow*.22))
    # soft floor + ground shadows
    draw_ellipse(Vector2(w*.51,h*.82), Vector2(w*.48,h*.125), Color(0.08, .35, .32, .15))
    draw_ellipse(Vector2(w*.29,h*.79), Vector2(w*.14,h*.035), Color(0.06,.24,.26,.19))
    draw_ellipse(Vector2(w*.76,h*.77), Vector2(w*.15,h*.045), Color(0.06,.24,.26,.22))
    # bobbing companion pets behind the hero
    var allies: Array = [BIRD, FOX, TURTLE]
    var ally_x: Array = [.14, .20, .115]
    var ally_y: Array = [.51, .68, .79]
    for i in range(3):
        if unlocked_pets[i]:
            var dy: float = sin(clock * (2.3 + i*.2) + i*2) * 7.0
            var ps: float = w * .185
            draw_texture_rect(allies[i], Rect2(Vector2(w*ally_x[i]-ps*.5,h*ally_y[i]-ps*.5+dy),Vector2(ps,ps)), false)
    # hero animate forward for its attack
    var hsize: float = minf(w * .46, h * .50)
    var jump: float = sin(clock * 3.6) * 5.5
    var hx: float = w*.30 + attacking * w*.047 - enemy_attacking * w*.012
    var hy: float = h*.68 + jump - attacking*18
    draw_texture_rect(HERO, Rect2(Vector2(hx-hsize*.5,hy-hsize*.5),Vector2(hsize,hsize)), false, Color(1.0, 1.0 - hero_flash*.32, 1.0 - hero_flash*.32))

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
    var esize: float = minf(w * (.49 if enemy_is_boss else .42), h * .54)
    var ex: float = w*.76 - enemy_attacking*w*.037 + attacking*w*.019
    var ey: float = h*.66 + sin(clock*2.8+1.0)*6.0
    var mob: Texture2D = BOSS if enemy_is_boss else ([SLIME, RAIDER, GOLEM][enemy_kind%3])
    draw_texture_rect(mob,Rect2(Vector2(ex-esize*.5, ey-esize*.5),Vector2(esize,esize)),false, Color(1,1-enemy_flash*.32,1-enemy_flash*.32))

    if enemy_is_boss:
        var aura_radius: float = esize * (.45 + .025 * sin(clock * 4.0))
        draw_arc(Vector2(ex,ey),aura_radius,0,TAU,48,Color(.96,.31,.56,.45),6.0,true)
        for orb in range(3):
            var ang: float = clock * (.7 + orb * .11) + orb * TAU / 3
            draw_circle(Vector2(ex,ey) + Vector2(cos(ang),sin(ang)) * aura_radius,8.0,Color("ffab7d"))
    # attack slash (brief)

    if attacking > .43:
        draw_arc(Vector2(w*.62,h*.55),w*.17,-1.0,1.55,28,Color(1.0,.86,.49,.4*attacking),17.0,true)
        draw_arc(Vector2(w*.62,h*.55),w*.115,-.8,1.45,28,Color("fef9c6"),8.0,true)
        draw_line(Vector2(w*.57,h*.62),Vector2(w*.67,h*.49),Color("ffffff"),5.0,true)
    # hero and foe HP bars, drawn into the battle scene
    _bar(Vector2(w*.08,h*.88),Vector2(w*.36,15),hero_health,Color("55e2a4"))
    _bar(Vector2(w*.56,h*.88),Vector2(w*.36,15),enemy_health,Color("ffcf72") if enemy_is_boss else Color("fa7b9b"))
    for spark in sparks:
        var c: Color = spark["color"]
        c.a = minf(1.0, float(spark["life"]) * 2.2)
        draw_circle(spark["pos"], maxf(2.0, spark["life"] * 12.0), c)

func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
    var pts: PackedVector2Array = PackedVector2Array()
    for i in range(40):
        var a: float = float(i) * TAU / 40.0
        pts.append(center + Vector2(cos(a)*radii.x,sin(a)*radii.y))
    draw_colored_polygon(pts,color)

func _bar(pos: Vector2, dims: Vector2, fraction: float, fill: Color) -> void:
    draw_rect(Rect2(pos-Vector2(2,2),dims+Vector2(4,4)),Color("112937"))
    draw_rect(Rect2(pos,dims),Color("334955"))
    draw_rect(Rect2(pos,Vector2(dims.x*clampf(fraction,0.0,1.0),dims.y)),fill)
    draw_rect(Rect2(pos+Vector2(0,2),Vector2(dims.x*clampf(fraction,0.0,1.0),3)),Color(1,1,1,.18))

func victory_effect() -> void:
    victory_glow = 1.0
    for i in range(36):
        var angle: float = randf() * TAU
        sparks.append({"pos":Vector2(size.x*.74,size.y*.59),
            "velocity":Vector2(cos(angle),sin(angle))*randf_range(80.0,270.0),
            "life":randf_range(.35,1.0),"color":Color("ffe194")})
