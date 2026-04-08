class_name ObstacleHoming
extends Obstacle

## 플레이어 추적 에너미 함선 (노란색 복엽기)
## 스폰 시 플레이어 위치를 향해 방향이 고정된다.
## 스폰 후에는 직선 이동만 하며, 유도탄이 아니다.
## 비주얼은 .tscn 의 Sprite 가 담당.


func _ready() -> void:
	speed = 250.0
	super._ready()
