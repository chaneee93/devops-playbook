# 📦 notes-app GitHub Actions CI/CD + 보안 게이트

> GitHub Actions로 CI 파이프라인을 구축하고, environment 승인 게이트와 보안 스캔 게이트를 적용한 프로젝트

---

## 개요

| 항목 | 내용 |
|------|------|
| 기간 | 2026.08 |
| 목표 | GitHub Actions로 CI/CD 파이프라인 구축 + 보안 스캔 자동화 |
| 환경 | GitHub.com + GitHub-hosted Runner |
| 사용 기술 | GitHub Actions, Gitleaks, Trivy |
| 리포 | [chaneee93/notes-app-actions](https://github.com/chaneee93/notes-app-actions) |

---

## 아키텍처

```
개발자 → git push → GitHub
                      │
                      ├── CI Pipeline (ci.yml)
                      │     build ✅ → test ✅ → package ✅
                      │                              │
                      │                    ┌─────────┴──────────┐
                      │               develop                  main
                      │            deploy-dev (자동)      deploy-prod (승인 필수)
                      │
                      └── Security Gate (security.yml)
                            secret-scan ✅
                            vulnerability-scan ❌ → 취약점 발견 시 차단!
```

---

## 구현 상세

### 1. CI 파이프라인 (GitLab → Actions 이식)

GitLab CI에서 구축한 build → test → package 파이프라인을 GitHub Actions로 이식했습니다.

핵심 차이:
- GitLab은 소스코드를 자동 clone하지만, Actions는 `actions/checkout@v4`를 명시해야 합니다
- GitLab의 `artifacts`가 Actions에서는 `upload-artifact` / `download-artifact` 두 개로 분리됩니다
- GitLab은 Runner를 직접 등록하지만, Actions는 `runs-on: ubuntu-latest`로 GitHub 호스팅 러너를 사용합니다

### 2. environment 승인 게이트

Settings → Environments에서 `prod` 환경에 Required reviewers를 설정했습니다.

검증 결과:
- `develop` 브랜치 push → deploy-dev 자동 실행
- `main` 브랜치 push → deploy-prod 승인 대기 (Waiting) → 승인 후 실행
- 승인 이력이 코멘트까지 포함되어 감사(audit) 추적 가능

### 3. 보안 스캔 게이트

일부러 취약한 코드를 넣어서 스캔이 실제로 차단하는지 검증했습니다.

넣은 취약점:
- Terraform: 보안그룹 0.0.0.0/0 전 포트 개방
- Terraform: S3 버킷 public ACL 미차단

검증 결과:
```
secret-scan          ✅ 통과 (5초)
vulnerability-scan   ❌ 실패 (17초)
  → Trivy: Tests 6, SUCCESSES 0, FAILURES 6
  → AWS-0086 (HIGH): S3 public ACL 차단 없음 + 기타 5건
  → exit-code: 1 → 파이프라인 자동 차단
```

---

## 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| security.yml이 Actions에 안 나타남 | WSL에서 파일 생성 후 push 누락 | GitHub 웹에서 직접 파일 생성 |
| prod 배포가 승인 없이 실행 | environment에 승인자 미설정 | Settings → Environments → Required reviewers 추가 |
| Trivy HIGH 6건 실패 | 일부러 넣은 취약 코드 | 보안 게이트 정상 작동 확인 (의도된 실패) |

---

## 배운 점

**도구가 아니라 원리를 남겨라.**
GitLab CI에서 배운 stage, job, artifacts, cache 개념이 GitHub Actions에서도 이름만 바뀔 뿐 그대로 적용됩니다.

**보안 게이트는 단계적으로 도입해야 한다.**
처음부터 전면 차단하면 기존 취약점이 수백 개 떠서 팀이 게이트를 꺼달라고 합니다. 관찰 → 신규 차단 → 등급 차단 → 전면 적용 순서로.

**Shift Left — 늦게 잡을수록 비용은 자릿수로 커진다.**
운영 장애로 발견하면 10배 비용이지만, PR 파이프라인에서 잡으면 커밋 하나 고치면 끝입니다.
