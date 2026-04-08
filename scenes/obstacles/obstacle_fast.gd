class_name ObstacleFast
extends Obstacle

## 고속 에너미 함선 (작은 제트기)
## 기본 장애물보다 빠르게 이동한다. 비주얼은 .tscn 의 Sprite 가 담당.


func _ready() -> void:
	speed = 400.0
	super._ready()
