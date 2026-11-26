# VIYA 표시용 테두리 보정 자료

CHARACTER-PILOT-032의 기술적 표시 파생물이다. 원본208PNG와 원본SpriteFrames는 상위 `frames/textures/resources`에 보존한다. 표시용200×248 전체 해상도·32동작/순서/타이밍과69×85.56 표시 크기는 유지한다.

GAME062의 기존 매트 RGB 필터에 ARTFIX001의 **E 달리기11장 한정 수정**을 추가했다. 다른197장은 기존 결과와 바이트 동일하다. E11은 Higgsfield 생성 결과를 원래 포즈에 맞춰 확인한 경계색·배경 틈에만 합성한다. 원본 흰 배경 잔사가 남은 마스크1,467픽셀의 알파 감소를 허용하며, 마스크 밖 알파와 불투명 내부를 보존한다. 따라서 전체 표시 PNG의 알파가 원본과 동일하다는 과거 GAME062 설명은 현재 E11에 적용하지 않는다.

`../edge_repair/final/`은 검증된 합성 입력이다. 캐시 생성기는 모든 입력/출력·마스크 해시와 보존 조건을 검사하고, **Godot `Image.fix_alpha_edges()`로 경계색을 정규화한 뒤 다시 보존 조건을 검사**해 현재 PNG를 저장한다. 기존 `process/fix_alpha_border=true` 임포트 설정을 유지하며 저장/임포트 RGBA가 일치한다. 이 정규화는 알파를 바꾸지 않는다. `manifest.json`에는 필터·생성기·수정 도구·승인 패킷·원본·출력 해시와 처리 방법을 기록한다.

저장소 루트에서 고정 Godot4.7.2로 실행한다.

```sh
godot --headless --path . --script res://tools/build_viya_render_cache.gd
godot --headless --path . --editor --import --quit
```

일반 게임은 미리 만든 프레임을 기존 비야 한 슬롯으로 읽는다. 플레이 중 픽셀 수정/서비스 호출이나 원본 묶음의 추가 로딩은 없다. [수정 패킷](../edge_repair/README.md)·[ARTFIX001 검증 보고서](../../../../docs/validation/ARTFIX001_REPORT.json)가 최신 기술 검증/실기·아트 승인 경계의 기준이다. GAME062_REPORT는 이전 필터 적용 당시 기록이다.
