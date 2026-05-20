# Triumph FE — 페이지 인벤토리

> **기준:** `repos/global-triumphserver/src/router/index.js`  
> **우선순위:** E2 Handoff [handoffs/E2-design-system.md](./handoffs/E2-design-system.md)  
> **갱신:** 2026-05-20 · UI/UX `@ui-ux`

| 우선순위 | 의미 | E2 DS |
|----------|------|-------|
| **P0** | 1차 DS 적용·폼 패턴 기준 | **적용 대상** |
| **P1** | 토너먼트·이벤트 핵심 UX | 문서화만 (다음 스프린트) |
| **P2** | 가이드·관리·에러·부가 auth | 제외 |

---

## Default 레이아웃 (`/`)

| 우선 | path | name | 화면명 (view) | auth |
|------|------|------|---------------|------|
| P1 | `/` | MainPage | 메인 (MainRedesigned) | — |
| **P0** | `/event/create` | EventCreatePage | 이벤트 생성 (EventCreate) | O |
| P1 | `/team/:teamId` | TeamPage | 팀 (→ members 리다이렉트) | — |
| P1 | `/team/:teamId/members` | TeamMembers | 팀 멤버 | — |
| P1 | `/team/:teamId/applicants` | TeamApplicants | 팀 지원자 (리더) | — |
| P2 | `/team/:teamId/setting` | TeamSetting | 팀 설정 (리더) | — |
| P2 | `/team/:teamId/mymenu` | TeamMyMenu | 팀 마이메뉴 | — |
| P2 | `/user` | User | 마이페이지 (→ profile) | O |
| P1 | `/user/profile` | UserProfilePage | 내 프로필 | O |
| P1 | `/user/event` | UserEventPage | 내 이벤트 목록 | O |
| P1 | `/user/team` | UserTeamPage | 내 팀 목록 | O |
| P1 | `/games` | BrowseGames | 게임 탐색 | — |
| P1 | `/games/:id` | GamePage | 게임 상세 | — |

## Auth (`/auth`, Default)

| 우선 | path | name | 화면명 | auth |
|------|------|------|--------|------|
| **P0** | `/auth/login` | AuthLogInPage | 로그인 (LoginPage) | forbid |
| P2 | `/auth/signin` | AuthSignInPage | 회원가입 (SignIn) | forbid |
| P2 | `/auth/reset-password` | AuthResetPassword | 비밀번호 재설정 | forbid |

## 이벤트 라운지 (`/event/:eventId`, ChatLayout)

| 우선 | path | name | 화면명 | 비고 |
|------|------|------|--------|------|
| P1 | `/event/:eventId` | EventPage | 라운지 (→ overview) | |
| P1 | `/event/:eventId/overview` | EventOverview | 이벤트 개요 (EventLounge) | |
| P1 | `/event/:eventId/entry` | EventEntry | 참가 신청 | |
| P1 | `/event/:eventId/announce` | EventAnnouncements | 공지 | |
| P1 | `/event/:eventId/bracket` | EventBracket | 대진 목록 | |
| P1 | `/event/:eventId/bracket/:bracketId` | EventBracketMain | 대진표 메인 (BracketMain) | D3·로직 별도 |

## 채팅

| 우선 | path | name | 화면명 |
|------|------|------|--------|
| P1 | `/event/:eventId/channel/:roomId` | EventChatRoom | 이벤트 채팅방 |

## 이벤트 관리 (`/manage`, ChatLayout)

| 우선 | path | name | 화면명 |
|------|------|------|--------|
| P2 | `/manage/event/:eventId` | ManagePage | 관리 (→ overview) |
| P2 | `/manage/event/:eventId/overview` | ManageEventOverview | 관리 개요 |
| P2 | `/manage/event/:eventId/announce` | ManageEventAnnouncements | 관리 공지 |
| P2 | `/manage/event/:eventId/bracket` | ManageEventBracket | 관리 대진 |
| P2 | `/manage/event/:eventId/entry` | ManageEventEntry | 관리 참가 |
| P2 | `/manage/event/:eventId/dashboard` | ManageEventDashboard | 관리 대시보드 |

## 가이드 (`/guide`, GuideLayout)

| 우선 | path | name | 화면명 |
|------|------|------|--------|
| P2 | `/guide` | MainGuidePage | 가이드 메인 |
| P2 | `/guide/quick-start` | QuickStartGuide | 퀵스타트 |
| P2 | `/guide/participant` | ParticipantGuide | 참가자 가이드 |
| P2 | `/guide/organizer` | OrganizerGuide | 주최자 가이드 |
| P2 | `/guide/team` | TeamGuide | 팀 가이드 |

## 에러·기타

| 우선 | path | name | 화면명 |
|------|------|------|--------|
| P2 | `/404` | NotFound | 404 |
| P2 | `/500` | ServerError | 500 |
| P2 | `/:pathMatch(.*)*` | CatchAll | 404 (fallback) |
| — | `/design-system` | DesignSystemShowcase | DS 쇼케이스 (**DEV only**) |

## 단축 URL (동적)

| 우선 | path | 처리 |
|------|------|------|
| — | `/{10자 키}` | `router.beforeEach` → API `url/{key}` 리다이렉트 (라우트 테이블 외) |

---

## E2 적용 요약

| P0 화면 | 주요 파일 |
|---------|-----------|
| 로그인 | `views/Auth/LoginPage.vue`, `components/auth/LoginForm.vue`, `LoginContent.vue` |
| 이벤트 생성 | `views/Event/EventCreate.vue`, `components/Event/Create/EventCreate*.vue` |

**총 라우트(name) 수:** 38 (+ DEV 쇼케이스 1)  
**P0:** 2 · **P1:** 17 · **P2:** 18 · **기타:** 1
