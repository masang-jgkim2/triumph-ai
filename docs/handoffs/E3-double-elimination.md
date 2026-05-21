# Handoff: E3 더블 엘리미네이션

**상태:** in_progress (UI/UX·FE 착수 — QA DB 반영 완료)  
**기획 확정일:** —  
**format:** `events.format = 1`  
**DB 참고:** [repos/db/README.md](../../repos/db/README.md)

---

## 목표

통합 스키마(`bracket_groups.bracket_type`, `brackets.next_*_bracket_id`)와 **DE SP**(`sp_bracket_de_*`)를 QA에 반영하고, API·WS·FE가 `format=1` 이벤트에서 **싱글과 동등한 end-to-end** 플로우(생성 → 대진 → 판정 → 실시간)를 제공한다.

---

## DB·SQL 산출물 (이미 `repos/db`)

| 순서 | 파일 | 내용 |
|------|------|------|
| 0 | `triumph_schema_qa_20260521.sql` | QA 스냅샷·diff 기준 |
| 1 | `unified_tournament_table_migration.sql` | STEP 1~6 DDL |
| 2 | `unified_tournament_se_proc.sql` | SE 통합 SP |
| 3 | `unified_tournament_de_proc.sql` | DE SP 7종+ |

### DE SP 목록 (BE 구현·API 매핑 대상)

| SP | 용도 |
|----|------|
| `sp_bracket_de_insert` | DE 뼈대(WB/LB/GF groups + brackets + 라우팅) |
| `sp_bracket_de_entries_insert` | 참가자 시드 배정 |
| `sp_bracket_de_adjudge` | 판정·진출 |
| `sp_bracket_de_score_auto` | 자동 스코어 |
| `sp_bracket_de_adjudge_auto` | 자동 판정 루프 |
| `sp_bracket_de_reset` | 대진 리셋 |
| `sp_bracket_de_participant_insert` | 참가자 등록(테스트/운영 보조) |

### 통합 스키마 핵심 (기획·FE·BE 공통)

- `bracket_groups.bracket_type`: `DE_WB`, `DE_LB`, `DE_GF` (+ `SE`, `FFA`)
- `brackets.group_id` FK, `next_winner_bracket_id`, `next_loser_bracket_id`
- 레거시: API 코드는 아직 `sp_bracket_single_insert` + `event_id`/`depth` 중심 → **교체·분기 필요**

---

## 에이전트별 작업 목록

### 1. 기획/아키텍처 (`@planning-architecture`)

| # | 업무 | 산출물 |
|---|------|--------|
| 1 | E3 Handoff `ready` 승인 (본 문서 갱신) | API 표·완료 조건 확정 |
| 2 | `format=0` vs `1` 기능 매트릭스 (생성·대진·판정·3/4위·리셋) | HANDOFF §비즈니스 규칙 |
| 3 | DE 인원 규칙 (4/8/16/32/64/128) · BO 포인트 CSV · GF 리셋 규칙 문서화 | `repos/db` SP 주석과 정합 |
| 4 | API 계약: 기존 Moderator/Bracket REST → **통합 SP** 매핑표 | Method/Path/파라미터 |
| 5 | WS 이벤트: `format=1` 시 payload·room·bracket_id 규칙 | service-map 보강 |
| 6 | QA 시나리오·회귀(싱글 이벤트 비깨짐) 체크리스트 | 완료 조건 § |
| 7 | UI/UX·FE에 넘길 화면 목록 (WB/LB 탭·라운드 라벨) | P1 브라켓·관리 |

**하지 말 것:** SP/SQL 직접 수정, 대량 코드

---

### 2. UI/UX (`@ui-ux`)

| # | 업무 | 화면·산출물 |
|---|------|-------------|
| 1 | 이벤트 생성/관리 — `format=1` 선택 시 안내·제약(인원·match34) | `EventCreateCompetitionInfo`, `EventManageCompeitionInfo` |
| 2 | 대진표 — **WB / LB / GF** 구역·라운드 칩 네이밍 (`DE_WB` 등) | `BracketContainer`, 모바일 slide-group |
| 3 | 패자부 진출·그랜드 파이널 상태 라벨 | `BracketStatusLabel`, i18n `ko.json` |
| 4 | `MakeBracketDialog` — DE 생성 플로우 와이어 | 관리 P2 |
| 5 | `design-system.md` § E3 브라켓 (토큰만, 로직 X) | 기획 검토용 |
| 6 | 「UI/UX 검토 요청」→ 기획 → FE Handoff | — |

