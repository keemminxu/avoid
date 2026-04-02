class_name CollisionHandler
extends Node

## 충돌 관리자
## 장애물(Area2D)과 플레이어(CharacterBody2D) 간의 충돌을 감지하고 처리한다.
## game.tscn의 자식 노드로 배치하여 사용.

# 플레이어가 장애물에 맞았을 때 발행되는 시그널
signal player_hit

# 플레이어 노드 참조 — game.tscn에서 에디터로 할당
@export var player: CharacterBody2D

# 게임 시작 시 무적 시간 (초)
@export var invincibility_duration: float = 2.0

# 현재 무적 상태 여부
var is_invincible: bool = false

# 무적 타이머
var _invincibility_timer: Timer


func _ready() -> void:
	_setup_invincibility_timer()


## 무적 상태를 활성화하고 타이머를 시작한다.
## 게임 시작 시 또는 외부에서 무적 상태가 필요할 때 호출.
func activate_invincibility() -> void:
	is_invincible = true
	_invincibility_timer.start(invincibility_duration)


## 장애물(Area2D)이 플레이어와 충돌했는지 확인하고 처리한다.
## 장애물 씬의 Area2D.body_entered 시그널에 연결하여 사용.
## 장애물 씬에서 직접 연결하거나, obstacle_spawner에서 스폰 시 연결한다.
func on_obstacle_body_entered(body: Node2D) -> void:
	# 플레이어가 아닌 노드는 무시
	if body != player:
		return

	# 무적 상태이면 무시
	if is_invincible:
		return

	player_hit.emit()


## 충돌 시스템을 초기화한다.
## 게임 재시작 시 호출. 무적 상태를 해제하고 타이머를 정지한다.
func reset() -> void:
	is_invincible = false
	_invincibility_timer.stop()


# 무적 타이머를 생성하고 설정한다.
func _setup_invincibility_timer() -> void:
	_invincibility_timer = Timer.new()
	_invincibility_timer.one_shot = true
	_invincibility_timer.timeout.connect(_on_invincibility_timeout)
	add_child(_invincibility_timer)


# 무적 시간이 끝났을 때 호출. 무적 상태를 해제한다.
func _on_invincibility_timeout() -> void:
	is_invincible = false
