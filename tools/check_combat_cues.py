#!/usr/bin/env python3
"""Changed-source proof only; NOT GDScript parsing, behavior, rendering or FPS."""
from __future__ import annotations
import ast
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
FILES = ('scripts/combat/run_state.gd', 'scripts/combat/battle_view.gd',
         'scripts/combat/combat_cues.gd', 'tests/test_combat_cues.gd',
         'tools/check_project.py', 'tools/check_combat_cues.py',
         'scripts/combat/enemy_patterns.gd',
         'scripts/combat/enemy_pattern_visuals.gd',
         'scripts/progression/run_snapshot.gd',
         'scripts/combat/actor_motion.gd',
         'data/enemy_patterns.json',
         'scripts/combat/enemy_patterns_v1.gd',
         'scripts/combat/enemy_patterns_v2.gd',
         'data/enemy_patterns_v2.json',
         'scripts/combat/enemy_patterns_v17.gd',
         'scripts/combat/enemy_patterns_v3.gd',
         'scripts/combat/curse_visuals.gd',
         'data/enemy_curse_v3.json',
         'scripts/combat/approach_cues.gd',
)
# GAME-024: reviewed enemy variants, formations and hostile projectile integration. Exact source baselines retain mutation guards.
BASE_RUN_BLOB = '673d75a748fa5f1f9ac72ec73bbd9120fdcfce02'
BASE_VIEW_BLOB = '9e5c23c321e53f3ccb948d5dc7f1a2f101ffcd32'
BASE_RUNNER_BLOB = '1ab68ad8a51271e3d47db8b02d433991f42e8d6c'
# Exact run_engine() from GAME-004D; all 7 suites and failure checks are protected.
BASE_ENGINE_FUNCTION_SHA256 = '9156043eaf896d72565563cc1e2f623cf0c8fbac7f032f19bffee7e4946a69ee'
ADDED_RUN_LINES = ('const CombatCues = preload("res://scripts/combat/combat_cues.gd")', 'var cues = CombatCues.new()', '\tcues.reset()', '\tcues.advance(dt)', '\t\tcues.record_collected_xp(player, reward)', '\t\tvar critical: bool = false', '\t\tvar previous_hp: int = int(enemies[i]["hp"])', '\t\tvar hit_at: Vector2 = enemies[i]["p"]', '\t\t\tcritical = true', '\t\t# Display HP actually removed, not theoretical overkill damage. Reuse the crit roll.', '\t\tvar hp_lost: int = maxi(0, previous_hp - maxi(0, int(enemies[i]["hp"])))', '\t\tcues.record_hit(id, hit_at, hp_lost, critical)', '\tcues.record_kill(int(enemy.id), enemy.p)')


# GAME030: exact cosmetic-only contextual damage hooks; strip back to GAME024.
RECEIVED_RUN_REPLACEMENTS = (
    ('func damage_player(amount: int, damage_type: String = "physical", enemy_penetration: float = 0.0, source: Dictionary = {}) -> bool:', 'func damage_player(amount: int, damage_type: String = "physical", enemy_penetration: float = 0.0) -> bool:'),
    ('\telif hp < previous_hp:\n\t\tfeedback.trigger("hurt")', '\telse:\n\t\tfeedback.trigger("hurt")'),
    ('damage_player(int(enemy.get("contact_damage",12)), "physical", 0.0, {"kind":"contact", "id":int(enemy.id), "p":enemy.p})', 'damage_player(int(enemy.get("contact_damage",12)))'),
    ('damage_player(int(bullet.damage), "physical", 0.0, {"kind":"projectile", "direction":-bullet.velocity.normalized()})', 'damage_player(int(bullet.damage))'),
)
RECEIVED_RUN_LINES = ('\tvar previous_hp: int = hp', '\tcues.record_received(player, previous_hp-hp, source)')

