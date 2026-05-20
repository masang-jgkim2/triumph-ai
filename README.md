# Triumph AI — 로컬 통합 오케스트레이션

3개의 독립 Git 저장소를 **하나로 합치지 않고**, 로컬에서 스크립트로 함께 기동·연동 테스트하기 위한 메타 저장소입니다.  
운영 배포는 각 서비스 repo의 기존 CI/CD를 그대로 사용합니다.

## 저장소

| 디렉터리 | 원격 | 역할 |
|----------|------|------|
| `repos/global-apiserver` | global-apiserver | Laravel API (PHP 8.1+) |
| `repos/global-renewal-websocket` | global-renewal-websocket | Socket.IO WebSocket (Node/TS) |
| `repos/global-triumphserver` | global-triumphserver | Vue 3 프론트엔드 (Vite) |

권장 커밋 SHA: [`repos.lock.json`](repos.lock.json)

## 빠른 시작

```powershell
# 1) 서비스 repo 클론 (최초 1회)
.\scripts\clone-repos.ps1

# 2) env 설정
.\scripts\sync-env.ps1          # 모드 A: env -> .env.proxy (프론트 로컬 + QA API/WS)
# 모드 B 풀스택 로컬:
#   .\scripts\sync-env.ps1 -strProfile fullstack   # env.local-fullstack -> .env.proxy
# 로컬 API/WS까지: 아래에 팀 .env 추가
#    - repos/global-apiserver/.env
#    - repos/global-renewal-websocket/.env

# 3) PHP 8.2 + Composer + npm 의존성 (최초 1회)
.\scripts\install-deps.ps1
# 상세: docs/local-dev.md

# 4) 전체 기동 (PowerShell에서 .\ 필수 — 더블클릭은 start-all.bat)
.\scripts\start-all.ps1

# 5) 전체 종료
.\scripts\stop-all.ps1

# CMD/탐색기 더블클릭용
start-all.bat
stop-all.bat
```

## 문서

- **[AGENTS.md](AGENTS.md)** — Cursor 세션·@에이전트 (진입점)
- **[docs/README.md](docs/README.md)** — 문서 맵·중복 방지
- [HANDOFF.md](docs/HANDOFF.md) · [local-dev.md](docs/local-dev.md) · [service-map.md](docs/service-map.md)
- [deployment-playbook.md](docs/deployment-playbook.md) · [db-deployment.md](docs/db-deployment.md)

## 기본 로컬 URL

| 서비스 | URL |
|--------|-----|
| API | http://127.0.0.1:8000 |
| WebSocket | http://127.0.0.1:9603 (기본 PORT) |
| Frontend | http://127.0.0.1:3100 |
