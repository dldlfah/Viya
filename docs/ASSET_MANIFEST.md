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