# GAME033: strip only these exact read-only pickup observations and shared glyph adapter.
SUPPLY_RUN_LINES = ('\t# Observe committed deltas only; keep the existing effect/reward order unchanged.', '\tvar supply_before:Dictionary={"hp":hp,"mp":magic.mana,"gold":gold_collected,"kills":kills,"bullets":enemy_bullets.size()}', '\tvar supply_xp:float=0.0', '\t\t\t\tsupply_xp=xp')
SUPPLY_RECEIPT = ('\tcues.record_item(player, str(SupplyCatalog.ITEM_NAMES[kind]), {"kind":kind,"hp":hp-int(supply_before.hp),"mp":magic.mana-float(supply_before.mp),"gold":gold_collected-int(supply_before.gold),"kills":kills-int(supply_before.kills),"bullets":int(supply_before.bullets)-enemy_bullets.size(),"xp":supply_xp})', '\tcues.record_item(player, str(SupplyCatalog.ITEM_NAMES[kind]))')
SUPPLY_VIEW_ADAPTER = ('\t_draw_supply_items()\n\nfunc _draw_supply_items() -> void:\n\tvar visible:=Rect2(Vector2.ZERO,size).grow(22)\n\tvar compact:bool=size.x<900 or size.y<350\n\tfor item in simulation.item_pickups:\n\t\tvar at:=_screen(item.p)\n\t\tif visible.has_point(at):SupplyFeedback.draw_item(self,at,str(item.kind),compact)\n', '\tfor item in simulation.item_pickups:\n\t\tvar at := _screen(item.p)\n\t\tif not visible.has_point(at):\n\t\t\tcontinue\n\t\tvar color: Color = {"hp":Color("f58c9c"),"mp":Color("7abcf3"),"magnet":Color("f3ce79"),"purge":Color("cea2fa")}[item.kind]\n\t\tdraw_circle(at,17,Color("20252c"))\n\t\tdraw_arc(at,18,0,TAU,24,color,2,true)\n\t\tmatch item.kind:\n\t\t\t"hp":\n\t\t\t\tdraw_line(at+Vector2(-9,0),at+Vector2(9,0),color,5)\n\t\t\t\tdraw_line(at+Vector2(0,-9),at+Vector2(0,9),color,5)\n\t\t\t"mp":\n\t\t\t\tdraw_colored_polygon(PackedVector2Array([at+Vector2(0,-11),at+Vector2(8,3),at+Vector2(0,10),at+Vector2(-8,3)]),color)\n\t\t\t"magnet":\n\t\t\t\tdraw_arc(at,8,0,PI,14,color,5,true)\n\t\t\t\tdraw_line(at+Vector2(-8,0),at+Vector2(-8,-9),color,5)\n\t\t\t\tdraw_line(at+Vector2(8,0),at+Vector2(8,-9),color,5)\n\t\t\t"purge":\n\t\t\t\tdraw_line(at-Vector2(8,8),at+Vector2(8,8),color,4)\n\t\t\t\tdraw_line(at+Vector2(-8,8),at+Vector2(8,-8),color,4)\n')
SUPPLY_VIEW_IMPORT = 'const SupplyFeedback=preload("res://scripts/combat/supply_feedback.gd")\n'


