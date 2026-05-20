# Triumph 로컬 개발 · 배포 플레이북

> `triumph_ai` + 3개 서비스 repo 기준 정리 (2026-05-20)  
> **Live 배포는 각 서비스 GitLab CI로 진행.** `triumph_ai`는 로컬 통합·문서 전용.

---

## 1. 프로젝트 구조 (한눈에)

```
triumph_ai/                          ← 메타 (로컬 스크립트, env 원본) — 운영 배포 X
├── env, env.qa, env.production      ← 프론트 Vite 설정 (배포용은 triumphserver repo)
├── scripts/                         ← clone, start, stop, sync-env, install-deps
├── repos/                           ← .gitignore (각각 독립 Git)
│   ├── global-triumphserver/        ← Vue 3 프론트 (포트 3100)
│   ├── global-apiserver/             ← Laravel API (포트 8000)
│   └── global-renewal-websocket/     ← Socket.IO (포트 9603)
└── repos.lock.json                  ← 권장 커밋 SHA
```

| Repo | 역할 | 로컬 기동 | QA 배포 트리거 | Live 배포 |
|------|------|-----------|----------------|-----------|
| global-triumphserver | UI·디자인·프론트 로직 | `npm run dev:proxy` | `qa` push | `main` push |
| global-apiserver | REST API·인증·비즈니스 | `php artisan serve` | `qa` push | 팀 파이프라인 확인 |
| global-renewal-websocket | 채팅·실시간·브래킷 | `npm run dev` | `release/*`, `hotfix/*` | `main` → **수동** CodeDeploy |
| triumph_ai | 로컬만 | `start-all.bat` | **없음** | **없음** |

### 연동 (QA 기준, `env` / `env.qa`)

| 구분 | URL |
|------|-----|
| 프론트 (로컬) | http://localhost:3100 |
| API | https://qa-msapi.masanggames.com/api |
| WebSocket | https://qa-tp-wss.masanggames.com |
| QA 사이트 | https://qa-tp.masanggames.com |

프론트는 DB에 **직접 연결하지 않음.** API·WebSocket 경유.

---

## 2. 로컬 개발 (배포 전 확인)

### 최초 1회

```powershell
cd D:\masang\project\triumph_ai
.\scripts\clone-repos.ps1
.\scripts\install-deps.ps1          # PHP 8.2, Composer, npm
.\scripts\setup-php.ps1 -strVersion 8.2
```

### env 위치

| 용도 | 파일 |
|------|------|
| 프론트 원본 (triumph_ai) | `triumph_ai\env`, `env.qa`, `env.production` |
| 프론트 실제 로드 | `repos\global-triumphserver\.env.proxy` ← `sync-env.ps1`로 복사 |
| API | `repos\global-apiserver\.env` (팀 제공) |
| WebSocket | `repos\global-renewal-websocket\.env` (팀 제공) |

```powershell
.\scripts\sync-env.ps1              # triumph_ai\env → .env.proxy
.\scripts\sync-env.ps1 -strProfile qa   # env.qa → .env.qa
```

### 기동 / 종료

| 목적 | 명령 |
|------|------|
| 전체 (가능한 것만) | `.\scripts\start-all.ps1` 또는 `start-all.bat` |
| 프론트만 (QA 원격 API) | `start-frontend.bat` |
| 종료 | `.\scripts\stop-all.ps1` 또는 `stop-all.bat` |

