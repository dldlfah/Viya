# GAME068 재현

저장소 루트에서 실행한다. 원천 번호는0부터,디코딩 캐시 파일명은1부터다. 원출력34~50을 그대로 선택하며51은 제외한다. 준비 도구는 영상 전체를 실제 PTS로 디코딩한다.

```bash
python3 tools/higgsfield/prepare_game068.py --video tools/higgsfield/requests/game068/evidence/candidate_01.mp4 --out assets/characters/pilot_32/game068_s_run --decoded-dir .local_validation/GAME068/source_frames --start 34 --end 51 --scale 0.22916666666666666 --tx 1 --ty 0.3
python3 tools/higgsfield/measure_game068.py --delivery assets/characters/pilot_32/game068_s_run
python3 tools/higgsfield/preview_game068.py --delivery assets/characters/pilot_32/game068_s_run --output assets/characters/pilot_32/game068_s_run/provenance/art_review.mp4
```

실행된 격리 재현은 PNG17장과 원천/명목/기본속도CSV의 바이트 동일성을 확인했다. prepare_game068는 RGB 분리/고정 등록과 시간표,measure는 독립 랜드마크/위상/기술 명세를 만든다. 원출력/원본캐시/게임 데이터를 변경하지 않는다. 실제 엔진 리소스 빌드나 전투 검수 명령이 아니다. 흑/백/회색·끝→첫/캐릭터 비교의 시각 판단은 저장된 검토 파일도 함께 확인한다.
