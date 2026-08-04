# 02. GitLab CI 파이프라인

> GitLab Server + Runner를 Docker로 직접 구축하고, build → test → package 파이프라인을 만든 기록

---

## 🎯 핵심 3줄

1. **CI의 본질은 자동화가 아니라 피드백 주기 단축이다**
2. **artifacts는 결과물, cache는 의존성 — cache는 지워도 파이프라인이 돌아야 한다**
3. **파이프라인은 실패하기 위해 존재한다** (깨진 코드를 운영에 못 가게 막는 것)

---

## 🏗 직접 구축한 것

### 아키텍처

```
Windows PC
  └── WSL2 Ubuntu 24.04
        └── Docker Engine
              ├── GitLab Server (컨테이너)  ← 코드 저장 + CI 지시
              └── GitLab Runner (컨테이너)  ← 실제 빌드/테스트 실행
                    └── job 실행 시 Alpine 컨테이너를 동적 생성
```

### 구현 범위

- [x] Docker Compose로 GitLab Server + Runner 구축
- [x] Runner 등록 (authentication token 방식)
- [x] build → test → package 3단계 파이프라인
- [x] artifacts로 stage 간 산출물 전달
- [x] cache로 의존성 재사용 (캐시 히트/미스 검증)
- [x] 테스트 실패 시 후속 stage 차단 검증
- [x] 브랜치별 배포 분기 (develop 자동 / main 수동 승인)
- [x] needs를 활용한 DAG 파이프라인

---

## 📖 핵심 개념

### 파이프라인 구조

```
Pipeline (전체 자동화 흐름)
  └── Stage (단계: build → test → package)
        └── Job (실제 작업 단위)
```

- 같은 stage의 job → **병렬 실행**
- 다른 stage 사이 → **순차 실행**
- 각 job → **독립된 컨테이너**에서 실행 (파일 공유 안 됨)

### Artifacts vs Cache

|  | Artifacts | Cache |
|---|---|---|
| 정체 | 빌드 결과물 (.jar, bundle.js) | 의존성 (node_modules, .gradle) |
| 비유 | 택배 상자 📦 | 내 책상 서랍 🗄 |
| 방향 | build → test (같은 파이프라인) | Pipeline #1 → #2 (파이프라인 간) |
| 없으면? | **다음 stage 실패** ❌ | 느려질 뿐 ⏱ |
| 저장 위치 | GitLab Server 업로드 | Runner 로컬 / 분산 캐시 |

### CI / CD / CD

| 약어 | 풀이 | 끝나는 지점 |
|---|---|---|
| CI | Continuous Integration | 빌드·테스트 자동 |
| CD | Continuous **Delivery** | 배포 가능 산출물까지 자동, 배포는 수동 승인 |
| CD | Continuous **Deployment** | 승인 없이 운영까지 자동 |

---

## 🌐 Docker 네트워크 이해 (중요!)

같은 GitLab인데 접근 위치에 따라 주소가 다릅니다.

```
컨테이너 → 컨테이너   : http://gitlab        (Docker 서비스명 = 내선번호)
WSL 터미널 → 컨테이너 : http://localhost     (포트포워딩 = 직통번호)
Windows 브라우저 → 컨테이너 : http://172.x.x.x (WSL IP = 대표번호)
```

> Docker Compose로 구성된 컨테이너들은 같은 bridge 네트워크에 속하며,
> 컨테이너 간 통신은 **서비스명으로 DNS가 자동 해석**됩니다.

---

## 🔥 트러블슈팅 (직접 겪은 것들)

| # | 증상 | 원인 | 해결 |
|---|------|------|------|
| 1 | GitLab 컨테이너 무한 Restarting | 최신 버전에서 `grafana` 설정 deprecated | `grafana['enable'] = false` 삭제 |
| 2 | `docker compose down` 실패 | YAML 들여쓰기 깨짐 | `cat > file << 'EOF'` 로 전체 재작성 |
| 3 | Windows 브라우저에서 localhost 접속 불가 | WSL2는 별도 가상 네트워크 사용 | `wsl hostname -I` 로 IP 확인 후 접속 |
| 4 | `git clone http://gitlab/...` 실패 | WSL 터미널은 Docker 네트워크 밖 | `http://localhost/...` 사용 |
| 5 | git clone 무한 대기 | credential 프롬프트 미출력 | URL에 인증정보 포함 (`@`는 `%40`으로 인코딩) |
| 6 | Runner가 job을 못 가져감 (**stuck**) | `.gitlab-ci.yml`의 tags와 Runner 태그 불일치 | tags 제거 또는 정확히 매칭 |
| 7 | job 컨테이너가 GitLab에 접근 불가 | job 컨테이너가 기본 bridge 네트워크에 붙음 | `config.toml`에 `network_mode` 추가 |
| 8 | `bash: not found` (exit code 127) | Alpine 이미지에 bash 미포함 | `bash` → `sh` 로 변경 |