**PowerShell:** 반드시 `.\scripts\stop-all.ps1` (`.\` 필수). `stop-all.ps1`만 입력하면 메모장이 뜸.

### 로컬 모드 2가지

| 모드 | 조건 | 결과 |
|------|------|------|
| A. 프론트 + QA 원격 | `env`/`env.qa` + sync-env | localhost:3100 → QA API/WS |
| B. 풀스택 로컬 | apiserver·websocket `.env` + DB/Redis | 3100 + 8000 + 9603 |

---

## 3. Git 커밋 — 어디에 올릴지

| 수정한 곳 | 커밋·푸시 대상 |
|-----------|----------------|
| `triumph_ai\scripts\`, `docs\` | `triumph_ai` (선택, 팀 내부용) |
| `repos\global-triumphserver\` | **global-triumphserver** |
| `repos\global-apiserver\` | **global-apiserver** |
| `repos\global-renewal-websocket\` | **global-renewal-websocket** |

**절대 커밋하지 말 것:** `env`, `env.qa`, `env.production` (API 키·Firebase 키 포함)

---

## 4. 상황별 배포 가이드

### 4-1. 디자인만 수정 (CSS, 레이아웃, Vuetify, 이미지)

**대상 repo:** `global-triumphserver`  
**경로 예:** `src/`, `src/styles/`, `src/components/`, `src/views/`, 정적 리소스

| 단계 | 작업 |
|------|------|
| 1 | 로컬 `npm run dev:proxy` 로 화면 확인 |
| 2 | `global-triumphserver`에서 commit |
| 3 | **QA:** `git push origin qa` → GitLab `deploy-qa` (SSH) |
| 4 | QA URL에서 UI 확인 |
| 5 | **Live:** 팀 릴리즈 절차 후 `git push origin main` → `deploy-main` |

**빌드:** 서버의 `git_deploy_qa.sh` / `git_deploy_live.sh` + `git_triumph_build.sh` (main 빌드)  
**env:** QA/Live URL이 바뀌면 triumphserver 쪽 `.env.qa` / production 모드 또는 `triumph_ai\env.qa` 반영 후 빌드 파이프라인에 맞게 적용

---

### 4-2. 프론트 코드 수정 (로직, API 호출, 라우터, Pinia, Socket 연동)

**대상 repo:** `global-triumphserver`  
**경로 예:** `src/store/`, `src/router/`, `src/plugins/axios.js`, `src/store/socket.js`

| 단계 | 작업 |
|------|------|
| 1 | 로컬에서 API/WS 연동 동작 확인 (QA env 또는 로컬 풀스택) |
| 2 | 필요 시 `VITE_*` 값 확인 (`env` / `.env.proxy`) |
| 3 | commit → **QA `qa` push** → 검증 |
| 4 | API·WS 계약이 바뀌었으면 **백엔드도 함께** 배포 (아래 4-3, 4-4) |
| 5 | Live: `main` push |

**주의:** API URL·토큰 키만 `triumph_ai\env`에 있고 triumphserver repo에 없으면, **서버 빌드 env**와 불일치할 수 있음. 배포 전 팀과 맞출 것.

---

### 4-3. API(백엔드) 코드 수정 — Laravel

**대상 repo:** `global-apiserver`  
**경로 예:** `app/`, `routes/`, `config/`

| 단계 | 작업 |
|------|------|
| 1 | 로컬 `repos\global-apiserver\.env` + `php artisan serve` (PHP **8.2**) |
| 2 | commit → **`git push origin qa`** |
| 3 | GitLab `deploy-qa` → SSH `git_deploy_qa.sh` |
| 4 | QA API·프론트 연동 테스트 |
| 5 | Live: 팀 규칙 확인 (CI에 qa만 자동인 경우, Live 스크립트 별도) |

**프론트 영향:** API 응답 형식·URL·인증이 바뀌면 프론트 수정·배포 필요할 수 있음.

---

### 4-4. WebSocket(백엔드) 코드 수정 — Node/TS

**대상 repo:** `global-renewal-websocket`

| 브랜치 | CI 동작 |
|--------|---------|
| `qa` | **빌드 검증만** (배포 없음) |
| `release/x.x.x`, `hotfix/*` | 빌드 → S3 → **QA CodeDeploy** |
| `main` | GitLab **`deploy_to_live` 수동 승인** |

| 단계 | 작업 |
|------|------|
| 1 | 로컬 `npm run dev`, `.env`에 DB/Redis |
| 2 | feature → `qa` MR로 빌드 검증 통과 |
| 3 | `release/x.x.x` 브랜치 push → QA CodeDeploy |
| 4 | `GET .../health` + 채팅/브래킷 기능 확인 |
| 5 | Live: `main` + GitLab에서 **수동** deploy_to_live |

**배포 후 서버:** PM2 `websocket`, `workers-chat`, `websocket-cron`

---

### 4-5. DB 수정

> **상세:** [db-deployment.md](./db-deployment.md) (배포 깃 세션용 정리)

DB는 **Git push만으로 끝나지 않음.** 반드시 QA → Live 순서와 백업.

| DB 사용처 | 스키마 위치 | 배포 시 |
|-----------|-------------|---------|
| API | Laravel `database/migrations/` | QA DB에 마이그레이션 적용 후 API 배포. `git_deploy`에 migrate 포함 여부 팀 확인 |
| WebSocket | `prisma/schema.prisma` | DDL/SQL을 QA DB에 적용 → `prisma generate`는 CI 빌드에 포함 |
| 프론트 | 없음 | 해당 없음 |

**권장 순서 (DB + 코드)**

1. QA DB에 스키마/데이터 변경 적용  
2. 백업  
3. 영향 받는 **API 또는 WebSocket** 코드 수정·배포  
4. 필요 시 **프론트** 배포  
5. Live: DB → 백엔드 → 프론트 (점검 시간)  

---

### 4-6. 기능 추가·변경 (프론트 + API + WS)

여러 repo를 건드는 일반적인 순서:

```text
1. 요구사항·API 계약 정리
2. DB 변경 (있으면) → QA DB 적용
3. global-apiserver 개발·배포 (qa)
4. global-renewal-websocket 개발·배포 (release/*)
5. global-triumphserver 개발·배포 (qa)
6. QA 통합 테스트 (qa-tp.masanggames.com 등)
7. Live: DB → API → WS → 프론트 (각 repo Live 절차)
```

---

### 4-7. 환경 변수만 변경 (URL, 키)

| 변경 내용 | 수정 위치 | 배포 |
|-----------|-----------|------|
| 프론트 QA URL | `triumph_ai\env.qa` + triumphserver 빌드 env | triumphserver `qa`/`main` |
| 프론트 Live URL | `triumph_ai\env.production` | triumphserver `main` |
| API DB/Redis | `global-apiserver\.env` | apiserver `qa` |
| WS DB/Redis | `global-renewal-websocket\.env` | websocket `release/*` |

`triumph_ai\env`만 고치고 **push하지 않으면** 서버에 반영 안 됨.

---

## 5. Live 배포 체크리스트 (나중에 여기서 할 때)

### 공통

- [ ] QA에서 동일 기능 검증 완료  
- [ ] `repos.lock.json` 또는 팀이 정한 버전 조합 확인  
- [ ] 비밀 파일(`env*`) Git 미포함  
- [ ] GitLab 파이프라인 **성공(녹색)** 확인  

### 프론트 Live

- [ ] `global-triumphserver` → `main` push  
- [ ] GitLab: `build` + `deploy-main` 성공  
- [ ] https://tp.masanggames.com (또는 팀 Live URL) 확인  

### API Live

- [ ] 팀 Live 배포 브랜치/스크립트 확인 (`qa`만 자동일 수 있음)  
- [ ] Live `.env`·DB 연결 확인  

### WebSocket Live

- [ ] QA에서 검증된 `release/*` 빌드가 S3에 있음  
- [ ] `main` push 후 GitLab **`deploy_to_live` 수동 실행**  
- [ ] CodeDeploy 성공 + `/health` 200  
- [ ] PM3 프로세스 online  

### DB Live

- [ ] Live DB 백업  
- [ ] 마이그레이션/SQL 적용  
- [ ] 백엔드 배포 후 smoke test  

---

## 6. 하지 말아야 할 것

### Git / 저장소

| 하지 말 것 | 이유 |
|------------|------|
| `triumph_ai` push로 운영 배포 기대 | 메타 repo는 CI 배포 없음 |
| `repos/`를 triumph_ai에 커밋 | `.gitignore` 대상, 각 repo가 별도 Git |
| `env`, `env.qa`, `env.production` Git 커밋 | Firebase·API 키 등 **비밀 노출** |
| 한 repo 수정을 다른 repo에 커밋 | 배포·권한·CI가 분리됨 |

### 로컬 / 스크립트

| 하지 말 것 | 이유 |
|------------|------|
| `stop-all.ps1`만 더블클릭/입력 | 메모장만 열림 → `.\scripts\stop-all.ps1` 또는 `stop-all.bat` |
| `triumph_ai\env`만 수정하고 sync-env 생략 | `.env.proxy` 미반영 |
| PHP 8.3으로 API `composer install` | lock 파일은 **8.2** 호환 |
| WebSocket `qa`만 push하고 배포 기대 | `qa`는 **검증만**, 배포는 `release/*` |

### 배포

| 하지 말 것 | 이유 |
|------------|------|
| DB 변경 없이 스키마만 다른 채 배포 | 런타임 DB 오류 |
| QA 미검증 상태로 Live WebSocket 수동 배포 | CodeDeploy 롤백 부담 |
| 프론트만 Live, API는 QA인 채 장기 운영 | 버전·계약 불일치 |
| Live에서 `triumph_ai` 스크립트 수정 | 운영 서버와 무관 |

---

## 7. 빠른 참조 — 명령 모음

```powershell
# 로컬
cd D:\masang\project\triumph_ai
.\scripts\sync-env.ps1
.\scripts\start-all.ps1
.\scripts\stop-all.ps1
.\scripts\verify-local.ps1

# 프론트 배포 (QA)
cd repos\global-triumphserver
git push origin qa

# API 배포 (QA)
cd repos\global-apiserver
git push origin qa

# WebSocket 배포 (QA)
cd repos\global-renewal-websocket
git push origin release/x.x.x

# 프론트 Live
git push origin main

# WebSocket Live
git push origin main
# → GitLab에서 deploy_to_live 수동 실행
```

---

## 8. 관련 문서

- [DB 배포 정리](db-deployment.md)
- [에이전트 · 핸드오프](HANDOFF.md) (세션 **배포 깃**)
- [로컬 개발 가이드](local-dev.md)
- [서비스 연동 맵](service-map.md)
- [README](../README.md)

---

## 9. 팀에 확인하면 좋은 것 (미확정)

- API **Live** 배포 브랜치·스크립트 (`apiserver` CI는 `qa`만 확인됨)
- `git_deploy_qa.sh` / `git_deploy_live.sh` 안의 `migrate`, `npm build` 상세
- Live DB 호스트·계정 (`.env`는 팀 공유)
- 릴리즈 승인·점검 시간·롤백 담당자
