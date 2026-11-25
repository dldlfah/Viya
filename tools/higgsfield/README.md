# Higgsfield 원화 제작·재현 도구

## 현재 결과 — ARTFIX001

실제 연결된 Higgsfield 도구로 비야 E 달리기11장의 투명 PNG를 생성하고 검증한 제한 영역을 활성 게임 캐시에 적용했다. 모델은 `gpt_image_2_6`, high/1k·800×992·PNG·transparent이며 입력은 각 기존 원본 프레임이다. 최초 시험1건 실패 후11건이 완료됐다. 잔액 조회 차이는13.75크레딧이고 새 결제/요금제 변경은 없다. 실제 작업 ID·입력/출력 해시·설정·견적은 [service_job.json](request/service_job.json)과 [generation_log.json](../../assets/characters/pilot_32/edge_repair/generation_log.json)에 기록한다.

생성 결과 전체를 캐릭터로 교체하지 않고 원래 디자인·포즈를 유지하는 경계색/배경 틈 수정으로 합성했다. 원본208장과 다른 표시197장은 변경하지 않았다. [수정 패킷](../../assets/characters/pilot_32/edge_repair/README.md)·[현재 검증 보고서](../../docs/validation/ARTFIX001_REPORT.json)를 따른다. 아래 공식 SDK의 과거 인증·접근 차단은 이번 연결 도구의 생성 완료와 별개다.

## 검증본 재현

`build_edge_repair.py`는 보관된 원본·baseline·생성본을 읽어 합성본·마스크를 별도 출력 폴더에 재현한다. 검증된 입력/출력 해시를 확인하고 승인 패킷을 자동 덮어쓰지 않는다. Python 의존성은 Pillow/NumPy/SciPy이며 실제 재현 버전은 수정 패킷 `manifest.json`에 기록한다.

저장소 루트에서 실행한다.

```sh
python3 tools/higgsfield/build_edge_repair.py --out .local_validation/higgsfield_rebuild
godot --headless --path . --script res://tools/build_viya_render_cache.gd
godot --headless --path . --editor --import --quit
```

첫 명령의 합성본·마스크·등록본44개 파일이 보관된 결과와 일치했다. 캐시 생성기는11장 전체의 해시/수정 범위를 검사하고 Godot `fix_alpha_edges()`로 경계색을 정규화한다. 최종 E11 저장 PNG와 임포트 RGBA 일치를 확인했다. 원래 표시69×85.56·캔버스200×248·32동작·E달리기60ms×11과 전투 수치는 유지하며 일반 게임은 미리 만든 캐시를 사용한다. 실제 GUI/Windows·모바일·최종 아트 승인은 별도다.

## 공식 SDK 경로 — 이전 연결 준비

대화용 Higgsfield 도구가 없던 세션에서 준비한 공식 Python SDK 실행기다. 플러그인 설치/활성화 도구가 아니며 ARTFIX001 생성에는 위 연결 도구를 사용했다. 당시 SDK0.2.0 설치·로컬 검사를 마쳤으나 인증 값 부재/API CONNECT403으로 실제 SDK 제출은 하지 않았다. [당시 검사 기록](../../docs/validation/HIGGSFIELD_CONNECTION_20261126.json)을 현재 전체 서비스의 차단 상태로 해석하지 않는다.

이 SDK 경로를 별도로 사용할 때는 [Higgsfield Cloud](https://cloud.higgsfield.ai/)의 Agent API 접근 권한·크레딧과 `https://api.higgsfield.ai` 접근이 필요하다. 환경 설정의 `HF_KEY`에 `API_KEY:API_SECRET`을 등록하거나 SDK가 지원하는 `HF_API_KEY`+`HF_API_SECRET`을 사용한다. 실제 값은 채팅·Git·명령 인자에 저장하지 않는다. 키 존재나 SDK 설치를 계정 인증 성공으로 간주하지 않으며, 실제 서비스 응답으로 확인한다. 인증 헤더를 미디어 업로드/결과 호스트에 복사하지 않는다.

```bash
bash tools/higgsfield/install.sh
bash tools/higgsfield/run.sh check
# 새로 승인된 SDK 작업만 별도 journal로 제출한다. 완료된 ARTFIX001을 재제출하지 않는다.
bash tools/higgsfield/run.sh submit --journal .local_validation/higgsfield/new_request.json
bash tools/higgsfield/run.sh poll --journal .local_validation/higgsfield/new_request.json
```

설치는 별도 `/workspace/.viya-tools/higgsfield-0.2.0/venv`에 하고 공식 SDK/의존성8개의 버전·해시를 검증한다. `VIYA_HIGGSFIELD_ENV`로 경로를 지정할 수 있다. `check`는 인증 값 존재만 확인하며 서비스 인증을 수행하지 않는다.

SDK의 기존 기본 입력은 `tools/higgsfield/request`의 E달리기0번·E대기 디자인·인접1/10번 네 PNG 역할/해시 명세다. 당시12master 입력의 `references`는 비공개·Git 제외 경로이고, 이번 수정에 사용한11원본은 별도 `edge_repair/native`에 보존했다. 새 환경에서 SDK 입력이 없으면 기존 원본 패키지와 명세로 복원한다. `--packet`은 같은 역할/파일 해시 명세를 요구하며 원본/게임 파일을 자동 덮어쓰지 않는다.

기존 journal이나 불명확한 제출 응답이 있으면 재제출하지 않고 `poll`로 확인한다. `FAILED_BEFORE_SEND`는 전송 전 실패 기록이다. 한 장 요청은 작업 범위이며 서버 비용 상한을 구현한 기능이 아니다. 기록은 `.local_validation`에0600권한으로 보관하고 결과 URL을 자동 신뢰·다운로드·게임 교체하지 않는다. 실제 모델/비용·투명도/디자인·발/총구/캔버스 등록·인접 프레임/루프를 확인한 뒤 적용한다. 새 결제·자동 충전·요금제 변경은 하지 않는다.

SDK의 import/버전·해시/인증 누락 처리·중복 제출 방지·오프라인8검사는 당시 확인했고, 현재 전체Python20도 통과했다. SDK 자체의 실제 계정 인증/생성은 미검증이며 연결 도구의11장 완료 기록과 구분한다.

```bash
/workspace/.viya-tools/higgsfield-0.2.0/venv/bin/python -m unittest discover -s tests -p 'test_higgsfield_bridge.py'
```
