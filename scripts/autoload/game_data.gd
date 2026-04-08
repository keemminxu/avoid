extends Node
## 게임 전역 데이터 싱글톤
## 씬 간 데이터 전달에 사용 (Autoload로 등록)

## 플레이어 닉네임
var player_nickname: String = ""

## 선택된 캐릭터 ID ("hodu" | "monggu")
## CharacterSelect 씬에서 저장되고, Player 씬의 Sprite2D 텍스처 결정에 사용된다.
var selected_character: String = "hodu"

## 캐릭터 ID → 텍스처 경로 매핑
const CHARACTER_TEXTURES: Dictionary = {
	"hodu": "res://assets/sprites/characters/hodu.png",
	"monggu": "res://assets/sprites/characters/monggu.png",
}

## 캐릭터 ID → 표시 이름 매핑
const CHARACTER_NAMES: Dictionary = {
	"hodu": "호두",
	"monggu": "몽구",
}


## 현재 선택된 캐릭터의 텍스처 경로를 반환한다.
## 매핑에 없으면 호두를 폴백으로 반환한다.
func get_character_texture_path() -> String:
	return CHARACTER_TEXTURES.get(selected_character, CHARACTER_TEXTURES["hodu"]) as String
