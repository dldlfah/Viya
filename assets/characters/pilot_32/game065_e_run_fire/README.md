# GAME065 — VIYA E 전용 전신 이동사격

기존 GAME064 E 달리기와 같은 보행 위상을 사용하는 **47개의 실제 전신 이동사격 프레임**이다. 기존32동작·244프레임을 보존한 합성 리소스에 `run_fire_e`를 추가해 **33동작·291프레임**으로 연결한다. 생성 완료·파생물 기술 채택·게임 실행 검증·사용자 최종 아트 승인을 구분한다.

현재 상태는 **최종 RGBA 기술 QA PASS / 게임 적용 / 네이티브435검사·최종 정적 검사·실제 GUI1544검사 PASS / 최종 사용자 아트 승인 NOT_VERIFIED**다. [현재 작업](../../../../docs/CURRENT_WORK.md) · [통합 보고서](../../../../docs/validation/GAME065_INTEGRATION_REPORT.json).

## 파일과 표시 규격

| 항목 | 실제 값·경로 |
|---|---|
| 순서가 있는 PNG | `frames/viya_run_fire_e_000.png` ~ `viya_run_fire_e_046.png` |
| 개수·형식 | 47개, 서로 다른200×248 RGBA PNG |
| 리소스 | [viya_game065_frames.tres](viya_game065_frames.tres) |
| 해시·동작·프레임 명세 | [manifest.json](manifest.json) |
| 개별 표시 시간 | [provenance/frame_timing.csv](provenance/frame_timing.csv), `duration_ms` 열 |
| 명목 한 주기 | 660ms, 개별7.603777~17.332793ms의 가변 시간 |
| 게임 표시 | 69×85.56, 원본 종횡비 유지 |
| 캔버스 기준점 | (100,248), 정규화(.5,1), 모든 프레임 동일 |
| 이동·보행 거리 | 초당235월드 / 주기당155월드 |
| 거리 기반 주기 | 155÷235초 =659.574468ms |
| 기존 달리기 대비 등록 | 주기 전체 X−1캔버스픽셀 =표시−0.345픽셀, Y변경0 |
| 총구 | [provenance/muzzle_landmarks.json](provenance/muzzle_landmarks.json), 실제47개 프레임별 좌표 |

프레임 수47은 출력의 전체 위상과 기준 E 보행 대응을 검사한 결과다. 원본 source0,2,…92를 선택하고 다음 주기 시작94를 끝에 복제하지 않았다. 각 프레임의 `source_frame`, 시작 시간, duration, 정규화 위상, 기존 달리기 대응은CSV에 있다. 하나의 고정 변환만 사용하며 알파 외곽 크기에 따라 각 프레임을 지면으로 당기지 않는다. 고정 변환은 scale0.26247288503253796, translation(11.334056399132322,−46.39479392624729)이며 원본 지면y1108은 캔버스y244.42516269에 해당한다. 캔버스 pivot과 영상 속 지면은 서로 다른 기준이다.

## 모델·출처와 원본/파생물 판정

Higgsfield **Seedance2.5 (`seedance_2_5`)**의 `video_edit`,720p, `generate_audio=false`, `bitrate_mode=high`,1개 출력을 사용했다. 영상 참조와 원본 길이 유지가 지원됐고, 노출된 설정에 네이티브 알파 PNG 시퀀스 필드는 없었다. 실제 채택 출처 영상은720×1280/24fps/97프레임/4.041667초의 알파 없는 MP4다. PNG의 투명도는 별도 파생 준비 결과다.

| 생성 | 작업 ID | 관측 차감 | 판정 |
|---|---|---:|---|
| 후보1 | `163de9a9-72ef-459e-8953-11cb99e3a104` | 31 | 원본 납품 거절, 후속 편집 입력으로 보존 |
| 후보2 | `d1817f67-fb19-4b70-b4a9-605f82981497` | 31 | 원본 납품 거절, 최종 RGBA 파생물의 출처 |
| 후보3 | `293f45c6-1226-4a36-8b44-617fdad53850` | 31 | 잔존 섬광·룬 색 변화로 탈락 |

