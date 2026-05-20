# Triumph — 에이전트 역할 · 핸드오프

> 로컬 메타 저장소 `triumph_ai` 기준. 코드·배포는 **각 서비스 repo**에서만 진행.  
> 상세 배포: [deployment-playbook.md](./deployment-playbook.md) · DB: [db-deployment.md](./db-deployment.md) · 연동: [service-map.md](./service-map.md)

### Cursor 세션

탭 이름 · `@에이전트` · 새 채팅 방법 → **[AGENTS.md](../AGENTS.md)** (여기서 표 중복 없음)

UI/UX 검토 예시: [handoffs/E2-design-system.md](./handoffs/E2-design-system.md) → 기획 탭에「검토 요청」붙여넣기

---

## 1. 역할 분리 (한눈에)

| 역할 | 담당 | 주 repo / 산출물 |
|------|------|------------------|
| **기획/아키텍처** | 에픽 순서, 형식 규칙, API·DB 계약, repo 의존, QA 범위, 핸드오프 작성 | `triumph_ai/docs/` |
| **UI/UX** | 디자인 시스템, 토큰, 컴포넌트 스펙, 화면·와이어, i18n 문구 | `global-triumphserver` (+ Figma) |
| **구현 · 프론트** | Vue, Pinia, 브라켓 UI, API·Socket 연동 | `global-triumphserver` |
| **구현 · 백엔드** | Laravel API, MySQL SP, Prisma/WS 실시간 | `global-apiserver`, `global-renewal-websocket` |
| **배포 깃** | QA/Live, push 순서, env, DB, 파이프라인 | [db-deployment.md](./db-deployment.md), playbook — 기능 구현 X |

**DB** 변경은 보통 **백엔드 구현**에 포함. 스키마·형식 값(`events.format`) 변경은 **기획/아키텍처**에서 먼저 확정.

---

## 2. 저장소 · 로컬 URL

→ 상세(아키텍처·env·기동 순서): [service-map.md](./service-map.md) · 명령: [local-dev.md](./local-dev.md)

| Repo | 로컬 URL |
|------|----------|
| global-triumphserver | :3100 |
| global-apiserver | :8000 |
| global-renewal-websocket | :9603 |

---

## 3. 기능 단위 권장 순서

```text
기획/아키텍처 (스펙·계약 확정)
    → UI/UX (해당 화면만 — 전역 리스킨은 마지막)
    → 백엔드 (DB/SP → API → WS 필요 시)
    → 프론트 (연동·브라켓·관리 화면)
    → 배포 (QA → 통합 QA → Live)
```

**배포 순서 (코드+DB):** QA DB → API(qa) → WS(release/*) → FE(qa) → Live  
→ [deployment-playbook.md §4-6](./deployment-playbook.md)

---

## 4. 현재 제품 맥락 (참고)

| `events.format` | 의미 | 구현 상태 (2026-05) |
|-----------------|------|---------------------|
| `0` | 싱글 엘리미네이션 | 운영 중 (`sp_bracket_single_insert` 등) |
| `1` | 더블 엘리미네이션 | UI·메시지 일부, SP/브라켓 로직 미완 |
| `2` | 풀 리그 | UI 라벨만 — **포인트제와 규칙 매핑은 기획에서 확정** |

**에픽 우선순위 (권장):** E0 스펙 → E1 싱글 안정화 → E2 DS(기능 화면만) → E3 더블 → E4 포인트제 → E5 DS 전역 적용

---

## 5. 에이전트별 하지 말 것

| 역할 | 금지 |
|------|------|
| 기획/아키텍처 | 대량 코드 수정, 배포 push |
| UI/UX | API/SP 변경, 전 페이지 일괄 리스킨(기능 PR과 충돌) |
| 프론트 | `global-apiserver` / websocket repo 커밋 |
| 백엔드 | triumphserver UI 전역 리스킨 |
| 배포 깃 | 기능 구현, 스펙 변경 |

**절대 Git 커밋 금지:** `triumph_ai/env`, `env.qa`, `env.production` (비밀키 포함)

---

## 6. 핸드오프 템플릿 (복사용)

새 작업 시작 시 기획/아키텍처 채팅에서 아래를 채워 각 에이전트에 전달.

```markdown
## Handoff: [에픽 ID] [제목]

**상태:** draft | ready | in QA | done  
**기획 확정일:** YYYY-MM-DD

### 목표
- (한 줄)

### 범위
- [ ] DB / SP
- [ ] API (global-apiserver)
- [ ] WebSocket (global-renewal-websocket)
- [ ] FE (global-triumphserver)
- [ ] UI/UX (Figma / 토큰 / 컴포넌트만)

### 비즈니스 규칙 (필수)
- format 값:
- 인원·라운드·3/4위전(match34):
- 판정·리셋·알림:

### API 계약 (요약)
| Method | Path | 비고 |
|--------|------|------|
| | | |

### DB
- SP / 테이블:
- QA 적용 여부:

### UI/UX
- 화면:
- DS 적용 범위: (예: BracketContainer만 / 전역 X)
- i18n 키:

### FE
- 주요 파일:
- store / class:

### 완료 조건 (QA)
1.
2.

### 의존
- 선행 Handoff:
- 블로커:

### 배포 메모 (배포 깃 세션용)
- repo + branch:
- DB 먼저: Y/N
```

---

## 7. 작업 예시 (에픽 ID)

| ID | 제목 | UI/UX | BE | FE | 배포 깃 |
|----|------|-------|----|----|------|
| E0 | 스펙·API 계약 | — | 검토 | 검토 | — |
| E1 | 싱글 엘리미네이션 안정화 | 최소 | SP/버그 | 브라켓·판정 | QA 회귀 |
| E2 | 디자인 시스템 (기능 화면) | **ready** — [E2-design-system.md](./handoffs/E2-design-system.md) | — | P0 적용 | FE만 |
| E3 | 더블 엘리미네이션 | 브라켓·생성 UI | SP·API·WS | Tournament/DE | DB→API→WS→FE |
| E4 | 포인트제 | 순위·대진 UI | SP·API | 신규 뷰 | 규칙 확정 후 |
| E5 | DS 전역 적용 | 전체 | — | 리스킨 | FE, 기능 안정 후 |

---

## 8. 로컬·문서 링크

| 문서 | 용도 |
|------|------|
| [local-dev.md](./local-dev.md) | clone, env, install, start/stop |
| [service-map.md](./service-map.md) | API·WS·FE 연동 |
| [deployment-playbook.md](./deployment-playbook.md) | 상황별 배포 |
| [db-deployment.md](./db-deployment.md) | DB QA→Live, CI 한계, 체크리스트 |

```powershell
cd D:\masang\project\triumph_ai
.\scripts\sync-env.ps1
.\scripts\start-all.ps1   # 또는 start-frontend.bat (QA 원격 API)
```

---

## 9. 이 파일 수정 규칙

- 역할 정의·템플릿 변경 → **기획/아키텍처** 채팅에서 PR/커밋 (`triumph_ai` only)
- 에픽별 진행 상황은 Handoff 섹션을 복사해 **각 기능 PR 설명** 또는 팀 위키에 붙여도 됨
