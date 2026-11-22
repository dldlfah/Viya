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