총93크레딧이며 조회 잔액은966.25→935.25→904.25→873.25다. [최종 재조회](../../../../tools/higgsfield/requests/game065/evidence/balance_final.json)에서도873.25를 확인했다. 새 결제·자동 충전·요금제 변경은 없다. 최초 입력은 채택된 GAME064 원본 작업 `fbf2fd2d-8596-4ca4-87e7-875712a2f7c9`, 후보2는 후보1의 영상 편집이다. 정확한 제출 설정·견적·출력 해시·입력 계보·잔액은 [production.json](provenance/production.json)과 [원본 서비스 증거](../../../../tools/higgsfield/requests/game065/evidence/)를 따른다. 후보2 원본 MP4 SHA256은 `688216786b493658922568c6f010c0b5bb5c9a77481c9b9488f0cfe320e9cef6`다.

후보2 원본에는source13~16/60~63의8개 섬광 프레임이 있다. 최종 선택47장에 포함되는14/16/60/62는 외부 효과를 알파로 제거했다. 초기 처리의 총열 금속 손실도 거절한 뒤, 깨끗한 왼쪽 녹색 배경을 추정하고 같은 프레임의 관측 금속 영역을 외부 효과 마스크에서 보호해 수정했다. 일반 배경 알파 처리는 계속 적용하며, 불투명 사각형·새 금속 그림·부위 복사·몸 변형은 넣지 않았다. 원본의 작은 따뜻한 반사색은 그림으로 남아 있으며 외부 섬광 형상과 구분한다.

[최종 기술 QA](provenance/review/final_qa.json)는 최종 파생47장만 채택한다. 원본 영상의 `REJECTED_FOR_DELIVERY`, 초기 알파 시도의 금속 손실, 후보3 탈락을 최종 승인으로 바꾸지 않는다. [frame_preparation.json](provenance/frame_preparation.json)의 `PREPARED_FOR_REVIEW_NOT_APPROVED`는 검토 전 제작 기록이며, 이후 판정은 최종QA/production.json에 기록한다.

## 게임에서 사용하는 방식

기존 `viya_battle` 슬롯이 이 합성 SpriteFrames를 사용한다. **E 방향을 바라보는 이동 상태에서 실제 발사를 관측한 창에서만** 이동사격 전신 프레임을 선택하고, 일반달리기와 같은 누적 거리 위상을 가변 duration에 매핑한다. 사격 시작/해제 때 위상을0으로 되돌리지 않으며 후진은 기존 거리 위상 역증분을 따른다. 두 자세 사이의 별도 보간 전환 애니메이션은 추가하지 않았다.

실제 총탄·엔진 섬광·기본0.3초 발사 간격·피해는 기존 전투 코드가 소유한다. 프레임마다 측정한 새 총구 좌표를 사용하며, 영상의 어깨/총 자세를 모든 실탄과1:1 동기화했다고 주장하지 않는다. 정상 로드된 합성 리소스에서 선택적 `run_fire_e` 클립/메타데이터가 없으면 같은 위상의 일반 달리기를 사용하고, 불투명 임포트는 실제 PNG로 복구를 시도한다.

GAME064의32동작·244프레임은 순서·PNG 경로·속도·duration·loop를 보존한다. 새 리소스의 상대 경로만 이전 자산을 올바르게 가리키도록 연결한다. 원본208PNG/원본SpriteFrames, ARTFIX001 캐시208PNG/리소스, [GAME064 E47/리소스](../game064_e_run/README.md)를 수정하거나 흰 테두리 작업을 재실행하지 않았다. 다른7방향·정지공격·단일RunState·저장22·7난수·게임플레이 수치는 유지한다.

## 검토 자료와 검증 범위

- [반복 검토 영상](../../../../docs/validation/GAME065_LOOP.mp4):600×440/240fps/792프레임/3.3초, 명목5주기.
- [동일 위상 전환 비교 영상](../../../../docs/validation/GAME065_MODE_SWITCH.mp4): 실제 프레임/가변 시간표로 만든 자산 비교. 게임 실행 영상이 아니다.
- [최종 독립 QA](provenance/review/final_qa.json):47개 고유 RGBA/200×248·외곽 알파0·고정 변환·교대 접지/회복·92→0·총열/전체 몸 보존 PASS. 검토자는 사용자 최종 아트 승인을 부여하지 않았다.
- [네이티브 보고서](../../../../docs/validation/GAME065_NATIVE_REPORT.json): Godot4.7.2 `test_run_navigation.gd`435검사 PASS·실패0·29.6309초/120초 제한, GAME065 신규18검사 포함.
- [최종 정적 보고서](../../../../docs/validation/GAME065_STATIC_REPORT.json):182파일/596참조·6계약, 전투99파일·변이125거부 PASS. [실제 임포트 RGBA47장](../../../../docs/validation/GAME065_IMPORT_REPORT.json)과 저장 PNG의 픽셀도 모두 같다.
- [실제 게임 영상](../../../../docs/validation/GAME065_GAMEPLAY.mp4):1280×720/60fps/208프레임/3.466667초, 이동사격160프레임과 사격 해제48프레임 발췌. [전체 통합 보고서](../../../../docs/validation/GAME065_INTEGRATION_REPORT.json): Linux X11/Mesa llvmpipe OpenGL4.5·Godot4.7.2에서1544검사/489그리기 PASS. 일반달리기47개/이동사격47개 각각4회 반복, 이동 중 실제9발, 사격 해제48단계의 같은 위상 복귀, 후진48/48·정지공격·일시정지를 확인했다.

