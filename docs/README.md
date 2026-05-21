# Triumph AI — 문서 인덱스 (중복 방지)

**역할·세션 탭·@에이전트 ID** → 루트 [AGENTS.md](../AGENTS.md) **만** (여기서 반복하지 않음)

| 문서 | 단일 진실 (이 내용은 이 파일만) |
|------|-------------------------------|
| [AGENTS.md](../AGENTS.md) | Cursor 탭 이름, `@planning-architecture` / `@ui-ux` / `@fe-dev` / `@be-dev`, 새 채팅 방법 |
| [HANDOFF.md](./HANDOFF.md) | 역할·워크플로·Handoff **템플릿**·에픽 E0~E5·하지 말 것 |
| [handoffs/*.md](./handoffs/) | 에픽 **인스턴스** (E2, E3 등) — 템플릿 복사본 |
| [design-system.md](./design-system.md) | UI/UX **산출물** (토큰·컴포넌트 표) |
| [page-inventory.md](./page-inventory.md) | FE 라우트·P0/P1/P2 인벤토리 |
| [service-map.md](./service-map.md) | 아키텍처·포트·`VITE_*`·WS health |
| [local-dev.md](./local-dev.md) | clone, install, start/stop, 트러블슈팅 |
| [deployment-playbook.md](./deployment-playbook.md) | 상황별 배포 (디자인/FE/BE/DB/Live) |
| [db-deployment.md](./db-deployment.md) | DB QA→Live, CI 한계, 체크리스트 |
| [db/README.md](./db/README.md) | → `repos/db/` SQL·스키마 참고 (SE/DE, E3) |

## `.cursor` 와 docs 관계

| 경로 | 용도 | docs와 중복? |
|------|------|----------------|
| `.cursor/agents/*.md` | 에이전트 **행동** 프롬프트 (`@이름`) | 역할 요약만 — 상세는 HANDOFF |
| `.cursor/rules/*.mdc` | 파일 열 때 짧은 규칙 | 배포 요약만 — 상세는 playbook/db-deployment |

**이름 대응 (헷갈리기 쉬운 것)**

| 탭 이름 | `@에이전트` | rule 파일 |
|---------|-------------|-----------|
| 기획/아키텍처 | `planning-architecture` | `triumph-planning.mdc` (alwaysApply) |
| UI/UX | `ui-ux` | `triumph-ui-ux.mdc` (globs) |
| 구현 · FE | `fe-dev` | `triumph-fe-dev.mdc` (globs) |
| 구현 · BE | `be-dev` | `triumph-be-dev.mdc` (globs, DB 포함) |
| 배포 깃 | (에이전트 파일 없음) | `deploy-git.mdc` (playbook 열 때) |

`HANDOFF.md` ≠ `handoffs/E2-*.md` — 전자는 규칙·템플릿, 후자는 작업 티켓.
