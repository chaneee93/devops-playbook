# 📦 notes-manifests — GitOps 매니페스트 저장소

> 앱 코드와 분리된 배포 매니페스트 전용 저장소. Day 1~7 전부 반영.

## 구조

```
base/                     ← 공통 원본 (Probe, preStop, ESO 참조)
overlays/dev/             ← replicas: 1, dev 태그
overlays/stg/             ← replicas: 2
overlays/prod/            ← replicas: 4, 리소스 상향 패치
```

## Day 1~7 반영 내역

- Day 4: Probe 3종 + preStop + terminationGracePeriodSeconds
- Day 5: ExternalSecret (Git에 비밀 0줄)
- Day 6: replicas를 overlay에서만 관리 (KEDA 충돌 대비)
- Day 7: 앱/매니페스트 저장소 분리, 디렉터리 방식 환경 분리

## 리포

[github.com/chaneee93/notes-manifests](https://github.com/chaneee93/notes-manifests)
