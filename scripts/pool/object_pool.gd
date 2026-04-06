class_name ObjectPool
extends Node

## 범용 오브젝트 풀
## PackedScene을 미리 인스턴스화하여 재사용함으로써
## instantiate/queue_free 반복에 의한 성능 저하를 방지한다.

## 풀링할 씬
@export var pool_scene: PackedScene

## 초기 생성 수 (프리웜)
@export var initial_size: int = 50

## 최대 풀 크기
@export var max_size: int = 200

## 오브젝트가 추가될 부모 노드
@export var container: Node2D

## 비활성 오브젝트 배열
var _available: Array[Node] = []

## 활성 오브젝트 수
var _active_count: int = 0


func _ready() -> void:
	_prewarm()


## 초기 오브젝트를 미리 생성하여 풀에 넣는다.
func _prewarm() -> void:
	for i in initial_size:
		var obj := _create_instance()
		_deactivate(obj)


## 풀에서 비활성 오브젝트를 하나 꺼내 활성화하여 반환한다.
## 비활성 오브젝트가 없으면 max_size 까지 새로 생성한다.
## max_size에 도달하면 null을 반환한다.
func get_object() -> Node:
	var obj: Node = null

	if _available.size() > 0:
		obj = _available.pop_back()
	elif _active_count + _available.size() < max_size:
		obj = _create_instance()
	else:
		push_warning("ObjectPool: 최대 풀 크기(%d)에 도달하여 오브젝트를 생성할 수 없습니다." % max_size)
		return null

	_activate(obj)
	_active_count += 1
	return obj


## 오브젝트를 비활성화하고 풀에 반환한다.
func release(obj: Node) -> void:
	if not is_instance_valid(obj):
		return

	_deactivate(obj)
	_active_count -= 1

	if not _available.has(obj):
		_available.append(obj)


## 모든 활성 오브젝트를 비활성화하고 풀에 반환한다.
## container의 자식 중 비활성 상태가 아닌 것들을 모두 반환한다.
func release_all() -> void:
	if not container:
		return

	for child in container.get_children():
		if child.visible:
			release(child)


## 씬 인스턴스를 생성하고 container에 add_child한 뒤 비활성 상태로 설정한다.
func _create_instance() -> Node:
	var obj := pool_scene.instantiate()

	if container:
		container.add_child(obj)

	return obj


## 오브젝트를 활성 상태로 전환한다.
func _activate(obj: Node) -> void:
	obj.visible = true
	obj.set_process(true)
	obj.set_physics_process(true)

	# Area2D인 경우 충돌 감지 활성화
	if obj is Area2D:
		(obj as Area2D).monitoring = true
		(obj as Area2D).monitorable = true


## 오브젝트를 비활성 상태로 전환한다.
func _deactivate(obj: Node) -> void:
	obj.visible = false
	obj.set_process(false)
	obj.set_physics_process(false)

	# Area2D인 경우 충돌 감지 비활성화
	if obj is Area2D:
		(obj as Area2D).monitoring = false
		(obj as Area2D).monitorable = false

	# 화면 밖으로 이동
	if obj is Node2D:
		(obj as Node2D).position = Vector2(-9999, -9999)
