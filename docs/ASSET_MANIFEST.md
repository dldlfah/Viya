# VIYA — 아트·제작 자산 원본 목록

이 문서는 이미지의 **명칭·승인 근거·파일 저장 위치·실제 등록 여부**를 구분한다.

| 식별자 | 대화에 존재하는 원본 파일 | 용도 | 상태 | 원격 GitHub 원본 |
| --- | --- | --- | --- | --- |
| ART-001 | `a_highly_detailed_layered_production_modeling_d.png` | 승인된 비야 캐릭터 방향 | 캐릭터 디자인 승인 | 등록 전/확인 필요 |
| ART-002 | `비야의_최후의_성벽_방어.png` | 모바일 서바이버 UI 구상(환경설정·스킬 2줄·필살기) | 기획 레이아웃 참고 | 등록 전/확인 필요 |
| ART-003 | `브레이커스_최후의_도시_세계관_보드.png` | 기존 브레이커 세계관 시각 참고 | 참고안 | 등록 전/확인 필요 |
| ART-004 | `비야_캐릭터_모델링_제작_시트.png` | 3D 모델링 분해 참고 | 제작 시트, 미검증 | 등록 전/확인 필요 |
| ART-005 | `piclumen-1794848217496.png` | 비야 키비주얼 생성 결과 | 참고 이미지, 모델 아님 | 등록 전/확인 필요 |

원본 PNG를 GitHub에 추가할 때는 경로를 `assets/references/<명칭>.png`로 기록하고 해시·해상도·출처(대화 생성/사용자 첨부)·사용권한을 명시한다. **이 문서만으로 이미지가 GitHub에 등록됐다는 뜻이 아니다.**

라이선스와 각 이미지 생성 서비스의 상업적 이용 약관은 실제 배포 전에 별도 확인한다. 원본 BREAKERS 프로젝트 자산을 복사할 경우에는 프로젝트 경계를 유지하며 승인 자산만 복사한다.

## 원본 무결성 식별값 (SHA-256)

- `ART-001`: `ccf3c90ea8383e0fe8eec95380bec181d9485e5d29196bb856dbe5c7bcd974d0`
- `ART-002`: `4640c244ca10352c4f7709a0187652ae5f261a802051f7fcda5bc2693f7de7a5`
- `ART-003`: `740072b33d70c0e8e227fba575abd1d56325993f62ffd3c7a173252d2ab34368`
- `ART-004`: `94978de2e081fcd2f9c6356b57b4d66a5e6683432447f1d0f0faa68a59bf5a28`
- `ART-005`: `e18743701e2fa303a458e29af5caf80d791d25ac8ba3121ea347172469da47aa`

**등록 현황(2026-11-17):** GitHub 커넥터의 이 작업 경로는 텍스트 파일을 등록했으며, **원본 PNG 5개는 아직 GitHub에 추가되지 않았다.** 대화 산출물에 원본 PNG 묶음 ZIP을 준비했으나 해당 ZIP 파일이 GitHub 커밋에 포함된 것은 아니다. 업로드 후 GitHub 경로를 확인하고 상태를 갱신한다.


