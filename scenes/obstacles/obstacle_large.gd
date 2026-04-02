class_name ObstacleLarge
extends Obstacle
## 크고 느린 장애물.
## 기본 장애물을 상속하며, 크기가 크고 속도가 느리다.


func _ready() -> void:
	speed = 120.0
	super._ready()
