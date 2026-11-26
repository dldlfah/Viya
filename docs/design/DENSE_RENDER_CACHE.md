# GAME063 — 밀집 전투의 정적 벡터 형상 재사용

기존 `BattleView` → `high_angle_battle.gd` → `battle_forms.gd` 경로에 `enemy_shape_cache.gd`를 연결한다. 일반·빠른·무거운·비행 임시 몸체의 고정 다각형/머리/팔/장식을 한 번 삼각형 메시로 만들고 같은 스타일에서 공유한다. 화면 발 위치·높이 변환과 기존 깊이 명령 순서를 유지한다. 비행의 날개/머리 사이 순서, 움직이는 다리·날개, 피격 중의 밝기 보간은 원래 그리기 경로를 따른다. 원거리 활, 슬라임, 실제 SpriteFrames와 비야는 기존 경로를 사용한다.

형상 정의는 `Forms.static_part` 하나이며 기본 도형 경로와 메시 컴파일러가 이를 함께 사용한다. 반투명 AA 선은 Godot4.7.2의 폭 보정·1.25 feather·모서리 삼각형과 같은 좌표를 만들고, 원은 기존64분할을 유지한다. 수학적 구성은 [Godot의 MIT 라이선스 렌더러](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/rendering/renderer_canvas_cull.cpp)를 참고했다. 메시의 정점 색상 인코딩으로 실제 GUI 비교에서 최대1/255의 채널 차이가 있다. 래스터 이미지로 굽거나 화풍·실루엣·프레임 수를 바꾸지 않는다.

캐시는 뷰당 최대64개이며 종/기본색/세부 표시/앞뒤 조각으로 구분한다. 개체 ID·HP·시각·보행 위상을 키로 쓰지 않는다. 새 개체별 노드·타이머·게임 상태·저장 필드는 없다. 피격 색상이 매 프레임 새 캐시를 만들지 않도록 실제 피격 중에는 기본 도형 경로를 사용한다. 기존 화면 밖 판정과 적 수·스폰·AI 주기·피해·보상은 그대로다. `cache_bodies`는 같은 화면의 A/B 검증용이며 기본값은 true, 저장/설정 UI에는 추가하지 않는다.

## 재현

모든 명령은 `/workspace/Viya`에서 저장소의 Godot4.7.2 활성화 후 실행한다. `XDG_CACHE_HOME`, `XDG_CONFIG_HOME`, `XDG_DATA_HOME`은 `/workspace/.viya-tools/godot-4.7.2/`의 cache/config/data를 사용한다. GUI는 실제 DISPLAY와 `--audio-driver Dummy --rendering-method gl_compatibility`가 필요하다. 사용자 저장 대신 `.local_validation/GAME063`의 별도 파일만 쓴다.

- `python3 tools/check_project.py --godot /workspace/.viya-tools/godot-4.7.2/bin/godot --output .local_validation/GAME063/check`: 기존10명령·7묶음·각120초와 실패 판정을 보존한 전체 검사.
- `godot --path . --audio-driver Dummy --rendering-method gl_compatibility --script res://tools/measure_dense_battle.gd -- --rounds=3`: 같은6저장/입력/시야의 동결 그리기와 고정1/60 갱신. 기본 도형/메시를 번갈아 실행한다. CPU 갱신·그리기 명령 준비·화면 제시 대기 포함 반복을 분리하고 원시 표본과 권위/7난수 해시를 저장한다. 239초는72갱신으로4분 경계를 지난다.
- `godot --path . --audio-driver Dummy --rendering-method gl_compatibility --script res://tests/render_enemy_shapes.gd`: 원래 도형 fixture와100개 자세/스타일의 실제 픽셀 대조.

자연 전투4저장은 GAME052의 기존 표본을 바이트 그대로 `tests/fixtures/game063`에 보존했다. 원래 전체 특성/시드7 표본은310.9초 패배였으며 정상 완주·최종 난도 승인 자료가 아니다. 640/1540은 기존 GAME050 합성 fixture다. GUI 반복 시간에는 프레임 스케줄링·다른 UI·소프트웨어 그리기/제시 대기가 포함되므로 순수 GPU 시간이나 사용자 Windows·모바일 FPS로 환산하지 않는다. 전체 결과와 현재 한계는 CURRENT/DEVELOPMENT_STATUS 및 GAME063_REPORT를 따른다.
