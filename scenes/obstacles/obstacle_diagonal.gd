class_name ObstacleDiagonal
extends Obstacle
## 대각선 이동 장애물.
## 기본 장애물을 상속하며, 대각선 방향으로 이동한다.


func _ready() -> void:
	speed = 250.0
	direction = Vector2(1, 1).normalized()
	super._ready()
