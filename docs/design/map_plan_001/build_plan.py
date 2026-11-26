from pathlib import Path
from collections import Counter,deque
import json,math,html,hashlib,subprocess

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
SOURCE_HASHES={
 'data/maps.json':'925638f794696b96fdf48df8c266654cef3af002f43e57f91daa80f8d70e8bd4',
 'data/destructibles.json':'130421dd85d4dbf9ff9f70ab297b36586870e65fb9426cec0c2f58ce57a49b39',
}
for name,digest in SOURCE_HASHES.items():
 assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest, 'Source changed; re-review the proposal before rebuilding: '+name

source_map=json.loads((ROOT/'data/maps.json').read_text())['prologue_wall']
source_props=json.loads((ROOT/'data/destructibles.json').read_text())['prologue_wall']
solid=[]
for i,item in enumerate(source_map['obstacles']):solid.append(dict(id='X'+str(i),name=item['name'],rect=item['rect'],kind='existing',district='A' if i==0 else ['B','D','F'][i-1],story='현재 충돌 위치 유지'))
new=[
 ('B1','불탄 병참창고',[630,940,460,260],'B','성문으로 올리던 군수품이 불타 멈춘 자리'),
 ('B2','서측 경비막사',[370,1900,460,250],'C','측면 공세에 무너진 경계 거점'),
 ('B3','붕괴한 숙영동',[1260,1810,360,230],'C','후퇴 도중 버린 장비와 낮은 벽체'),
 ('B4','부서진 수레 정비소',[650,2450,440,230],'C','전선 가까이 밀려난 보급 수레'),
 ('B5','반파된 동측 병영',[3650,980,650,240],'D','전선과 성문 사이에 남은 병영 외벽'),
 ('B6','버려진 야전 구호소',[3920,1990,460,260],'E','물 항아리와 이송 흔적이 남은 구호 거점'),
 ('B7','무너진 대기소',[3240,2230,370,250],'E','부상자와 병력이 철수한 흔적'),
 ('B8','파손된 병기 정비터',[3790,2580,480,200],'E','적의 돌파로 작업이 중단된 병기 잔해'),
 ('B9','기울어진 서측 망루',[1530,2610,230,230],'F','남측 전진 방어선의 꺾인 표식'),
 ('B10','부러진 동측 망루',[2950,2660,230,230],'F','돌파구를 양쪽에서 가리키는 잔존 기둥')]
for ident,name,rect,district,story in new:solid.append(dict(id=ident,name=name,rect=rect,kind='building',district=district,story=story))
for ident,name,rect in [
 ('L1','마지막 서측 방책',[1750,1040,370,100]),('L2','마지막 동측 방책',[2840,1100,380,100]),
 ('L3','끊어진 서측 방어선',[1830,1820,330,100]),('L4','끊어진 동측 방어선',[2810,1950,330,100]),
 ('L5','돌파구 서측 잔해',[1880,2590,250,90]),('L6','돌파구 동측 잔해',[2850,2500,260,90])]:
 solid.append(dict(id=ident,name=name,rect=rect,kind='barricade',district='F',story='연속 벽 대신 끊긴 방책으로 공세와 후퇴 방향을 드러냄'))

districts=[
 dict(id='A',name='마지막 성문 · 집결지',rect=[1750,420,1500,520],label=[2500,485],story='아직 버티는 북쪽 성벽. 시작 주변은 비워 상황을 읽을 시간을 준다.'),
 dict(id='B',name='불탄 병참 구역',rect=[300,900,1450,800],label=[1000,700],story='창고 옆 보급품과 탄 흔적을 묶어, 성문을 지키려던 준비가 끊겼음을 보여준다.'),
 dict(id='C',name='무너진 서측 거점',rect=[250,1750,1500,1150],label=[960,2320],story='막사·숙영동·수레 정비터를 지나며 측면 방어가 붕괴한 흔적을 읽는다.'),
 dict(id='D',name='반파된 동측 병영',rect=[3100,900,1600,850],label=[3900,700],story='질서 있던 병영 앞 공간과 부서진 벽을 대비해 전투 전후를 읽게 한다.'),
 dict(id='E',name='철수한 구호·병기 구역',rect=[3200,1900,1400,1000],label=[4000,2410],story='항아리·물자·견인 흔적을 시설 근처에 모아, 급히 철수한 장면을 만든다.'),
 dict(id='F',name='돌파당한 전진 방어선',rect=[1750,1700,1500,1400],label=[2500,2400],story='남쪽으로 갈수록 파손과 흔적이 심해진다. 중앙은 전투와 큰 무리가 펼쳐질 공간으로 남긴다.')]

