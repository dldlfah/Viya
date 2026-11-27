# GAME070 입력 수정안 — SW 시점과 양발 교대 타이밍

후보 1의 43→44프레임에서 접힌 다리와 지지 자세가 급히 바뀐다. 시험 구간 38~49 안에도 이 변화가 있다. 후보 2의 34~38프레임에서 가까운 다리가 앞쪽 지지 자세를 취하고 39~41에서 회복하다가, 42~46에서 같은 다리의 지지 자세가 다시 나온다. 시작 이미지의 역할을 바꾼 두 번째 작업에서도 이 문제가 남았다. 저장소의 확대 시트는 문제 구간을 보여 준다. 전체 원본은 보관 ZIP의 다운로드 요청이 403으로 차단되어 이번 세션에서 다시 재생하지 못했다.

- [후보 1 확대 시트](evidence/candidate01_stride_detail.jpg)
- [후보 2 확대 시트](evidence/candidate02_stride_defect.jpg)
- [원본 검토 패키지](ARCHIVE.json)

## 준비한 입력

| 자료 | 사용할 정보 |
| --- | --- |
| `assets/characters/pilot_32/render_cache/viya_run_sw_00.png` | SW 고각과 화면 왼쪽 아래 진행 방향, 얼굴, 비대칭, 양손 낮은 총기 휴대 |
| `assets/characters/pilot_32/render_cache/viya_run_sw_08.png` | 같은 시점에서 보이는 반대쪽 장화와 무릎 위치의 비교 |
| [S17 타이밍 참조](../../../../docs/validation/GAME070_S_TIMING_REFERENCE.mp4) | 양발 지지·이탈·회복 순서와 템포 |
| [기존 SW 실제 게임 기준](../../../../docs/validation/GAME070_SW_BASELINE.mp4) | 현재 11장, 원래 표시 크기와 S↔SW 방향 전환 비교 |

타이밍 영상은 GAME068에서 채택한 RGB 원천 34~50번을 원본 24fps로 여섯 번 재생한다. 37번과 45번은 반대 지지 자세의 비교 지점이다. 102프레임의 순서를 원본과 대조했다. 전신의 실제 연속 자세를 보여 주는 타이밍 자료이며 화면 진행 방향은 S다. SW 방향과 투영은 기존 SW 이미지가 지정한다. 기존 SW 스틸 두 장에는 양발 교대 순서가 담겨 있지 않으므로, SW00과 SW08은 외형과 자세 비교에 쓴다.

## 다음 작업의 실행 조건

선택한 방식은 이미지에서 SW 외형과 카메라를 지정하고 영상으로 보행 타이밍을 지정하는 참조 구성이다. 지원되는 역할을 확인한 뒤 이 역할 구성을 그대로 표현할 수 있는 기능을 검토한다. 이전 조회의 `image_references`와 `video_references`는 별도 입력 필드였지만 영상의 방향을 무시한다는 보증은 없다. 새 결과에서 S 방향이 섞이면 SW 채택 기준에 미달한다. GAME070의 기존 2회 제출 범위는 소진됐으며, 이 자료 준비의 생성과 차감은 0이다.

생성용 핵심 지시

> Use the supplied SOUTHWEST image as the source for VIYA's identity, fixed high-angle view, screen-down-left orientation, asymmetric costume, and two-handed low carry. Use the reference clip for the timing and order of the alternating steps only. The projected torso, weapon and travel must continuously face screen down-left. Follow one near-leg support, one far-leg support, and then the next near-leg support, with a continuous recovery and transfer between them. Each leg takes one turn in the cycle. Keep the entire existing character on a fixed canvas with clear margins. Preserve the full-body SOUTHWEST silhouette and low carry throughout.

결과 검수는 같은 다리의 지지 자세에서 다음 같은 다리 지지 자세까지 본다. 그 사이 반대 다리가 정확히 한 번 지지하고, 회복에서 지지로 가는 중간 자세가 연속적이어야 한다. 마지막 장 다음에는 첫 장과 같은 운동 방향이 이어져야 한다. 자세를 눈으로 추적할 수 있는 프레임 번호를 적고, 같은 위상의 S↔SW 전환도 현재 게임 크기로 비교한다. 조건을 충족한 연속 주기에 한해 실제 원천 시간표, 프레임별 총구, 발 랜드마크, 고정 캔버스·기준점을 기록해 제작 세션에 납품한다.

[검증 기록과 참조 해시](../../../../docs/validation/GAME070_BASELINE_REPORT.json)
