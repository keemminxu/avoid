class_name ObstacleLarge
extends Obstacle

## 크고 느린 화살 장애물
## 기본 장애물보다 크기가 크고 속도가 느리다.
## 길이 80px, 너비 8px, 진한 빨간색

func _ready() -> void:
	arrow_length = 80.0
	arrow_width = 8.0
	arrow_color = Color(0.8, 0.2, 0.2)
	speed = 120.0

	# CollisionShape 크기를 화살 크기에 맞게 조정
	var collision_shape := $CollisionShape2D as CollisionShape2D
	if collision_shape and collision_shape.shape is RectangleShape2D:
		(collision_shape.shape as RectangleShape2D).size = Vector2(80, 8)

	super._ready()


func _draw() -> void:
	draw_rect(Rect2(-40, -4, 80, 8), arrow_color)