# GAME038: exact reviewed gameplay adapters. Removing only these additions must
# still recover the original GAME024 mutation-protected RunState byte for byte.
PATTERN_RUN_LINES = (
    'const EnemyPatterns = preload("res://scripts/combat/enemy_patterns.gd")',
    'var enemy_patterns = EnemyPatterns.new()',
    'var enemy_pattern_version:int=0',
    '\tvar selected_pattern:int=(3 if selected_profile==1 and mode=="campaign" else 0) if pattern_version==-1 else pattern_version',
    '\tif selected_pattern not in [0,1,2,3] or (selected_pattern>0 and (selected_profile!=1 or mode!="campaign" or not enemy_patterns.available(selected_pattern))):return false',
    '\tenemy_pattern_version = selected_pattern',
    '\tenemy_patterns.attach(self,enemy)',
    '\t\tvar pattern_locked:bool=enemy_patterns.tick(self,enemy,dt)',
    '\t\tif phase!=Phase.RUNNING:return',
    '\t\tif pattern_locked:continue',
    '\t\tif enemy_patterns.locked(self,enemy):continue',
)
CURSE_BULLET_ADAPTER = '\t\tif enemy_patterns.is_curse(self,bullet):\n\t\t\tif enemy_patterns.move_curse(self,bullet,dt):enemy_bullets.remove_at(index)\n\t\t\tif phase!=Phase.RUNNING:return\n\t\t\tcontinue\n'
CURSE_VIEW_ADAPTER = '\t\tif simulation.enemy_patterns.is_curse(simulation,bullet):\n\t\t\tpreload("res://scripts/combat/curse_visuals.gd").draw_bullet(self,bullet)\n\t\t\tcontinue\n'
PATTERN_START_SIGNATURE = (', pacing_version:int=-1, pattern_version:int=-1) -> bool:', ', pacing_version:int=-1) -> bool:')
# Pin the reviewed new AI/migration/render adapters as well as the historical baseline.
PATTERN_REVIEWED_SHA256 = {'scripts/combat/enemy_patterns.gd': 'a19cad533e9185a0bbca1671028349463a2c9c7c020c0e26dea1d5f59b3eebda', 'scripts/combat/enemy_pattern_visuals.gd': 'ffe5032905c8df738b2d7f2a92346206b7df14502b4d2f8babc88304adc5d666', 'scripts/progression/run_snapshot.gd': 'f6e6abd9dd2ff61e66505ee0e35ee6d208c9965d59f9e0681737c0ac14ca3bab', 'scripts/combat/actor_motion.gd': '77c63ca6327c28a4b99aafea6f104a0b0ae9a91c2e364914d79307d4e90b5261', 'data/enemy_patterns.json': 'ba04c2b3076746724a09cf212576886edfa33821f666daa97a541d5042680bec', 'scripts/combat/enemy_patterns_v1.gd': '4059f30002b56fa0ccb73ed38b4fe4af9c0fe8092a8f5836ad53f6e3cef5a4af', 'scripts/combat/enemy_patterns_v2.gd': '60ff5da133476bd9c851aaef695cd07ae748e313d9f654dd4b2b0e258af7ca1d', 'data/enemy_patterns_v2.json': '83bf0449e6dad16499af5a4c533c51d0ce3dc06fd73c02eb626de2d1e2e7ac21', 'scripts/combat/enemy_patterns_v17.gd': 'df42114040f4da370a67257445063fdb851033182108111eac609758334b81ab', 'scripts/combat/enemy_patterns_v3.gd': '1c5ea0cee251c0fda6a5a77b40201dba8d97b27f42f5ac92c93602e43c831114', 'scripts/combat/curse_visuals.gd': 'f6fd054527091a5631eb003a2ea38c8308d1bccc29098f5542250916ea0fb3ac', 'data/enemy_curse_v3.json': 'c1d23889286fe1f91d4ef3b206de5b6e910211a52e935162da42355dc5d39659', 'scripts/combat/approach_cues.gd': '3b61db842e2fced8e08c391e83fe342a2f349e7453d2d37421f51d1b340ce4fe'}


def blob(text: str) -> str:
    data = text.encode('utf-8')
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def section(source: str, name: str) -> str:
    return source.split('func ' + name + '(', 1)[1].split('\nfunc ', 1)[0]


def engine_function_digest(source: str) -> str:
    """Allow source-orchestration changes, never alteration of native checks."""
    try:
        nodes = [n for n in ast.parse(source).body
                 if isinstance(n, ast.FunctionDef) and n.name == 'run_engine']
        if len(nodes) != 1:
            return ''
        function_source = ast.get_source_segment(source, nodes[0])
        return hashlib.sha256(function_source.encode('utf-8')).hexdigest()
    except (SyntaxError, AttributeError, UnicodeError):
        return ''


