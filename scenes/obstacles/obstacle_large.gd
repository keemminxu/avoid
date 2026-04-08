class_name ObstacleLarge
extends Obstacle

## 대형 에너미 함선 (전함)
## 기본 장애물보다 크고 느리게 이동한다. 비주얼은 .tscn 의 Sprite 가 담당.


func _ready() -> void:
	speed = 120.0
	super._ready()