### 자주 쓴 디버깅 명령어

```bash
# 컨테이너 상태 확인
docker compose ps

# GitLab 로그 확인 (에러 원인 파악)
docker logs gitlab --tail 50

# Runner 등록 상태 확인
docker exec gitlab-runner gitlab-runner list

# Runner 설정 확인
docker exec gitlab-runner cat /etc/gitlab-runner/config.toml

# 컨테이너 간 네트워크 연결 테스트
docker exec gitlab-runner sh -c "wget -q -O- --timeout=5 http://gitlab:80/"
```

---

## 🚀 환경 구축

### 1. docker-compose.yml

[docker-compose.yml](./docker-compose.yml) 참고

```bash
docker compose up -d
```

> ⚠️ GitLab은 첫 기동에 3~5분 소요됩니다.

### 2. Runner 등록

GitLab UI → Settings → CI/CD → Runners → New project runner → 토큰 복사

```bash
docker exec -it gitlab-runner gitlab-runner register \
  --non-interactive \
  --url http://gitlab \
  --token <복사한_토큰> \
  --executor docker \
  --docker-image alpine:latest \
  --clone-url http://gitlab
```

**옵션 설명**

| 옵션 | 의미 |
|------|------|
| `--non-interactive` | 대화형 질문 없이 한 번에 등록 |
| `--url` | GitLab 서버 주소 (컨테이너 간 통신이므로 서비스명 사용) |
| `--token` | Runner 인증 토큰 (구 registration token은 deprecated) |
| `--executor docker` | job 실행 방식 — Docker 컨테이너를 띄워서 실행 |
| `--docker-image` | job에 이미지 미지정 시 사용할 기본 이미지 |
| `--clone-url` | 소스코드 clone 시 사용할 주소 |

### 3. 네트워크 설정 (필수!)

Runner가 띄우는 job 컨테이너를 GitLab과 같은 네트워크에 배치해야 합니다.

```bash
docker exec gitlab-runner sed -i \
  's/network_mtu = 0/network_mtu = 0\n    network_mode = "gitlab-ci-lab_default"/' \
  /etc/gitlab-runner/config.toml

docker restart gitlab-runner
```

---

## 📁 템플릿

| 파일 | 용도 |
|------|------|
| [01-basic-pipeline.yml](./templates/01-basic-pipeline.yml) | build → test → package 기본형 |
| [02-with-cache.yml](./templates/02-with-cache.yml) | 의존성 캐싱 적용 |
| [03-branch-strategy.yml](./templates/03-branch-strategy.yml) | 브랜치별 배포 분기 + needs |
| [04-docker-build-push.yml](./templates/04-docker-build-push.yml) | Docker 이미지 빌드 + 레지스트리 푸시 |

---

## 💡 알아두면 손해 안 보는 기본값

| 설정 | 기본값 | 권장 |
|------|--------|------|
| `artifacts.expire_in` | 30일 | 명시적으로 짧게 설정 (디스크 절약) |
| `cache.policy` | pull-push | 읽기만 하면 `pull`로 변경 |
| `retry` | 0 | 네트워크 에러 대비 1~2 권장 |

---

## 🔑 주요 CI 내장 변수

| 변수 | 의미 |
|------|------|
| `$CI_COMMIT_BRANCH` | 브랜치명 (MR 파이프라인에서는 비어 있음) |
| `$CI_MERGE_REQUEST_TARGET_BRANCH_NAME` | MR의 대상 브랜치 |
| `$CI_PIPELINE_SOURCE` | push / merge_request_event / schedule |
| `$CI_COMMIT_SHORT_SHA` | 짧은 커밋 해시 (이미지 태그로 유용) |
| `$CI_REGISTRY_IMAGE` | GitLab 컨테이너 레지스트리 이미지 경로 |
