class_name ObstacleFast
extends Obstacle
## 빠른 소형 장애물.
## 기본 장애물을 상속하며, 크기가 작고 속도가 빠르다.


func _ready() -> void:
	speed = 400.0
	super._ready()
