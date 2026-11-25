# Higgsfield 비야 E 달리기 흰 매트 수정

기존 CHARACTER-PILOT-006 / pilot32의 E 달리기 11장에 대한 파생 수정이다. 원본 `../frames`와 `../resources`는 변경하지 않는다. `generation_log.json`은 실제 Higgsfield 모델·입력·견적·작업 ID·결과 URL·잔액 조회를 기록한다. 기술 검증과 최종 ART-001 승인은 별도다.

## 파일 역할

| 경로 | 용도 |
| --- | --- |
| `native/` | 기존 400×496 원본 11장 |
| `baseline/` | 수정 전 GAME062 표시 PNG 11장 |
| `generated/` | Higgsfield 800×992 재생성 결과 11장 |
| `registered/` | 기존 공통 크롭·배율·위치에 정렬한 생성 결과 |
| `final/` | 경계색·한정 투명도 수정을 반영한 200×248 검증본. Godot 경계색 정규화 전 단계 |
| `alpha_masks/` | 원본 흰 배경 잔사에만 알파 감소를 허용하는 L8 이진 마스크 |
| `manual_hair_masks/` | 확대 비교로 확인한 머리 뒤 흰 배경 잔사. 전체 알파 마스크의 부분집합 |
| `rgb_masks/` | 이전 표시본 대비 정규화 전 합성 단계의 RGB 변경 위치 |
| `reports/` | 프레임별 처리 위치·색상·해시·수치 |
| `manifest.json` | 실제 cache 생성기가 검증하는 경로·해시·수정 범위 |

생성 결과 전체를 새 캐릭터로 교체하지 않는다. 원래 프레임의 얼굴·의상·총·보폭을 고정하고 생성 결과의 확인된 재질색과 작은 배경 틈만 사용한다. 알파는 마스크 밖에서 원본과 동일하며, 마스크 안에서도 감소만 허용한다. RGB는 원래 투명 경계와 승인된 구멍의 주변 3픽셀로 제한한다. 밝은 피부·아이보리·금속을 일괄 제거하는 색상 키는 사용하지 않는다.

## 재현

저장소 루트에서 실행한다. Python 재현 도구는 Pillow, NumPy, SciPy를 사용한다. 원본과 동결된 baseline을 읽으며 검증된 파일을 자동 덮어쓰지 않는다.

```bash
python3 tools/higgsfield/build_edge_repair.py --out .local_validation/higgsfield_rebuild
godot --headless --path . --script tools/build_viya_render_cache.gd
godot --headless --editor --path . --import
```

첫 명령의 `frames`·`alpha_masks`·`rgb_masks`·`registered` 결과 44개는 이 폴더의 검증본과 바이트 단위로 일치한다. 두 번째 명령은 모든 원본/수정본/마스크 해시와 보존 조건을 검사하고, 기존 PNG 임포트의 `fix_alpha_border=true`와 같은 `Image.fix_alpha_edges()`를 적용한다. 정규화 뒤에도 알파·수정 범위 보존 조건을 다시 검사한 뒤 실제 활성 `../render_cache/viya_render_frames.tres`의 PNG를 저장한다. 실제 캐시 11장과 Godot 임포트 결과의 RGBA가 일치한다. `final/`과 정규화 후 캐시가 파일 단위로 같다는 뜻은 아니다.

11장 전체에서 흰 배경 잔사 1,467픽셀의 알파만 감소했다. 그중 총 아래·다리 사이 497픽셀, 머리 뒤 970픽셀이다. 정규화 전 RGB 변경은 6,159픽셀, 실제 캐시에서 이전 표시본 대비 원래 알파가 0보다 큰 RGB 변경은 6,577픽셀이다. 불투명 내부는 보존했다. 넓게 설정한 얼굴·아이보리 보호 영역의 가장자리에는 정규화로 RGB가 바뀐 거의 투명한 4픽셀(알파 1/255 또는 3/255)이 있으며, 알파와 원화 내부는 바뀌지 않았다. 엄격한 해당 영역 전체 RGB 동일성 검사는 이 예외를 그대로 기록한다.

E 달리기 11장 외 197장은 기존 필터를 그대로 사용한다. 원래 32동작·208프레임·E 달리기 60ms×11·표시 크기 69×85.56을 유지한다. 원본 10→00 루프의 보행 이음은 이번 배경 수정으로 해결됐다고 판정하지 않는다. 검증 결과와 전체 회귀 시간 초과는 [ARTFIX001 보고서](../../../../docs/validation/ARTFIX001_REPORT.json)에 구분했다.

이 폴더는 `.gdignore`로 일반 게임 임포트에서 제외했다. 게임은 완성된 `render_cache`를 읽으므로 플레이 중 픽셀 수정이나 생성 서비스 호출이 없다.