groups=[
 ('C1','성문 보급 수레','A',[(1840,820),(1940,840),(2040,820),(2140,860)]),
 ('C2','창고 출고 물자','B',[(1160,950),(1220,1040),(1180,1130),(1250,1200)]),
 ('C3','막사 철수 장비','C',[(860,2100),(960,2140),(1060,2100),(1130,2170)]),
 ('C4','방책 후퇴 잔해','F',[(1770,1990),(1870,2010),(1970,1990),(2070,2050)]),
 ('C5','병영 보급 묶음','D',[(3320,1320),(3420,1320),(3520,1360),(3620,1310)]),
 ('C6','구호소 이송 물자','E',[(3680,2070),(3760,2150),(3670,2230),(3760,2320)]),
 ('C7','전진 수레 잔해','C',[(1140,2750),(1240,2790),(1340,2750),(1410,2840)]),
 ('C8','병기터 파편 묶음','E',[(3390,2680),(3500,2700),(3610,2680),(3560,2820)])]
pools={style:[i for i,p in enumerate(source_props) if p['style']==style] for style in ['crate','urn','debris']}
props=[];clusters=[]
for n,(ident,name,district,points) in enumerate(groups):
 selected=[pools['crate'][n*2],pools['crate'][n*2+1],pools['urn'][n],pools['debris'][n]]
 clusters.append(dict(id=ident,name=name,district=district,count=4,center=[sum(p[0] for p in points)/4,sum(p[1] for p in points)/4],story='상자 2 · 항아리 1 · 잔해 1. 주변 시설의 사용·철수 이유가 보이게 배치한다.'))
 for index,point in zip(selected,points):props.append(dict(id=-index-2,source_index=index,cluster=ident,style=source_props[index]['style'],hp=source_props[index]['hp'],p=list(point)))
props.sort(key=lambda p:p['source_index'])
routes=[
 dict(id='R1',name='중앙 진격·후퇴로',width=260,points=[[2500,600],[2500,1400],[2600,1800],[2650,2350],[2500,2770],[2500,3030]],story='보이는 노면 폭 680, 기존 유적 옆 최소 440. 끊기지 않는 주 동선.'),
 dict(id='R2',name='외곽 순환 회피로',width=260,points=[[200,800],[200,3030],[4800,3030],[4800,800],[200,800]],story='한 방향으로 쫓길 때 옆 구역으로 탈출할 수 있는 순환로.'),
 dict(id='R3',name='서측 연결로',width=260,points=[[650,1540],[1100,1580],[2200,1580],[2500,1500]],story='병참 구역에서 중앙으로 복귀하는 횡단 동선.'),
 dict(id='R4',name='동측 연결로',width=260,points=[[4450,1560],[3900,1780],[3700,1820],[3020,1790],[2750,1720],[2500,1500]],story='구호 구역과 중앙을 잇는 횡단 동선.')]
