# 📦 notes-app 컨테이너 이미지 파이프라인 + EKS 배포

> 멀티스테이지 빌드 → ECR push → EKS 배포 → IRSA까지 전 과정을 직접 구축한 프로젝트

---

## 개요

| 항목 | 내용 |
|------|------|
| 기간 | 2026.08 |
| 목표 | 컨테이너 이미지 빌드부터 EKS 배포, IRSA 권한 부여까지 전체 파이프라인 구축 |
| 환경 | WSL2 Ubuntu + Docker + AWS (ECR, EKS) |
| 사용 기술 | Docker 멀티스테이지, ECR, EKS, eksctl, IRSA |
| 리전 | eu-west-3 (파리) |

---

## 아키텍처

```
WSL (로컬)
  │
  ├── docker build (멀티스테이지)
  │     단일: 1.29GB → 멀티: 7.7MB (40배 감소!)
  │
  └── docker push
        │
        ▼
  AWS ECR (eu-west-3)
  ├── notes-app:v1.0
  ├── 태그: IMMUTABLE (덮어쓰기 금지)
  │
  └── EKS 클러스터 (devops-training)
        ├── 워커 노드 2대 (t3.medium)
        ├── namespace: student16
        ├── Deployment: notes-app (replicas: 2)
        ├── Service: ClusterIP
        └── IRSA: notes-sa → IAM Role
              └── Pod 안에 JWT 토큰 자동 마운트
                    sub: "system:serviceaccount:student16:notes-sa"
```

---

## 구현 상세

### 1. 멀티스테이지 빌드

단일 스테이지와 멀티스테이지의 이미지 크기를 직접 비교했습니다.

| | 단일 스테이지 | 멀티스테이지 |
|---|---|---|
| 이미지 크기 | 1.29GB | 7.7MB |
| 포함된 것 | Go 컴파일러 + OS 전체 + 앱 | Alpine + 앱 바이너리만 |
| 공격 표면 | 넓음 (bash, gcc 등) | 최소 |

### 2. ECR push

MFA 세션 토큰 발급 → ECR 로그인 → 태그 → push의 순서로 진행했습니다.

### 3. EKS 클러스터 생성

eksctl로 클러스터와 노드그룹을 한 번에 생성했습니다. (약 13분 소요)

### 4. IRSA 검증

Pod 안에서 JWT 토큰이 마운트된 것을 확인했습니다:
- 경로: `/var/run/secrets/eks.amazonaws.com/serviceaccount/token`
- JWT sub: `system:serviceaccount:student16:notes-sa`
- OIDC issuer: EKS 클러스터의 OIDC Provider URL

---

## 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| ECR CreateRepository AccessDenied | MFA 미인증 (Force-MFA 정책) | `aws sts get-session-token`으로 세션 토큰 발급 + 환경변수 설정 |
| kubectl not found | eksctl이 kubectl 자동 설치 안 함 | `curl -LO` + `sudo install`로 수동 설치 |
| docker login WARNING | 자격증명 평문 저장 경고 | Login Succeeded 확인, 학습용 무시 가능 |

---

## 배운 점

**멀티스테이지는 선택이 아니라 필수입니다.**
1.29GB vs 7.7MB — 이미지 크기가 pull 속도, 보안 스캔 결과, 공격 표면 모두에 영향을 줍니다.

**'신원을 증명한다'는 개념이 계속 반복됩니다.**
Day 2의 GitHub OIDC, Day 3의 IRSA — 주체만 다르고 원리는 동일합니다. 키를 주는 대신 JWT로 신원을 증명하고 임시 자격증명을 받는 패턴입니다.