실제 키 이벤트·고정1/60초 갱신의 렌더 검증이며 실시간FPS 측정은 아니다. VSync 미지원 경고·Dummy 오디오 환경을 기록했고 스크립트/리소스 오류·누수는 없었다. 초기 검증 경로의 병영 충돌로 생긴 기대118실패는 이력으로 남기고, 런타임 변경 없이 시작점 수정 후 재검증했다. 기존 게임/데이터/자산1188파일 중1185개가 바이트 동일하고 표시 코드/설정3개만 변경됐다. 과거 GAME064 전체4,465검사를 이번 소스의 전체 재실행으로 취급하지 않는다.

최종 같은 위상 비교의 발끝 표식 차이는 최대0.533842표시픽셀, 최종 래스터 발바닥 경계 차이는0.711236픽셀이다. 이는 이미지 기반 측정이며 골격 동일성·정지한 발의 완전 무미끄러짐을 증명하지 않는다. 최종 사용자 아트 승인과 실제 오디오·Windows/모바일·실시간FPS/발열은 NOT_VERIFIED다.

## 파생물·리소스 재현

저장소 루트에서 보존된 후보2 RGB MP4를 디코딩하고 동일한 위상표·금속 보호 영역·고정 변환으로 다시 준비한다. FFmpeg와 Python의 Pillow·NumPy·SciPy, 미리보기용DejaVuSans가 필요하다. 준비/측정 결과는 별도 작업 폴더에 쓰며 원본 제작·검토 JSON은 보존한다. 아래 명령은 새 외부 생성을 요청하지 않는다.

```bash
VIYA_GAME065_ASSET="assets/characters/pilot_32/game065_e_run_fire"
VIYA_GAME065_WORK=".local_validation/GAME065_REBUILD"
mkdir -p "$VIYA_GAME065_WORK/decoded"
ffmpeg -n -i "$VIYA_GAME065_ASSET/provenance/originals/d1817f67_source_rgb.mp4" -map 0:v:0 -fps_mode passthrough -start_number 1 "$VIYA_GAME065_WORK/decoded/frame_%03d.png"
python tools/prepare_viya_game065.py --decoded "$VIYA_GAME065_WORK/decoded" --source-map "$VIYA_GAME065_ASSET/provenance/source_phase_map.json" --out "$VIYA_GAME065_WORK/prepared" --scale 0.26247288503253796 --tx 11.334056399132322 --ty=-46.39479392624729
python tools/measure_viya_game065.py --prepared "$VIYA_GAME065_WORK/prepared" --reference-timing assets/characters/pilot_32/game064_e_run/provenance/frame_timing.csv --out "$VIYA_GAME065_WORK/measured"
cmp "$VIYA_GAME065_WORK/measured/frame_timing.csv" "$VIYA_GAME065_ASSET/provenance/frame_timing.csv"
cp "$VIYA_GAME065_WORK/prepared/frames_200x248/"*.png "$VIYA_GAME065_ASSET/frames/"
python tools/build_viya_game065.py --source-job d1817f67-fb19-4b70-b4a9-605f82981497 --model seedance_2_5
```

디코드 파일 이름은1부터 시작하며 실제 `source_frame`0은`frame_001.png`다. 시간표/총구 재측정은 위상 대응을 새로 승인하는 절차가 아니므로 저장된 독립 QA 근거와 함께 검토한다. PNG/CSV가 이미 준비됐다면 마지막 빌더 명령만으로 합성 리소스/manifest를 다시 만들 수 있다. 빌더는 원본 PNG·게임 설정을 변경하지 않는다.

다음 범위는 E 이동사격 결과의 검토와 확인된 E 수정이며 다른 방향·새 적을 자동 제작하지 않는다.