def validate(sources: dict[str, str]) -> list[str]:
    errors: list[str] = []
    run, view, cues, tests, runner, _ = [sources[x] for x in FILES[:6]]
    for path, expected in PATTERN_REVIEWED_SHA256.items():
        if hashlib.sha256(sources[path].encode('utf-8')).hexdigest() != expected:
            errors.append('Reviewed GAME038-040 pattern/compatibility source changed: ' + path)
    if 'res://tests/test_pattern_reacquire.gd' not in tests:
        errors.append('Reacquisition runtime tests are not registered')
    if 'res://tests/test_enemy_patterns.gd' not in tests:
        errors.append('Pattern runtime tests are not registered')
    if view.count('preload("res://scripts/combat/enemy_pattern_visuals.gd").draw(self)') != 1:
        errors.append('Shared hostile telegraph hook changed')
    if run.count(CURSE_BULLET_ADAPTER)!=1 or view.count(CURSE_VIEW_ADAPTER)!=1:
        errors.append("Missing/changed curse bullet adapters")
    if "res://tests/test_enemy_curse.gd" not in tests:
        errors.append("Curse runtime tests are not registered")
    restored = run.replace(CURSE_BULLET_ADAPTER, "", 1)
    if restored.count(PATTERN_START_SIGNATURE[0]) != 1:
        errors.append('Missing/changed reviewed pattern start gate')
    restored = restored.replace(*PATTERN_START_SIGNATURE, 1)
    for line in PATTERN_RUN_LINES:
        if restored.splitlines().count(line) != 1:
            errors.append('Missing/changed reviewed pattern adapter: ' + line.strip())
        restored = restored.replace(line + '\n', '', 1)
    if restored.count(SUPPLY_RECEIPT[0]) != 1:
        errors.append('Missing/changed committed supply receipt hook')
    restored = restored.replace(*SUPPLY_RECEIPT, 1)
    for line in SUPPLY_RUN_LINES:
        if restored.splitlines().count(line) != 1:
            errors.append('Missing/changed read-only supply observation: ' + line.strip())
        restored = restored.replace(line + '\n', '', 1)
    for old, original in RECEIVED_RUN_REPLACEMENTS:
        if restored.count(old) != 1:
            errors.append('Missing/duplicate reviewed received-damage hook: ' + old)
        restored = restored.replace(old, original, 1)
    for line in ADDED_RUN_LINES + RECEIVED_RUN_LINES:
        if restored.splitlines().count(line) != 1:
            errors.append('Missing/duplicate reviewed visual hook: ' + line.strip())
        restored = restored.replace(line + '\n', '', 1)
    if blob(restored) != BASE_RUN_BLOB:
        errors.append('RunState differs from the reviewed GAME-024 baseline')
    if engine_function_digest(runner) != BASE_ENGINE_FUNCTION_SHA256:
        errors.append('Existing native engine commands or pass/fail criteria changed')
    if view.count(SUPPLY_VIEW_ADAPTER[0]) != 1 or view.count(SUPPLY_VIEW_IMPORT) != 1:
        errors.append('Missing/changed shared supply glyph adapter')
    restored_view = view.replace(CURSE_VIEW_ADAPTER, '', 1).replace(*SUPPLY_VIEW_ADAPTER, 1).replace(SUPPLY_VIEW_IMPORT, '', 1)
    restored_view = restored_view.split('\nfunc _draw_combat_cues() -> void:', 1)[0]
    restored_view = restored_view.replace('\t_draw_combat_cues()\n', '', 1)
    restored_view = restored_view.replace('\t\t\tvar flash: float = simulation.cues.flash_alpha(int(enemy["id"]))\n', '', 1)
    restored_view = restored_view.replace('\t\t\tvar enemy_color: Color = Color("aa5364").lerp(Color("fff1db"), flash)\n', '', 1)
    restored_view = restored_view.replace(']), enemy_color)', ']), Color("aa5364"))', 1)
    if blob(restored_view) != BASE_VIEW_BLOB:
        errors.append('Battle View differs from the reviewed GAME-030 incoming feedback baseline')
    for value in ('const MAX_EVENTS := 48', 'const MAX_FLASHES := 80',
                  'events.size() >= MAX_EVENTS', 'events.pop_front()',
                  'flashes.size() >= MAX_FLASHES', 'flashes.erase(flashes.keys()[0])',
                  'events.remove_at(i)', 'flashes.erase(id)',
                  'events.duplicate(true)', 'not enabled or hp_lost <= 0',
                  'not enabled or amount <= 0.0 or not is_finite(amount)'):
        if value not in cues:
            errors.append('Missing bounded presentation contract: ' + value)
    code_cues = '\n'.join(line.split('#', 1)[0] for line in cues.splitlines())
    for forbidden in ('randf(', 'randi(', 'RandomNumberGenerator', 'Timer.new(',
                      'create_timer(', 'create_tween(', 'Time.get_', 'simulation.',
                      'growth.', 'magic.', 'RunState.new('):
        if forbidden in code_cues:
            errors.append('Presentation must not own gameplay/RNG/wall time: ' + forbidden)
    step = section(run, 'step')
    if step.index('cues.advance(dt)') < step.index('if phase != Phase.RUNNING'):
        errors.append('Visual time advances before the RUNNING guard')
    received = section(run, 'damage_player')
    if 'cues.record_received(player, previous_hp-hp, source)' not in received or received.index('cues.record_received(') < received.index('hp = maxi(0, hp - (amount - prevented))'):
        errors.append('Received cue must follow committed post-mitigation HP loss')
    for marker in ('const MAX_RECEIVED := 6', 'received.size() >= MAX_RECEIVED', 'received.pop_front()', 'received.duplicate(true)', 'received.clear()'):
        if marker not in cues:
            errors.append('Missing received-damage bound/reset/copy: ' + marker)
    hit = section(run, '_damage_enemy')
    if hit.index('cues.record_hit(') < hit.index('enemies[i]["hp"] -='):
        errors.append('Hit cue emitted before actual damage')
    death = section(run, '_defeat_enemy')
    if '_defeat_enemy(i)' not in hit:
        errors.append('Lethal damage must use the committed death path')
    if death.index('cues.record_kill(') < death.index('kills += 1'):
        errors.append('Kill cue emitted before actual kill')
    collect = section(run, '_collect_pickups')
    if collect.index('cues.record_collected_xp(') < collect.index('grant_xp(reward)'):
        errors.append('XP cue emitted before actual collection grant')
    if 'cues.' in section(run, 'add_pickup') or 'cues.' in section(run, 'grant_xp'):
        errors.append('Drop creation or arbitrary XP grant must not advertise collection')
    if 'cues.advance(' in view or 'cues.record_' in view or 'cues.reset(' in view:
        errors.append('View must be read-only')
    for marker in ('simulation.cues.flash_alpha(int(enemy["id"]))', '_draw_combat_cues()',
                   'display_plan=Display.build(self)', 'clip_contents = true'):
        if marker not in view:
            errors.append('View missing connection: ' + marker)
    for marker in ('gameplay_snapshot(a) == gameplay_snapshot(b)', 'Cues.MAX_EVENTS',
                   'state.request_transition("leave"', 'scene.slot_buttons[0].pressed.emit()',
                   'state.cues.events.is_empty() and state.cues.flashes.is_empty()'):
        if marker not in tests:
            errors.append('Missing authored engine regression: ' + marker)
    return errors