## 2026-11-17 외부 제작 파생 자산
| 식별자 | URL 및 제작 작업 | 결과 | GitHub 바이너리 |
| --- | --- | --- | --- |
| GEN-001 | [Higgsfield A포즈 PNG](https://d8j0ntlcm91z4.cloudfront.net/user_3LHdo37hN3iiYXd8WT9stnWXw4M/hf_20261116_174554_5a7ff135-f678-489d-98af-4acab0f49863.png) · 작업 `5a7ff135-f678-489d-98af-4acab0f49863` | 생성 완료 / ART-001과 별도 파생 레퍼런스 | 미등록 |
| 3D-001 | Tripo H3.1 작업 `9a92414f-5d95-4cda-a71e-a8f70b7b39e8` | 실패, GLB 없음 | 해당 없음 |
| 3D-002 | [Meta SAM 3D GLB](https://d8j0ntlcm91z4.cloudfront.net/user_3LHdo37hN3iiYXd8WT9stnWXw4M/hf_20261116_180300_b659d5ce-0b95-4e98-b234-1f9361fd8a19.glb) · 작업 `b659d5ce-0b95-4e98-b234-1f9361fd8a19` | 실제 GLB 생성, **시각 미합격** / 비리깅 임시 프로토타입 | 미등록 |

링크는 Higgsfield 제공 결과 링크이며 GitHub 저장소의 바이너리 파일을 의미하지 않는다. 서비스 보존 기간과 다운로드 지속성은 별도 확인 필요.


## 신규 4방향 원화 및 2026-11-17 검수 자산

| 식별자 | 원본 | 방향/성격 | 검수 상태 | GitHub 원본 등록 |
| --- | --- | --- | --- | --- |
| GEN-002 | [좌측면 PNG](https://d8j0ntlcm91z4.cloudfront.net/user_3LHdo37hN3iiYXd8WT9stnWXw4M/hf_20261116_183253_37f25fe8-c018-4785-84fb-06124d02152e.png) | 1792×2400 / 왼쪽 측면 | 생성 PASS, 부품 정합 FAIL | 미등록 |
| GEN-003 | [후면 PNG](https://d8j0ntlcm91z4.cloudfront.net/user_3LHdo37hN3iiYXd8WT9stnWXw4M/hf_20261116_182525_159e8ce3-fe40-4de5-bcae-103d5ecaa5ef.png) | 1792×2400 / 뒷면 | 생성 PASS, 가려진 부위 정합 미검증 | 미등록 |
| GEN-004 | [우측면 PNG](https://d8j0ntlcm91z4.cloudfront.net/user_3LHdo37hN3iiYXd8WT9stnWXw4M/hf_20261116_183252_b00b3827-726c-4c03-b934-690eadc98d03.png) | 1792×2400 / 오른쪽 측면 | 생성 PASS, 부품 정합 FAIL | 미등록 |
| QA-001 | [4방향 실측 시트](../assets/references/qa/viya_4view_alignment_preview.jpg) | 파일 전체 크기가 아닌 축소판, 비율·축 위치 검수 | 측정·시트 생성 PASS | **등록 완료** |
| QA-002 | [좌우 대조 이미지](../assets/references/qa/viya_side_silhouette_comparison.jpg) | 왼쪽 미러링 대조(부품 구조 결정 기준 아님) | 측정 PASS / 시각 미합격 | **등록 완료** |

[원본 4방향 PNG·원본 외곽 측정 JSON 및 전체 크기 QA JPG를 포함한 ZIP](https://d2ol7oe51mr4n9.cloudfront.net/user_3LHdo37hN3iiYXd8WT9stnWXw4M/68bc52c2-9a6a-4b56-beb7-e9cce87668da.zip) · [검수/모델링 기준 상세](VIYA_TURNAROUND_QA_20261117.md).

전후 관계: `ART-001`만 사용자 승인 원화 방향. `GEN-001..004`는 그 승인 디자인에서 파생된 4방향 작업용 이미지이며, **원화 최종 치수와 의상 분해 정합성은 여전히 미승인**. 원본 및 전체 비교 ZIP을 GitHub에 올렸다는 주장은 금지.

## 2026-11-22 — 비야 3/4 정면 전투 포즈 시안

| 식별자 | GitHub 원본 | 용도 | 상태 |
| --- | --- | --- | --- |
| `GEN-005` | [GEN-005_viya_combat_pose_three_quarter_front.png](../assets/references/GEN-005_viya_combat_pose_three_quarter_front.png) | 로비 대표 일러스트 후보, 전투 HUD 기본 초상화 참고 | PNG 원본 등록, 최종 채택 승인 대기, 게임 화면 미연결 |

- 출처는 사용자 첨부 `비야 캐릭터 모델링 제작 시트(2).png`를 참조해 채팅에서 생성한 `비야의 다크 판타지 전투 포즈.png`다.
- 원본은 PNG RGB **1024×1536**, **1,921,148바이트**다. SHA-256은 `d3c0084c73aff9a706a50a6cac760d124c0647d23fa36e6ae30635dc6929a730`이다.
- 사용 권한은 사용자 지시에 따른 Viya 저장소 등록이다. 상업 배포 권한은 별도 검토 대상이다.

## 2026-11-24 — MAP-PILOT-001 사용자 맵 파일럿

사용자가 `VIYA_map_pilot_01.zip`의 구성·호환성 검토 뒤 ‘작업해’로 시범 적용을 지시했다. 준비 PNG3개를 프롤로그 기본 고각 화면에만 연결했다. **시범 적용 허용이며 최종 아트 승인으로 간주하지 않는다.** ART001/GEN005/3D·캐릭터 승인 경계는 그대로다. 입력 ZIP SHA256은 `6c200744a153aff6f99f107443b1efc5d3e6e373ee164a95568ccfc5d9cb7ab9`다.

| 파일 | 실제 등록 경로 | 규격 / SHA256 |
| --- | --- | --- |
| 바닥 | [stone_floor_tile.png](../assets/maps/pilot_01/stone_floor_tile.png) |224×160 RGB / `9beefd01712a5c45b71908ad679d105b00a7ce6b99e61a639e384b7de06257e6` |
| 성벽 앞면 | [wall_segment.png](../assets/maps/pilot_01/wall_segment.png) |192×244 RGB / `15b4a1a6f64b88df88424075d6710c0761cac7e7ac30dfc3ff889d0b3705d11a` |
| 정상 상자 | [prop_crate.png](../assets/maps/pilot_01/prop_crate.png) |92×86 RGBA / `7a0fefb9f935a5026e1bb9ded4029542e9f33323bbac87481f22144ece712edc` |

준비 PNG는 업로드 원본과 바이트 동일하다. 생성 로그의 Higgsfield 표기는 동봉 출처 기록이며 이번 세션에서 재생성·유료 호출하지 않았다. 대형 masters/준비 스크립트는 게임에 복사하거나 실행하지 않았으며 출처 명세/ZIP 식별은 [자산 README](../assets/maps/pilot_01/README.md)와 [원본 manifest](../assets/maps/pilot_01/source_manifest.json)에 남겼다.3개의 Godot2D 임포트 설정을 보존했다. 코드/검증은 CURRENT·DEVELOPMENT_STATUS8.34를 따른다.

## 2026-11-24 — MAP-PILOT-002 사용자 맵 파일럿 추가

사용자선택으로기존프롤로그고각에3종을추가했다. 시범적용이며최종아트/실기승인은아니다. ZIP SHA256 `49557ccb6ed1efb40341004da82518438fe077aa8f25cdfad33598005637e24f`. 기존파일럿01·공용53빈칸/다른맵/F8·캐릭터승인경계를유지한다.

| 파일 | 실제 등록 경로 | 규격 / SHA256 |
| --- | --- | --- |
| 폐허 수직 앞면 | [ruin_block.png](../assets/maps/pilot_02/ruin_block.png) | 192×130 / `1cfc847408ab4cdf6783f1dcc1c13db5251187fc4525afd4f0bdaaf991b7d9a2` |
| 정상 항아리 | [prop_urn.png](../assets/maps/pilot_02/prop_urn.png) | 92×86 / `81973f42653a6a3008ff11aaf5f18b1c4aaf6389577d1c8c1248aaf4b1feb94e` |
| 정상 잔해 더미 | [prop_debris.png](../assets/maps/pilot_02/prop_debris.png) | 92×86 / `ab0cccf2713543f0bd127a7f76ef1a4854695473ba7f0eca58bc1f919fe4b9d5` |

준비PNG3개/51025바이트는업로드원본과동일하다. 3개의2D무손실임포트설정·[출처README](../assets/maps/pilot_02/README.md)/[원본명세](../assets/maps/pilot_02/source_manifest.json)를보존했다. 동봉준비스크립트/생성작업을실행하거나대형masters를런타임에복사하지않았다. 원본명세의c412d1d/후보상태는제작당시출처기록이고현재게임적용결과와구분한다. 검증은DEVELOPMENT_STATUS8.37을따른다.

## 2026-11-24 — MAP-PILOT-003 윗면·닫힌 성문

사용자 선택으로 프롤로그에3종을 추가해 맵 파일럿 총9종을 연결했다. 시범 적용이며 최종아트/실기 승인은 아니다. ZIP SHA256 `887357f23b29a1226d6d49190fd58de113ea67039be75fa09be22cd411e60864`. 동봉HASHES28항목을검토했다. 기존6PNG·공유53빈칸·캐릭터/다른맵/F8을유지한다.

| 파일 | 실제 등록 경로 | 규격 / SHA256 |
| --- | --- | --- |
| 성벽 윗면 | [wall_top_tile.png](../assets/maps/pilot_03/wall_top_tile.png) | 192×160 RGB / `77173228a87824927c1d01f17b62bcaaf4a855fe39d8e5132c03f1eb5a3a4c33` |
| 폐허 윗면 | [ruin_top_tile.png](../assets/maps/pilot_03/ruin_top_tile.png) | 192×160 RGB / `b99c7efffbbad26c8fe9ce3a7c84014faf3c2cd069d46ca5662b26b314cfb127` |
| 닫힌 성문 앞면 | [gate_front.png](../assets/maps/pilot_03/gate_front.png) | 480×228 RGB / `a0f5bc29d4187798a1af025fb0b08fc909a1b556f2e615036d83514c3c4d5872` |

준비PNG3개/225560바이트는 업로드 원본과 같다. [출처README](../assets/maps/pilot_03/README.md)·[원본명세](../assets/maps/pilot_03/source_manifest.json)와 무손실2D임포트3개를 보존했다. 원본명세의적용대기 상태는 제작당시 출처기록이며 현재연결 결과와 구분한다. masters/준비·생성 스크립트 실행·이미지 편집/재생성·유료호출은하지않았다. 검증은DEVELOPMENT_STATUS8.38을따른다.

## 2026-11-24 — MAP-PILOT-004 파괴 잔해3종

사용자가 프롤로그 파괴 상태3종 추가를 선택했다. 원본92×86RGBA를HP0분기의기존46×43화면/하단중앙에연결했으며맵PNG총12종이다. 기존정상/다른맵/F8·공유53빈칸은유지한다. ZIP SHA256 `89ea7d5d44fcb42ebcbbf989887b27c9f520ce31c2d28761b12ad5b12b164eba`,HASHES23항목·알파영역/크기/해시를확인했다. 원본PNG3개20943바이트와무손실2D임포트3개를보존했다.

| 파일 | 실제 등록 경로 | 원본/실제표시 / SHA256 |
| --- | --- | --- |
| 부서진 상자 | [prop_crate_broken.png](../assets/maps/pilot_04/prop_crate_broken.png) | 92×86/가시46×15 / `13b2efa02cbe6f085125f2b7c94ecad406d2fc51bee3baf2e357af772cb4e030` |
| 깨진 항아리 | [prop_urn_broken.png](../assets/maps/pilot_04/prop_urn_broken.png) | 92×86/가시44×16 / `aed6316a83fbf7b41b451644ae547b373d1096fe01c2e73d3610ac4ab508ac0f` |
| 흩어진 돌조각 | [prop_debris_broken.png](../assets/maps/pilot_04/prop_debris_broken.png) | 92×86/가시46×12 / `c9ff22710bd078ee80c5747568ce83e889b20efafaf6d09baf994314e4d2c364` |

[출처README](../assets/maps/pilot_04/README.md)·[원본명세](../assets/maps/pilot_04/source_manifest.json)의GAME045/3142eb7/적용대기는제작당시출처다. 실제적용은GAME046이후를보존한GAME047이며DEVELOPMENT_STATUS8.40/GAME047_REPORT를따른다. masters/준비·생성스크립트를실행/복사하거나이미지편집/유료생성을하지않았다. 시범적용과최종아트/실기승인은구분한다.

## 2026-11-24 — GAME-049 1스테이지의 기존 맵 자산 재사용

`map_presentation_slots.json`의 별도 `siege_battlefield`는 기존 `prologue_wall`의12PNG경로를 그대로 재사용한다. 새PNG/승인원본편집은 없고 공유캐릭터/전역53빈칸도 그대로다. `battlefield_presentation.gd`의 정적도형은 임시시설/방책/수레자국 표현이며,`docs/design/map_plan_001/concept.png`는 계속 문서용 미확정시안/게임미연결이다. 프롤로그/외곽의 이전/현재 렌더러6쌍픽셀동일과 모든원본자산바이트보존은GAME049_REPORT에기록했다. 최종캐릭터/건물아트·모바일품질승인은별도다.

## 2026-11-25 — CHARACTER-PILOT-032 비야 8방향 전투 파일럿

사용자의‘기존전투에시범적용’선택으로기존viya_battle한경로에연결했다. 8방향×idle/run/attack/hurt32상태·208PNG이며공통200×248RGBA를50×62·하단pivot(0.5,1)로표시한다. [원본SpriteFrames](../assets/characters/pilot_32/resources/viya_directional_motion.tres)·[출처/208개해시](../assets/characters/pilot_32/source_manifest.json)·[제공당시인계문](../assets/characters/pilot_32/source_docs/INTEGRATION_HANDOFF_ko.txt)을보존한다. 리소스SHA256은`11254fff2baec6de74bce61988544a4296a9753007f27bef2950788aea8b6a19`,PNG합계10,269,848바이트다. 208무손실2D임포트설정을함께등록했다. 아틀라스24·masters/생성·검증스크립트를런타임에넣거나실행하지않았다.

분할z01/z02/zip복원CRC와동봉395체크섬을독립확인했고원본208PNG/리소스는바이트동일하다. 공유53키중다른52와별도초상화4경로는빈칸이다. 시범사용이며최종아트승인/모바일검증을뜻하지않는다. 제공당시구성완비/미연결과현재실제시범연결을구분하고기존승인ART001·GEN005/3D보류·맵12PNG는유지한다. 현재실행/한계는DEVELOPMENT_STATUS8.50과[GAME056_REPORT](validation/GAME056_REPORT.json)를따른다.

## RENDER-CACHE-062 — 비야 표시용 매트 보정 파생물 (2026-11-26)

`assets/characters/pilot_32/render_cache`의208PNG/한SpriteFrames·manifest는 CHARACTER-PILOT-032 원본에서 생성한 기술적 표시 파생물이다. 원본200×248/알파·32동작/순서/타이밍과 승인 상태를 유지하고 흰 매트 외곽 RGB/투명 여백만 정리했다. 원본208장·원본Resource는 불변이고 새 승인 원화로 분류하지 않는다. 기존viya_battle슬롯은 이 표시용Resource에 연결하며 다른52/초상화4·ART001/GEN005미승인·3D보류/지원2+2는 유지한다. 빌드 도구/입출력 해시와 검증은GAME062_REPORT를 참조한다.

## Higgsfield 수정 입력 원본 보관 (2026-11-26)

현재 환경의 비공개 `tools/higgsfield/request/references/masters`에 업로드 CHARACTER-PILOT-032 ZIP에서 복원한 E달리기400×496의11PNG와 E대기1600×1984 PNG를 원본 그대로 보관했다. 복원 ZIP SHA256 `51d5972a9e818d275bc630f18489e37f893deef1ba6f5dce0467660c45dbc4b3`는 기존 source_manifest와 일치하며 프레임 해시는 service_job.json에 기록한다. 제작 도구 입력이며 `.gitignore`로 Git에서, `.gdignore`로 게임 임포트에서 제외한다. 신규 생성/ART001 승인 승격·게임 연결은 없고 기존208런타임/표시용 파생물은 유지한다.

## 2026-11-26 — ARTFIX001 E 달리기 흰 배경 잔사 수정 완료

위 GAME062의 알파 보존/SDK 입력 준비 설명은 당시 이력이다. 현재 수정 코드 `4793d743c1451131c91d0ffe3776c2f7cfec85fc`에서는 Higgsfield 결과11장을 검증해 기존 E 달리기의 경계색·흰 배경 틈을 한정 수정했다. 새 생성본을 그대로 전신 교체한 것이 아니라 원래 프레임의 자세·디자인을 유지한 파생 합성이다.

- [입력·생성본·등록본·수정본·마스크](../assets/characters/pilot_32/edge_repair/README.md): 원본/생성11장과 작업 ID·해시·설정·견적 기록.
- [실제 표시 캐시](../assets/characters/pilot_32/render_cache/README.md): E11 변경, 다른197장 바이트 동일. 원본208장/리소스 보존. E11 마스크1,467픽셀의 알파 감소 예외와 Godot 경계색 정규화를 반영.
- [ARTFIX001_REPORT](validation/ARTFIX001_REPORT.json): 실제 적용·재현/임포트 검증과 전체 회귀 TIMEOUT·실기 미검증을 구분. 최종 ART001 승인 승격은 없다.

**다음 제작 순위:** [PLANNED_WORK63](PLANNED_WORK.md). E 달리기 반복 연결/이동 사격을 먼저 보완하고, 신규 적은 고블린 약탈병1종부터 실제 전투에 연결하는 순서를 제안한다. 초상화4경로는 여전히 비어 있으며 이번 계획 갱신에서 새 자산을 생성하거나 연결하지 않았다.


## 2026-11-26 — GAME064 E 달리기 파생47장

사용자의 “게임에 반영해” 지시로 기존 `viya_battle`을 [GAME064 파생 SpriteFrames](../assets/characters/pilot_32/game064_e_run/viya_game064_frames.tres)에 연결했다. E 달리기47장과 보존된 캐시197장을 참조해32동작/244프레임이다. 원본208PNG/원본 리소스와 ARTFIX001 표시 캐시208PNG/리소스를 변경하지 않고 별도 경로에 준비했다. 새47PNG는 최종 납품본과 바이트 동일하다.

| 항목 | 경로 / 값 |
| --- | --- |
| 새 E PNG | `assets/characters/pilot_32/game064_e_run/frames/viya_run_e_000.png`~`046.png` |
| 활성 리소스 | `assets/characters/pilot_32/game064_e_run/viya_game064_frames.tres` |
| 해시/시간/연결 명세 | [manifest.json](../assets/characters/pilot_32/game064_e_run/manifest.json) |
| 개별 표시 시간 | [frame_timing.csv](../assets/characters/pilot_32/game064_e_run/provenance/frame_timing.csv) |
| 모델 / 작업 | `hf_mult_motion_control` / `fbf2fd2d-8596-4ca4-87e7-875712a2f7c9` |
| 원출력 SHA256 | `103a6aa16585f5c6160f03c4373f8fcbba55283e655ff8dfcff371faded4d29d` |
| 캔버스 / 표시 / 기준점 | 200×248 / 69×85.56 / (100,248), 정규화(.5,1) |
| 시간 | 명목660ms 가변47구간; 이동235·stride155에서659.574468ms |

서비스 원출력은720×1280/24fps RGB MP4다. 이47장은 제작 단계의 알파 추출·고정 변환으로 준비한 RGBA이며 Godot 재매트 처리를 끈 무손실2D 임포트를 사용한다. 원본0,2,…92와 실제 두 다리 주기를 유지하고 다음 대응 프레임94는 제외한다. 대형 원본/탈락 후보 전체를 런타임에 복사하지 않고 출처·해시·비용·선정 근거를 [provenance](../assets/characters/pilot_32/game064_e_run/provenance/production_record.txt)에 보존했다. 그 안의 미연결 표시는 제작 당시 이력이며 현재 적용 상태는 CURRENT/DEVELOPMENT8.60을 따른다.

이번 통합의 추가 생성·크레딧 사용·새 결제·자동충전은0이다. 채택 작업은 제작 당시 무료1회/0크레딧을 사용했고, 이전 보정 전체의 관측 차감62/마지막 조회966.25는 별도 비용 기록이다. 최종 아트 승인·다른 방향/전용 이동사격 제작으로 계산하지 않는다. 기존 승인 원본·ARTFIX001 근거·다른52공유경로·초상화4빈칸·GEN005미승인/3D보류를 유지한다.

## GAME065 E 이동사격 등록 보완 — 제작 당시2026-11-26 / 기록2026-11-27

기존에 게임에 연결된 E 전용 이동사격47장의 목록 누락만 보완한다. 이번 검수에서 새 원화를 만든 것이 아니다. [파생 자산](../assets/characters/pilot_32/game065_e_run_fire/README.md)·[시간표/메타데이터](../assets/characters/pilot_32/game065_e_run_fire/provenance/production.json)를 따른다. 원본 후보2 `d1817f67-fb19-4b70-b4a9-605f82981497`/Seedance2.5의 RGBA 파생물이며 GAME06432클립/244프레임을 보존해33클립/291프레임으로 연결했던 이력이다. 현재도 E 이동사격47은 아래 GAME066 복합 리소스에 그대로 보존된다. 당시93크레딧/873.25조회는 과거 기록이고 새 비용/조회가 아니다. 원출력의 구운 섬광 반려와 최종 파생물 기술 채택·최종 아트 승인을 구분한다.

## GAME066 SE 달리기18 — 이전 활성 복합 리소스 (2026-11-27)

원격b42b7ed에서 기존 SE11만 파생18장으로 교체했다. 이번 재검수에서는 PNG/리소스/기존 메타데이터를 변경하지 않았다. 새 파일은 기존 E와 같은 `provenance/.gdignore`이며 시간표 CSV가 번역으로 자동 임포트되지 않도록 빌더도 같은 파일을 만든다. 정상 editor import와 원본 CSV를 읽는 관련465검사를 재확인했다. [자산 설명](../assets/characters/pilot_32/game066_se_run/README.md)·[등록/해시](../assets/characters/pilot_32/game066_se_run/provenance/source_registration.json)·[실행 검수](validation/GAME066_REVIEW_REPORT.json)를 따른다.

| 항목 | 경로 / 값 |
| --- | --- |
| SE 신규 RGBA | `assets/characters/pilot_32/game066_se_run/frames/viya_run_se_000.png`~`017.png` |
| 현재 활성 SpriteFrames | `assets/characters/pilot_32/game066_se_run/viya_game066_frames.tres` |
| SpriteFrames SHA256 | `403baa687c026db8479238aaa737727b2f3ed4ef078402bb92e31effe82e9390` |
| 개별 원화 해시/총구 | `game066_se_run/provenance/source_registration.json`의18개 frame_checks |
| 시간표 | [frame_timing.csv](../assets/characters/pilot_32/game066_se_run/provenance/frame_timing.csv),18×36.666666…ms/660ms |
| 모델/작업 기록 | Seedance2.5/video_edit `a9ab0954-f528-4194-b8c1-3cb8954dd02c`,Genjutsu `ee75ff39-7354-4f8e-a6fb-df30c4eeae46`는 시점 드리프트로 반려 |
| 출처/범위 기록 | RGB89프레임/24fps의36~53,54제외;원출력기록SHA `53cf0b38aa393369bf72d33ece585bc95763f0634772321387b87b84bf8c82d3` |
| 등록 | 200×248 RGBA/표시69×85.56/pivot(100,248),고정scale.231·translation(1.2,-1.4),기존SE원점3/11 |
| 보존 | 다른32클립/280프레임·원본208·ARTFIX001·GAME064 E47·GAME065 E이동사격47·SAVEFIX001 |
| 현재 총계 | 33클립/298프레임,이동235/stride155,명목660ms/거리주기659.574468ms |
| 상태 | 기술 채택·기존 전투 연결·이번 실제 전투 검수 PASS,프로듀서 최종 아트 승인 별도 |

빌더를 격리 입력으로 재실행해 리소스/manifest/motion/slot4개가 납품본과 바이트 동일함을 확인했다. manifest.status는 빌드 시점의 상태 서술이고 이후의 실제 엔진 상태는 날짜가 있는 검증 보고서/CURRENT를 따른다. 원출력 URL은 현재 환경의 네트워크403으로 독립 재다운로드하지 못했으므로 기록된 원출력 해시를 이번 파일 독립 검증으로 승격하지 않는다. 실제 RGBA18은 해시/투명도와 Godot 실행에서 확인했다.

제작 당시 차감58/조회815.25는 해당 세션 기록이며 이번 검수의 생성/추가 비용/결제0과 구분한다. 현재 실제전투1,793검사/379그리기와 전체네이티브4,531을 통과했다. 숫자 위상 보존을 물리 발 접지/미끄러짐·모바일FPS·최종 아트 승인으로 계산하지 않는다. 다음 GAME067 SE 이동사격은 제작 지시/참조만 준비했고 새 원화·연결은 아직 없다.

## GAME067 — SE 이동사격 원화20장 납품 (2026-11-27)

[납품 README](../assets/characters/pilot_32/game067_se_run_fire/README.md) · [전체 해시/메타데이터 명세](../assets/characters/pilot_32/game067_se_run_fire/manifest.json) · [원출력/작업/비용/후보 판단](../tools/higgsfield/requests/game067/evidence/).

| 항목 | 경로 / 값 |
| --- | --- |
| 새 RGBA20장 | assets/characters/pilot_32/game067_se_run_fire/frames/viya_run_fire_se_000.png~019.png |
| 모델/실제 작업 | Seedance2.5/omni_reference/5b7cc811-ad50-4759-b8ea-8d1a40de7c77 |
| 원출력 | RGB H264/864×1072/97장·24fps/4.041667초, 원출력 파일과SHA는 evidence/candidate_07_source.json |
| 실제 선택 | 연속 원천10~29, 다음 대응30은 제외 |
| 시간 | provenance/frame_timing.csv, 실제 원천 PTS→660ms/기본속도659.574468ms |
| 총구 | provenance/muzzle_coordinates.csv, 새 원화에서 독립 측정20개 |
| 발 위상 | provenance/phase_alignment.json, 권고0.819949494949495/기존3/11 복사 아님 |
| 고정 등록 | 200×248/root(100,248)/표시69×85.56,scale200/864·translation(0,-0.148148148148),bbox 재정렬 없음 |
| 출력/알파 | RGB 청록 매트에서 별도 RGBA 분리, 서비스 네이티브 알파 아님 |
| 실제 상태 | 원화 기술 납품20장/게임 연결0/최종 아트 NOT_VERIFIED |
| 활성 게임 보존 | GAME066/33클립·298프레임·원본208/ARTFIX001/GAME064·065·066/SAVEFIX001 그대로 |

20장 경계알파0·독립 총구/양수 시간표·전체 주기/이음과 SE 고각/캐릭터·무기/천을 검토했다. 새 발 벌림/위치는 SE18과 달라 실제 전환/물리 접지·무미끄러짐을 완료로 세지 않는다. provenance의240프레임 아트 분석 영상은 실제 main.tscn 화면/FPS 측정이 아니다. CSV/검토 이미지는 .gdignore로 자동 임포트에서 제외한다.

반려 원출력과 실패 기록, 후보2의 미채택18장 참고 패킷도 보존했다. 실제 네이티브 GIF는 요청24장 대신16장/투명으로 나왔으며 보행 문제로 미채택했다. 전체 관측 차감158.25/마지막 조회657, 선택 생성28크레딧·새 결제/충전0이다. 기존 게임 수치/저장/스폰은 변경하지 않았다. 후속 연결은 NEXT/DEVELOPMENT_STATUS8.67을 따른다.


## GAME067 — 게임 연결 등록 (2026-11-27, 원화 납품 이후)

사용자의 게임 연결 지시로 위 원화20장을 별도 복합리소스에 추가했다. 위의 게임연결0/활성GAME066 표시는 원화 납품 당시 이력이며 현재는 아래를 따른다. 원화manifest/CHECKSUMS·PNG·provenance·원출력/비용 근거는 바이트 그대로다.

| 항목 | 경로 / 값 |
| --- | --- |
| 현재 활성 SpriteFrames | assets/characters/pilot_32/game067_se_run_fire/viya_game067_frames.tres |
| 새 통합 명세 | [integration_manifest.json](../assets/characters/pilot_32/game067_se_run_fire/integration_manifest.json) |
| 총계 | 기존33클립/298프레임 보존+run_fire_se20장=34클립/318프레임 |
| 엔진 메타데이터 | data/viya_motion.json의directions.se.run_fire 및 run_fire_phase_origin0.819949494949495 |
| 임포트 |20PNG.import,lossless/fix_alpha_border=false,20장 실제 임포트RGBA가 원본과 동일 |
| 빌더 | tools/build_viya_game067.py,격리한4출력바이트동일 |
| 실제 검증 | 전체 네이티브4,558·main헤드리스1,331/43발/그리기0,PASS |
| 화면 상태 | X11소켓 권한/자동 승인 정책으로 GUI BLOCKED,전환 외관/물리접지/최종 아트NOT_VERIFIED |
| 증거 | [통합 보고서](validation/GAME067_INTEGRATION_REPORT.json)·[실행 로그](validation/GAME067_INTEGRATION_RUNTIME.log) |

200×248/root(100,248)·표시69×85.56·235/stride155·명목660ms/거리659.574468ms를 유지한다. 원본208/ARTFIX001/GAME064·065·066/SAVEFIX001을 보존했다. 이번 추가 생성/크레딧/결제0. 모델/알파/과거 비용/선정 근거는 원화 제작 기록을 따르며 이번에 재조회하거나 생성하지 않았다.

## GAME067 실제 화면 검수·GAME068 참조 등록 (2026-11-27)

원화31b80cc/게임 연결ce7e779를 검수했다. 기존assets/scripts/data1,405파일을 보존했고 납품CHECKSUMS36개/원출력 해시/격리 빌더4출력 일치를 확인했다. 위GUI 차단/게임 연결0은 각각 당시 기록이며 현재는 실제GUI 검수PASS다. 원화README/manifest/CHECKSUMS는 납품 당시 자료로 유지한다.

| 자료 | 경로 | 출처와 범위 |
| --- | --- | --- |
| 실제 게임 검수 | [GAME067_REVIEW_REPORT.json](validation/GAME067_REVIEW_REPORT.json) | 생산main.tscn·2,473검사/444그리기/43발, 최종 아트/실기 별도 |
| 실제 사격/해제 영상 | [GAME067_REVIEW_MOVING_FIRE.mp4](validation/GAME067_REVIEW_MOVING_FIRE.mp4) | 실제 연속110QA 캡처/60fps, 새 원화/FPS 증거 아님 |
| 전체QA 영상 | [GAME067_REVIEW_GAMEPLAY.mp4](validation/GAME067_REVIEW_GAMEPLAY.mp4) |444회 실제 그리기 재생, 장면 전환/정지 시도 포함 |
| 실제 스크린샷 | GAME067_REVIEW_IN_GAME.png / HURT.png / PAUSED.png (validation/) | 이동사격/피격/일시정지 |
| S11 참조 | [GAME068_S_RUN_REFERENCE.mp4](validation/GAME068_S_RUN_REFERENCE.mp4) | 현재S11을 실제Godot로600×744/60fps·198장/명목5주기 재생 |
| S 제작 인계 | [GAME068 패킷](../tools/higgsfield/requests/game068/README.md) | 한글/영문·입력 해시·범위, 새S 원화/교체0 |

검수 영상/참조 해시는 각 보고서와request_plan에 기록한다. 화면은 고정 시간 검수의 재생이며 실시간FPS/물리 입력/Windows·모바일·최종 아트 승인이 아니다. 신규 캐릭터PNG/이미지 편집/Higgsfield 요청/비용/결제는0이며 기존200×248·69×85.56·pivot(100,248)·34클립/318프레임을 유지한다.
