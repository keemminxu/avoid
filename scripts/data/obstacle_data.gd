class_name ObstacleData
extends Resource
## 장애물 스폰 데이터 리소스.
## 스포너가 어떤 장애물을 어떤 확률/난이도에서 생성할지 결정할 때 사용한다.

## 장애물 씬 경로
@export var scene: PackedScene

## 스폰 확률 가중치 (높을수록 자주 등장)
@export var weight: float = 1.0

## 이 난이도 이상에서만 등장 (0 = 처음부터 등장)
@export var min_difficulty: int = 0
