# 📦 notes-app 시크릿 관리 — ESO로 Git에 비밀 0줄

> Parameter Store + Secrets Manager + ESO로 비밀을 Git에서 완전히 분리한 프로젝트

## 개요

| 항목 | 내용 |
|------|------|
| 기간 | 2026.08 |
| 목표 | 매니페스트에서 비밀을 완전히 제거, AWS에서 자동 동기화 |
| 환경 | AWS EKS (eu-west-3) + ESO |
| 검수 기준 | `grep -ri "password" manifests/` → 결과 없음 |

## 구현 상세

### 1. AWS에 비밀 저장
- Parameter Store: 앱 포트, DB 호스트 (String/SecureString)
- Secrets Manager: DB 자격증명 JSON (username, password, host, port, dbname)

### 2. ESO 설치 + IRSA 연결
- Helm으로 ESO 설치 (`--set installCRDs=true`)
- IRSA로 ESO ServiceAccount에 SSM/SM 읽기 권한 부여

### 3. SecretStore + ExternalSecret
- SecretStore: AWS Secrets Manager 연결 (IRSA 인증)
- ExternalSecret: `/notes/dev/db-credentials`에서 username/password/host 가져오기
- ESO가 자동으로 K8s Secret `db-secret` 생성

### 4. 검증
```
$ kubectl get externalsecret -n student16
NAME             STATUS         READY
db-credentials   SecretSynced   True

$ grep -ri "password" eso-lab/*.yaml
(결과 없음) ← Git에 비밀 0줄!
```

## 배운 점

**분류가 먼저다.** 전부 Secrets Manager에 넣으면 비용이 터진다. 공개/내부/준민감/비밀로 분류하고 등급에 맞는 저장소에 넣어야 한다.

**ESO는 OIDC 위에 있다.** Day 2 GitHub OIDC → Day 3 IRSA → Day 5 ESO. 전부 '신원을 증명한다'는 같은 원리 위에 쌓인다.
