class_name ObstacleFast
extends Obstacle

## 빠르고 작은 화살 장애물
## 기본 장애물보다 크기가 작고 속도가 빠르다.
## 길이 24px, 너비 3px, 주황색

func _ready() -> void:
	arrow_length = 24.0
	arrow_width = 3.0
	arrow_color = Color(1.0, 0.6, 0.0)
	speed = 400.0

	# CollisionShape 크기를 화살 크기에 맞게 조정
	var collision_shape := $CollisionShape2D as CollisionShape2D
	if collision_shape and collision_shape.shape is RectangleShape2D:
		(collision_shape.shape as RectangleShape2D).size = Vector2(24, 3)

	super._ready()


func _draw() -> void:
	draw_rect(Rect2(-12, -1.5, 24, 3), arrow_color)