pockets=[dict(id='P1',name='남측 전개 여유',p=[2500,2820],radius=300),dict(id='P2',name='서측 전개 여유',p=[650,1540],radius=300),dict(id='P3',name='동측 전개 여유',p=[4450,1560],radius=300)]
plan=dict(id='MAP-PLAN-001',status='PROPOSAL_NOT_IMPLEMENTED',date_kst='2026-11-24',basis_commit='84c9718d9c71ff410749975d76d6d1b773fa7570',runtime_code='85ddb8282a46967bef9ec0dc54dcf903d6023729',source_sha256=SOURCE_HASHES,map_id='prologue_wall',world_size=[5000,3200],start=source_map['start'],start_clear_radius=150,theme='성문 앞 마지막 방어선 — 남측 돌파와 양 측면 붕괴의 흔적',districts=districts,solids=solid,clusters=clusters,destructibles=props,routes=routes,formation_pockets=pockets,original_destructibles=source_props,notes=['제안 좌표이며 게임 데이터에 연결하지 않는다.','기존 4개 충돌체/성문/시작점을 유지한 설계다.','32개 총수/16상자·8항아리·8잔해/원래 HP·ID·순서는 유지한다.','소품은 기존처럼 이동 비충돌이다. 배치 집중에 따른 회복·재생성 효율은 적용 시 별도 측정한다.','적 화살표는 방향 가이드다. 실제 생성2는 플레이어 주변이며, 고정 스폰/보스 위치나 체크포인트 건물을 추가하지 않는다.','신규 폐허 실루엣/수레/목책/흔적은 필요한 후속 아트 제안이다. 최종 원화 승인이 아니다.'])
(OUT/'layout.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2)+'\n')

def blocked(point,radius=30):
 x,y=point
 if x<radius or y<radius or x>5000-radius or y>3200-radius:return True
 return any(a['rect'][0]-radius<=x<a['rect'][0]+a['rect'][2]+radius and a['rect'][1]-radius<=y<a['rect'][1]+a['rect'][3]+radius for a in solid)
assert len(solid)==20 and len(props)==32
assert Counter(x['style'] for x in props)==Counter(x['style'] for x in source_props)
assert all((p['id'],p['style'],p['hp'])==(-p['source_index']-2,source_props[p['source_index']]['style'],source_props[p['source_index']]['hp']) for p in props)
assert all(not blocked(p['p'],24) and math.dist(p['p'],plan['start'])>=174 for p in props)
min_pair=min(math.dist(a['p'],b['p']) for n,a in enumerate(props) for b in props[n+1:]);assert min_pair>=48
for pocket in pockets:assert not blocked(pocket['p'],297.095),pocket
route_checks=[]
for route in routes:
 ok=True
 for a,b in zip(route['points'],route['points'][1:]):
  for step in range(101):
   t=step/100;ok=ok and not blocked([a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t],130)
 assert ok,route['id'];route_checks.append(dict(id=route['id'],centerline_clearance=130,result='PASS'))
step=50;start=(50,12);seen={start};queue=deque([start])
while queue:
 x,y=queue.popleft()
 for nxt in [(x+1,y),(x-1,y),(x,y+1),(x,y-1)]:
  if nxt not in seen and not blocked((nxt[0]*step,nxt[1]*step),130):seen.add(nxt);queue.append(nxt)
waypoints=[[2500,600],[650,1540],[4450,1560],[2500,2820],[200,800],[200,3030],[4800,3030],[4800,800],[1100,2100],[3750,2350]]
for point in waypoints:assert (round(point[0]/step),round(point[1]/step)) in seen,point
area=sum(a['rect'][2]*a['rect'][3] for a in solid if a['id']!='X0');open_ratio=1-area/(5000*2780)
validation=dict(status='PASS',scope='Proposal geometry only: original-source anchors, exact32 style/HP/ID mapping,collision clearance,continuous routes and50-unit-grid reachability. Not Godot/navigation/mobile/performance/game approval.',existing_solids_preserved=4,total_solids=20,props=32,style_counts=dict(Counter(p['style'] for p in props)),minimum_prop_spacing=round(min_pair,2),route_checks=route_checks,waypoints=waypoints,reachable_clearance130_grid_cells=len(seen),formation_footprint_radius297095='3centers clear',approx_open_fraction_below_wall=round(open_ratio,4))
(OUT/'validation.json').write_text(json.dumps(validation,ensure_ascii=False,indent=2)+'\n')

esc=lambda s:html.escape(str(s),quote=True)
def text(x,y,value,size=52,fill='#e7e1d5',anchor='middle',extra=''):
 return f'<text x="{x}" y="{y}" font-size="{size}" fill="{fill}" text-anchor="{anchor}" {extra}>{esc(value)}</text>'
def shape_prop(p,old=False):
 x,y=p['p'];style=p['style'];color={'crate':'#e1b875','urn':'#82c8ce','debris':'#b2b7be'}[style]
 if old:return f'<circle cx="{x}" cy="{y}" r="27" fill="none" stroke="#c58b91" stroke-width="7"/><path d="M{x-20},{y-20}l40,40m-40,0l40,-40" stroke="#c58b91" stroke-width="5"/>'
 attr=f'data-item="prop:{p["source_index"]}" class="selectable"'
 if style=='crate':return f'<g {attr}><rect x="{x-26}" y="{y-23}" width="52" height="46" rx="5" fill="{color}" stroke="#262b30" stroke-width="6"/><path d="M{x-18},{y-15}l36,30m-36,0l36,-30" stroke="#6a5238" stroke-width="4"/></g>'
 if style=='urn':return f'<g {attr}><circle cx="{x}" cy="{y}" r="25" fill="{color}" stroke="#222c34" stroke-width="6"/><ellipse cx="{x}" cy="{y-12}" rx="16" ry="7" fill="#304953"/></g>'
 return f'<g {attr}><path d="M{x-30},{y+12}l12,-32 34,-2 18,30 -18,15Z" fill="{color}" stroke="#27323b" stroke-width="6"/></g>'

def map_svg(labels=True):
 s=['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 5000 3200" role="img" aria-label="프롤로그 전체 배치 시안" style="font-family:Noto Sans CJK KR,sans-serif">',
 '<defs><pattern id="grid" width="500" height="500" patternUnits="userSpaceOnUse"><path d="M500,0H0V500" fill="none" stroke="#7c8992" stroke-opacity=".16" stroke-width="4"/></pattern><pattern id="hatch" width="50" height="50" patternUnits="userSpaceOnUse"><path d="M0,50L50,0" stroke="#c1b59e" stroke-opacity=".16" stroke-width="8"/></pattern><marker id="arrow" markerWidth="8" markerHeight="8" refX="6" refY="4" orient="auto"><path d="M0,0L8,4L0,8" fill="#d87870"/></marker></defs>',
 '<rect width="5000" height="3200" fill="#20282d"/><rect width="5000" height="3200" fill="url(#grid)"/>']
 # Low-contrast narrative scars;decorative only.
 for x,y,rx,ry in [(900,1150,560,370),(900,2170,650,280),(3880,1230,680,300),(3910,2300,650,470),(2500,2780,810,360)]:
  s.append(f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="#705447" opacity=".10"/>')
 s.append('<path d="M2450,3160Q2640,2620 2520,2170T2440,1350L2480,850M2630,3130Q2810,2540 2680,2110T2570,1230" fill="none" stroke="#a89478" opacity=".09" stroke-width="45"/>')
 s.append('<g class="layer-routes">')
 for route in routes:
  pts=' '.join(','.join(map(str,p)) for p in route['points']);width=680 if route['id']=='R1' else 260
  s.append(f'<polyline points="{pts}" fill="none" stroke="#ae9b73" stroke-opacity=".10" stroke-width="{width}" stroke-linejoin="round"/><polyline points="{pts}" fill="none" stroke="#7ba9b2" stroke-opacity=".8" stroke-width="8" stroke-dasharray="32 24"/>')
 if labels:s += [text(2550,1260,'중앙 진격로',60, '#d1c9b8'),text(2500,1328,'노면 680 · 유적 옆 최소 440',39,'#9baeb3'),text(155,2250,'외곽 순환 · 여유 폭 260',43,'#8db4bc',extra='transform="rotate(-90 155 2250)"')]
 s.append('</g><g class="layer-formation">')
 for pocket in pockets:
  x,y=pocket['p'];s.append(f'<circle cx="{x}" cy="{y}" r="300" fill="#7fa58e" fill-opacity=".06" stroke="#7fa58e" stroke-width="7" stroke-dasharray="22 20"/>')
  if labels and pocket['id']!='P1':s.append(text(x,y+340,'30무리 전개 여유',37,'#95bca4'))
 s.append('</g><g class="layer-solids">')
 for a in solid:
  x,y,w,h=a['rect'];old=a['kind']=='existing';border='#bcc5c5' if old else ('#c8a36c' if a['kind']=='building' else '#a67b59');fill='#404b54' if old else ('#394149' if a['kind']=='building' else '#524238')
  s.append(f'<g data-item="solid:{a["id"]}" class="selectable"><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12" fill="{fill}" stroke="{border}" stroke-width="8"/><rect x="{x+12}" y="{y+12}" width="{max(1,w-24)}" height="{max(1,h-24)}" fill="url(#hatch)"/>')
  if a['id']=='X0':
   for px in [350,1100,1850,3150,3900,4650]:s.append(f'<path d="M{px},370v90l40,-25 40,25v-90" fill="#814c4d" stroke="#b48d65" stroke-width="5"/>')
   s.append('<rect x="2380" y="160" width="240" height="260" fill="#151c23" stroke="#d4b983" stroke-width="9"/><path d="M2420,200v180m60,-180v180m60,-180v180" stroke="#88775c" stroke-width="8"/>')
   if labels:s += [text(880,245,'현재 성벽 · 출입 불가',58),text(4110,245,'북측 성벽 유지',58)]
  elif labels:
   s.append(text(x+w/2,y+h/2+18,a['id'],56,border))
  s.append('</g>')
 s.append('</g>')
 if labels:
  s.append('<g class="layer-districts">')
  for d in districts:
   x,y=d['label'];s.append(f'<g data-item="district:{d["id"]}" class="selectable">'+text(x,y,d['id']+'. '+d['name'],62,'#dfd6c4',extra='paint-order="stroke" stroke="#20282d" stroke-width="14"')+'</g>')
  s.append('</g>')
 s.append('<g class="layer-props">')
 for c in clusters:
  items=[a for a in props if a['cluster']==c['id']];xs=[a['p'][0] for a in items];ys=[a['p'][1] for a in items];x=min(xs)-55;y=min(ys)-55;w=max(xs)-min(xs)+110;h=max(ys)-min(ys)+110
  s.append(f'<g data-item="cluster:{c["id"]}" class="selectable"><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="40" fill="#c5a572" fill-opacity=".05" stroke="#c5a572" stroke-opacity=".6" stroke-width="5" stroke-dasharray="15 13"/>')
  if labels:s.append(text(x+w/2,y-18,c['id']+' · 4',44,'#e1be86',extra='paint-order="stroke" stroke="#20282d" stroke-width="10"'))
  s.append('</g>')
  s.extend(shape_prop(item) for item in items)
 s.append('</g><g class="layer-original" style="display:none">');s.extend(shape_prop(a,True) for a in source_props);s.append('</g>')
 s.append('<g class="layer-start"><circle cx="2500" cy="600" r="150" fill="#70b2b5" fill-opacity=".07" stroke="#94ced0" stroke-width="6" stroke-dasharray="18 16"/><path d="M2500,564l28,36 -28,36 -28,-36Z" fill="#b2e3dc"/>')
 if labels:s.append(text(2500,792,'비야 시작 · 2500,600',43,'#b2e3dc'))
 s.append('</g><g class="layer-flow">')
 arrows=[(0,'M2500,3170L2500,2880'),(120,'M30,1540L550,1540'),(240,'M4970,1560L4550,1560')]
 for at,path in arrows:s.append(f'<path data-at="{at}" d="{path}" fill="none" stroke="#d87870" stroke-width="24" stroke-linecap="round" marker-end="url(#arrow)"/>')
 if labels:s += [text(2850,3140,'남측 주공세 · 0:00',46,'#df9c8d'),text(500,1420,'서측 압박 · 2:00',44,'#df9c8d'),text(4480,1440,'동측 압박 · 4:00',44,'#df9c8d'),text(2500,2650,'최종 교전 여유 · 시설물 비움',42,'#a9c2b3')]
 s.append('</g>')
 if labels:
  for n in range(0,5001,1000):s.append(text(n+20,3190,str(n),33,'#7e8d96','start'))
  s.append(text(4910,540,'N ↑',54,'#ceb68c'))
 s.append('</svg>');return ''.join(s)

map_labeled=map_svg(True);map_clean=map_svg(False)
(OUT/'map.svg').write_text(map_labeled);(OUT/'blockout.svg').write_text(map_clean)
sheet=['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 7200 4550" width="2160" height="1365" style="font-family:Noto Sans CJK KR,sans-serif">','<rect width="7200" height="4550" fill="#11181f"/>',text(240,220,'VIYA / MAP-PLAN-001',64,'#c9ad7a','start'),text(240,405,'최후의 성벽 — 공세가 남긴 전장',112,'#f0e9dc','start'),text(240,525,'프롤로그 5000×3200 · 배치 시안 · 게임 미적용 / 아트 미확정',54,'#96a7b2','start'),'<g transform="translate(240 680)">',map_labeled.replace('<svg ', '<svg width="5000" height="3200" ',1),'</g>','<rect x="5500" y="680" width="1460" height="3200" rx="32" fill="#18232c" stroke="#33444f" stroke-width="4"/>',text(5610,825,'배치 의도',72,'#e5d7bd','start')]
legend=[('A','마지막 성문','시작 주위는 비우고 보급은 서쪽에.'),('B','불탄 병참 구역','창고 옆에 물자를 묶어 배치.'),('C','무너진 서측 거점','막사·수레와 후퇴 잔해를 연결.'),('D','반파된 동측 병영','병영 전면은 넓게 열어 둠.'),('E','철수한 구호·병기 구역','물 항아리·이송 물자를 시설 옆에.'),('F','돌파당한 방어선','남쪽일수록 파손, 중앙은 전개 공간.')]
for i,(ident,title,desc) in enumerate(legend):
 y=1010+i*260;sheet +=[text(5610,y,ident+'  '+title,55,'#d9c6a3','start'),text(5610,y+88,desc,41,'#9cadb6','start')]
sheet += [text(5610,2690,'파괴 소품 32 = 8묶음 × 4',53,'#e0bd81','start'),text(5610,2780,'상자16 / 항아리8 / 잔해8',43,'#b6c1c6','start'),text(5610,2910,'고정 장애물 20 (기존4 유지)',49,'#d6c5a5','start'),text(5610,3000,'소품은 이동 비충돌 · 수치 제안 없음',40,'#9cadb6','start'),text(5610,3130,'청록 점선  이동·회피 동선',44,'#86b2bd','start'),text(5610,3230,'녹색 원    30무리 전개 여유',44,'#99b79f','start'),text(5610,3330,'붉은 화살표  공세 방향 가이드',42,'#dc9387','start'),text(5610,3470,'실제 생성은 플레이어 주변 규칙 유지.',39,'#a8b5bb','start'),text(5610,3550,'고정 스폰·보스 좌표를 뜻하지 않음.',39,'#a8b5bb','start'),text(5610,3710,'정확한 좌표: layout.json',39,'#c5b38e','start'),text(240,4120,'설계 원칙  시설 옆에 소품을 묶고, 중앙 진격로·양측 연결로·외곽 회피로를 비운다.',58,'#d5d1c7','start'),text(240,4230,'기존 소품 종류·HP·ID·32개 총수 유지  /  현재 게임 데이터·전투·저장에는 미반영',46,'#91a2ad','start'),text(240,4350,'도식은 좌표 설계 기준. 생성형 분위기 그림이 다르면 이 도식과 JSON을 우선한다.',43,'#728793','start'),'</svg>']
(OUT/'layout.svg').write_text(''.join(sheet))

html_template='''<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>VIYA — 전장 배치 시안 01</title><style>
*{box-sizing:border-box}body{margin:0;background:#10171f;color:#e8e1d3;font-family:'Noto Sans CJK KR',sans-serif}header{padding:24px 30px;border-bottom:1px solid #33414d}.eyebrow{font-size:12px;letter-spacing:.12em;color:#bca47a}h1{font-size:25px;margin:8px 0}header p{color:#a2b1bb;margin:8px 0;font-size:13px}.badges{display:flex;gap:12px;flex-wrap:wrap}.badges span{border:1px solid #43505b;padding:5px 9px;border-radius:4px;font-size:12px;color:#cab893}main{display:grid;grid-template-columns:minmax(0,1fr) 330px;min-height:72vh}.left{padding:20px}.tools{display:flex;gap:12px;flex-wrap:wrap;align-items:center;font-size:12px;margin-bottom:14px;color:#becbd2}button,select,a.download{background:#22313c;color:#e0d7c7;border:1px solid #52616c;border-radius:4px;padding:7px 11px;font:inherit;cursor:pointer}.tools label{cursor:pointer}input{accent-color:#bda375}.stage{border:1px solid #45515c;border-radius:8px;overflow:hidden;background:#20282d;touch-action:none;height:min(70vh,900px);min-height:350px}.stage>svg{width:100%;height:100%;display:block}.selectable{cursor:pointer}.selectable:hover>rect,.selectable:hover>circle{stroke:#fff0be;stroke-width:12}.selected>rect,.selected>circle{stroke:#ffe0a2;stroke-width:14}.meta{font-size:12px;color:#9eafb8;display:flex;justify-content:space-between;gap:16px;margin-top:8px}aside{background:#17232d;border-left:1px solid #344752;padding:24px}aside h2{font-size:20px;margin-top:0}aside p,aside li{font-size:13px;line-height:1.8;color:#b1c0c8}.entry{border-bottom:1px solid #34434c;padding:13px 0;cursor:pointer}.entry b{color:#d8c39d}.entry small{display:block;line-height:1.7;color:#98aab5}.actions{display:flex;gap:8px;flex-wrap:wrap;margin-top:20px}a{color:#d1b782;text-decoration:none}footer{padding:18px 30px;color:#8fa2ad;font-size:12px;border-top:1px solid #33434e}.off{display:none!important}@media(max-width:950px){main{grid-template-columns:1fr}aside{border-left:0;border-top:1px solid #344752}.stage{height:auto;aspect-ratio:25/16;min-height:0}}@media print{.tools,.actions{display:none}main{grid-template-columns:1fr 300px}.stage{height:70vh}body{print-color-adjust:exact}}
</style><header><div class="eyebrow">VIYA / MAP-PLAN-001</div><h1>최후의 성벽 — 공세가 남긴 전장</h1><p>프롤로그 전체 배치 시안입니다. 시설·소품을 누르면 위치와 배치 이유를 볼 수 있습니다.</p><div class="badges"><span>5000 × 3200</span><span>고정 장애물 20 · 기존4 유지</span><span>파괴 소품32 · 8묶음</span><span>제안 / 게임 미적용 / 아트 미확정</span></div></header><main><section class="left"><nav class="tools"><label><input type="checkbox" data-layer="props" checked> 소품32</label><label><input type="checkbox" data-layer="routes" checked> 이동·회피로</label><label><input type="checkbox" data-layer="formation" checked> 전개 여유</label><label><input type="checkbox" data-layer="original"> 현재 소품 위치 비교</label><select id="phase"><option value="240">전체 공세 방향</option><option value="0">0~2분 정면</option><option value="120">2~4분 +서측</option><option value="240">4~6분 +동측</option></select><button id="zoom-in" aria-label="지도 확대">확대 +</button><button id="zoom-out" aria-label="지도 축소">축소 −</button><button id="reset">전체 보기</button></nav><div class="stage" id="stage">__SVG__</div><div class="meta"><span>휠/버튼 확대 · 드래그 이동 · 시설 클릭</span><span id="coords">좌표 0,0</span></div></section><aside id="info"></aside></main><footer>붉은 화살표는 방향 설명입니다. 실제 적 생성은 플레이어 주변 규칙을 유지하며, 고정 스폰·보스 좌표나 체크포인트 시설을 뜻하지 않습니다.</footer><script>
const plan=__DATA__;const svg=document.querySelector('#stage>svg'),info=document.getElementById('info');let view=[0,0,5000,3200],drag=null,moved=false;
const escape=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function renderInfo(type,id){document.querySelectorAll('.selected').forEach(e=>e.classList.remove('selected'));const node=document.querySelector(`[data-item="${type}:${id}"]`);if(node)node.classList.add('selected');let title=plan.theme,body='북쪽 성문에서 남쪽 돌파구로 내려갈수록 파손과 철수 흔적이 강해집니다.';if(type==='district'){const d=plan.districts.find(x=>x.id===id);title=d.id+'. '+d.name;body=d.story+`<p>소품 묶음 ${plan.clusters.filter(c=>c.district===id).length}곳 · 시설과 연결된 배치</p>`}else if(type==='solid'){const d=plan.solids.find(x=>x.id===id);title=d.name;body=`${escape(d.story)}<p>좌표 ${d.rect.join(', ')}<br>${d.kind==='existing'?'현재 충돌체 유지':'신규 고정 장애물 제안'}<br>내부 진입·새 상호작용은 별도 제안 없음</p>`}else if(type==='cluster'){const d=plan.clusters.find(x=>x.id===id);title=d.id+'. '+d.name;body=d.story+'<p>총량을 늘리지 않고 시설 주변에 4개씩 묶습니다.</p>'}else if(type==='prop'){const d=plan.destructibles.find(x=>x.source_index===Number(id));title={crate:'보급 상자',urn:'물 항아리',debris:'파괴 가능한 잔해'}[d.style];body=`소속 ${d.cluster}<p>제안 좌표 ${d.p.join(', ')}<br>기존 ID ${d.id} / HP ${d.hp}<br>이동 비충돌 · 파괴/재생성 규칙 유지 제안</p>`}info.innerHTML=`<h2>${escape(title)}</h2><p>${body}</p>`+(type==='overview'?plan.districts.map(d=>`<div class="entry" data-pick="${d.id}"><b>${d.id}. ${escape(d.name)}</b><small>${escape(d.story)}</small></div>`).join(''):'<button id="overview">구역 목록으로</button>')+`<div class="actions"><a class="download" href="layout.svg" download>배치도 SVG</a><a class="download" href="layout.png" download>PNG</a><a class="download" href="concept.png" download>분위기 그림</a><button id="json">좌표 JSON</button></div><p>중앙·외곽·양측 연결로를 확보합니다. 그룹 집중에 따른 자원 회수 효율과 실제 AI/모바일 성능은 적용 시 검증합니다.</p>`;info.querySelectorAll('[data-pick]').forEach(e=>e.onclick=()=>renderInfo('district',e.dataset.pick));const back=info.querySelector('#overview');if(back)back.onclick=()=>renderInfo('overview','');info.querySelector('#json').onclick=()=>{const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([JSON.stringify(plan,null,2)],{type:'application/json'}));a.download='viya_map_plan_001.json';a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000)}}
function pos(e){const p=svg.createSVGPoint();p.x=e.clientX;p.y=e.clientY;return p.matrixTransform(svg.getScreenCTM().inverse())}function apply(){svg.setAttribute('viewBox',view.join(' '))}
svg.onwheel=e=>{e.preventDefault();const p=pos(e),factor=e.deltaY>0?1.15:.87,w=Math.max(900,Math.min(6000,view[2]*factor)),ratio=w/view[2];view=[p.x-(p.x-view[0])*ratio,p.y-(p.y-view[1])*ratio,w,w*.64];apply()};svg.onpointerdown=e=>{drag={x:e.clientX,y:e.clientY,v:[...view],target:e.target.closest('[data-item]')};moved=false;svg.setPointerCapture(e.pointerId)};svg.onpointermove=e=>{const p=pos(e);document.getElementById('coords').textContent=`좌표 ${Math.round(p.x)}, ${Math.round(p.y)}`;if(drag){const r=svg.getBoundingClientRect(),dx=e.clientX-drag.x,dy=e.clientY-drag.y;if(Math.abs(dx)+Math.abs(dy)>5)moved=true;const scale=Math.min(r.width/drag.v[2],r.height/drag.v[3]);view=[drag.v[0]-dx/scale,drag.v[1]-dy/scale,drag.v[2],drag.v[3]];apply()}};svg.onpointerup=()=>{if(drag&&!moved&&drag.target){const [type,id]=drag.target.dataset.item.split(':');renderInfo(type,id)}drag=null};svg.onpointercancel=()=>drag=null;
document.getElementById('zoom-in').onclick=()=>{const w=Math.max(900,view[2]*.8);view=[view[0]+(view[2]-w)*.5,view[1]+(view[3]-w*.64)*.5,w,w*.64];apply()};document.getElementById('zoom-out').onclick=()=>{const w=Math.min(6000,view[2]*1.25);view=[view[0]+(view[2]-w)*.5,view[1]+(view[3]-w*.64)*.5,w,w*.64];apply()};document.getElementById('reset').onclick=()=>{view=[0,0,5000,3200];apply()};document.querySelectorAll('[data-layer]').forEach(input=>input.onchange=()=>{const layer=svg.querySelector('.layer-'+input.dataset.layer);layer.style.display=input.checked?'':'none'});document.getElementById('phase').onchange=e=>svg.querySelectorAll('[data-at]').forEach(p=>p.style.display=Number(p.dataset.at)<=Number(e.target.value)?'':'none');renderInfo('overview','');
</script></html>'''
(OUT/'preview.html').write_text(html_template.replace('__SVG__',map_labeled).replace('__DATA__',json.dumps(plan,ensure_ascii=False)))
print(json.dumps({'output':str(OUT),'solid_count':len(solid),'props':len(props),'open_ratio':open_ratio,'grid_cells':len(seen)},ensure_ascii=False))
