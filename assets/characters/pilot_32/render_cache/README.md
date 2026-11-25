# VIYA 표시용 테두리 보정 자료

CHARACTER-PILOT-032의 기술적 표시 파생물이다. 원본208PNG와 원본SpriteFrames는 상위 frames/textures/resources에 보존한다. 표시용200×248 전체 해상도·알파와32동작/순서/타이밍은 원본과 같다. 투명 경계 부근의 밝은 무채색 매트 RGB와 투명 여백 색만 정리하며 실제 내부 아이보리/피부/금속 색상과 선명도를 유지한다.

루트에서 고정 Godot4.7.2와 설정된 XDG 경로로 `godot --headless --path . --script res://tools/build_viya_render_cache.gd` 후 `godot --headless --path . --editor --import --quit`를 실행한다. manifest는 도구·원본·출력 해시를 포함한다. 일반 게임 실행은 이 도구를 실행하지 않고 기존 비야 한 슬롯으로 미리 만든 프레임을 읽는다. 원본 Resource를 게임에 추가로 바인딩하지 않는다. GAME062_REPORT와 CHARACTER_PILOT_032 문서가 구현/실기 검수 경계의 기준이다.
