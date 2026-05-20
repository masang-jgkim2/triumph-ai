# 로컬 개발 가이드

## 선행 조건

| 도구 | 버전 | 용도 |
|------|------|------|
| Git | 2.x | repo 클론 |
| Node.js | 18+ 권장 | websocket, triumphserver |
| npm | 9+ | 패키지 설치 |
| PHP | **8.2** (lock 파일 호환) | apiserver |
| Composer | 2.x | Laravel 의존성 (`php`로 실행) |
| MySQL | 5.7+ / 8.x | API·WebSocket DB |
| Redis | 6+ | WebSocket adapter, Laravel cache |

사내 Git: `https://web-git.masangsoft.com` 접근 및 인증 필요.

### PHP / Composer 설치 (Windows, winget)

```powershell
winget install PHP.PHP.8.2 --accept-package-agreements --accept-source-agreements
# Composer는 공식 installer (PHP openssl 필요)
cd d:\masang\project\triumph_ai
.\scripts\setup-php.ps1 -strVersion 8.2
```

Composer 수동 설치(최초 1회):

```powershell
php -r "copy('https://getcomposer.org/installer', '$env:TEMP\composer-setup.php');"
php $env:TEMP\composer-setup.php --install-dir="$env:LOCALAPPDATA\Programs\Composer" --filename=composer
```

> API는 PATH의 기본 `php`(8.3)가 아니라 **PHP 8.2**를 사용합니다. `scripts/lib/service-config.ps1`이 자동 선택합니다.

## 1. 저장소 클론

```powershell
cd d:\masang\project\triumph_ai
.\scripts\clone-repos.ps1
```

특정 브랜치:

```powershell
.\scripts\clone-repos.ps1 -Branch develop
```

`repos.lock.json` SHA와 맞추기:

```powershell
.\scripts\clone-repos.ps1 -CheckoutLock
```

## 2. 환경 파일 (.env)

각 서비스 repo는 `.env`가 git에 없습니다. **팀에서 공유받은 dev `.env`**를 복사하세요.

| 경로 | 비고 |
|------|------|
| `repos/global-apiserver/.env` | `php artisan key:generate` 필요 시 실행 |
| `repos/global-renewal-websocket/.env` | `DATABASE_URL`, `REDIS_URL`, `PORT=9603` |
| `repos/global-triumphserver/.env.proxy` | `dev:proxy`용. `VITE_*` 로컬 URL |

참고 템플릿: [`config/local.env.example`](../config/local.env.example)

### 모드 A vs B (프론트 env)

| 모드 | triumph_ai 원본 | sync-env | API/WS |
|------|-----------------|----------|--------|
| A. 프론트 + QA 원격 | `env` | `.\scripts\sync-env.ps1` | QA (원격) |
| B. 풀스택 로컬 | **`env.local-fullstack`** | `.\scripts\sync-env.ps1 -strProfile fullstack` | `127.0.0.1:8000`, `:9603` |

```powershell
# 모드 B
.\scripts\sync-env.ps1 -strProfile fullstack
.\scripts\start-all.ps1
```

모드 B 선행: `repos/global-apiserver/.env`, `repos/global-renewal-websocket/.env` (팀 제공).

API/WS 서버 쪽 로컬 URL 예 (`config/local.env.example` 참고):

```env
# apiserver .env
APP_URL=http://127.0.0.1:8000
WEBSOCKET_URL=http://127.0.0.1:9603
```

## 3. 의존성 설치 (최초 1회)

```powershell
.\scripts\install-deps.ps1
```

또는 수동:

```powershell
.\scripts\setup-php.ps1 -strVersion 8.2
# API — PHP 8.2 + composer
php82 = (Get-Command php -All | ? Source -match '8\.2').Source
& $php82 $env:LOCALAPPDATA\Programs\Composer\composer install -d repos\global-apiserver

cd repos\global-renewal-websocket; npm install; npx prisma generate
cd ..\global-triumphserver; npm install
```

## 4. 기동 / 종료

```powershell
.\scripts\start-all.ps1    # API → WS → FE 순서, 각각 새 PowerShell 창
.\scripts\stop-all.ps1     # 포트 8000, 9603, 3100 기준 종료
.\scripts\verify-local.ps1 # repo·도구·(선택) health 확인
```

## 5. 동작 확인

| 확인 | URL / 명령 |
|------|------------|
| API | http://127.0.0.1:8000 |
| WebSocket health | http://127.0.0.1:9603/health |
| Frontend | http://127.0.0.1:3100 |

`health`가 503이면 DB/Redis 연결 또는 `.env`를 점검하세요.

## 트러블슈팅

### clone 실패

- VPN/사내망 연결 확인
- `git credential` 또는 SSH key 등록

### 포트 이미 사용 중

```powershell
.\scripts\stop-all.ps1
netstat -ano | findstr ":8000"
```

### WebSocket DB 연결 실패

- `DATABASE_URL`이 dev MySQL을 가리키는지 확인
- `npx prisma generate` 재실행

### Frontend API CORS / 401

- `VITE_API_SERVER_URL`이 실행 중인 API와 일치하는지 확인
- `dev:proxy` 모드와 `.env.proxy` 파일 존재 여부 확인

### PHP artisan 오류

- `composer install` 완료 여부
- PHP 8.1+ 및 `ext-*` 확장 (팀 Laravel 요구사항)

## 배포와의 관계

- 코드 변경·PR: **각 서비스 repo**에서만 진행
- `triumph_ai` 변경: 스크립트·문서만 — 운영 서버에 배포하지 않음
