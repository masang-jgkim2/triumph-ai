# Triumph AI — Cursor 에이전트 (진입점)

> 역할·워크플로·Handoff 템플릿: [docs/HANDOFF.md](docs/HANDOFF.md)  
> 문서 전체 맵: [docs/README.md](docs/README.md)

## 세션 탭 ↔ @에이전트

| 탭 이름 | @에이전트 | rule (참고) |
|---------|-----------|-------------|
| **기획/아키텍처** | `planning-architecture` | `triumph-planning.mdc` |
| **UI/UX** | `ui-ux` | `triumph-ui-ux.mdc` |
| **구현 · FE** | `fe-dev` | `triumph-fe-dev.mdc` |
| **구현 · BE** | `be-dev` | `triumph-be-dev.mdc` |
| **배포 깃** | *(미정의)* | `deploy-git.mdc` |

탭 Rename: 채팅 탭 우클릭 → Rename (자동 변경 불가).

## 새 채팅

| 탭 이름 | Agent 선택 |
|---------|------------|
| 기획/아키텍처 | `planning-architecture` |
| UI/UX | `ui-ux` |
| 구현 · FE | `fe-dev` |
| 구현 · BE | `be-dev` |
| 배포 깃 | playbook/db-deployment 파일 @ 멘션 + `deploy-git` 규칙 |

### UI/UX → 기획 검토

1. UI/UX: `@ui-ux` + `docs/handoffs/E2-design-system.md` 등  
2. 완료 후 `docs/design-system.md` 갱신 +「UI/UX 검토 요청」블록  
3. 기획 탭에 붙여넣기:

```text
@docs/handoffs/E2-design-system.md @docs/design-system.md
UI/UX 작업 검토해줘.
(검토 요청 블록)
```

### 구현 (FE / BE)

1. 기획 Handoff(`docs/handoffs/*.md`)에 API·DB·화면 범위 확정  
2. BE: `@be-dev` + Handoff — API/SP/WS 먼저 (FE가 의존할 때)  
3. FE: `@fe-dev` + Handoff + `docs/design-system.md` — 연동·화면  
4. 완료 보고 블록을 기획 탭 또는 QA에 전달 (각 에이전트 파일 하단 템플릿)

## 문서 (링크만)

| 용도 | 파일 |
|------|------|
| Handoff·에픽 | [HANDOFF.md](docs/HANDOFF.md) |
| UI 산출물 · E2 Handoff | [design-system.md](docs/design-system.md) · [handoffs/E2-design-system.md](docs/handoffs/E2-design-system.md) |
| E3 더블 엘리미네이션 | [handoffs/E3-double-elimination.md](docs/handoffs/E3-double-elimination.md) · [repos/db/README.md](repos/db/README.md) |
| 연동·포트 | [service-map.md](docs/service-map.md) |
| 로컬 기동 | [local-dev.md](docs/local-dev.md) |
| 배포 | [deployment-playbook.md](docs/deployment-playbook.md) · [db-deployment.md](docs/db-deployment.md) |

## `.cursor` 파일

| 파일 | 역할 |
|------|------|
| `agents/planning-architecture.md` | 기획 세션 프롬프트 |
| `agents/ui-ux.md` | UI/UX 세션 프롬프트 |
| `agents/fe-dev.md` | 구현 · FE 세션 프롬프트 |
| `agents/be-dev.md` | 구현 · BE 세션 프롬프트 (DB 포함) |
| `rules/triumph-planning.mdc` | 기획 alwaysApply |
| `rules/triumph-ui-ux.mdc` | UI/UX globs |
| `rules/triumph-fe-dev.mdc` | FE globs (`global-triumphserver`) |
| `rules/triumph-be-dev.mdc` | BE globs (apiserver·websocket) |
| `rules/deploy-git.mdc` | 배포 깃 (playbook/db 문서 열 때) |