def check() -> dict:
    sources = {name: (ROOT / name).read_text(encoding='utf-8') for name in FILES}
    errors = validate(sources)
    tree = ast.parse(sources['tools/check_project.py'])
    helper = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'check_delimiters')
    ns: dict = {}
    exec(compile(ast.Module(body=[helper], type_ignores=[]), 'existing_delimiter_helper', 'exec'), ns)
    for name, text in sources.items():
        try:
            if name.endswith('.gd'):
                ns['check_delimiters'](text)
                names = re.findall(r'^func (\w+)\(', text, re.M)
                if len(names) != len(set(names)):
                    errors.append(name + ': duplicate function')
            elif name.endswith('.json'):
                json.loads(text)
            else:
                ast.parse(text, name)
            for number, line in enumerate(text.splitlines(), 1):
                if line.rstrip() != line or (name.endswith('.gd') and line.startswith(' ')):
                    errors.append(f'{name}:{number}: whitespace/indentation')
        except (ValueError, SyntaxError) as error:
            errors.append(f'{name}: {error}')
    negative = []
    cases = [
        ('curse_unregistered', FILES[3], 'res://tests/test_enemy_curse.gd', 'res://tests/missing_curse.gd'),
        ('curse_doublefire', 'scripts/combat/enemy_patterns_v3.gd', 'p.phase="recovery"', 'p.phase="windup"'),
        ('v17_retrofit', 'scripts/progression/run_snapshot.gd', 'return data # Preserve published17 AI', 'data.run.enemy_pattern_version=3\n\treturn data # Preserve published17 AI'),
        ('curse_gate', FILES[0], CURSE_BULLET_ADAPTER, ''),
        ('curse_render', FILES[1], CURSE_VIEW_ADAPTER, ''),
        ('reacquire_unregistered', FILES[3], 'res://tests/test_pattern_reacquire.gd', 'res://tests/missing_reacquire.gd'),
        ('v16_retrofit', 'scripts/progression/run_snapshot.gd', 'return data # Preserve original rules', 'data.run.enemy_pattern_version=2\n\treturn data # Preserve original rules'),
        ('pattern_single_hit', 'scripts/combat/enemy_patterns_v1.gd', 'p.phase="strike"', 'p.phase="windup"'),
        ('pattern_old_ai', 'scripts/progression/run_snapshot.gd', 'data.run.enemy_pattern_version=0', 'data.run.enemy_pattern_version=1'),
        ('pattern_visual_mutation', 'scripts/combat/enemy_pattern_visuals.gd', 'var result:Array=[]', 'var result:Array=[]\n\tview.simulation.hp=1'),
        ('pattern_unregistered', FILES[3], 'res://tests/test_enemy_patterns.gd', 'res://tests/missing_pattern.gd'),
        ('pattern_gate', FILES[0], 'if selected_pattern not in [0,1,2,3]', 'if false'),
        ('pattern_contact_guard', FILES[0], '\t\tif enemy_patterns.locked(self,enemy):continue', ''),
        ('pattern_stop_on_defeat', FILES[0], '\t\tif phase!=Phase.RUNNING:return', ''),
        ('missing_reset', FILES[0], '\tcues.reset()\n', ''),
        ('early_clock', FILES[0], '\tvar dt := minf(delta, 0.05)\n', '\tvar dt := minf(delta, 0.05)\n\tcues.advance(dt)\n'),
        ('changed_damage', FILES[0], 'damage *= float(stats.get("crit_damage", 2.0))', 'damage *= 99.0'),
        ('drop_as_collection', FILES[0], '\tpickups.append(', '\tcues.record_collected_xp(at, value)\n\tpickups.append('),
        ('unbounded_received', FILES[2], 'received.pop_front()', 'pass'),
        ('received_before_hp', FILES[0], '\thp = maxi(0, hp - (amount - prevented))\n\tcues.record_received(player, previous_hp-hp, source)', '\tcues.record_received(player, previous_hp-hp, source)\n\thp = maxi(0, hp - (amount - prevented))'),
        ('unbounded_visuals', FILES[2], 'events.pop_front()', 'pass'),
        ('cosmetic_rng', FILES[2], 'flashes[id] = FLASH_SECONDS', 'flashes[id] = randf()'),
        ('mutable_view', FILES[1], '\t_draw_combat_cues()', '\tsimulation.cues.advance(0.05)\n\t_draw_combat_cues()'),
        ('supply_changes_rewards', FILES[0], 'gold_collected += int(gold.value)', 'gold_collected += int(gold.value) * 2'),
        ('supply_mutates_observation', FILES[0], '\tvar supply_xp:float=0.0', '\thp += 1\n\tvar supply_xp:float=0.0'),
        ('supply_glyph_mutates_state', FILES[1], 'func _draw_supply_items() -> void:', 'func _draw_supply_items() -> void:\n\tsimulation.hp=1'),
        ('unregistered_test', FILES[4], 'res://tests/test_combat_cues.gd', 'res://tests/missing.gd'),
        ('ignored_engine_exit', FILES[4], 'result.returncode == 0 and not bad_log', 'True and not bad_log'),
        ('ignored_engine_errors', FILES[4], 'and not bad_log and not test_not_passed', 'and not test_not_passed'),
        ('ignored_test_result', FILES[4], 'and not bad_log and not test_not_passed', 'and not bad_log'),
    ]
    for label, path, old, new in cases:
        altered = dict(sources)
        # The drop insertion is inside the original indentation; it is only a bad-source fixture.
        if old not in altered[path] and label == 'drop_as_collection':
            old = '\t\tpickups.append('
            new = '\t\tcues.record_collected_xp(at, value)\n\t\tpickups.append('
        if old not in altered[path]:
            errors.append('fixture not applied: ' + label)
            continue
        altered[path] = altered[path].replace(old, new, 1)
        rejected = bool(validate(altered))
        negative.append({'fixture': label, 'rejected': rejected})
        if not rejected:
            errors.append('negative not rejected: ' + label)
    hashes = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in FILES}
    return {'status': 'FAIL' if errors else 'PASS', 'files_checked': len(FILES),
            'errors': errors, 'negative_controls': negative, 'source_sha256': hashes,
            'source_fingerprint': hashlib.sha256(json.dumps(hashes, sort_keys=True).encode()).hexdigest(),
            'baseline_run_blob': BASE_RUN_BLOB, 'baseline_runner_blob': BASE_RUNNER_BLOB,
            'baseline_engine_function_sha256': BASE_ENGINE_FUNCTION_SHA256,
            'scope': 'Changed-source UTF-8/delimiters/Python syntax, hook order, bounds, isolation, '
                     'reviewed GAME-024 RunState/GAME-030 view baselines with exact GAME-033 observations and GAME-038/039/040 version-gated pattern adapters and frozen v1/v2/v17, preserved engine runner. '
                     'NOT Godot parser/type/runtime, visual quality, input dispatch, or FPS.'}


if __name__ == '__main__':
    try:
        result = check()
    except (OSError, ValueError, IndexError, KeyError, SyntaxError, StopIteration) as error:
        result = {'status': 'FAIL', 'error': str(error)}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    raise SystemExit(0 if result['status'] == 'PASS' else 1)
