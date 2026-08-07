# 07. 상태와 비동기 · ElastiCache · SQS · SNS · KEDA

> 세션을 밖으로 빼고, 느린 작업은 큐로 분리하고, 큐 길이로 워커를 자동 스케일한 기록

---

## 🎯 핵심 3줄

1. **파드 안에 상태가 있으면 늘릴 수도, 죽일 수도 없다 — 세션을 ElastiCache로 빼야 진짜 무상태**
2. **큐는 '나중에 한다'가 아니라 '실패를 흡수한다'는 장치**
3. **KEDA — 큐 길이로 워커 자동 증감, 0까지 축소 (비용 0!)**

---

## 🏗 직접 구축한 것

- [x] ElastiCache (Valkey/Redis) 클러스터 생성 + EKS VPC 연결
- [x] SQS 큐 생성 + DLQ 연결 (3번 실패 → 격리)
- [x] SQS 메시지 송수신 테스트 (send/receive/delete)
- [x] SNS 토픽 생성 + SQS 구독 (팬아웃)
- [x] SNS → SQS 자동 전달 확인
- [x] KEDA 설치 + ScaledObject로 SQS 기반 오토스케일
- [x] Pod 0개 → 메시지 15개 → Pod 자동 생성 확인!

---

## 📖 핵심 개념

### 무상태 vs 상태

| | 상태를 들고 있는 앱 | 무상태 앱 |
|---|---|---|
| 세션 | Pod 메모리에 저장 | ElastiCache에 저장 |
| Pod 교체 시 | 세션 소멸 (로그아웃) | 세션 유지 |
| 스케일링 | sticky session 필요 | 자유롭게 늘리기/줄이기 |
| 롤링 배포 | 5xx 발생 가능 | 무중단 |

### 캐시 전략 3가지

| 전략 | 원리 | 장점 | 단점 |
|------|------|------|------|
| Lazy Loading | 캐시 미스 시 DB에서 읽어 캐시에 넣음 | 요청된 것만 캐시 | 첫 요청 느림, 오래된 데이터 |
| Write-Through | DB에 쓸 때 캐시도 갱신 | 항상 최신 | 안 읽는 것도 캐시 |
| TTL 병행 | 둘 다 + 만료 시간 | 실무 최적 | 스탬피드 주의 |

> 캐시 스탬피드: TTL 동시 만료 → DB로 한꺼번에 몰림 → 해결: jitter(랜덤 TTL) + 락

### SQS — 비동기 처리

| | 동기 처리 | 큐로 분리 |
|---|---|---|
| 사용자 대기 | 8초 (변환 끝날 때까지) | 0.1초 (즉시 응답) |
| 실패 시 | 요청 전체 실패 | 큐에 남아서 재시도 |
| 트래픽 폭주 | API가 같이 죽음 | 큐에 쌓일 뿐 |

**Standard vs FIFO:**
- Standard: 순서 보장 안 됨, 거의 무한 처리량 (대부분 이거)
- FIFO: 순서 보장, 초당 300건 (결제/주문 상태 변경)

**DLQ:** N번 실패한 메시지를 격리 → 무한 루프 방지

**Visibility Timeout:** 메시지 꺼내면 일정 시간 안 보임 → 중복 처리 방지

**멱등 처리:** 같은 메시지 2번 처리해도 결과가 같아야 함

### SNS — 팬아웃

하나의 이벤트를 여러 구독자에게 동시 전달. 새 서비스 추가 = 구독만 추가 (발행 코드 수정 없음)

### KEDA — 외부 메트릭 기반 오토스케일

| | HPA | KEDA |
|---|---|---|
| 기준 | CPU/메모리 | SQS 큐 길이, Kafka 랙 등 외부 메트릭 |
| 최소 Pod | 1개 | **0개** (비용 0!) |
| 설치 | K8s 내장 | Helm으로 설치 |

---

## 🔥 트러블슈팅

| # | 증상 | 원인 | 해결 |
|---|------|------|------|
| 1 | IRSA 생성 실패 "no IAM OIDC provider" | OIDC Provider 미등록 | `eksctl utils associate-iam-oidc-provider` 먼저 |
| 2 | TriggerAuthentication "Unsupported identityOwner" | KEDA 버전에 따라 identityOwner 미지원 | `identityOwner` 제거 또는 `operator`로 ScaledObject에 설정 |
| 3 | ScaledObject READY False | KEDA operator에 SQS 권한 없음 | operator SA에 IRSA로 SQS 권한 부여 + 재시작 |

---

## 📁 템플릿

| 파일 | 용도 |
|------|------|
| [scaledobject.yaml](./templates/scaledobject.yaml) | KEDA SQS 기반 오토스케일 |
| [worker-deployment.yaml](./templates/worker-deployment.yaml) | SQS 워커 Deployment |
