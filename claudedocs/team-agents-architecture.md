# Team Agent Architecture — 죽림고수(Avoid)

## Agent Team Overview

프로젝트의 3계층(Client / Server / DB)에 맞춰 5개 에이전트 + 1 오케스트레이터로 구성.

```mermaid
graph TB
    subgraph Orchestrator["🎯 Orchestrator (Main Claude)"]
        direction TB
        O[Task Router & Coordinator]
    end

    subgraph ClientTeam["🎮 Client Layer"]
        A1["🎨 Game Client Agent<br/>─────────────<br/>Godot 4.4 / GDScript<br/>씬 구성, 플레이어 이동<br/>장애물 렌더링, UI/UX"]
        A2["🖼️ Asset & Scene Agent<br/>─────────────<br/>씬 트리 설계<br/>스프라이트/애니메이션<br/>타일맵, 이펙트"]
    end

    subgraph ServerTeam["🌐 Server Layer"]
        A3["⚡ Network Agent<br/>─────────────<br/>MultiplayerAPI/WebSocket<br/>서버-클라 동기화<br/>지역 매칭 로직"]
        A4["🛡️ Game Logic Agent<br/>─────────────<br/>장애물 스폰 로직<br/>난이도 시스템<br/>충돌 판정, 점수 계산"]
    end

    subgraph DBTeam["💾 DB Layer"]
        A5["🗄️ DB & Ranking Agent<br/>─────────────<br/>점수 저장 API<br/>랭킹 시스템<br/>유저 데이터 관리"]
    end

    O -->|"씬/스크립트 작업"| A1
    O -->|"에셋/씬트리 작업"| A2
    O -->|"네트워크 구현"| A3
    O -->|"게임 로직 구현"| A4
    O -->|"DB 스키마/API"| A5

    A1 <-->|"씬 참조"| A2
    A3 <-->|"동기화 프로토콜"| A4
    A4 -->|"점수 기록"| A5
    A1 <-->|"클라 네트워크"| A3

    style Orchestrator fill:#1a1a2e,stroke:#e94560,color:#fff
    style ClientTeam fill:#16213e,stroke:#0f3460,color:#fff
    style ServerTeam fill:#1a1a2e,stroke:#533483,color:#fff
    style DBTeam fill:#0f3460,stroke:#e94560,color:#fff
```

## Agent 상세 역할

### 🎯 Orchestrator (Main Claude Session)
| 항목 | 내용 |
|------|------|
| **역할** | 전체 작업 분배, 의존성 관리, 병합 조율 |
| **도구** | Agent tool, TodoWrite, Git |
| **판단 기준** | 작업 복잡도, 의존성 그래프, 충돌 위험도 |

### 🎨 Agent 1: Game Client
| 항목 | 내용 |
|------|------|
| **담당** | 플레이어 캐릭터, 입력 처리, 게임 씬 |
| **subagent_type** | `frontend-architect` |
| **파일 범위** | `*.gd`, `*.tscn` (메인 게임 씬) |
| **의존성** | Asset Agent 씬 구조, Network Agent 동기화 |

### 🖼️ Agent 2: Asset & Scene
| 항목 | 내용 |
|------|------|
| **담당** | 씬 트리 설계, 노드 구조, 리소스 관리 |
| **subagent_type** | `system-architect` |
| **파일 범위** | `*.tscn`, `*.tres`, 리소스 파일 |
| **의존성** | 독립적 (다른 에이전트에 씬 구조 제공) |

### ⚡ Agent 3: Network
| 항목 | 내용 |
|------|------|
| **담당** | 서버-클라이언트 통신, 매칭, 동기화 |
| **subagent_type** | `backend-architect` |
| **파일 범위** | `network/`, `multiplayer/` |
| **의존성** | Game Logic Agent 프로토콜 정의 |

### 🛡️ Agent 4: Game Logic
| 항목 | 내용 |
|------|------|
| **담당** | 장애물 스폰, 난이도, 충돌, 점수 |
| **subagent_type** | `backend-architect` |
| **파일 범위** | `game_logic/`, `obstacles/` |
| **의존성** | Network Agent (서버사이드), DB Agent (점수) |

### 🗄️ Agent 5: DB & Ranking
| 항목 | 내용 |
|------|------|
| **담당** | 점수 저장, 랭킹 조회, 유저 관리 |
| **subagent_type** | `backend-architect` |
| **파일 범위** | `database/`, `api/` |
| **의존성** | Game Logic Agent 점수 데이터 |

## 병렬 실행 전략

### Phase 1: 기반 구축 (병렬)
```
┌─ Agent 1: 플레이어 이동 + 기본 씬 ─────────┐
├─ Agent 2: 씬 트리 + 장애물 씬 설계 ─────────┤  ← 동시 실행
├─ Agent 4: 장애물 스폰 로직 (싱글) ───────────┤
└─ Agent 5: DB 스키마 설계 ────────────────────┘
```

### Phase 2: 통합 (순차 의존)
```
Agent 3: 네트워크 계층 구현
  ← Agent 1 결과 (클라 구조)
  ← Agent 4 결과 (서버 로직)
```

### Phase 3: 연동 (병렬)
```
┌─ Agent 1+3: 클라-서버 연동 테스트 ───────────┐
└─ Agent 4+5: 게임로직-DB 연동 ────────────────┘
```

## Worktree 전략

| Agent | Isolation | 이유 |
|-------|-----------|------|
| Game Client | worktree | 메인 씬 직접 수정 → 충돌 방지 |
| Asset & Scene | worktree | .tscn 파일 동시 수정 위험 |
| Network | worktree | 새 디렉토리 생성, 독립 작업 |
| Game Logic | worktree | 새 디렉토리 생성, 독립 작업 |
| DB & Ranking | worktree | 완전 독립 계층 |
