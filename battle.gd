extends Control
# Procedural arena art; no external textures required.
var t: float = 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
    t += delta
    queue_redraw()

func _draw() -> void:
    var w: float = size.x
    var h: float = size.y
    if w < 10 or h < 10:
        return
    var boss: bool = int(get_parent().get_parent().get_parent().game["stage"]) % 5 == 0
    draw_rect(Rect2(Vector2.ZERO, size), Color("#173f50"))
    draw_circle(Vector2(w * 0.85,h * 0.18), h * 0.21, Color("#376777"))
    draw_circle(Vector2(w * 0.85,h * 0.18), h * 0.15, Color("#5a8b8a"))
    for i in range(7):
        var xx := float(i) / 6.0 * w
        draw_colored_polygon(PackedVector2Array([Vector2(xx - 130, h * 0.68),Vector2(xx + 30,h * (0.22 + 0.1 * sin(float(i) * 3.1))),Vector2(xx + 160, h * 0.68)]),Color("#235965"))
    draw_rect(Rect2(0,h * 0.68,w,h * 0.32),Color("#294d45"))
    for j in range(9):
        var px := float(j) * w / 8.0
        draw_circle(Vector2(px,h * 0.81 + sin(float(j)) * 11),8,Color("#447461"))
    var bob := sin(t * 3.4) * 6.0
    var hx := w * 0.31
    var hy := h * 0.62 + bob
    _dino(Vector2(hx,hy),minf(w,h) * 0.24,Color("#74d68c"))
    var ex := w * 0.75
    var ey := h * 0.63 + sin(t * 2.6) * 5.0
    _monster(Vector2(ex,ey), minf(w,h) * (0.30 if boss else 0.23), boss)
    var root: Control = get_parent().get_parent().get_parent()
    var hero_ratio: float = clampf(root.hero_hp / root._max_hp(),0.0,1.0)
    var enemy_ratio: float = clampf(root.enemy_hp / root.enemy_max,0.0,1.0)
    _bar(Vector2(w * 0.09,h * 0.89),w * 0.34,hero_ratio,Color("#7be8a1"))
    _bar(Vector2(w * 0.57,h * 0.89),w * 0.34,enemy_ratio,Color("#f6a178"))

func _bar(p:Vector2, width:float, amount:float, hue:Color) -> void:
    draw_rect(Rect2(p,Vector2(width,17)),Color("#132831"))
    draw_rect(Rect2(p + Vector2(2,2),Vector2((width - 4) * amount,13)),hue)

func _dino(center:Vector2, radius:float, col:Color) -> void:
    draw_circle(center + Vector2(-radius * 0.12,radius * 0.16),radius * 0.72,Color("#3b9e73"))
    draw_colored_polygon(PackedVector2Array([center + Vector2(-radius * 0.3,radius * 0.2),center + Vector2(-radius * 1.15,radius * 0.55),center + Vector2(-radius * 0.65,-radius * 0.13)]),Color("#3b9e73"))
    draw_circle(center + Vector2(radius * 0.30,-radius * 0.34),radius * 0.72,col)
    draw_circle(center + Vector2(radius * 0.55,-radius * 0.44),radius * 0.10,Color("#112a32"))
    draw_circle(center + Vector2(radius * 0.61,-radius * 0.48),radius * 0.027,Color.WHITE)
    draw_colored_polygon(PackedVector2Array([center + Vector2(-radius * 0.36,-radius * 0.44),center + Vector2(-radius * 0.13,-radius * 1.10),center + Vector2(radius * 0.1,-radius * 0.53)]),Color("#eddb8b"))
    draw_line(center + Vector2(radius * 0.48,-radius * 0.05),center + Vector2(radius * 0.94,radius * 0.05),Color("#215b56"),5.0)
    draw_circle(center + Vector2(-radius * 0.25,radius * 0.77),radius * 0.15,col)
    draw_circle(center + Vector2(radius * 0.34,radius * 0.75),radius * 0.15,col)
    draw_circle(center + Vector2(radius * 0.54,radius * 0.19),radius * 0.20,col)

func _monster(center:Vector2, radius:float, boss:bool) -> void:
    var c := Color("#dc819b") if boss else Color("#9e94dd")
    draw_circle(center + Vector2(0,radius * 0.10),radius * 0.78,c)
    draw_circle(center + Vector2(-radius * 0.29,-radius * 0.2),radius * 0.27,c.lightened(0.15))
    draw_circle(center + Vector2(radius * 0.30,-radius * 0.2),radius * 0.27,c.lightened(0.15))
    draw_circle(center + Vector2(-radius * 0.26,-radius * 0.10),radius * 0.10,Color("#142b36"))
    draw_circle(center + Vector2(radius * 0.26,-radius * 0.10),radius * 0.10,Color("#142b36"))
    draw_arc(center + Vector2(0,radius * 0.20),radius * 0.26,0.12,PI - 0.12,16,Color("#543b5c"),5.0)
    if boss:
        draw_colored_polygon(PackedVector2Array([center + Vector2(-radius * 0.65,-radius * 0.45),center + Vector2(-radius * 0.68,-radius * 1.12),center + Vector2(-radius * 0.15,-radius * 0.65)]),Color("#f0b76b"))
        draw_colored_polygon(PackedVector2Array([center + Vector2(radius * 0.65,-radius * 0.45),center + Vector2(radius * 0.68,-radius * 1.12),center + Vector2(radius * 0.15,-radius * 0.65)]),Color("#f0b76b"))
