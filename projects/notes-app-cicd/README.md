# 📦 notes-app CI/CD 파이프라인 구축

> GitLab Server부터 Runner, 파이프라인까지 **전 과정을 직접 구축**한 프로젝트

---

## 개요

| 항목 | 내용 |
|------|------|
| 기간 | 2026.08 |
| 목표 | git push 시 자동으로 빌드·테스트·패키지가 실행되는 CI 파이프라인 구축 |
| 환경 | Windows + WSL2 Ubuntu 24.04 + Docker |
| 사용 기술 | GitLab CE, GitLab Runner, Docker, Docker Compose |

---

## 아키텍처

```
Windows PC
  │
  ├── 브라우저 ──────────────► http://172.x.x.x (GitLab Web UI)
  │
  └── WSL2 Ubuntu 24.04
        │
        └── Docker Engine
              │
              ├── gitlab (컨테이너)
              │     ├── Web UI          :80
              │     ├── Git SSH         :2222
              │     └── 코드 저장 + CI 지시
              │
              └── gitlab-runner (컨테이너)
                    ├── /var/run/docker.sock 마운트
                    └── job 실행 시 Alpine 컨테이너 동적 생성
                          ├── build-job 컨테이너
                          ├── test-job 컨테이너
                          └── package-job 컨테이너
```

---

## 구축 과정

### 1. 인프라 프로비저닝

Docker Compose로 GitLab Server와 Runner를 한 번에 구성했습니다.
GitLab은 메모리 사용량이 크기 때문에 `puma workers`와 `sidekiq concurrency`를 조정하고,
불필요한 모니터링 컴포넌트를 비활성화했습니다.

### 2. Runner 등록

GitLab 16 이후 권장되는 **runner authentication token** 방식으로 등록했습니다.
(기존 `registration token`은 deprecated — GitLab 20.0에서 제거 예정)

```bash
docker exec -it gitlab-runner gitlab-runner register \
  --non-interactive \
  --url http://gitlab \
  --token <token> \
  --executor docker \
  --docker-image alpine:latest \
  --clone-url http://gitlab
```

### 3. 파이프라인 구성

```
commit push → build → test → package → deploy
                              ↑
                    test 실패 시 여기서 차단
```

| Stage | 역할 |
|-------|------|
| build | 소스코드를 실행 가능한 산출물로 변환, artifacts로 전달 |
| test | 산출물 검증, 실패 시 후속 stage 차단 |
| package | 배포 가능한 형태로 포장 |
| deploy | 브랜치별 환경 배포 (develop 자동 / main 수동 승인) |

### 4. 검증 시나리오

**실패 실험** — 의도적으로 실패하는 테스트를 추가하여 파이프라인이 후속 stage를 차단하는지 확인

```
push → build ✅ → test ❌ → package ⏸ (실행 안 됨)
```

**캐시 검증** — 동일 파이프라인을 2회 실행하여 캐시 히트를 확인

```
Pipeline #4 : "캐시 미스 — 의존성 새로 설치"
Pipeline #5 : "캐시 히트 — 의존성 재사용, 스킵"
```

**브랜치 전략 검증**

```
develop push → deploy-dev  자동 실행 ✅
main push    → deploy-prod 수동 승인 대기 ▶️
```

---

## 트러블슈팅

프로젝트 진행 중 총 8건의 이슈를 해결했습니다. 주요 사례:

### Runner가 job을 가져가지 못하는 문제 (stuck)

**증상** — 파이프라인이 생성되지만 `stuck` 상태로 진행되지 않음

**원인** — `.gitlab-ci.yml`에 지정한 `tags`와 Runner에 등록된 태그가 일치하지 않음.
GitLab은 태그가 정확히 매칭되는 Runner에게만 job을 할당합니다.

**해결** — tags를 제거하거나 Runner 태그와 정확히 일치시킴

### job 컨테이너가 GitLab에 접근하지 못하는 문제

**증상** — `dial tcp 172.18.0.2:80: i/o timeout`

**원인** — Runner 자체는 Compose 네트워크에 있지만, Runner가 job 실행을 위해
**새로 생성하는 컨테이너**는 기본 bridge 네트워크에 배치됨

**해결** — `config.toml`에 `network_mode`를 지정하여 동일 네트워크에 배치

```toml
[runners.docker]
  network_mode = "gitlab-ci-lab_default"
```

### Alpine 이미지에서 bash 실행 실패

**증상** — `bash: not found` (exit code 127)

**원인** — Alpine Linux는 경량화를 위해 bash를 포함하지 않음 (`sh`만 제공)

**해결** — 모든 스크립트를 POSIX sh 호환으로 작성. CI 스크립트는
어떤 이미지에서 실행될지 모르므로 sh 호환으로 작성하는 것이 안전합니다.

> 전체 트러블슈팅 기록: [../../02-gitlab-ci/README.md](../../02-gitlab-ci/README.md#-트러블슈팅-직접-겪은-것들)

---

## 배운 점

**CI의 본질은 자동화가 아니라 피드백 주기 단축입니다.**
빌드 실패를 배포일이 아닌 push 시점에 발견하는 것이 핵심입니다.

**파이프라인은 실패하기 위해 존재합니다.**
test가 실패했을 때 package가 실행되지 않는 것 — 이것이 파이프라인이
깨진 코드를 운영 환경에서 막아주는 지점입니다.

**Docker 네트워크의 경계를 이해하는 것이 중요합니다.**
같은 GitLab이라도 컨테이너 내부(`http://gitlab`), 호스트(`http://localhost`),
외부 네트워크(`http://172.x.x.x`)에서 접근 주소가 다릅니다.