**참고:** E2 P0(로그인·생성 폼)와 충돌 없이 **브라켓·DE 라벨만**  
**하지 말 것:** `Bracket.js`, API/SP

---

### 3. 구현 · BE (`@be-dev`) — DB 포함

| # | 업무 | repo·참고 |
|---|------|-----------|
| **DB** |
| 1 | QA: `unified_tournament_table_migration.sql` 적용·V6/V7 검증 | `repos/db` |
| 2 | QA: `unified_tournament_se_proc.sql` (싱글 회귀) | |
| 3 | QA: `unified_tournament_de_proc.sql` | E3 |
| **API** |
| 4 | `BracketsRepository` — `format` 분기: `sp_bracket_single_insert` vs `sp_bracket_de_insert` | apiserver |
| 5 | 엔트리 배정·판정·리셋 Controller → `sp_bracket_de_*` 연동 | Moderator/*Bracket* |
| 6 | `GET event/{id}/bracket` 응답 — `group_id`, `bracket_type`, `next_*_bracket_id` 반영 | FE 소비 필드 확정 |
| 7 | 이벤트 `format` 검증(생성/수정) | EventsRepository |
| **WS** |
| 8 | `bracket` module — DE 판정 후 emit·room `bracket_type` 처리 | websocket |
| 9 | Prisma `db pull` + `generate` (DDL 후) | |
| **검증** |
| 10 | BE 완료 보고 (SP·API·FE 연동 메모) | |

**현재 갭:** 코드는 레거시 `sp_bracket_single_insert` only — **통합 SP 미연동**

**하지 말 것:** triumphserver UI, `env*` 커밋

---

### 4. 구현 · FE (`@fe-dev`)

| # | 업무 | 파일·영역 |
|---|------|-----------|
| 1 | Handoff·BE API 확정 후 `DTO/bracket.js`, `store/bracket.js` | group_id, bracket_type |
| 2 | `BracketContainer` / `RoundContainer` — `format===1` 시 WB·LB·GF 컬럼/탭 | P1 `/event/.../bracket` |
| 3 | `DoubleEliminationBracket` 또는 API 트리 전용 렌더 (기획 확정) | `class/Bracket.js` |
| 4 | `MakeBracketDialog` — DE 생성 API 호출 | 관리 |
| 5 | 판정·리셋 UI → 통합 API | `BracketMatchInfo`, socket |
| 6 | i18n·`EventFormatCard` 등 라벨 정합 | 이미 `defs.double_elimination` |
| 7 | `format=0` 회귀 테스트 | — |
| 8 | FE 완료 보고 | |

**선행:** BE §6 응답 스펙 + UI/UX 와이어  
**하지 말 것:** apiserver/websocket repo

---

### 5. 배포 깃 (규칙·playbook)

| # | 업무 |
|---|------|
| 1 | QA DB 백업 → migration → SE proc → DE proc |
| 2 | push: `global-apiserver`(qa) → `global-renewal-websocket`(release/*) → `global-triumphserver`(qa) |
| 3 | 스모크: `format=1` 이벤트 생성·`sp_bracket_de_insert`·판정·WS·FE 대진표 |
| 4 | Live: DB 백업 후 동일 순서 (`db-deployment.md`) |

**하지 말 것:** 기능·스펙 구현

---

## 권장 실행 순서

```text
기획: 본 Handoff ready + API 매핑표
  → UI/UX: DE 브라켓·생성 UI 스펙
  → BE: repos/db SQL QA 적용 → API·WS
  → FE: 연동·브라켓 UI
  → 배포 깃: QA → 통합 QA
```

---

## 완료 조건 (QA 초안)

1. QA DB에 통합 migration + DE SP 존재
2. `format=1` 이벤트: 대진 생성·시드·판정·리셋 E2E
3. `format=0` 싱글 이벤트 회귀 통과
4. FE: WB/LB(및 GF) 구역 표시·라운드 네비 동작
5. WS: 판정 후 클라이언트 상태 동기화

---

## 의존·블로커

| 항목 | 상태 |
|------|------|
| E3 Handoff ready | draft |
| `repos/db` SQL | **있음** |
| API `.env` (로컬/QA DB) | 팀 제공 |
| E2 P0 DS | 병렬 가능 (브라켓 리스킨 X) |

---

## 배포 메모 (배포 깃용)

- repo + branch: API `qa`, WS `release/*`, FE `qa`
- DB 먼저: **Y** — `repos/db` 순서 준수
