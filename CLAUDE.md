# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"죽림고수(Avoid)" — Godot 4.4 기반 2D 캐주얼 멀티플레이어 회피 게임.
2000년대 플래시 게임 "죽림고수"를 오마주한 프로젝트로, 사방에서 날아오는 장애물을 피해 최대한 오래 생존하는 게임.

### 핵심 특징
- **멀티플레이어**: 지역 기반 서버 매칭 (slither.io 방식), 서버에서 장애물 스폰
- **DB 연동**: 점수 저장 및 랭킹 시스템
- **점진적 난이도**: 시간 경과에 따라 장애물 빈도/속도 증가

## Tech Stack

- **Engine**: Godot 4.4 (Mobile renderer)
- **Language**: GDScript
- **Platform Target**: 2D, Casual
- **Version Control**: Git (godot-git-plugin v3.1.1)
- **Server/DB**: TBD (스펙 확정 시 업데이트)

## Project Structure

```
avoid/             # 게임 클라이언트 소스 (개발 진행 중)
first.tscn         # 메인 씬 (Node2D root + Timer 노드들)
first_script.gd    # 메인 스크립트 (테스트용, 리팩토링 예정)
project.godot      # Godot 프로젝트 설정
```

## Input Mappings

| Action | Key |
|--------|-----|
| `move_right` | Arrow Right |
| `move_left` | Arrow Left |
| `move_up` | Arrow Up |
| `move_down` | Arrow Down |

## Development Commands

```bash
# Godot CLI (godot가 PATH에 있을 때)
godot --editor         # 에디터 열기
godot --path .         # 프로젝트 실행
godot --export-debug   # 디버그 빌드 내보내기
```

## Conventions

- GDScript 코드는 Godot 공식 스타일 가이드를 따름 (snake_case 함수/변수, PascalCase 클래스)
- 씬 파일(.tscn)은 기능 단위로 분리
- 네트워크 코드는 Godot의 MultiplayerAPI/ENet 또는 WebSocket 기반으로 구현 예정
- 커밋 메시지는 한국어 또는 영어, 변경 의도를 명확히 기술
- **커밋 시 Co-Authored-By에 Claude를 절대 포함하지 않는다** — AI co-author 라인 금지
