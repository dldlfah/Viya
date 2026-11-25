# Higgsfield 공식 API 실행기

대화용 Higgsfield 플러그인 도구가 없는 환경에서 공식 Python SDK로 같은 서비스를 호출하는 경로다. 플러그인을 설치하거나 대화의 도구 목록을 활성화하는 기능은 아니다.

현재 SDK0.2.0 설치와 로컬 검사 완료, 실제 연결/생성은 인증·네트워크 대기 상태다. API 기본 주소 `https://api.higgsfield.ai`는 공식 SDK 소스에서 확인했다. 현재 환경에는 인증 값이 없고 API 호스트 연결은 프록시의 CONNECT403으로 차단됐다.

## 인증과 접근

1. [Higgsfield Cloud](https://cloud.higgsfield.ai/)에서 API 인증 정보를 준비한다. 이 실행 경로는 공식 SDK의 **Agent API**를 사용하므로 계정에 해당 접근 권한과 크레딧이 필요하다. 현재 계정 권한/잔액은 미확인이다.
2. 환경 설정의 비밀 값 `HF_KEY`에 `API_KEY:API_SECRET` 형식으로 등록한다. 실제 값은 채팅·Git·명령 인자에 넣지 않는다. SDK는 기존 `HF_API_KEY`+`HF_API_SECRET` 조합도 지원한다.
3. `api.higgsfield.ai`의 HTTPS 접근을 허용하고 설정을 저장한다. 키 전달 대상은 API 호스트 하나로 제한한다. 미디어 업로드/결과 호스트는 실제 API가 반환한 목적지를 확인해 필요한 접근만 추가한다. 인증 헤더를 미디어 호스트에 복사하지 않는다.

앱 태그·스킬의 사용 허용·SDK 설치·인증 값의 존재는 실제 계정 인증 성공을 뜻하지 않는다. 실제 서비스 응답을 확인하기 전에는 연결/생성 성공으로 보고하지 않는다. 새 계정/결제·자동 충전·요금제 변경은 하지 않는다.

## 설치와 실행

저장소 루트 `/workspace/Viya`에서 실행한다.

```bash
bash tools/higgsfield/install.sh
bash tools/higgsfield/run.sh check
bash tools/higgsfield/run.sh submit --journal .local_validation/higgsfield/e_run00_trial1.json
bash tools/higgsfield/run.sh poll --journal .local_validation/higgsfield/e_run00_trial1.json
```

설치는 별도 `/workspace/.viya-tools/higgsfield-0.2.0/venv`에 하고 공식 SDK 및 의존성8개의 버전/해시를 검증한다. `VIYA_HIGGSFIELD_ENV`로 해당 가상 환경 경로를 지정할 수 있다. `check`는 인증 값의 유무만 확인하며 서비스 인증을 수행하지 않는다.

기본 입력은 `tools/higgsfield/request` 자료다. 제작 원본12장은 현재 환경의 비공개 입력으로 보관하고, 프롬프트/해시 명세와 실행 코드는 Git으로 보존한다. `.gitignore`는 원본 입력을 Git에서, `.gdignore`는 도구 자료를 게임 임포트에서 제외한다. 새 환경에 원본이 없으면 기존 업로드 ZIP에서 복원해야 한다. 대상 E달리기0번400×496, 디자인 참고 E대기1600×1984, 인접1·10번의 네 PNG를 원본 해시와 대조해 전송한다. 다른 입력은 `--packet`으로 지정하되 같은 역할/파일 해시 명세를 갖춰야 한다. 기존 원본/게임 파일은 덮어쓰지 않는다.

`submit`은 원본 한 프레임 보정 시험을 요청하고 반환된 세션/메시지 ID를 기록한다. 한 장이라는 지시는 요청 범위이며 서비스의 비용/모델 실행 상한을 구현한 것은 아니다. 실제 모델·비용·결과 품질은 서비스 응답을 확인해 기록해야 한다. Agent API 권한 부족/크레딧 부족은 별도 실제 서비스 응답으로 판별한다.

기존 journal이 있거나 제출 응답이 불명확하면 재제출하지 않고 `poll`로 상태를 확인한다. 서비스가 질문하면 private journal의 `agent_text`를 검토하고 필요한 답만 제공한다. `FAILED_BEFORE_SEND`는 생성 전 실패이며 원인을 해소한 뒤 새 journal로 재시도할 수 있다. 자동 결제 재시도/자동 구매는 없다. 기록은 `.local_validation` 아래0600권한으로 저장한다. 결과 URL은 미검증 자료로 보관하고 자동 다운로드/게임 연결은 하지 않는다. 결과를 확인한 뒤 원화/투명도·수정 범위·발/총구 등록과11장 연속성, 실제 게임 표시를 검증한다.

## 검증 범위

공식 SDK import, 해시 고정 설치, 실제 입력 해시 검사와 오프라인8검사를 확인했다. 인증 누락 시 서비스 요청을 보내지 않으며, 제출 타임아웃 후 중복 호출과 원치 않는 게임 자산 교체를 막는다. API 인증/원화 생성과 비용은 아직 미실행이다.

```bash
/workspace/.viya-tools/higgsfield-0.2.0/venv/bin/python -m unittest discover -s tests -p 'test_higgsfield_bridge.py'
```
