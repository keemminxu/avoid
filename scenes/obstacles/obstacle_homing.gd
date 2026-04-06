class_name ObstacleHoming
extends Obstacle

## 플레이어 추적 화살 장애물
## 스폰 시 플레이어 위치를 향해 방향이 고정된다.
## 스폰 후에는 직선 이동만 하며, 유도탄이 아니다.
## 길이 40px, 너비 4px, 보라색

func _ready() -> void:
	arrow_length = 40.0
	arrow_width = 4.0
	arrow_color = Color(0.7, 0.2, 0.9)
	speed = 250.0
	super._ready()


func _draw() -> void:
	draw_rect(Rect2(-20, -2, 40, 4), arrow_color)
