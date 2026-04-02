class_name DifficultyManager
extends Node

## 시간 기반 난이도 관리자
## 경과 시간에 따라 난이도를 자동으로 조절하며, 스폰 간격/속도/사용 가능한 장애물 종류를 결정한다.

# 난이도 변경 시 발행되는 시그널 (새로운 레벨 전달)
signal difficulty_changed(level: int)

# 현재 난이도 레벨 (1~5)
var current_level: int = 1

# 게임 시작 후 경과 시간 (초)
var elapsed_time: float = 0.0

# 난이도 시스템 활성화 여부
var _active: bool = false

# 난이도 테이블: 각 레벨별 설정
# threshold_sec: 해당 레벨로 진입하는 경과 시간
# spawn_interval: 장애물 스폰 간격 (초)
# speed_multiplier: 장애물 속도 배율
# available_obstacle_indices: 사용 가능한 장애물 인덱스 목록
var DIFFICULTY_TABLE: Array[Dictionary] = [
	{
		"level": 1,
		"threshold_sec": 0.0,
		"spawn_interval": 1.2,
		"speed_multiplier": 1.0,
		"available_obstacle_indices": [0],
	},
	{
		"level": 2,
		"threshold_sec": 15.0,
		"spawn_interval": 1.0,
		"speed_multiplier": 1.0,
		"available_obstacle_indices": [0, 1],
	},
	{
		"level": 3,
		"threshold_sec": 30.0,
		"spawn_interval": 0.8,
		"speed_multiplier": 1.0,
		"available_obstacle_indices": [0, 1, 2],
	},
	{
		"level": 4,
		"threshold_sec": 60.0,
		"spawn_interval": 0.6,
		"speed_multiplier": 1.0,
		"available_obstacle_indices": [0, 1, 2, 3],
	},
	{
		"level": 5,
		"threshold_sec": 90.0,
		"spawn_interval": 0.4,
		"speed_multiplier": 1.3,
		"available_obstacle_indices": [0, 1, 2, 3],
	},
]


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	if not _active:
		return

	elapsed_time += delta
	_evaluate_level()


## 난이도 시스템을 시작한다. _process가 활성화되고 시간 측정이 시작됨.
func start() -> void:
	_active = true
	set_process(true)


## 난이도 시스템을 정지한다. 시간 측정이 멈추지만 상태는 유지됨.
func stop() -> void:
	_active = false
	set_process(false)


## 난이도를 초기 상태로 되돌린다.
func reset() -> void:
	_active = false
	set_process(false)
	elapsed_time = 0.0
	current_level = 1


## 현재 난이도에 맞는 스폰 간격(초)을 반환한다.
func get_spawn_interval() -> float:
	var entry := _get_current_entry()
	return entry["spawn_interval"] as float


## 현재 난이도에 맞는 장애물 속도 배율을 반환한다.
func get_speed_multiplier() -> float:
	var entry := _get_current_entry()
	return entry["speed_multiplier"] as float


## 현재 난이도에서 스폰 가능한 장애물 인덱스 배열을 반환한다.
## obstacle_spawner.gd의 obstacle_scenes 배열 인덱스에 대응.
func get_available_obstacles() -> Array:
	var entry := _get_current_entry()
	return entry["available_obstacle_indices"] as Array


# 경과 시간에 따라 레벨을 판정하고, 변경 시 시그널을 발행한다.
func _evaluate_level() -> void:
	var new_level: int = 1

	# 테이블을 역순으로 탐색하여 threshold를 만족하는 최고 레벨을 찾는다
	for i in range(DIFFICULTY_TABLE.size() - 1, -1, -1):
		var entry: Dictionary = DIFFICULTY_TABLE[i]
		if elapsed_time >= entry["threshold_sec"] as float:
			new_level = entry["level"] as int
			break

	if new_level != current_level:
		current_level = new_level
		difficulty_changed.emit(current_level)


# 현재 레벨에 해당하는 테이블 엔트리를 반환한다.
func _get_current_entry() -> Dictionary:
	for entry in DIFFICULTY_TABLE:
		if entry["level"] as int == current_level:
			return entry
	# 폴백: 레벨 1
	return DIFFICULTY_TABLE[0]
