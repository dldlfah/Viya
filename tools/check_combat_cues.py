#!/usr/bin/env python3
"""Changed-source proof only; NOT GDScript parsing, behavior, rendering or FPS."""
from __future__ import annotations
import ast
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
FILES = ('scripts/combat/run_state.gd', 'scripts/combat/battle_view.gd', 'scripts/combat/combat_cues.gd', 'tests/test_combat_cues.gd', 'tools/check_project.py', 'tools/check_combat_cues.py', 'scripts/combat/enemy_patterns.gd', 'scripts/combat/enemy_pattern_visuals.gd', 'scripts/progression/run_snapshot.gd', 'scripts/combat/actor_motion.gd', 'data/enemy_patterns.json', 'scripts/combat/enemy_patterns_v1.gd', 'scripts/combat/enemy_patterns_v2.gd', 'data/enemy_patterns_v2.json', 'scripts/combat/enemy_patterns_v17.gd', 'scripts/combat/enemy_patterns_v3.gd', 'scripts/combat/curse_visuals.gd', 'data/enemy_curse_v3.json', 'scripts/combat/approach_cues.gd', 'scripts/combat/combat_camera.gd', 'scripts/combat/campaign_encounters.gd', 'data/campaign_encounters.json', 'scripts/combat/supply_feedback.gd', 'scripts/combat/combat_display.gd', 'scripts/main.gd', 'scripts/ui/mobile_main.gd', 'tests/fixtures/game046_v18/baseline.json', 'scripts/combat/campaign_pressure.gd', 'data/campaign_pressure.json', 'scripts/combat/campaign_encounters_v19.gd', 'tests/fixtures/game048_v19/baseline.json', 'data/campaign_battlefield.json', 'scripts/world/map_catalog.gd', 'scripts/world/supply_catalog.gd', 'scripts/combat/combat_profiles.gd', 'scripts/combat/stage_catalog.gd', 'scripts/combat/high_angle_battle.gd', 'scripts/combat/battlefield_presentation.gd', 'data/map_presentation_slots.json', 'data/chapter_one.json', 'tests/fixtures/game049_v20/baseline.json', 'scripts/world/map_space.gd', 'scripts/combat/spatial_candidates.gd', 'scripts/combat/weapon_modules.gd', 'tests/fixtures/game050_v21/map_space_before.gd', 'tests/fixtures/game050_v21/baseline.json', 'tests/test_run_navigation.gd', 'scripts/combat/loot_attraction.gd', 'tests/test_loot_attraction.gd', 'tests/test_route_queries.gd', 'scripts/combat/purge_feedback.gd', 'tests/test_purge_feedback.gd', 'scripts/combat/combat_audio.gd', 'scripts/combat/combat_audio_bank.gd', 'tests/test_combat_audio.gd', 'data/portrait_presentation.json', 'scripts/ui/portrait_assets.gd', 'scripts/ui/feedback_panel.gd', 'scripts/ui/responsive_feedback_panel.gd', 'scripts/combat/feedback_state.gd', 'tests/test_portrait_reactions.gd', 'tests/test_feedback.gd', 'tools/check_feedback_data.py', 'scripts/combat/oblique_projection.gd', 'scripts/combat/oblique_scenery.gd', 'tests/test_oblique_stage.gd', 'scripts/ui/battle_chrome.gd', 'scripts/combat/boss_guidance.gd', 'tests/test_camera_lead.gd', 'tests/test_actor_animation.gd', 'scripts/combat/incoming_feedback.gd', 'tests/test_incoming_feedback.gd', 'data/presentation_slots.json', 'assets/characters/pilot_32/source_manifest.json', 'assets/characters/pilot_32/resources/viya_directional_motion.tres', 'tests/test_character_pilot.gd', 'tests/test_map_pilot.gd', 'tests/test_maps.gd', 'scripts/progression/account_reset.gd', 'scripts/progression/gold_progress.gd', 'tests/test_stage_access_reset.gd', 'tests/test_chapter_ui.gd', 'data/actor_presentation.json', 'scripts/ui/actor_assets.gd', 'data/viya_motion.json', 'scripts/combat/viya_presentation.gd', 'tests/test_viya_presentation.gd', 'tools/viya_edge_filter.gd', 'tools/build_viya_render_cache.gd', 'tests/test_viya_edges.gd', 'assets/characters/pilot_32/render_cache/manifest.json', 'assets/characters/pilot_32/render_cache/viya_render_frames.tres', 'tools/viya_generated_edge_override.gd', 'tools/higgsfield/build_edge_repair.py', 'assets/characters/pilot_32/edge_repair/manifest.json')
# GAME064 adds a separate active resource and its immutable production PNG provenance.
FILES += ('assets/characters/pilot_32/game064_e_run/viya_game064_frames.tres',
          'assets/characters/pilot_32/game064_e_run/provenance/asset_manifest.json')
FILES += ('tests/test_gun_receipt.gd','tests/test_flier_expiry.gd','tests/fixtures/savefix001/flier_before.gd','tests/test_combat_performance.gd')
# GAME066 changes only the separately tested SE clip in the composite.
FILES += ('assets/characters/pilot_32/game066_se_run/viya_game066_frames.tres', 'assets/characters/pilot_32/game066_se_run/manifest.json', 'assets/characters/pilot_32/game066_se_run/provenance/source_registration.json', 'tests/test_viya_game066.gd')
# GAME065 preserves that complete resource and adds one separately tested E clip.
FILES += ('assets/characters/pilot_32/game065_e_run_fire/viya_game065_frames.tres',
          'tests/test_viya_game065.gd')
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
STABLE_CAMERA_VIEW_ADAPTER = ('\tcamera.advance(simulation,size,displacement,delta,active)\n', '\tcamera.advance(simulation.run_id,displacement,delta,active)\n')
PATTERN_START_SIGNATURE = (', pacing_version:int=-1, pattern_version:int=-1) -> bool:', ', pacing_version:int=-1) -> bool:')
# Pin the reviewed new AI/migration/render adapters as well as the historical baseline.
PATTERN_REVIEWED_SHA256 = {'scripts/combat/enemy_patterns.gd': 'a19cad533e9185a0bbca1671028349463a2c9c7c020c0e26dea1d5f59b3eebda', 'scripts/combat/enemy_pattern_visuals.gd': 'ffe5032905c8df738b2d7f2a92346206b7df14502b4d2f8babc88304adc5d666', 'scripts/progression/run_snapshot.gd': '74dde47c7790fff4fceb16555c86e3440411382d956a5c5106d78d414b3a1602', 'scripts/combat/actor_motion.gd': '44b43a18d99e011977b8a4d51d41cf16118b168a93d6baaf1f0d9c2d60fe3ffc', 'data/enemy_patterns.json': 'ba04c2b3076746724a09cf212576886edfa33821f666daa97a541d5042680bec', 'scripts/combat/enemy_patterns_v1.gd': '4059f30002b56fa0ccb73ed38b4fe4af9c0fe8092a8f5836ad53f6e3cef5a4af', 'scripts/combat/enemy_patterns_v2.gd': '60ff5da133476bd9c851aaef695cd07ae748e313d9f654dd4b2b0e258af7ca1d', 'data/enemy_patterns_v2.json': '83bf0449e6dad16499af5a4c533c51d0ce3dc06fd73c02eb626de2d1e2e7ac21', 'scripts/combat/enemy_patterns_v17.gd': 'df42114040f4da370a67257445063fdb851033182108111eac609758334b81ab', 'scripts/combat/enemy_patterns_v3.gd': '1c5ea0cee251c0fda6a5a77b40201dba8d97b27f42f5ac92c93602e43c831114', 'scripts/combat/curse_visuals.gd': 'f6fd054527091a5631eb003a2ea38c8308d1bccc29098f5542250916ea0fb3ac', 'data/enemy_curse_v3.json': 'c1d23889286fe1f91d4ef3b206de5b6e910211a52e935162da42355dc5d39659', 'scripts/combat/approach_cues.gd': '8c5bed155ec7cbe829d20bc5ea3f06b87b2365a4dcfc47503f0f4fe32b15b80f', 'scripts/combat/combat_camera.gd': '0039e471d576f4daeb00f6b453f54a29d32917fe71aef4490b3f0bd33e90f896', 'scripts/combat/campaign_encounters.gd': '210d49f4065cc6fe0e5bf960ce97762bc25529d7542d5f93a5ff85d2452490ca', 'data/campaign_encounters.json': 'bb95382de9a546f1f1ffb95e0b119cf311801e96e43f3929ecce0a02631178ce', 'scripts/combat/supply_feedback.gd': '32651a49a6f9d0581390406837a9fed170e265251d403e54c2d6f87cc628241d', 'scripts/combat/combat_display.gd': '9e08022d0249aa66e3d4ea6489b5e49d20cd90275ebe592620a28ebe9c82893e', 'scripts/main.gd': '979313ed3960dd31ea0690f2d176816687de7616b10047cfc3913fbe37c07e84', 'scripts/ui/mobile_main.gd': '01f6a84c44d414aa178afe3cb1816546edf2100ec18269b6a00fea54d09dbe64', 'tests/fixtures/game046_v18/baseline.json': '08a2f204b02efe5e7da4018d9fc2c08f4fef8587be8cc0f4429c4e7ab1565b0b', 'scripts/combat/campaign_pressure.gd': '594b6a781d5d067027f5d3f0008a784e1779871672c66d001dc794a7aa5433f4', 'data/campaign_pressure.json': '071bd8be7adefa32668d23d4127fe6a83e5692f67217df27b2ae9be1275d1203', 'scripts/combat/campaign_encounters_v19.gd': '61c5baade67f4d98b6fddd438664beb957abddf80f9f6950a1f41a84947a0332', 'tests/fixtures/game048_v19/baseline.json': 'adbea21957b68c33ad324445c9af7f252dbd9fd3d60e53e639e66e3ec5e35952', 'data/campaign_battlefield.json': '743c2062876ec3b4818fc73a40cad93ba907707e23fc052edeff4a0eaab2eb06', 'scripts/world/map_catalog.gd': 'e2cd8e50be728d455d0ea9f793ed7413a403c29cb41769a59b273e6ff07d2c50', 'scripts/world/supply_catalog.gd': '9dab0562ce196819d64647ba75deb8d9b89d3710b0edffcc45b6cb00325e874c', 'scripts/combat/combat_profiles.gd': '8dc9e65ddef8bf8a57a4304c1b9d5e7f196d6d846b2a5048874b1579a1279e5f', 'scripts/combat/stage_catalog.gd': '618ad3e28458dd3bde18507139abacea84a5084ca8e85b15a64badc63682b4ca', 'scripts/combat/high_angle_battle.gd': '9ed94208be32641681762d209fbb1bc709025407e8d5960d864e96446b7c83e1', 'scripts/combat/battlefield_presentation.gd': '359b189334ab7539b25587cc82629394c389380432f209dfc67e5cfc35e3734a', 'data/map_presentation_slots.json': '41ce2337d279eb95fd9b13ab041476cb7e58664c4affb10f9cef24776ee0dcef', 'data/chapter_one.json': 'd2265967ac28989d69b394eb784785caf0df0cfe9bb81d0c9fdb1c25cb00c4d2', 'tests/fixtures/game049_v20/baseline.json': 'd135fae75b08cb4d3d10682c32343df502d38efa6d98fb84e0ac7b7e7364c8de', 'scripts/world/map_space.gd': 'dc542903e9960f6e4107e967109e1538b476f13e800cfa3319419549a179218c', 'scripts/combat/spatial_candidates.gd': 'a8b2c35980801036c0a2471cb6662bb64160090988161221f43133187f63be9a', 'scripts/combat/weapon_modules.gd': 'b38ed89c5459ef37aff85553fd5f08856c3e6b8665e81d79f926639f1a60a6bd', 'tests/fixtures/game050_v21/map_space_before.gd': '8110f4a28e04e67fe738011ea888f31a9c74c450ed79148d88c1da602fa03ae8', 'tests/fixtures/game050_v21/baseline.json': '8e5d50b54f4808ab5e60d3da46a9b9fd3bf20a5d2cdd958a848947aabcfca259', 'scripts/combat/loot_attraction.gd': '7220bce58431c07c9ac53e8ee8882becd3de799e3bb6ca22dd38a154fc5d57d8', 'tests/test_loot_attraction.gd': 'a645d982e12defd2265d0a434cf4397a019a2c79bdfba55e51c0d381d79ecce2', 'tests/test_run_navigation.gd': '37a77911095bb0f6205181214454a2dbf31e2a09636261141b3c42773bb57687', 'tests/test_route_queries.gd': '04db6708e68a1da892cb61f29c5ed0fc20675095b1634c550e8a07facc9d28ff', 'scripts/combat/purge_feedback.gd': 'f9d31b42cc7e5eb72d5b9c6793dc1c937383b8a862807794e699dc12624caed8', 'tests/test_purge_feedback.gd': '8d71e53f81d07901eec980f9c9e92fc6e2ee5422f9e4292c8aa82162f2c14d52', 'scripts/combat/combat_audio.gd': '4eccf16086332645866e4d71b3805bcba1de6c0d09ae42a8e67ca3fb515e1302', 'scripts/combat/combat_audio_bank.gd': '4dd99aff553c2eb3526694121d48fe70965c631d899643c7381201ad21d503cc', 'tests/test_combat_audio.gd': 'f73650eb9f76d0d79144a445160408d7773765815dd2067ef348bef052f6e093', 'data/portrait_presentation.json': 'edc61a6a04eb7429adf5c319397cb7d9306d55f00d30d5c8560e581a90c8d2a9', 'scripts/ui/portrait_assets.gd': '59352d312bd0f157d036c41e89ce81a78a862234a3b1eece5e73d047cd83a7b7', 'scripts/ui/feedback_panel.gd': '39d53c848c83a1049b92fb5c994c319fc35b4c49af26b0f7793eb6573e403e55', 'scripts/ui/responsive_feedback_panel.gd': '465d11d1402079a4c881b017d47937baad4ecfd949b4e75a848a560cd7d5fddd', 'scripts/combat/feedback_state.gd': 'a35de54d4078db33dff1661a543db909a7fe55db53f0ea204de773fa677a7ab6', 'tests/test_portrait_reactions.gd': '0da740477a2e4449a97c750f617f5f0f23cbeaeb24de31b20323f9c1b9680095', 'tests/test_feedback.gd': '14c6802aeaf2a194647b397ba34ce17e2257f652f6b067172d1dde79e45c6db3', 'tools/check_feedback_data.py': 'b7a43c3b2395653de7d9b6a96524241dc2d896631689ca7d0582522424a9f3ba', 'scripts/combat/oblique_projection.gd': 'dadc9084707fd11b1855444cbab62bb207805df1833f7d0b827c4932c7f93420', 'scripts/combat/oblique_scenery.gd': '78b27a88fd4b62dc088bd7cb52c5780e0ba9611c5f027ca5fd12793f08e6c6cc', 'tests/test_oblique_stage.gd': '2b238b5edd7264b7dfeb1deb1e92ee5db875a4dbe513b2deded3556bd9bb9ea0', 'scripts/ui/battle_chrome.gd': '135444ca0ee001f145214929767dbcc4ad0dcbe958d7ffb40ffa879f4001970e', 'scripts/combat/boss_guidance.gd': 'e420e633b1d945fd98dfc1c2180419ac5a0d25ad613344e3da0dd8d519ceb1c8', 'tests/test_camera_lead.gd': '961f079b6135e2f2e6cf9bb12aba84318e4e2a2aae6e933810ecae035f0bac3f', 'tests/test_actor_animation.gd': '2d36c1f4619d51992a3873eaac11424c4dc270412e34338481b1c31fc538b8b5', 'scripts/combat/incoming_feedback.gd': '21428a9e268c4b69ef9e34f844459eb5c229ff6ad308561b9d108fc031eb5b75', 'tests/test_incoming_feedback.gd': '198fdf46e82e6cc386cd24db9f22e2adf07cf9cfe17d9c6c9992282a26ae768e', 'data/presentation_slots.json': 'fee7eb60457c4871419b88e76713c189e5be608e170422a9fa4f7543ca25353f', 'assets/characters/pilot_32/source_manifest.json': 'ce2e9b310cf6e5c2c8a0c8a32988f5be60456ff2ba4e07b5a9f65631017941b6', 'assets/characters/pilot_32/resources/viya_directional_motion.tres': '11254fff2baec6de74bce61988544a4296a9753007f27bef2950788aea8b6a19', 'tests/test_character_pilot.gd': 'a7305abcf91a166b5a36594ade2c1d5f0e120e8c812a0c765c0528e6a7e93272', 'tests/test_map_pilot.gd': '0e8e9d4c0bdc711e933a03c9f67328425eb5080ad588436228d662c0dc26cc04', 'tests/test_maps.gd': 'ae385c8abf558c08eef2e8d30dc1e2bb60a9d57c5d71bdf36502dedee396066c', 'scripts/progression/account_reset.gd': 'f72208f6e85a3b8b7e5740800a6e483b8dbbfe248bf38678aeefdc1a53d4555a', 'scripts/progression/gold_progress.gd': '11f545246fa59ac044c5384776c1e0822c8de04f742be48a2352366fc929d9a3', 'tests/test_stage_access_reset.gd': '08fb11e7c876a46fdbb39264159c9b5fb544f0303a363c9cf62939dd82a73378', 'tests/test_chapter_ui.gd': '74a089133c742cc24896460a6cab9c190d39e73dd37e1e04b12ff7024ab4a849', 'data/actor_presentation.json': '8edecb9192200e9d51c7bdc9a075bd7b98e79f4948d16321ae5efb5861b3098d', 'scripts/ui/actor_assets.gd': 'c5a563587f7441a306d3a840442fddabf2a3e5d6b91bf6cc184b459ba86b7aaf', 'data/viya_motion.json': '75be241a6fd72934c73bc1720ef61b0c77fcd43015dbff520a41b070b198f680', 'scripts/combat/viya_presentation.gd': 'ada816cc3b82a02e9a8798263bae37bca9124359f706e82ccfac801863310062', 'tests/test_viya_presentation.gd': 'e1e5d30dfc0b4c56eaf4cf9a56f1c22c2dea4a34405840af1cee9e9279f4114b', 'tools/viya_edge_filter.gd': 'ed29d4b828e1ae5b5da82e4d0cf352a6a9ddd3a54e5f9cfdcd4704b91f6335d8', 'tools/build_viya_render_cache.gd': 'd6951fb4256edf8e8c0cc0b5dda2167dd7378fe1ba2006d4d98a0e37092fa2ae', 'tests/test_viya_edges.gd': 'cf5cbac0ccd4937a7080a215f3785afaa3f5b9b27c8b73a04369ae456717dfe2', 'assets/characters/pilot_32/render_cache/manifest.json': '939588e27baae07bce97017e53421accbca7d5117d982e684d70841e5df1a82f', 'assets/characters/pilot_32/render_cache/viya_render_frames.tres': '245c025c908ba7ea21c3e27015c8aa16daafe05049b8c9d3b18964b03da0c66b', 'tools/viya_generated_edge_override.gd': '68610e5a898033757fdecfee301406a80a1fbeb11c2368eee58a37a20321a693', 'tools/higgsfield/build_edge_repair.py': '03df0ecddf1f54cbb24034862d0a5e01ad7a2cf9ff29e5190730829e48b99ba8', 'assets/characters/pilot_32/edge_repair/manifest.json': '25125c0e0b4cbb7bc5d38fef7186a281124a5c6575b3f727d2dc91ebc14c0194'}

# Reviewed GAME064 composite and production image hashes; prior source/cache hashes remain pinned.
PATTERN_REVIEWED_SHA256.update({
    'assets/characters/pilot_32/game064_e_run/viya_game064_frames.tres': '50766b0e761623aa1768806cc20c2399b1812a604bc40dfd6b44e69c71ae085a',
    'assets/characters/pilot_32/game064_e_run/provenance/asset_manifest.json': '4f60d83f3afe27d235e21212e7eb3afc8ff397b379f08aa50950382dca84a3c8',
})
# Reviewed actual GAME065 resource and 18 native transition/recovery checks.
# Existing 32 clips/244 frames, source/cache and authority proofs stay pinned.
PATTERN_REVIEWED_SHA256.update({
    'assets/characters/pilot_32/game065_e_run_fire/viya_game065_frames.tres': '95886e3b759e8fc8b7d6be0afbc741230f3ab0bd72c1931722a533415e7a5210',
    'tests/test_viya_game065.gd': '888fdfc2d2ba5b98ba8225cfb190e17875c46ada413b0e7e7f343163f63ed1b7',
})

# GAME046: exact reviewed encounter adapters; retain the historical byte proof.
CAMPAIGN_RUN_ADAPTERS = (('const EnemyPatterns = preload("res://scripts/combat/enemy_patterns.gd")\nvar enemy_patterns = EnemyPatterns.new()\nvar enemy_pattern_version:int=0\nconst CampaignEncounters=preload("res://scripts/combat/campaign_encounters.gd")\nvar encounters=CampaignEncounters.new()\nvar encounter_version:int=0 # Published battles keep their original population/rewards.\nvar chest_pickups:Array[Dictionary]=[]\nvar _chest_serial:int=0\nvar _chests_opened:int=0\nvar _chest_bonus_ranks:int=0\nenum Phase { READY, RUNNING, PAUSED, DEFEAT, CHOOSING, ABANDONED, CLEARED }\nconst WORLD_SIZE := Vector2(1800.0, 1200.0) # Legacy API; mapped runs use world_size.\nconst PLAYER_SPEED := 235.0\n', 'const EnemyPatterns = preload("res://scripts/combat/enemy_patterns.gd")\nvar enemy_patterns = EnemyPatterns.new()\nvar enemy_pattern_version:int=0\nenum Phase { READY, RUNNING, PAUSED, DEFEAT, CHOOSING, ABANDONED, CLEARED }\nconst WORLD_SIZE := Vector2(1800.0, 1200.0) # Legacy API; mapped runs use world_size.\nconst PLAYER_SPEED := 235.0\n'), ('func enemy_definition(id: String) -> Dictionary:\n\treturn dungeon.species(wave_profile()) if id=="gold_slime" and run_mode=="gold_slime" else profiles.species(id)\n\nfunc start(seed_value: int = 0, character_id: String = "viya", account_level: Variant = null, selected_map: String = "legacy_arena", skill_ruleset: String = "legacy", support_loadout: Dictionary = {}, mode: String = "campaign", entry_day: int = -1, pacing_version:int=-1, pattern_version:int=-1, encounter_rules:int=0) -> bool:\n\t# Validate the complete selected character before changing the previous run.\n\tvar selected_levels: Dictionary = account_talent_levels.duplicate(true)\n\tif account_level is int:\n', 'func enemy_definition(id: String) -> Dictionary:\n\treturn dungeon.species(wave_profile()) if id=="gold_slime" and run_mode=="gold_slime" else profiles.species(id)\n\nfunc start(seed_value: int = 0, character_id: String = "viya", account_level: Variant = null, selected_map: String = "legacy_arena", skill_ruleset: String = "legacy", support_loadout: Dictionary = {}, mode: String = "campaign", entry_day: int = -1, pacing_version:int=-1, pattern_version:int=-1) -> bool:\n\t# Validate the complete selected character before changing the previous run.\n\tvar selected_levels: Dictionary = account_talent_levels.duplicate(true)\n\tif account_level is int:\n'), ('\tvar selected_profile := 1 if skill_ruleset=="weapons_v1" else 0\n\tvar selected_pattern:int=(3 if selected_profile==1 and mode=="campaign" else 0) if pattern_version==-1 else pattern_version\n\tif selected_pattern not in [0,1,2,3] or (selected_pattern>0 and (selected_profile!=1 or mode!="campaign" or not enemy_patterns.available(selected_pattern))):return false\n\tif encounter_rules not in [0,1] or (encounter_rules==1 and (mode!="campaign" or selected_profile!=1 or encounters.data.is_empty())):return false\n\tif selected_profile==1 and (not profiles.error.is_empty() or profiles.hero(character_id).is_empty() or (mode=="campaign" and not profiles.data.maps.has(selected_map))):\n\t\treturn false\n\tvar candidate: Dictionary = magic_configuration(hero,selected_profile,character_id)\n', '\tvar selected_profile := 1 if skill_ruleset=="weapons_v1" else 0\n\tvar selected_pattern:int=(3 if selected_profile==1 and mode=="campaign" else 0) if pattern_version==-1 else pattern_version\n\tif selected_pattern not in [0,1,2,3] or (selected_pattern>0 and (selected_profile!=1 or mode!="campaign" or not enemy_patterns.available(selected_pattern))):return false\n\tif selected_profile==1 and (not profiles.error.is_empty() or profiles.hero(character_id).is_empty() or (mode=="campaign" and not profiles.data.maps.has(selected_map))):\n\t\treturn false\n\tvar candidate: Dictionary = magic_configuration(hero,selected_profile,character_id)\n'), ('\tarmor_enabled = skill_ruleset == "weapons_v1"\n\tcombat_profile_version = selected_profile\n\tenemy_pattern_version = selected_pattern\n\tencounter_version=encounter_rules\n\tchest_pickups.clear()\n\t_chest_serial=0\n\t_chests_opened=0\n\t_chest_bonus_ranks=0\n\tvar previous_mode: String=run_mode\n\trun_mode = mode\n\tdungeon_day = entry_day\n', '\tarmor_enabled = skill_ruleset == "weapons_v1"\n\tcombat_profile_version = selected_profile\n\tenemy_pattern_version = selected_pattern\n\tvar previous_mode: String=run_mode\n\trun_mode = mode\n\tdungeon_day = entry_day\n'), ('\t\treturn false\n\tif scatter_group < 0 or scatter_group > _scatter_index or (scatter_group > 0 and (kind != "normal" or variant not in SCATTER_VARIANTS)):\n\t\treturn false\n\tif scatter_group == 0 and variant != "flier" and _ground_count() >= population_limit():\n\t\treturn false\n\tif run_mode=="gold_slime" and (kind!="normal" or variant!="normal" or species_id not in ["","gold_slime"] or enemies.size()>=int(dungeon.data.max_enemies)):\n\t\treturn false\n', '\t\treturn false\n\tif scatter_group < 0 or scatter_group > _scatter_index or (scatter_group > 0 and (kind != "normal" or variant not in SCATTER_VARIANTS)):\n\t\treturn false\n\tif scatter_group == 0 and variant != "flier" and _ground_count() >= MAX_ENEMIES:\n\t\treturn false\n\tif run_mode=="gold_slime" and (kind!="normal" or variant!="normal" or species_id not in ["","gold_slime"] or enemies.size()>=int(dungeon.data.max_enemies)):\n\t\treturn false\n'), ('\tif not species_id.is_empty() and (combat_profile_version!=1 or definition.is_empty() or definition.kind!=kind or definition.variant!=variant):\n\t\treturn false\n\tif combat_profile_version==1 and species_id.is_empty():\n\t\tspecies_id = profiles.select(map_id,kind,variant,encounters.elite_index(encounter_version,_elites_spawned),species_rng)\n\t\tdefinition = profiles.species(species_id)\n\t\tif definition.is_empty():return false\n\t_enemy_serial += 1\n\tvar wave := wave_profile()\n\tvar life: int = int(wave.hp)\n\tif kind == "elite":\n\t\tlife = int(stage_rules.elite_hp[mini(encounters.elite_index(encounter_version,_elites_spawned), 1)])\n\telif kind == "boss":\n\t\tlife = int(stage_rules.boss_hp)\n\tvar speed: float = float(wave.speed)\n', '\tif not species_id.is_empty() and (combat_profile_version!=1 or definition.is_empty() or definition.kind!=kind or definition.variant!=variant):\n\t\treturn false\n\tif combat_profile_version==1 and species_id.is_empty():\n\t\tspecies_id = profiles.select(map_id,kind,variant,_elites_spawned,species_rng)\n\t\tdefinition = profiles.species(species_id)\n\t\tif definition.is_empty():return false\n\t_enemy_serial += 1\n\tvar wave := wave_profile()\n\tvar life: int = int(wave.hp)\n\tif kind == "elite":\n\t\tlife = int(stage_rules.elite_hp[mini(_elites_spawned, 1)])\n\telif kind == "boss":\n\t\tlife = int(stage_rules.boss_hp)\n\tvar speed: float = float(wave.speed)\n'), ('\tspawn_clock -= dt\n\tif run_mode=="campaign" and elapsed >= float(stage_rules.boss_at) and not _boss_spawned:\n\t\t_boss_spawned = _spawn_enemy("boss")\n\telif run_mode=="campaign" and _elites_spawned < elite_schedule().size() and elapsed >= float(elite_schedule()[_elites_spawned]):\n\t\tif _spawn_enemy("elite"):\n\t\t\t_elites_spawned += 1\n\tif spawn_clock <= 0.0:\n\t\tvar wave := wave_profile()\n\t\tfor index in range(encounters.batch(self,wave)):\n\t\t\t_spawn_enemy()\n\t\tspawn_clock = float(wave.interval)\n\t_tick_swarm(dt)\n', '\tspawn_clock -= dt\n\tif run_mode=="campaign" and elapsed >= float(stage_rules.boss_at) and not _boss_spawned:\n\t\t_boss_spawned = _spawn_enemy("boss")\n\telif run_mode=="campaign" and _elites_spawned < 2 and elapsed >= float(stage_rules.elites[_elites_spawned]):\n\t\tif _spawn_enemy("elite"):\n\t\t\t_elites_spawned += 1\n\tif spawn_clock <= 0.0:\n\t\tvar wave := wave_profile()\n\t\tfor index in range(int(wave.batch)):\n\t\t\t_spawn_enemy()\n\t\tspawn_clock = float(wave.interval)\n\t_tick_swarm(dt)\n'), ('func _collect_pickups(dt: float) -> void:\n\t_collect_gold(dt)\n\t_collect_items(dt)\n\tencounters.collect(self,dt)\n\tif phase != Phase.RUNNING:\n\t\treturn # A global magnet may open an exact, saved level-up offer.\n\tvar reward: float = 0.0\n', 'func _collect_pickups(dt: float) -> void:\n\t_collect_gold(dt)\n\t_collect_items(dt)\n\tif phase != Phase.RUNNING:\n\t\treturn # A global magnet may open an exact, saved level-up offer.\n\tvar reward: float = 0.0\n'), ('func _spawn_enemy(kind: String = "normal") -> bool:\n\tif run_mode=="gold_slime" and (kind!="normal" or enemies.size()>=int(dungeon.data.max_enemies)):return false\n\t# Flying formations have their own lifetime; only reserve the ground boss slot.\n\tvar limit: int = population_limit() - (0 if _boss_spawned else 1)\n\tif encounter_version==1 and kind=="normal":limit-=elite_schedule().size()-_elites_spawned\n\tif kind == "boss":\n\t\tlimit = population_limit()\n\tif _ground_count() >= limit:\n\t\treturn false\n\tif map_id != "legacy_arena":\n', 'func _spawn_enemy(kind: String = "normal") -> bool:\n\tif run_mode=="gold_slime" and (kind!="normal" or enemies.size()>=int(dungeon.data.max_enemies)):return false\n\t# Flying formations have their own lifetime; only reserve the ground boss slot.\n\tvar limit: int = MAX_ENEMIES - (0 if _boss_spawned else 1)\n\tif kind == "boss":\n\t\tlimit = MAX_ENEMIES\n\tif _ground_count() >= limit:\n\t\treturn false\n\tif map_id != "legacy_arena":\n'), ('\tenemies.remove_at(index)\n\tkills += 1\n\tcues.record_kill(int(enemy.id), enemy.p)\n\tencounters.drop(self,enemy)\n\t_heal_on_kill()\n\tif enemy.kind == "boss" and _boss_spawned:\n\t\t_boss_defeated = true\n', '\tenemies.remove_at(index)\n\tkills += 1\n\tcues.record_kill(int(enemy.id), enemy.p)\n\t_heal_on_kill()\n\tif enemy.kind == "boss" and _boss_spawned:\n\t\t_boss_defeated = true\n'), ('\tif transition_action == "restart" and run_mode=="gold_slime":return false # UI must settle/forfeit before a fresh charged admission.\n\tif transition_action == "restart":\n\t\t# start() validates first. On failure keep the old run and confirmation.\n\t\treturn start(0, growth.character_id, account_level, map_id, growth.ruleset,{},run_mode,dungeon_day,growth.pacing_version,-1,encounter_version)\n\t_finish_run("abandoned")\n\treturn true\n\n', '\tif transition_action == "restart" and run_mode=="gold_slime":return false # UI must settle/forfeit before a fresh charged admission.\n\tif transition_action == "restart":\n\t\t# start() validates first. On failure keep the old run and confirmation.\n\t\treturn start(0, growth.character_id, account_level, map_id, growth.ruleset,{},run_mode,dungeon_day,growth.pacing_version)\n\t_finish_run("abandoned")\n\treturn true\n\n'), ('\telse:\n\t\t_finish_run("timeout")\n\nfunc population_limit()->int:return encounters.population_limit(encounter_version,elapsed)\n\nfunc elite_schedule()->Array:return encounters.elite_times(stage_rules,encounter_version)\n\nfunc wave_profile() -> Dictionary:\n\tvar selected: Dictionary = stage_rules.get("waves", [{"hp": 20, "speed": 68.0}])[0]\n\tfor wave in stage_rules.get("waves", []):\n', '\telse:\n\t\t_finish_run("timeout")\n\nfunc wave_profile() -> Dictionary:\n\tvar selected: Dictionary = stage_rules.get("waves", [{"hp": 20, "speed": 68.0}])[0]\n\tfor wave in stage_rules.get("waves", []):\n'))
CAMPAIGN_VIEW_ADAPTERS = (('\tfor item in simulation.item_pickups:\n\t\tvar at:=_screen(item.p)\n\t\tif visible.has_point(at):SupplyFeedback.draw_item(self,at,str(item.kind),compact)\n\tfor chest in simulation.chest_pickups:\n\t\tvar at:=_screen(chest.p)\n\t\tif visible.has_point(at):SupplyFeedback.draw_item(self,at,"chest",compact)\n\nfunc _draw_weapon_fields() -> void:\n\tfor event in simulation.weapon_events:\n', '\tfor item in simulation.item_pickups:\n\t\tvar at:=_screen(item.p)\n\t\tif visible.has_point(at):SupplyFeedback.draw_item(self,at,str(item.kind),compact)\n\nfunc _draw_weapon_fields() -> void:\n\tfor event in simulation.weapon_events:\n'),)

PRESSURE_RUN_ADAPTERS = (('var enemy_pattern_version:int=0\nconst CampaignEncounters=preload("res://scripts/combat/campaign_encounters.gd")\nvar encounters=CampaignEncounters.new()\nconst CampaignPressure=preload("res://scripts/combat/campaign_pressure.gd")\nvar pressure=CampaignPressure.new()\nvar encounter_version:int=0 # Published battles keep their original population/rewards.\nvar chest_pickups:Array[Dictionary]=[]\nvar _chest_serial:int=0\n', 'var enemy_pattern_version:int=0\nconst CampaignEncounters=preload("res://scripts/combat/campaign_encounters.gd")\nvar encounters=CampaignEncounters.new()\nvar encounter_version:int=0 # Published battles keep their original population/rewards.\nvar chest_pickups:Array[Dictionary]=[]\nvar _chest_serial:int=0\n'), ('\tvar selected_profile := 1 if skill_ruleset=="weapons_v1" else 0\n\tvar selected_pattern:int=(3 if selected_profile==1 and mode=="campaign" else 0) if pattern_version==-1 else pattern_version\n\tif selected_pattern not in [0,1,2,3] or (selected_pattern>0 and (selected_profile!=1 or mode!="campaign" or not enemy_patterns.available(selected_pattern))):return false\n\tif encounter_rules not in [0,1,2] or (encounter_rules>0 and (mode!="campaign" or selected_profile!=1 or encounters.data.is_empty() or (encounter_rules==2 and pressure.data.is_empty()))):return false\n\tif selected_profile==1 and (not profiles.error.is_empty() or profiles.hero(character_id).is_empty() or (mode=="campaign" and not profiles.data.maps.has(selected_map))):\n\t\treturn false\n\tvar candidate: Dictionary = magic_configuration(hero,selected_profile,character_id)\n', '\tvar selected_profile := 1 if skill_ruleset=="weapons_v1" else 0\n\tvar selected_pattern:int=(3 if selected_profile==1 and mode=="campaign" else 0) if pattern_version==-1 else pattern_version\n\tif selected_pattern not in [0,1,2,3] or (selected_pattern>0 and (selected_profile!=1 or mode!="campaign" or not enemy_patterns.available(selected_pattern))):return false\n\tif encounter_rules not in [0,1] or (encounter_rules==1 and (mode!="campaign" or selected_profile!=1 or encounters.data.is_empty())):return false\n\tif selected_profile==1 and (not profiles.error.is_empty() or profiles.hero(character_id).is_empty() or (mode=="campaign" and not profiles.data.maps.has(selected_map))):\n\t\treturn false\n\tvar candidate: Dictionary = magic_configuration(hero,selected_profile,character_id)\n'), ('\t\tfor index in range(encounters.batch(self,wave)):\n\t\t\t_spawn_enemy()\n\t\tspawn_clock = float(wave.interval)\n\tpressure.tick(self,dt)\n\t_tick_swarm(dt)\n\t_tick_scatter(dt)\n\t_move_enemies(dt)\n', '\t\tfor index in range(encounters.batch(self,wave)):\n\t\t\t_spawn_enemy()\n\t\tspawn_clock = float(wave.interval)\n\t_tick_swarm(dt)\n\t_tick_scatter(dt)\n\t_move_enemies(dt)\n'), ('\tif run_mode=="gold_slime" and (kind!="normal" or enemies.size()>=int(dungeon.data.max_enemies)):return false\n\t# Flying formations have their own lifetime; only reserve the ground boss slot.\n\tvar limit: int = population_limit() - (0 if _boss_spawned else 1)\n\tif encounter_version>0 and kind=="normal":limit-=elite_schedule().size()-_elites_spawned\n\tif kind == "boss":\n\t\tlimit = population_limit()\n\tif _ground_count() >= limit:\n\t\treturn false\n\tif map_id != "legacy_arena":\n\t\tvar at: Variant = pressure.anchor(self,kind) if encounter_version==2 else map_space.spawn_anchor(rng, player, elapsed, kind, visible_world(), 24.0)\n\t\treturn add_enemy(at, kind, _roll_variant() if kind == "normal" else "normal") if at is Vector2 else false\n\tfor attempt in range(8):\n\t\tvar candidate := player + Vector2.from_angle(rng.randf_range(0.0, TAU)) * 590.0\n', '\tif run_mode=="gold_slime" and (kind!="normal" or enemies.size()>=int(dungeon.data.max_enemies)):return false\n\t# Flying formations have their own lifetime; only reserve the ground boss slot.\n\tvar limit: int = population_limit() - (0 if _boss_spawned else 1)\n\tif encounter_version==1 and kind=="normal":limit-=elite_schedule().size()-_elites_spawned\n\tif kind == "boss":\n\t\tlimit = population_limit()\n\tif _ground_count() >= limit:\n\t\treturn false\n\tif map_id != "legacy_arena":\n\t\tvar at: Variant = map_space.spawn_anchor(rng, player, elapsed, kind, visible_world(), 24.0)\n\t\treturn add_enemy(at, kind, _roll_variant() if kind == "normal" else "normal") if at is Vector2 else false\n\tfor attempt in range(8):\n\t\tvar candidate := player + Vector2.from_angle(rng.randf_range(0.0, TAU)) * 590.0\n'), ('\t\tif hit:\n\t\t\tif damage_player(int(bullet.damage), "physical", 0.0, {"kind":"projectile", "direction":-bullet.velocity.normalized()}):\n\t\t\t\tapply_slow(RANGED_SLOW_DURATION)\n\t\tif hit or bullet.life <= (0.000001 if encounter_version==2 else 0.0) or wall_hit < 1.0:\n\t\t\tenemy_bullets.remove_at(index)\n\t\tif phase != Phase.RUNNING:\n\t\t\treturn\n', '\t\tif hit:\n\t\t\tif damage_player(int(bullet.damage), "physical", 0.0, {"kind":"projectile", "direction":-bullet.velocity.normalized()}):\n\t\t\t\tapply_slow(RANGED_SLOW_DURATION)\n\t\tif hit or bullet.life <= 0.0 or wall_hit < 1.0:\n\t\t\tenemy_bullets.remove_at(index)\n\t\tif phase != Phase.RUNNING:\n\t\t\treturn\n'))

OPTIMIZATION_RUN_ADAPTERS = (('const SpatialCandidates=preload("res://scripts/combat/spatial_candidates.gd")\nvar _push_candidates = null # Frame-local derived query; never saved.\nvar _bullet_candidates = null\n\n', ''), ('func _move_enemies(dt: float) -> void:\n\t# Ground movement happens first so fly-bys cannot be undone by pursuit this frame.\n\tvar default_speed:float=wave_profile().speed\n\tfor enemy in enemies:\n\t\tvar pattern_locked:bool=enemy.has("pattern") and enemy_patterns.tick(self,enemy,dt)\n\t\tif phase!=Phase.RUNNING:return\n\t\tif pattern_locked:continue\n\t\tif enemy.variant == "flier":\n\t\t\tcontinue\n\t\tvar speed: float = float(enemy.get("speed", default_speed)) * WeaponModules.speed_scale(enemy)\n\t\tvar pos: Vector2 = enemy["p"]\n\t\tvar offset := player - pos\n\t\tvar variant: String = str(enemy.get("variant", "normal"))\n\t\tif variant == "ranged":\n\t\t\tvar distance := offset.length()\n\t\t\tif distance > float(stage_rules.ranged.range) * 0.85:\n\t\t\t\tpos += offset.normalized() * speed * dt\n\t\t\telif distance < float(stage_rules.ranged.keep_distance) * 0.75:\n\t\t\t\tpos -= offset.normalized() * speed * dt\n\t\t\tpos = pos.clamp(Vector2.ONE * 24.0, world_size - Vector2.ONE * 24.0)\n\t\telif map_id=="legacy_arena" and offset.length_squared() > 0.01:\n\t\t\tpos += offset.normalized() * minf(speed * dt, offset.length())\n\t\tif map_id != "legacy_arena":\n\t\t\tif variant != "ranged" or offset.length() > float(stage_rules.ranged.range) * 0.85:\n\t\t\t\tvar waypoint: Vector2 = map_space.route_target(enemy.p, player, 24.0)\n\t\t\t\tpos = enemy.p.move_toward(waypoint, speed * dt)\n\t\t\tpos = map_space.move(enemy.p, pos - enemy.p, 24.0)\n\t\tenemy["p"] = pos\n\t\tif variant == "ranged":\n\t\t\t_tick_ranged(enemy, dt)\n\t_move_fliers(dt)\n\tfor enemy in enemies:\n\t\tif enemy.has("pattern") and enemy_patterns.locked(self,enemy):continue\n\t\tif enemy.p.distance_squared_to(player) <= pow(PLAYER_RADIUS + ENEMY_RADIUS, 2.0):\n\t\t\tvar accepted := damage_player(int(enemy.get("contact_damage",12)), "physical", 0.0, {"kind":"contact", "id":int(enemy.id), "p":enemy.p})\n\t\t\tif accepted and enemy.variant == "flier":\n\t\t\t\tpush_player(enemy.velocity.normalized() * FLIER_PLAYER_PUSH)\n\t\t\tif phase == Phase.DEFEAT:\n\t\t\t\treturn\n\n', 'func _move_enemies(dt: float) -> void:\n\t# Ground movement happens first so fly-bys cannot be undone by pursuit this frame.\n\tfor enemy in enemies:\n\t\tvar pattern_locked:bool=enemy_patterns.tick(self,enemy,dt)\n\t\tif phase!=Phase.RUNNING:return\n\t\tif pattern_locked:continue\n\t\tif enemy.variant == "flier":\n\t\t\tcontinue\n\t\tvar speed: float = float(enemy.get("speed", wave_profile().speed)) * WeaponModules.speed_scale(enemy)\n\t\tvar pos: Vector2 = enemy["p"]\n\t\tvar offset := player - pos\n\t\tvar variant: String = str(enemy.get("variant", "normal"))\n\t\tif variant == "ranged":\n\t\t\tvar distance := offset.length()\n\t\t\tif distance > float(stage_rules.ranged.range) * 0.85:\n\t\t\t\tpos += offset.normalized() * speed * dt\n\t\t\telif distance < float(stage_rules.ranged.keep_distance) * 0.75:\n\t\t\t\tpos -= offset.normalized() * speed * dt\n\t\t\tpos = pos.clamp(Vector2.ONE * 24.0, world_size - Vector2.ONE * 24.0)\n\t\telif offset.length_squared() > 0.01:\n\t\t\tpos += offset.normalized() * minf(speed * dt, offset.length())\n\t\tif map_id != "legacy_arena":\n\t\t\tif variant != "ranged" or offset.length() > float(stage_rules.ranged.range) * 0.85:\n\t\t\t\tvar waypoint: Vector2 = map_space.route_target(enemy.p, player, 24.0)\n\t\t\t\tpos = enemy.p.move_toward(waypoint, speed * dt)\n\t\t\tpos = map_space.move(enemy.p, pos - enemy.p, 24.0)\n\t\tenemy["p"] = pos\n\t\tif variant == "ranged":\n\t\t\t_tick_ranged(enemy, dt)\n\t_move_fliers(dt)\n\tfor enemy in enemies:\n\t\tif enemy_patterns.locked(self,enemy):continue\n\t\tif enemy.p.distance_squared_to(player) <= pow(PLAYER_RADIUS + ENEMY_RADIUS, 2.0):\n\t\t\tvar accepted := damage_player(int(enemy.get("contact_damage",12)), "physical", 0.0, {"kind":"contact", "id":int(enemy.id), "p":enemy.p})\n\t\t\tif accepted and enemy.variant == "flier":\n\t\t\t\tpush_player(enemy.velocity.normalized() * FLIER_PLAYER_PUSH)\n\t\t\tif phase == Phase.DEFEAT:\n\t\t\t\treturn\n\n'), ('func _move_fliers(dt: float) -> void:\n\t_push_candidates=null\n\tfor index in range(enemies.size() - 1, -1, -1):\n\t\tvar flier: Dictionary = enemies[index]\n\t\tif flier.variant != "flier":\n\t\t\tcontinue\n\t\tflier.life -= dt\n\t\tif flier.life <= 0.0:\n\t\t\tenemies.remove_at(index) # Expiry never awards a kill or loot.\n\t\t\tcontinue\n\t\tif _push_candidates==null and enemies.size()>=96:\n\t\t\t_push_candidates=SpatialCandidates.new()\n\t\t\tif not _push_candidates.build([enemies],true):_push_candidates=null\n\t\tvar previous: Vector2 = flier.p\n\t\tflier.p += flier.velocity * dt * WeaponModules.speed_scale(flier)\n\t\t_push_ground(previous, flier.p)\n\t_push_candidates=null\n\n', 'func _move_fliers(dt: float) -> void:\n\tfor index in range(enemies.size() - 1, -1, -1):\n\t\tvar flier: Dictionary = enemies[index]\n\t\tif flier.variant != "flier":\n\t\t\tcontinue\n\t\tflier.life -= dt\n\t\tif flier.life <= 0.0:\n\t\t\tenemies.remove_at(index) # Expiry never awards a kill or loot.\n\t\t\tcontinue\n\t\tvar previous: Vector2 = flier.p\n\t\tflier.p += flier.velocity * dt * WeaponModules.speed_scale(flier)\n\t\t_push_ground(previous, flier.p)\n\n'), ('func _push_ground(previous: Vector2, destination: Vector2) -> void:\n\tvar direction := previous.direction_to(destination)\n\tif direction.is_zero_approx():\n\t\treturn\n\tvar radius := ENEMY_RADIUS * 2.0\n\tvar candidates:Array=_push_candidates.segment(previous,destination,radius) if _push_candidates!=null else enemies\n\tfor enemy in candidates:\n\t\tif enemy.variant == "flier" or (enemy.p - previous).dot(direction) < 0.0:\n\t\t\tcontinue\n\t\tvar nearest := Geometry2D.get_closest_point_to_segment(enemy.p, previous, destination)\n\t\tif nearest.distance_squared_to(enemy.p) >= radius * radius:\n\t\t\tcontinue\n\t\tvar relative: Vector2 = enemy.p - destination\n\t\tvar lateral: float = relative.dot(direction.orthogonal())\n\t\tvar front := sqrt(maxf(0.0, radius * radius - lateral * lateral)) + 0.1\n\t\tvar distance: float = relative.dot(direction)\n\t\tif distance < front:\n\t\t\t# Preserve the flying path and push every ground type, including bosses.\n\t\t\tenemy.p = map_space.move(enemy.p, direction * (front - distance), 24.0)\n\t\t\tif _push_candidates!=null:_push_candidates.moved(enemy)\n\n', 'func _push_ground(previous: Vector2, destination: Vector2) -> void:\n\tvar direction := previous.direction_to(destination)\n\tif direction.is_zero_approx():\n\t\treturn\n\tvar radius := ENEMY_RADIUS * 2.0\n\tfor enemy in enemies:\n\t\tif enemy.variant == "flier" or (enemy.p - previous).dot(direction) < 0.0:\n\t\t\tcontinue\n\t\tvar nearest := Geometry2D.get_closest_point_to_segment(enemy.p, previous, destination)\n\t\tif nearest.distance_squared_to(enemy.p) >= radius * radius:\n\t\t\tcontinue\n\t\tvar relative: Vector2 = enemy.p - destination\n\t\tvar lateral: float = relative.dot(direction.orthogonal())\n\t\tvar front := sqrt(maxf(0.0, radius * radius - lateral * lateral)) + 0.1\n\t\tvar distance: float = relative.dot(direction)\n\t\tif distance < front:\n\t\t\t# Preserve the flying path and push every ground type, including bosses.\n\t\t\tenemy.p = map_space.move(enemy.p, direction * (front - distance), 24.0)\n\n'), ('func projectile_candidates(from:Vector2,to:Vector2,width:float) -> Array[Dictionary]:\n\treturn _bullet_candidates.segment(from,to,maxf(ENEMY_RADIUS,SupplyCatalog.RADIUS)+width) if _bullet_candidates!=null else WeaponModules.actors(self)\n\nfunc projectile_target_moved(actor:Dictionary) -> void:\n\tif _bullet_candidates!=null:_bullet_candidates.moved(actor)\n\nfunc _move_bullets(dt: float) -> void:\n\tif not bullets.is_empty() and enemies.size()>=96:\n\t\t_bullet_candidates=SpatialCandidates.new()\n\t\tif not _bullet_candidates.build([enemies,structures]):_bullet_candidates=null\n\t_move_bullets_indexed(dt)\n\t_bullet_candidates=null\n\nfunc _move_bullets_indexed(dt: float) -> void:\n\tfor bullet_index in range(bullets.size() - 1, -1, -1):\n\t\tvar bullet: Dictionary = bullets[bullet_index]\n\t\tif bullet.has("weapon"):\n\t\t\tWeaponModules.move_projectile(self,bullet_index,dt)\n\t\t\tif phase != Phase.RUNNING:\n\t\t\t\treturn\n\t\t\tcontinue\n\t\tvar old_pos: Vector2 = bullet["p"]\n\t\tvar new_pos: Vector2 = old_pos + bullet["direction"] * float(bullet["speed"]) * dt\n\t\tvar wall_hit: float = map_space.wall_fraction(old_pos,new_pos,4.0)\n\t\tnew_pos = old_pos.lerp(new_pos,wall_hit)\n\t\tbullet["p"] = new_pos\n\t\tbullet["life"] -= dt\n\t\t# Swept collision, ordered impacts, stable enemy IDs: one hit per target.\n\t\twhile int(bullet["remaining"]) > 0:\n\t\t\tvar victim := -1\n\t\t\tvar first_distance := INF\n\t\t\tfor actors in [projectile_candidates(old_pos,new_pos,4.0)]:\n\t\t\t\tfor actor in actors:\n\t\t\t\t\tif actor.hp <= 0 or bullet["seen"].has(actor.id):\n\t\t\t\t\t\tcontinue\n\t\t\t\t\tvar pos: Vector2 = actor.p\n\t\t\t\t\tvar nearest := Geometry2D.get_closest_point_to_segment(pos, old_pos, new_pos)\n\t\t\t\t\tvar radius: float = SupplyCatalog.RADIUS if actor.id < 0 else ENEMY_RADIUS\n\t\t\t\t\tif pos.distance_squared_to(nearest) <= pow(radius + 4.0, 2.0):\n\t\t\t\t\t\tvar distance := old_pos.distance_squared_to(nearest)\n\t\t\t\t\t\tif distance < first_distance:\n\t\t\t\t\t\t\tfirst_distance = distance\n\t\t\t\t\t\t\tvictim = int(actor.id)\n\t\t\tif victim == -1:\n\t\t\t\tbreak\n\t\t\tbullet["seen"][victim] = true\n\t\t\tbullet["remaining"] -= 1\n\t\t\t_damage_target(victim, float(bullet["damage"]))\n\t\t\tif phase != Phase.RUNNING:\n\t\t\t\treturn\n\t\tif bullet["remaining"] <= 0 or bullet["life"] <= 0.0 or wall_hit < 1.0:\n\t\t\tbullets.remove_at(bullet_index)\n\n\n', 'func _move_bullets(dt: float) -> void:\n\tfor bullet_index in range(bullets.size() - 1, -1, -1):\n\t\tvar bullet: Dictionary = bullets[bullet_index]\n\t\tif bullet.has("weapon"):\n\t\t\tWeaponModules.move_projectile(self,bullet_index,dt)\n\t\t\tif phase != Phase.RUNNING:\n\t\t\t\treturn\n\t\t\tcontinue\n\t\tvar old_pos: Vector2 = bullet["p"]\n\t\tvar new_pos: Vector2 = old_pos + bullet["direction"] * float(bullet["speed"]) * dt\n\t\tvar wall_hit: float = map_space.wall_fraction(old_pos,new_pos,4.0)\n\t\tnew_pos = old_pos.lerp(new_pos,wall_hit)\n\t\tbullet["p"] = new_pos\n\t\tbullet["life"] -= dt\n\t\t# Swept collision, ordered impacts, stable enemy IDs: one hit per target.\n\t\twhile int(bullet["remaining"]) > 0:\n\t\t\tvar victim := -1\n\t\t\tvar first_distance := INF\n\t\t\tfor actors in [enemies, structures]:\n\t\t\t\tfor actor in actors:\n\t\t\t\t\tif actor.hp <= 0 or bullet["seen"].has(actor.id):\n\t\t\t\t\t\tcontinue\n\t\t\t\t\tvar pos: Vector2 = actor.p\n\t\t\t\t\tvar nearest := Geometry2D.get_closest_point_to_segment(pos, old_pos, new_pos)\n\t\t\t\t\tvar radius: float = SupplyCatalog.RADIUS if actor.id < 0 else ENEMY_RADIUS\n\t\t\t\t\tif pos.distance_squared_to(nearest) <= pow(radius + 4.0, 2.0):\n\t\t\t\t\t\tvar distance := old_pos.distance_squared_to(nearest)\n\t\t\t\t\t\tif distance < first_distance:\n\t\t\t\t\t\t\tfirst_distance = distance\n\t\t\t\t\t\t\tvictim = int(actor.id)\n\t\t\tif victim == -1:\n\t\t\t\tbreak\n\t\t\tbullet["seen"][victim] = true\n\t\t\tbullet["remaining"] -= 1\n\t\t\t_damage_target(victim, float(bullet["damage"]))\n\t\t\tif phase != Phase.RUNNING:\n\t\t\t\treturn\n\t\tif bullet["remaining"] <= 0 or bullet["life"] <= 0.0 or wall_hit < 1.0:\n\t\t\tbullets.remove_at(bullet_index)\n\n\n'))

LOOT_RUN_ADAPTERS = (('var dungeon_day: int = -1\nvar gold_reward_version:int=0 # Published1-14 keep original drops throughout Continue.\nconst LootAttraction=preload("res://scripts/combat/loot_attraction.gd")\nvar loot_rules_version:int=0 # Existing entries keep their amounts and instant magnet.\nvar dungeon = preload("res://scripts/combat/gold_dungeon.gd").new()\nfunc enemy_definition(id: String) -> Dictionary:\n\treturn dungeon.species(wave_profile()) if id=="gold_slime" and run_mode=="gold_slime" else profiles.species(id)\n\nfunc start(seed_value: int = 0, character_id: String = "viya", account_level: Variant = null, selected_map: String = "legacy_arena", skill_ruleset: String = "legacy", support_loadout: Dictionary = {}, mode: String = "campaign", entry_day: int = -1, pacing_version:int=-1, pattern_version:int=-1, encounter_rules:int=0, loot_rules:int=0) -> bool:\n\t# Validate the complete selected character before changing the previous run.\n\tif loot_rules not in [0,1]:return false\n\tvar selected_levels: Dictionary = account_talent_levels.duplicate(true)\n\tif account_level is int:\n', 'var dungeon_day: int = -1\nvar gold_reward_version:int=0 # Published1-14 keep original drops throughout Continue.\nvar dungeon = preload("res://scripts/combat/gold_dungeon.gd").new()\nfunc enemy_definition(id: String) -> Dictionary:\n\treturn dungeon.species(wave_profile()) if id=="gold_slime" and run_mode=="gold_slime" else profiles.species(id)\n\nfunc start(seed_value: int = 0, character_id: String = "viya", account_level: Variant = null, selected_map: String = "legacy_arena", skill_ruleset: String = "legacy", support_loadout: Dictionary = {}, mode: String = "campaign", entry_day: int = -1, pacing_version:int=-1, pattern_version:int=-1, encounter_rules:int=0) -> bool:\n\t# Validate the complete selected character before changing the previous run.\n\tvar selected_levels: Dictionary = account_talent_levels.duplicate(true)\n\tif account_level is int:\n'), ('\tdungeon_day = entry_day\n\tgold_reward_version=1 if mode=="gold_slime" else 0\n\tloot_rules_version=loot_rules\n\tgold_drop_chance = 1.0 if mode=="gold_slime" else (0.30 if previous_mode=="gold_slime" else gold_drop_chance)\n\tsupport_attack_ids = loadout.attack.duplicate()\n', '\tdungeon_day = entry_day\n\tgold_reward_version=1 if mode=="gold_slime" else 0\n\tgold_drop_chance = 1.0 if mode=="gold_slime" else (0.30 if previous_mode=="gold_slime" else gold_drop_chance)\n\tsupport_attack_ids = loadout.attack.duplicate()\n'), ('\tfor i in range(pickups.size() - 1, -1, -1):\n\t\tvar pos: Vector2 = pickups[i]["p"]\n\t\tif loot_rules_version==1 and pickups[i].get("magnet",false):\n\t\t\tpos = LootAttraction.move(pickups[i], player, float(stats["pickup"]), dt)\n\t\t\tpickups[i]["p"] = pos\n\t\telif pos.distance_squared_to(player) <= pow(float(stats["pickup"]), 2.0):\n\t\t\tpos = pos.move_toward(player, 420.0 * dt)\n\t\t\tpickups[i]["p"] = pos\n', '\tfor i in range(pickups.size() - 1, -1, -1):\n\t\tvar pos: Vector2 = pickups[i]["p"]\n\t\tif pos.distance_squared_to(player) <= pow(float(stats["pickup"]), 2.0):\n\t\t\tpos = pos.move_toward(player, 420.0 * dt)\n\t\t\tpickups[i]["p"] = pos\n'), ('\tif transition_action == "restart":\n\t\t# start() validates first. On failure keep the old run and confirmation.\n\t\treturn start(0, growth.character_id, account_level, map_id, growth.ruleset,{},run_mode,dungeon_day,growth.pacing_version,-1,encounter_version,loot_rules_version)\n\t_finish_run("abandoned")\n\treturn true\n', '\tif transition_action == "restart":\n\t\t# start() validates first. On failure keep the old run and confirmation.\n\t\treturn start(0, growth.character_id, account_level, map_id, growth.ruleset,{},run_mode,dungeon_day,growth.pacing_version,-1,encounter_version)\n\t_finish_run("abandoned")\n\treturn true\n'), ('\treturn true\n\nfunc _original_gold_range(kind:String)->Vector2i:\n\tif kind!="normal":return Vector2i(100,1000)\n\treturn dungeon.drop_range(gold_reward_version) if run_mode=="gold_slime" else Vector2i(10,50)\n\nfunc gold_drop_range(kind:String="normal")->Vector2i:\n\tvar limits:=_original_gold_range(kind)\n\treturn Vector2i(limits.x / 2, limits.y / 2) if loot_rules_version==1 else limits\n\nfunc _drop_gold(at: Vector2, kind: String) -> void:\n\tif gold_drop_chance < 1.0 and gold_rng.randf() >= gold_drop_chance:\n\t\treturn\n\tvar limits:Vector2i=_original_gold_range(kind)\n\tvar amount:int=gold_rng.randi_range(limits.x,limits.y)\n\tif loot_rules_version==1:amount=maxi(1,amount / 2) # Same roll/chance; floor half to whole coins.\n\tif gold_pickups.size() >= MAX_PICKUPS:\n\t\tgold_pickups[-1]["value"] += amount\n', '\treturn true\n\nfunc gold_drop_range(kind:String="normal")->Vector2i:\n\tif kind!="normal":return Vector2i(100,1000)\n\treturn dungeon.drop_range(gold_reward_version) if run_mode=="gold_slime" else Vector2i(10,50)\n\nfunc _drop_gold(at: Vector2, kind: String) -> void:\n\tif gold_drop_chance < 1.0 and gold_rng.randf() >= gold_drop_chance:\n\t\treturn\n\tvar limits:Vector2i=gold_drop_range(kind)\n\tvar amount:int=gold_rng.randi_range(limits.x,limits.y)\n\tif gold_pickups.size() >= MAX_PICKUPS:\n\t\tgold_pickups[-1]["value"] += amount\n'), ('\tfor i in range(gold_pickups.size() - 1, -1, -1):\n\t\tvar pos: Vector2 = gold_pickups[i]["p"]\n\t\tif loot_rules_version==1 and gold_pickups[i].get("magnet",false):\n\t\t\tpos = LootAttraction.move(gold_pickups[i], player, float(stats["pickup"]), dt)\n\t\t\tgold_pickups[i]["p"] = pos\n\t\telif pos.distance_squared_to(player) <= pow(float(stats["pickup"]), 2.0):\n\t\t\tpos = pos.move_toward(player, 420.0 * dt)\n\t\t\tgold_pickups[i]["p"] = pos\n', '\tfor i in range(gold_pickups.size() - 1, -1, -1):\n\t\tvar pos: Vector2 = gold_pickups[i]["p"]\n\t\tif pos.distance_squared_to(player) <= pow(float(stats["pickup"]), 2.0):\n\t\t\tpos = pos.move_toward(player, 420.0 * dt)\n\t\t\tgold_pickups[i]["p"] = pos\n'), ('\t\t\tmagic.mana = minf(magic.maximum_mana(), magic.mana + magic.maximum_mana() * SupplyCatalog.RECOVERY_FRACTION)\n\t\t"magnet":\n\t\t\tif loot_rules_version==1:\n\t\t\t\tvar count:int=LootAttraction.activate(pickups)+LootAttraction.activate(gold_pickups)\n\t\t\t\tcues.record_item(player, str(SupplyCatalog.ITEM_NAMES[kind]), {"kind":kind,"attracting":count})\n\t\t\t\treturn # Credit only on arrival; a save retains each flagged pickup.\n\t\t\tvar xp := 0.0\n\t\t\tfor pickup in pickups:\n', '\t\t\tmagic.mana = minf(magic.maximum_mana(), magic.mana + magic.maximum_mana() * SupplyCatalog.RECOVERY_FRACTION)\n\t\t"magnet":\n\t\t\tvar xp := 0.0\n\t\t\tfor pickup in pickups:\n'))

LOOT_VIEW_ADAPTERS = (('\tfor pickup in simulation.pickups:\n\t\tvar pos := _screen(pickup["p"])\n\t\tif Rect2(Vector2.ZERO,size).grow(32).has_point(pos):\n\t\t\t_draw_loot_trail(pickup,false)\n\t\tdraw_colored_polygon(PackedVector2Array([pos + Vector2(0, -7),\n\t\t\tpos + Vector2(5, 0), pos + Vector2(0, 7), pos + Vector2(-5, 0)]), Color("7cd3c1"))\n', '\tfor pickup in simulation.pickups:\n\t\tvar pos := _screen(pickup["p"])\n\t\tdraw_colored_polygon(PackedVector2Array([pos + Vector2(0, -7),\n\t\t\tpos + Vector2(5, 0), pos + Vector2(0, 7), pos + Vector2(-5, 0)]), Color("7cd3c1"))\n'), ('\tfor gold in simulation.gold_pickups:\n\t\tvar at := _screen(gold["p"])\n\t\tif Rect2(Vector2.ZERO,size).grow(32).has_point(at):\n\t\t\t_draw_loot_trail(gold,true)\n\t\tdraw_circle(at, 7.0, Color("edbc54"))\n\t\tdraw_arc(at, 4.0, 0.0, TAU, 12, Color("fff0b3"), 1.2, true)\n', '\tfor gold in simulation.gold_pickups:\n\t\tvar at := _screen(gold["p"])\n\t\tdraw_circle(at, 7.0, Color("edbc54"))\n\t\tdraw_arc(at, 4.0, 0.0, TAU, 12, Color("fff0b3"), 1.2, true)\n'), ('\t\t\tdraw_rect(Rect2(at+Vector2(-20,-33),Vector2(40.0*structure.hp/structure.max_hp,4)),Color("c7b187"))\n\t_draw_supply_items()\n\nfunc _draw_loot_trail(pickup:Dictionary,gold:bool) -> void:\n\tdraw_set_transform(_screen(Vector2.ZERO))\n\tsimulation.LootAttraction.draw_trail(self,pickup,simulation.player,gold)\n\tdraw_set_transform(Vector2.ZERO)\n\nfunc _draw_supply_items() -> void:\n', '\t\t\tdraw_rect(Rect2(at+Vector2(-20,-33),Vector2(40.0*structure.hp/structure.max_hp,4)),Color("c7b187"))\n\t_draw_supply_items()\n\nfunc _draw_supply_items() -> void:\n'))

PURGE_RUN_ADAPTERS = (('var gold_reward_version:int=0 # Published1-14 keep original drops throughout Continue.\nconst LootAttraction=preload("res://scripts/combat/loot_attraction.gd")\nconst PurgeFeedback=preload("res://scripts/combat/purge_feedback.gd")\nvar loot_rules_version:int=0 # Existing entries keep their amounts and instant magnet.\nvar dungeon = preload("res://scripts/combat/gold_dungeon.gd").new()\n', 'var gold_reward_version:int=0 # Published1-14 keep original drops throughout Continue.\nconst LootAttraction=preload("res://scripts/combat/loot_attraction.gd")\nvar loot_rules_version:int=0 # Existing entries keep their amounts and instant magnet.\nvar dungeon = preload("res://scripts/combat/gold_dungeon.gd").new()\n'), ('\tvar supply_before:Dictionary={"hp":hp,"mp":magic.mana,"gold":gold_collected,"kills":kills,"bullets":enemy_bullets.size()}\n\tvar supply_xp:float=0.0\n\tvar purge_marks:Array[Vector2]=[]\n\tif kind=="purge" and cues.enabled:purge_marks=PurgeFeedback.capture(enemies,visible_world())\n\tmatch kind:\n\t\t"hp":\n', '\tvar supply_before:Dictionary={"hp":hp,"mp":magic.mana,"gold":gold_collected,"kills":kills,"bullets":enemy_bullets.size()}\n\tvar supply_xp:float=0.0\n\tmatch kind:\n\t\t"hp":\n'), ('\t\t\tenemy_bullets.clear()\n\tcues.record_item(player, str(SupplyCatalog.ITEM_NAMES[kind]), {"kind":kind,"hp":hp-int(supply_before.hp),"mp":magic.mana-float(supply_before.mp),"gold":gold_collected-int(supply_before.gold),"kills":kills-int(supply_before.kills),"bullets":int(supply_before.bullets)-enemy_bullets.size(),"xp":supply_xp})\n\tif kind=="purge":PurgeFeedback.attach(cues,purge_marks)\n\nfunc _clear_stage() -> void:\n', '\t\t\tenemy_bullets.clear()\n\tcues.record_item(player, str(SupplyCatalog.ITEM_NAMES[kind]), {"kind":kind,"hp":hp-int(supply_before.hp),"mp":magic.mana-float(supply_before.mp),"gold":gold_collected-int(supply_before.gold),"kills":kills-int(supply_before.kills),"bullets":int(supply_before.bullets)-enemy_bullets.size(),"xp":supply_xp})\n\nfunc _clear_stage() -> void:\n'))

PURGE_VIEW_ADAPTERS = (('const BossGuidance=preload("res://scripts/combat/boss_guidance.gd")\nconst SupplyFeedback=preload("res://scripts/combat/supply_feedback.gd")\nconst PurgeFeedback=preload("res://scripts/combat/purge_feedback.gd")\nconst IncomingFeedback=preload("res://scripts/combat/incoming_feedback.gd")\nvar incoming_plan:Dictionary={}\n', 'const BossGuidance=preload("res://scripts/combat/boss_guidance.gd")\nconst SupplyFeedback=preload("res://scripts/combat/supply_feedback.gd")\nconst IncomingFeedback=preload("res://scripts/combat/incoming_feedback.gd")\nvar incoming_plan:Dictionary={}\n'), ('\t\tdraw_line(center + direction * 6.0, center + direction * 34.0, Color("3a3e48"), 8.0, true)\n\t\tdraw_arc(center, 24.0, 0.0, TAU, 36, Color("b69a65"), 1.4, true)\n\tPurgeFeedback.draw(self)\n\t_draw_combat_cues()\n\tIncomingFeedback.draw(self,incoming_plan)\n', '\t\tdraw_line(center + direction * 6.0, center + direction * 34.0, Color("3a3e48"), 8.0, true)\n\t\tdraw_arc(center, 24.0, 0.0, TAU, 36, Color("b69a65"), 1.4, true)\n\t_draw_combat_cues()\n\tIncomingFeedback.draw(self,incoming_plan)\n'))

PORTRAIT_RUN_ADAPTERS = (('\t\t"hp":\n\t\t\t_heal_hp(max_hp * SupplyCatalog.RECOVERY_FRACTION)\n\t\t\tfeedback.trigger("heal") # Consumed HP supply, including full HP; never ordinary regeneration.\n\t\t"mp":\n\t\t\tmagic.mana = minf(magic.maximum_mana(), magic.mana + magic.maximum_mana() * SupplyCatalog.RECOVERY_FRACTION)\n', '\t\t"hp":\n\t\t\t_heal_hp(max_hp * SupplyCatalog.RECOVERY_FRACTION)\n\t\t"mp":\n\t\t\tmagic.mana = minf(magic.maximum_mana(), magic.mana + magic.maximum_mana() * SupplyCatalog.RECOVERY_FRACTION)\n'),)

VIYA_PRESENTATION_VIEW_ADAPTERS = (('var actor_art=preload("res://scripts/ui/actor_assets.gd").new()\nvar actors=preload("res://scripts/combat/actor_motion.gd").new()\nvar viya=preload("res://scripts/combat/viya_presentation.gd").new()\nvar simulation\nvar show_damage: bool = true\n', 'var actor_art=preload("res://scripts/ui/actor_assets.gd").new()\nvar actors=preload("res://scripts/combat/actor_motion.gd").new()\nvar simulation\nvar show_damage: bool = true\n'), ('\tif not enemy.is_empty():keys=[str(enemy.get("species","")),str(enemy.kind if enemy.kind!="normal" else enemy.get("variant","normal"))]\n\tdata.sample=actor_art.frame(art,keys,data.pose,data.direction,data.clock,size)\n\tif enemy.is_empty() and not data.sample.is_empty():viya.apply(self,data)\n\treturn data\n\n', '\tif not enemy.is_empty():keys=[str(enemy.get("species","")),str(enemy.kind if enemy.kind!="normal" else enemy.get("variant","normal"))]\n\tdata.sample=actor_art.frame(art,keys,data.pose,data.direction,data.clock,size)\n\treturn data\n\n'), ('\tfor bullet in simulation.bullets:\n\t\tvar at := _screen(bullet["p"])\n\t\tvar shown:Dictionary=viya.projectile(self,bullet)\n\t\tAttackVisuals.draw_projectile(self, shown.p, shown.direction, str(bullet.get("source", "rifle")), display_plan.simple, bool(bullet.get("weapon",{}).get("evolved",false)), bool(bullet.get("weapon",{}).get("fragment",false)))\n\n\tfor effect in display_plan.effects:\n', '\tfor bullet in simulation.bullets:\n\t\tvar at := _screen(bullet["p"])\n\t\tAttackVisuals.draw_projectile(self, at, bullet["direction"], str(bullet.get("source", "rifle")), display_plan.simple, bool(bullet.get("weapon",{}).get("evolved",false)), bool(bullet.get("weapon",{}).get("fragment",false)))\n\n\tfor effect in display_plan.effects:\n'), ('\tvar direction: Vector2 = hero.facing\n\tif not hero.sample.is_empty():\n\t\tviya.draw(self,actor_art,hero,center)\n\telse:\n\t\tdraw_circle(center + Vector2(0, 8), 23, Color(0, 0, 0, 0.5))\n', '\tvar direction: Vector2 = hero.facing\n\tif not hero.sample.is_empty():\n\t\tdraw_texture_rect(hero.sample.texture,actor_art.rectangle(hero.sample,center),false)\n\telse:\n\t\tdraw_circle(center + Vector2(0, 8), 23, Color(0, 0, 0, 0.5))\n'), ('\t\tdraw_circle(center, 16.0, player_color)\n\t\tdraw_line(center + direction * 6.0, center + direction * 34.0, Color("3a3e48"), 8.0, true)\n\tPurgeFeedback.draw(self)\n\t_draw_combat_cues()\n', '\t\tdraw_circle(center, 16.0, player_color)\n\t\tdraw_line(center + direction * 6.0, center + direction * 34.0, Color("3a3e48"), 8.0, true)\n\t\tdraw_arc(center, 24.0, 0.0, TAU, 36, Color("b69a65"), 1.4, true)\n\tPurgeFeedback.draw(self)\n\t_draw_combat_cues()\n'))
CHARACTER_SIZE_VIEW_ADAPTERS = (('\tdata.sample=actor_art.frame(art,keys,data.pose,data.direction,data.clock,size)\n', '\tdata.sample=actor_art.frame(art,keys,data.pose,data.direction,data.clock)\n'),)
GLOBAL_VIEW_ADAPTERS = (('\t\tvar projected:Vector2=ObliqueProjection.screen_direction(lag,size)\n\t\tvar fraction:float=minf(1,minf(size.x*.08/maxf(.001,absf(projected.x)),size.y*.08/maxf(.001,absf(projected.y))))\n\t\tvar target:Vector2=simulation.player+lag*fraction\n\t\treturn target if simulation.map_id=="legacy_arena" else simulation.map_space.camera_center(target,extent)\n\treturn camera.center(simulation,size)\n\n', '\t\tvar projected:Vector2=ObliqueProjection.screen_direction(lag,size)\n\t\tvar fraction:float=minf(1,minf(size.x*.08/maxf(.001,absf(projected.x)),size.y*.08/maxf(.001,absf(projected.y))))\n\t\treturn simulation.map_space.camera_center(simulation.player+lag*fraction,extent)\n\treturn camera.center(simulation,size)\n\n'), ('\nfunc uses_oblique() -> bool:\n\treturn high_angle and oblique_enabled and simulation!=null\n\nfunc ground_transform() -> Transform2D:\n', '\nfunc uses_oblique() -> bool:\n\treturn high_angle and oblique_enabled and simulation!=null and simulation.map_id=="siege_battlefield"\n\nfunc ground_transform() -> Transform2D:\n'))
OBLIQUE_VIEW_ADAPTERS = (('const ApproachCues = preload("res://scripts/combat/approach_cues.gd")\nconst BattleProjection = preload("res://scripts/combat/battle_projection.gd")\nconst ObliqueProjection = preload("res://scripts/combat/oblique_projection.gd")\nvar oblique_enabled:bool=true # Diagnostic only; no saved rule or rotating camera.\nvar _tilt_player:=Vector2.INF\nvar _tilt_offset:=Vector2.INF\nvar _tilt_size:=Vector2.ZERO\nvar _tilt_run:String=""\nvar _tilt_matrix:=Transform2D.IDENTITY # One derived transform, never one per actor.\nconst Display=preload("res://scripts/combat/combat_display.gd")\nconst BossGuidance=preload("res://scripts/combat/boss_guidance.gd")\n', 'const ApproachCues = preload("res://scripts/combat/approach_cues.gd")\nconst BattleProjection = preload("res://scripts/combat/battle_projection.gd")\nconst Display=preload("res://scripts/combat/combat_display.gd")\nconst BossGuidance=preload("res://scripts/combat/boss_guidance.gd")\n'), ('\nfunc camera_center() -> Vector2:\n\tif uses_oblique():\n\t\tvar extent:Vector2=BattleProjection.world_view_size(size)\n\t\tvar lag:Vector2=camera.offset*extent if camera.run_id==simulation.run_id and camera._initialized and camera._viewport==size else Vector2.ZERO\n\t\tvar projected:Vector2=ObliqueProjection.screen_direction(lag,size)\n\t\tvar fraction:float=minf(1,minf(size.x*.08/maxf(.001,absf(projected.x)),size.y*.08/maxf(.001,absf(projected.y))))\n\t\treturn simulation.map_space.camera_center(simulation.player+lag*fraction,extent)\n\treturn camera.center(simulation,size)\n\n', '\nfunc camera_center() -> Vector2:\n\treturn camera.center(simulation,size)\n\n'), ('\tcamera.advance(simulation,size,displacement,delta,active)\n\nfunc uses_oblique() -> bool:\n\treturn high_angle and oblique_enabled and simulation!=null and simulation.map_id=="siege_battlefield"\n\nfunc ground_transform() -> Transform2D:\n\tif not uses_oblique():return BattleProjection.transform(camera_center(),size)\n\tif _tilt_player!=simulation.player or _tilt_offset!=camera.offset or _tilt_size!=size or _tilt_run!=simulation.run_id:\n\t\t_tilt_player=simulation.player;_tilt_offset=camera.offset;_tilt_size=size;_tilt_run=simulation.run_id\n\t\t_tilt_matrix=ObliqueProjection.transform(camera_center(),size)\n\treturn _tilt_matrix\n\nfunc ground_visible() -> Rect2:\n\treturn ground_transform().affine_inverse()*Rect2(Vector2.ZERO,size) if uses_oblique() else BattleProjection.visible_world(camera_center(),size)\n\nfunc approach_cues() -> Array:\n\tvar area:Rect2=ground_visible() if high_angle else Rect2(camera_center()-size*.5,size)\n\tvar test:Callable=func(at:Vector2):return Rect2(Vector2.ZERO,size).has_point(world_to_screen(at))\n\treturn ApproachCues.build(simulation,area,test) if uses_oblique() else ApproachCues.build(simulation,area)\n\nfunc input_direction(value:Vector2) -> Vector2:\n\treturn ObliqueProjection.input_direction(value,size) if uses_oblique() else value\n\nfunc project_direction(value:Vector2) -> Vector2:\n\tif not high_angle:return value\n\tvar basis:Transform2D=ground_transform()\n\treturn basis.x*value.x+basis.y*value.y\n\nfunc world_to_screen(at: Vector2) -> Vector2:\n\treturn ground_transform()*at if high_angle else at-camera_center()+size*.5\n\nfunc screen_to_world(at: Vector2) -> Vector2:\n\treturn ground_transform().affine_inverse()*at if high_angle else at+camera_center()-size*.5\n\nfunc world_view_size() -> Vector2:\n', '\tcamera.advance(simulation,size,displacement,delta,active)\n\nfunc world_to_screen(at: Vector2) -> Vector2:\n\treturn BattleProjection.world_to_screen(at,camera_center(),size) if high_angle else at-camera_center()+size*.5\n\nfunc screen_to_world(at: Vector2) -> Vector2:\n\treturn BattleProjection.screen_to_world(at,camera_center(),size) if high_angle else at+camera_center()-size*.5\n\nfunc world_view_size() -> Vector2:\n'), ('func actor_visual(enemy:Dictionary={}) -> Dictionary:\n\tvar data:Dictionary=actors.pose(simulation,int(enemy.get("id",0)))\n\tif uses_oblique():data.direction=actors.DIRECTIONS[posmod(roundi(project_direction(data.facing).angle()/(PI/4)),8)]\n\tvar keys:Array=["viya_battle"]\n\tif not enemy.is_empty():keys=[str(enemy.get("species","")),str(enemy.kind if enemy.kind!="normal" else enemy.get("variant","normal"))]\n', 'func actor_visual(enemy:Dictionary={}) -> Dictionary:\n\tvar data:Dictionary=actors.pose(simulation,int(enemy.get("id",0)))\n\tvar keys:Array=["viya_battle"]\n\tif not enemy.is_empty():keys=[str(enemy.get("species","")),str(enemy.kind if enemy.kind!="normal" else enemy.get("variant","normal"))]\n'))

# GAME060: actual wide viewport, exact rollback before historical byte proofs.
SURVIVOR_VIEW_ADAPTERS = (('func camera_center() -> Vector2:\n\tif uses_oblique():\n\t\tvar extent:Vector2=BattleProjection.world_view_size(size)\n\t\tvar lag:Vector2=camera.offset*extent if camera.run_id==simulation.run_id and camera._initialized and camera._viewport==size else Vector2.ZERO\n\t\tvar projected:Vector2=ObliqueProjection.screen_direction(lag,size)\n\t\tvar fraction:float=minf(1,minf(size.x*.08/maxf(.001,absf(projected.x)),size.y*.08/maxf(.001,absf(projected.y))))\n\t\tvar target:Vector2=simulation.player+lag*fraction\n\t\tvar center:Vector2=target if simulation.map_id=="legacy_arena" else simulation.map_space.camera_center(target,ObliqueProjection.world_view_size(size))\n\t\treturn ObliqueProjection.keep_player_visible(simulation.player,center,size)\n\treturn camera.center(simulation,size)\n', 'func camera_center() -> Vector2:\n\tif uses_oblique():\n\t\tvar extent:Vector2=BattleProjection.world_view_size(size)\n\t\tvar lag:Vector2=camera.offset*extent if camera.run_id==simulation.run_id and camera._initialized and camera._viewport==size else Vector2.ZERO\n\t\tvar projected:Vector2=ObliqueProjection.screen_direction(lag,size)\n\t\tvar fraction:float=minf(1,minf(size.x*.08/maxf(.001,absf(projected.x)),size.y*.08/maxf(.001,absf(projected.y))))\n\t\tvar target:Vector2=simulation.player+lag*fraction\n\t\treturn target if simulation.map_id=="legacy_arena" else simulation.map_space.camera_center(target,extent)\n\treturn camera.center(simulation,size)\n'), ('func spawn_guard_size() -> Vector2:\n\treturn world_view_size()*(1.0+2.0*camera.MAX_OFFSET_FRACTION)\n', 'func spawn_guard_size() -> Vector2:\n\treturn camera.guard_size(size)\n'), ('func world_view_size() -> Vector2:\n\t# Layout feeds this actual display footprint into the existing viewport input.\n\treturn ObliqueProjection.world_view_size(size) if uses_oblique() else BattleProjection.world_view_size(size)\n', 'func world_view_size() -> Vector2:\n\t# The comparison toggle does not change saved viewport geometry or spawn RNG.\n\t# Unshifted extent; spawn_guard_size also covers the entire possible lead.\n\treturn BattleProjection.world_view_size(size)\n'))


# SAVEFIX001: freeze the original reproduction and the narrowly reviewed new golden.
FLIER_REVIEWED_SHA256 = {'tests/fixtures/savefix001/flier_before.gd': '76e935bd016c29eb8c8687a9181f88e077ce87ef7999a51ad15165cac6e80405', 'tests/test_flier_expiry.gd': '53354de6942ef42b095fcaeb3bed5329df3aad4153e120d4c9d141f6f6851193', 'tests/test_combat_performance.gd': '9b2e05a0e6406fb437ed4dc483d8c6d5c61c63503b142cc603e2d586cf3ba2f0'}

GAME066_REVIEWED_SHA256 = {'assets/characters/pilot_32/game066_se_run/viya_game066_frames.tres': '403baa687c026db8479238aaa737727b2f3ed4ef078402bb92e31effe82e9390', 'assets/characters/pilot_32/game066_se_run/manifest.json': '8339c85795b4c93b37f25ae157c45241bd7f16b9c9297f910c8f55465c674dcb', 'assets/characters/pilot_32/game066_se_run/provenance/source_registration.json': 'da667ebfdf22c0adf5b9de365d600dd947e1c369551526a7122bdd5b7c135408', 'tests/test_viya_game066.gd': 'bacdd00dda89cc729edf787e7daa2bae43e85a23e1066e8bc6ace47ac028ceaf'}

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


# GAME067 reviewed integration scope; historical authority/source pins above remain.
FILES += ('assets/characters/pilot_32/game067_se_run_fire/viya_game067_frames.tres', 'assets/characters/pilot_32/game067_se_run_fire/integration_manifest.json', 'tests/test_viya_game067.gd', 'tools/build_viya_game067.py')
PATTERN_REVIEWED_SHA256.update({'data/presentation_slots.json': 'fee7eb60457c4871419b88e76713c189e5be608e170422a9fa4f7543ca25353f', 'tests/test_character_pilot.gd': 'a7305abcf91a166b5a36594ade2c1d5f0e120e8c812a0c765c0528e6a7e93272', 'tests/test_map_pilot.gd': '0e8e9d4c0bdc711e933a03c9f67328425eb5080ad588436228d662c0dc26cc04', 'tests/test_maps.gd': 'ae385c8abf558c08eef2e8d30dc1e2bb60a9d57c5d71bdf36502dedee396066c', 'data/viya_motion.json': '75be241a6fd72934c73bc1720ef61b0c77fcd43015dbff520a41b070b198f680', 'scripts/combat/viya_presentation.gd': '848a6fb57789f896a9de692ddf8499ce28fcd7fbc2e41840795e29542e94c509', 'tests/test_viya_presentation.gd': 'e1e5d30dfc0b4c56eaf4cf9a56f1c22c2dea4a34405840af1cee9e9279f4114b', 'tests/test_viya_game065.gd': '888fdfc2d2ba5b98ba8225cfb190e17875c46ada413b0e7e7f343163f63ed1b7'})
GAME066_REVIEWED_SHA256["tests/test_viya_game066.gd"] = "624dcde65a3ad35a3ba8d8b38d4eb1a24687dc3b6e797ff9a5165505c207c5a9"
GAME067_REVIEWED_SHA256 = {'assets/characters/pilot_32/game067_se_run_fire/viya_game067_frames.tres': 'd44c9437cce0eb02c69ebfcde3ef13e691eae8ce3c14c9ca10f95b0fc2fad6e3', 'assets/characters/pilot_32/game067_se_run_fire/integration_manifest.json': '80a3636dde6f442d0834e72e54d36f7d996902f98b198b7b24327cd61ec7c6e3', 'tests/test_viya_game067.gd': 'aea30a414ec6af0909d7cbcd35f99a8c45de0d3f83a12045f3b3b5e14220e99e', 'tools/build_viya_game067.py': '6e42220a1271fa23f5dac66fc9b180e54166076c9905d6f709dcf228c2c12df2'}


PATTERN_REVIEWED_SHA256["tests/test_actor_animation.gd"] = "dbe967d362747bd0199fb6794a78e796662b8b69fe3d917459b6bfad0bc83201"

# GAME068 replaces only S; historical resources remain pinned and native comparisons remain exact.
FILES += ('assets/characters/pilot_32/game068_s_run/viya_game068_frames.tres', 'assets/characters/pilot_32/game068_s_run/integration_manifest.json', 'assets/characters/pilot_32/game068_s_run/manifest.json', 'assets/characters/pilot_32/game068_s_run/provenance/clip_metadata.json', 'assets/characters/pilot_32/game068_s_run/provenance/frame_timing.csv', 'assets/characters/pilot_32/game068_s_run/provenance/phase_alignment.json', 'tests/test_viya_game068.gd', 'tools/build_viya_game068.py')
PATTERN_REVIEWED_SHA256.update({'data/presentation_slots.json': 'fee7eb60457c4871419b88e76713c189e5be608e170422a9fa4f7543ca25353f', 'data/viya_motion.json': '75be241a6fd72934c73bc1720ef61b0c77fcd43015dbff520a41b070b198f680', 'tests/test_character_pilot.gd': 'a7305abcf91a166b5a36594ade2c1d5f0e120e8c812a0c765c0528e6a7e93272', 'tests/test_map_pilot.gd': '0e8e9d4c0bdc711e933a03c9f67328425eb5080ad588436228d662c0dc26cc04', 'tests/test_maps.gd': 'ae385c8abf558c08eef2e8d30dc1e2bb60a9d57c5d71bdf36502dedee396066c', 'tests/test_actor_animation.gd': '2d36c1f4619d51992a3873eaac11424c4dc270412e34338481b1c31fc538b8b5', 'tests/test_viya_presentation.gd': 'e1e5d30dfc0b4c56eaf4cf9a56f1c22c2dea4a34405840af1cee9e9279f4114b'})
GAME066_REVIEWED_SHA256["tests/test_viya_game066.gd"] = 'd2dcc42cec245fb0986e94c9010111592ed6f61ac4442be5b564553d3e190cf0'
GAME067_REVIEWED_SHA256["tests/test_viya_game067.gd"] = '1b3c5cbb705822ff851331b518eba762009440835c4ee36d136ab019d28c86e0'
GAME068_REVIEWED_SHA256 = {'assets/characters/pilot_32/game068_s_run/viya_game068_frames.tres': 'e2b95bebb78f7127458081f4f4912e4d255cf55e6c24ab17aca28478f262b178', 'assets/characters/pilot_32/game068_s_run/integration_manifest.json': 'a06dd6988072dbba98894001b3f265907667a08c6ebc58713acb514ca1b76174', 'assets/characters/pilot_32/game068_s_run/manifest.json': '108fe5c0ca2da4373d2c7d947b6b5a5844d9d18ca599bae588bc661e6f577cbb', 'assets/characters/pilot_32/game068_s_run/provenance/clip_metadata.json': '772eb0ffea792759dca2123f10a054d01314e52bcbc5975e98a7dab3f8166a8b', 'assets/characters/pilot_32/game068_s_run/provenance/frame_timing.csv': '8b809c865e8ce61649df89c70572bc3cf9ec19cef51ac3a0b21b176b8bf28189', 'assets/characters/pilot_32/game068_s_run/provenance/phase_alignment.json': '040ebc9f990164065a173b93f1b9c9d10e189c01ba1814ae0b4377c1035d730b', 'tests/test_viya_game068.gd': 'cc81742d9aaaa1e111c9751783db646f86ff52dd4de91e0bf2f12daf196cfa89', 'tools/build_viya_game068.py': '6c9262cc6f72e236f9ec31c88f0edfc37d76201c5c14e05a5d77f3bdf26ea338'}

# GAME069 adds S firing; every34existing clip is independently compared in engine.
FILES += ('assets/characters/pilot_32/game069_s_run_fire/viya_game069_frames.tres', 'assets/characters/pilot_32/game069_s_run_fire/integration_manifest.json', 'assets/characters/pilot_32/game069_s_run_fire/manifest.json', 'assets/characters/pilot_32/game069_s_run_fire/provenance/clip_metadata.json', 'assets/characters/pilot_32/game069_s_run_fire/provenance/frame_timing.csv', 'assets/characters/pilot_32/game069_s_run_fire/provenance/phase_alignment.json', 'tests/test_viya_game069.gd', 'tools/build_viya_game069.py')
PATTERN_REVIEWED_SHA256.update({'data/presentation_slots.json': 'fee7eb60457c4871419b88e76713c189e5be608e170422a9fa4f7543ca25353f', 'data/viya_motion.json': '75be241a6fd72934c73bc1720ef61b0c77fcd43015dbff520a41b070b198f680', 'scripts/combat/viya_presentation.gd': '66a75a092e9447345dd788981e23647ed9f1198a18ab28dec1d7d2d3f87ae109', 'tests/test_actor_animation.gd': '2d36c1f4619d51992a3873eaac11424c4dc270412e34338481b1c31fc538b8b5', 'tests/test_character_pilot.gd': 'a7305abcf91a166b5a36594ade2c1d5f0e120e8c812a0c765c0528e6a7e93272', 'tests/test_map_pilot.gd': '0e8e9d4c0bdc711e933a03c9f67328425eb5080ad588436228d662c0dc26cc04', 'tests/test_maps.gd': 'ae385c8abf558c08eef2e8d30dc1e2bb60a9d57c5d71bdf36502dedee396066c', 'tests/test_viya_presentation.gd': 'e1e5d30dfc0b4c56eaf4cf9a56f1c22c2dea4a34405840af1cee9e9279f4114b', 'tests/test_viya_game065.gd': '888fdfc2d2ba5b98ba8225cfb190e17875c46ada413b0e7e7f343163f63ed1b7'})
GAME066_REVIEWED_SHA256["tests/test_viya_game066.gd"] = '79bb115656a8e778298bdf87d50320d30445ec72b77f7edb8f8853f0d265b8e7'
GAME067_REVIEWED_SHA256["tests/test_viya_game067.gd"] = '4c23b0d5ad566e0aea1b8204d07570a896d06245ff3e87c8a4c4b5083b837ca4'
GAME068_REVIEWED_SHA256["tests/test_viya_game068.gd"] = '9484cbc33bf114431b0604c75aa055c8f47a1e9f876b99641e6db457d42c18fc'
GAME069_REVIEWED_SHA256 = {'assets/characters/pilot_32/game069_s_run_fire/viya_game069_frames.tres': 'fe99d53e11d042343ef8261189e99925a9d29c117c8d9189ccfe8cc8c43082a6', 'assets/characters/pilot_32/game069_s_run_fire/integration_manifest.json': 'ad38f330b1ff5732dea4950bdd9764af2d7f1e1320db27fb28c094a7ab0fc28c', 'assets/characters/pilot_32/game069_s_run_fire/manifest.json': '992f87c2986f6f6e3ef0c58bd51ee17bdc91f3462801fe741f046e4191f313d1', 'assets/characters/pilot_32/game069_s_run_fire/provenance/clip_metadata.json': '7ec508cd67e936e66dd69fb268359dc08937ca48f17b4be44526821a97f4f8c5', 'assets/characters/pilot_32/game069_s_run_fire/provenance/frame_timing.csv': '7663733ac8fc749501065bbf8bd61ab98088cc72c77759bc702b684afd114e9c', 'assets/characters/pilot_32/game069_s_run_fire/provenance/phase_alignment.json': '1428671635f81ffacd98bdab6b6aff9eb7f469612067bfe7213322be85d0d179', 'tests/test_viya_game069.gd': 'e62be85c821816a2adaed26b91cbc10febc8584e882a87dff74869268e0d0c53', 'tools/build_viya_game069.py': '828778088f0a19cb97d7af4098501a998ab2d69015488079235b70d110a51870'}

# GAME071 keeps full-source checks for the revised routing and rendering paths.
PATTERN_REVIEWED_SHA256.update({
    'scripts/world/map_space.gd': '453fce85c5731942b308ab144a010af2a155a01d0817141e1fc50931df41921d',
    'scripts/combat/actor_motion.gd': 'a1e4a899233531ef128bbac9f046014f321e0b0e5cd57a10465bb4773f761357',
    'scripts/combat/high_angle_battle.gd': 'ab3e98d7e0f02ee435836f0713785b8e8184ef80a6db6c0e17ea3f0868c80abe',
})
CAMPAIGN_GOLD_ADAPTERS = (
    ('const CAMPAIGN_GOLD_DROP_CHANCE := 0.15\n', ''),
    ('var gold_drop_chance: float = CAMPAIGN_GOLD_DROP_CHANCE', 'var gold_drop_chance: float = 0.3'),
    ('\trun_mode = mode\n', '\tvar previous_mode: String=run_mode\n\trun_mode = mode\n'),
    ('gold_drop_chance = 1.0 if mode=="gold_slime" else CAMPAIGN_GOLD_DROP_CHANCE',
     'gold_drop_chance = 1.0 if mode=="gold_slime" else (0.30 if previous_mode=="gold_slime" else gold_drop_chance)'),
)

# GAME072 connects the lobby sheet to the existing read-only character data.
FILES += ('scripts/ui/character_info.gd',)
PATTERN_REVIEWED_SHA256.update({
    'scripts/ui/mobile_main.gd': '2cbd90e77a3652443d0ad2bcb00bdde25df8b31009c50617bd60f9149ec9b27a',
    'scripts/ui/character_info.gd': 'c6e5221e2ea7eb6b84302ec16547b0525f4d93f71b8ac66e508f73cb8299dd36',
})

# Producer-accepted GAME070 SW replacement; strictly preserve all other clips.
FILES += ('tests/test_viya_game070.gd', 'tools/build_viya_game070.py', 'assets/characters/pilot_32/game070_sw_run/viya_game070_frames.tres', 'assets/characters/pilot_32/game070_sw_run/provenance/clip_metadata.json', 'assets/characters/pilot_32/game070_sw_run/provenance/frame_timing.csv', 'assets/characters/pilot_32/game070_sw_run/provenance/phase_alignment.json')
PATTERN_REVIEWED_SHA256.update({'tests/test_viya_game070.gd': 'b0e9e385a9901b79405080f7bba58edb8658b53de7619d3ac2d569953acc8459', 'tools/build_viya_game070.py': 'd1c82fdf2732373ccbd74cb04c0ea89940ae0fa46b1fcefa3d56c97acda0f887', 'assets/characters/pilot_32/game070_sw_run/viya_game070_frames.tres': '1de72b71f36d8a984de507977917a59fd136330ffa7d0b3f78b7b36f21c93016', 'assets/characters/pilot_32/game070_sw_run/provenance/clip_metadata.json': 'ad2e2acd1cf68ba0b9bb5d5f95e6955c3db184db4574acb83eed64bbb9953a67', 'assets/characters/pilot_32/game070_sw_run/provenance/frame_timing.csv': '471fb545255d50c9241552d7a11c22ca2c9d9cacd87f4a6567796c0cc21253ba', 'assets/characters/pilot_32/game070_sw_run/provenance/phase_alignment.json': '0cebd3000d388311b3b6c0a83d624f2875a2c806cc2b59e62493c5afacfc9fdd'})

GAME068_REVIEWED_SHA256['tests/test_viya_game068.gd'] = 'cc81742d9aaaa1e111c9751783db646f86ff52dd4de91e0bf2f12daf196cfa89'
GAME066_REVIEWED_SHA256['tests/test_viya_game066.gd'] = 'bacdd00dda89cc729edf787e7daa2bae43e85a23e1066e8bc6ace47ac028ceaf'

# GAME073 adds account persistence and guarded lobby navigation for Viya.
FILES += ('scripts/progression/character_progress.gd', 'tests/test_viya_progression.gd')
PATTERN_REVIEWED_SHA256.update({
    'scripts/progression/character_progress.gd': '41743ffab91391006e40d7e9c14cf79288ade7f4059c2e14bb636930b4b9bac5',
    'scripts/progression/gold_progress.gd': '1e044e52166c1dd8acf4b248b4c1fc7577a64c8d918fb279b06b0e9434e93cf3',
    'scripts/ui/mobile_main.gd': '98e6f8b0d1118bfb09000712dbb3f73aa45a64b9ab66c4309332e9a6c189b1ee',
    'tests/test_viya_progression.gd': '0972cddc67d1869cac1867e45ef9a7db28e1d898dbc4833b106efc9353f31953',
})

def validate(sources: dict[str, str]) -> list[str]:
    errors: list[str] = []
    run, view, cues, tests, runner, _ = [sources[x] for x in FILES[:6]]
    if 'res://tests/test_route_queries.gd' not in sources['tests/test_run_navigation.gd']:
        errors.append('Exact route-query runtime tests are not registered')
    if 'res://tests/test_stage_battlefield.gd' not in tests:
        errors.append('Stage battlefield runtime tests are not registered')
    if 'res://tests/test_combat_performance.gd' not in sources['tests/test_run_navigation.gd']:
        errors.append('Dense optimization runtime tests are not registered')
    if 'res://tests/test_loot_attraction.gd' not in sources['tests/test_run_navigation.gd']:
        errors.append('Magnet/reward runtime tests are not registered')
    if 'res://tests/test_purge_feedback.gd' not in sources['tests/test_run_navigation.gd']:
        errors.append('Purge feedback runtime tests are not registered')
    if 'res://tests/test_portrait_reactions.gd' not in sources['tests/test_run_navigation.gd']:
        errors.append('Four portrait reaction runtime tests are not registered')
    if 'res://tests/test_character_pilot.gd' not in sources['tests/test_run_navigation.gd']:
        errors.append('Supplied character pilot runtime tests are not registered')
    if 'res://tests/test_viya_game067.gd' not in sources['tests/test_viya_presentation.gd']:
        errors.append('SE moving-fire runtime tests are not registered')
    if 'res://tests/test_viya_game068.gd' not in sources['tests/test_viya_presentation.gd']:
        errors.append('S17 native integration checks are not registered')
    if 'res://tests/test_viya_game069.gd' not in sources['tests/test_viya_presentation.gd']:
        errors.append('S moving-fire native trials are not registered')
    for path, expected in GAME069_REVIEWED_SHA256.items():
        if hashlib.sha256(sources[path].encode('utf-8')).hexdigest() != expected:
            errors.append('Reviewed GAME069 delivery/integration changed: ' + path)
    for path, expected in GAME068_REVIEWED_SHA256.items():
        if hashlib.sha256(sources[path].encode('utf-8')).hexdigest() != expected:
            errors.append('Reviewed GAME068 delivery/integration changed: ' + path)
    for path, expected in GAME067_REVIEWED_SHA256.items():
        if hashlib.sha256(sources[path].encode('utf-8')).hexdigest() != expected:
            errors.append('Reviewed GAME067 delivery/integration changed: ' + path)
    for path, expected in GAME066_REVIEWED_SHA256.items():
        if hashlib.sha256(sources[path].encode('utf-8')).hexdigest() != expected:
            errors.append('Reviewed GAME066 SE clip/provenance/regression changed: ' + path)
    for path, expected in FLIER_REVIEWED_SHA256.items():
        if hashlib.sha256(sources[path].encode('utf-8')).hexdigest() != expected:
            errors.append('Reviewed flier expiry reproduction/golden changed: ' + path)
    expiry_hook = '\t\t# Match the existing snapshot\'s one-microsecond live-lifetime floor.\n\t\t# Repeated subtraction of 5s can leave ~9e-15s and one ghost update.\n\t\tif flier.life < 0.000001:'
    if run.count(expiry_hook) != 1:
        errors.append('Missing/changed reviewed flier expiry correction')
    run = run.replace(expiry_hook, '\t\tif flier.life <= 0.0:', 1)
    gun_hook = '\tcues.record_gun_fire(direction, source)\n'
    if run.count(gun_hook) != 1:
        errors.append('Missing/changed committed legacy gun receipt adapter')
    run = run.replace(gun_hook, '', 1)
    for after, before in PORTRAIT_RUN_ADAPTERS:
        if run.count(after) != 1:
            errors.append('Missing/changed HP item presentation adapter')
        run = run.replace(after, before, 1)
    for after, before in PURGE_RUN_ADAPTERS:
        if run.count(after) != 1:
            errors.append('Missing/changed reviewed cosmetic purge capture/receipt adapter')
        run = run.replace(after, before, 1)
    if 'res://tests/test_oblique_stage.gd' not in sources['tests/test_run_navigation.gd']:
        errors.append('Oblique stage runtime tests are not registered')
    if 'res://tests/test_stage_access_reset.gd' not in sources['tests/test_run_navigation.gd']:
        errors.append('Global stage access/account reset runtime tests are not registered')
    if 'res://tests/test_viya_presentation.gd' not in sources['tests/test_run_navigation.gd']:
        errors.append('Viya gait/muzzle/alpha runtime tests are not registered')
    for after, before in SURVIVOR_VIEW_ADAPTERS:
        if view.count(after) != 1:
            errors.append("Missing/changed reviewed wide viewport adapter")
        view = view.replace(after, before, 1)
    for after, before in VIYA_PRESENTATION_VIEW_ADAPTERS:
        if view.count(after) != 1:
            errors.append('Missing/changed reviewed gait, gun height or ground-marker adapter')
        view = view.replace(after, before, 1)
    for after, before in CHARACTER_SIZE_VIEW_ADAPTERS:
        if view.count(after) != 1:
            errors.append('Missing/changed responsive hero frame adapter')
        view = view.replace(after, before, 1)
    for after, before in GLOBAL_VIEW_ADAPTERS:
        if view.count(after) != 1:
            errors.append('Missing/changed global projection adapter')
        view = view.replace(after, before, 1)
    for after, before in OBLIQUE_VIEW_ADAPTERS:
        if view.count(after) != 1:
            errors.append('Missing/changed reviewed oblique presentation adapter')
        view = view.replace(after, before, 1)
    for after, before in PURGE_VIEW_ADAPTERS:
        if view.count(after) != 1:
            errors.append('Missing/changed reviewed read-only purge draw adapter')
        view = view.replace(after, before, 1)
    for after, before in CAMPAIGN_GOLD_ADAPTERS:
        if run.count(after) != 1:
            errors.append('Missing/changed reviewed campaign gold chance')
        run = run.replace(after, before, 1)
    for after, before in LOOT_RUN_ADAPTERS:
        if run.count(after) != 1:
            errors.append('Missing/changed reviewed magnet/reward adapter')
        run = run.replace(after, before, 1)
    for after, before in LOOT_VIEW_ADAPTERS:
        if view.count(after) != 1:
            errors.append('Missing/changed reviewed attraction visual adapter')
        view = view.replace(after, before, 1)
    for after, before in OPTIMIZATION_RUN_ADAPTERS:
        if run.count(after) != 1:
            errors.append('Missing/changed reviewed optimization adapter')
        run = run.replace(after, before, 1)
    for after, before in PRESSURE_RUN_ADAPTERS:
        if run.count(after) != 1:
            errors.append('Missing/changed reviewed local-pressure adapter')
        run = run.replace(after, before, 1)
    if 'res://tests/test_campaign_pressure.gd' not in tests:
        errors.append('Local encounter pressure runtime tests are not registered')
    for after, before in CAMPAIGN_RUN_ADAPTERS:
        if run.count(after) != 1:
            errors.append('Missing/changed reviewed campaign encounter adapter')
        run = run.replace(after, before, 1)
    for after, before in CAMPAIGN_VIEW_ADAPTERS:
        if view.count(after) != 1:
            errors.append('Missing/changed reviewed chest presentation adapter')
        view = view.replace(after, before, 1)
    if 'res://tests/test_campaign_encounters.gd' not in tests:
        errors.append('Campaign encounters runtime tests are not registered')
    for path, expected in PATTERN_REVIEWED_SHA256.items():
        reviewed = sources[path]
        if path == 'scripts/combat/weapon_modules.gd':
            hook = '\tstate.cues.record_gun_fire(direction, str(p.id), bool(p.get("fragment",false)))\n'
            if reviewed.count(hook) != 1:
                errors.append('Missing/changed committed modular gun receipt adapter')
            reviewed = reviewed.replace(hook, '', 1)
        if path == 'tests/test_run_navigation.gd':
            registration = '\tpreload("res://tests/test_enemy_shape_cache.gd").run(scene, verify)\n'
            if reviewed.count(registration) != 1:
                errors.append('Missing GAME063 cache regression registration')
            reviewed = reviewed.replace(registration, '', 1)
            expiry_registration = '\tawait preload("res://tests/test_flier_expiry.gd").run(scene, verify)\n'
            if reviewed.count(expiry_registration) != 1:
                errors.append('Missing flier expiry/disk regression registration')
            reviewed = reviewed.replace(expiry_registration, '', 1)
        if hashlib.sha256(reviewed.encode('utf-8')).hexdigest() != expected:
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
    if view.count(STABLE_CAMERA_VIEW_ADAPTER[0])!=1:
        errors.append("Stable camera simulation/viewport adapter changed")
    if "res://tests/test_camera_lead.gd" not in tests:
        errors.append("Stable camera runtime checks are not registered")
    restored_view = view.replace(*STABLE_CAMERA_VIEW_ADAPTER, 1).replace(CURSE_VIEW_ADAPTER, '', 1).replace(*SUPPLY_VIEW_ADAPTER, 1).replace(SUPPLY_VIEW_IMPORT, '', 1)
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
    if 'res://tests/test_gun_receipt.gd' not in sources['tests/test_actor_animation.gd']:
        errors.append('Consumed-projectile animation tests are not registered')
    for path, name, commit in (('scripts/combat/run_state.gd', '_projectile', 'shots += 1'),
                               ('scripts/combat/weapon_modules.gd', 'projectile', 'state.shots += 1')):
        method = section(sources[path], name)
        if method.count('cues.record_gun_fire(') != 1 or method.index('cues.record_gun_fire(') < method.index(commit):
            errors.append('Gun receipt must follow successful projectile commit: ' + path)
    for marker in ('gun_serial = 0', 'gun_direction = Vector2.ZERO',
                   'not enabled or fragment or not direction.is_finite() or direction.is_zero_approx()',
                   'gun_serial += 1', 'gun_direction = direction.normalized()',
                   '"gun_serial":gun_serial', '"gun_direction":gun_direction'):
        if marker not in cues:
            errors.append('Missing bounded committed gun receipt: ' + marker)
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
            elif name.endswith('.tres'):
                ns['check_delimiters'](text)
                if not text.startswith('[gd_resource type="SpriteFrames"'):
                    errors.append(name + ': expected data-only SpriteFrames resource')
            else:
                ast.parse(text, name)
            for number, line in enumerate(text.splitlines(), 1):
                if line.rstrip() != line or (name.endswith('.gd') and line.startswith(' ')):
                    errors.append(f'{name}:{number}: whitespace/indentation')
        except (ValueError, SyntaxError) as error:
            errors.append(f'{name}: {error}')
    negative = []
    cases = [
        ('game069_active_rollback', 'data/presentation_slots.json', 'res://assets/characters/pilot_32/game070_sw_run/viya_game070_frames.tres', 'res://assets/characters/pilot_32/game068_s_run/viya_game068_frames.tres'),
        ('game069_missing_s_fire', 'assets/characters/pilot_32/game069_s_run_fire/viya_game069_frames.tres', '"name": &"run_fire_s"', '"name": &"missing_fire_s"'),
        ('game069_missing_s_run', 'assets/characters/pilot_32/game069_s_run_fire/viya_game069_frames.tres', '"name": &"run_s"', '"name": &"missing_run_s"'),
        ('game069_missing_se_fire', 'assets/characters/pilot_32/game069_s_run_fire/viya_game069_frames.tres', '"name": &"run_fire_se"', '"name": &"missing_fire_se"'),
        ('game069_phase_corrupt', 'data/viya_motion.json', '0.8510092121212124', '0.4572192098143875'),
        ('game069_muzzle_corrupt', 'assets/characters/pilot_32/game069_s_run_fire/provenance/clip_metadata.json', '109.8', '199.0'),
        ('game069_unregistered', 'tests/test_viya_presentation.gd', 'res://tests/test_viya_game069.gd', 'res://tests/missing_s_fire.gd'),
        ('game069_s_selection_disabled', 'scripts/combat/viya_presentation.gd', 'if visual.direction in ["e","se","s"]', 'if visual.direction in ["e","se"]'),

        ('game068_active_rollback', 'data/presentation_slots.json', 'res://assets/characters/pilot_32/game070_sw_run/viya_game070_frames.tres', 'res://assets/characters/pilot_32/game067_se_run_fire/viya_game067_frames.tres'),
        ('game068_missing_s', 'assets/characters/pilot_32/game068_s_run/viya_game068_frames.tres', '"name": &"run_s"', '"name": &"missing_run_s"'),
        ('game068_preserved_se_fire', 'assets/characters/pilot_32/game068_s_run/viya_game068_frames.tres', '"name": &"run_fire_se"', '"name": &"missing_fire_se"'),
        ('game068_preserved_e', 'assets/characters/pilot_32/game068_s_run/viya_game068_frames.tres', '"name": &"run_e"', '"name": &"missing_run_e"'),
        ('game068_phase_corrupt', 'data/viya_motion.json', '0.4572192098143875', '0.2727272727272727'),
        ('game068_muzzle_corrupt', 'assets/characters/pilot_32/game068_s_run/provenance/clip_metadata.json', '152.5', '199.0'),
        ('game068_unregistered', 'tests/test_viya_presentation.gd', 'res://tests/test_viya_game068.gd', 'res://tests/missing_s.gd'),

        ('campaign_gold_old_default', 'scripts/combat/run_state.gd', 'CAMPAIGN_GOLD_DROP_CHANCE := 0.15', 'CAMPAIGN_GOLD_DROP_CHANCE := 0.30'),
        ('imprint_free_without_cost', 'scripts/progression/character_progress.gd', 'cost <= 0', 'cost < 0'),
        ('imprint_stale_account', 'scripts/progression/gold_progress.gd', ' and other.character_progress == character_progress', ''),
        ('character_info_invents_other_bonus', 'scripts/ui/character_info.gd', '_add_row(row[0], row[1], increase, "")', '_add_row(row[0], row[1], increase, "+5%")'),
        ('campaign_gold_affects_dungeon', 'scripts/combat/run_state.gd', 'gold_drop_chance = 1.0 if mode=="gold_slime"', 'gold_drop_chance = 0.15 if mode=="gold_slime"'),
        ('route_loses_endpoint', 'scripts/world/map_space.gd', 'bounds.intersects(wall,true)', 'bounds.intersects(wall,false)'),
        ('cache_hurt_bypass', 'scripts/combat/high_angle_battle.gd', 'cache_bodies and flash==0', 'cache_bodies'),
        ('cache_unregistered', 'tests/test_run_navigation.gd', 'res://tests/test_enemy_shape_cache.gd', 'res://tests/missing_enemy_shape_cache.gd'),
        ('viya_edge_bypass','data/presentation_slots.json','res://assets/characters/pilot_32/game070_sw_run/viya_game070_frames.tres','res://assets/characters/pilot_32/resources/viya_directional_motion.tres'),
        ('game064_active_rollback','data/presentation_slots.json','res://assets/characters/pilot_32/game070_sw_run/viya_game070_frames.tres','res://assets/characters/pilot_32/render_cache/viya_render_frames.tres'),
        ('game065_active_rollback','data/presentation_slots.json','res://assets/characters/pilot_32/game070_sw_run/viya_game070_frames.tres','res://assets/characters/pilot_32/game064_e_run/viya_game064_frames.tres'),
        ('game066_active_rollback','data/presentation_slots.json','res://assets/characters/pilot_32/game070_sw_run/viya_game070_frames.tres','res://assets/characters/pilot_32/game065_e_run_fire/viya_game065_frames.tres'),
        ('game067_active_rollback','data/presentation_slots.json', 'res://assets/characters/pilot_32/game070_sw_run/viya_game070_frames.tres', 'res://assets/characters/pilot_32/game066_se_run/viya_game066_frames.tres'),
        ('game067_missing_fire','assets/characters/pilot_32/game067_se_run_fire/viya_game067_frames.tres','"name": &"run_fire_se"','"name": &"missing_fire_se"'),
        ('game067_unregistered','tests/test_viya_presentation.gd','res://tests/test_viya_game067.gd','res://tests/missing.gd'),
        ('game066_missing_se','assets/characters/pilot_32/game066_se_run/viya_game066_frames.tres','"name": &"run_se"','"name": &"run_missing_se"'),
        ('game066_missing_old_fire','assets/characters/pilot_32/game066_se_run/viya_game066_frames.tres','"name": &"run_fire_e"','"name": &"run_missing_fire_e"'),
        ('game066_unregistered','tests/test_viya_presentation.gd','res://tests/test_viya_game066.gd','res://tests/missing.gd'),
        ('game066_muzzle_corrupt','assets/characters/pilot_32/game066_se_run/provenance/source_registration.json','173.5','400.0'),
        ('game065_missing_fire','assets/characters/pilot_32/game065_e_run_fire/viya_game065_frames.tres','"name": &"run_fire_e"','"name": &"run_missing_fire_e"'),
        ('game065_unregistered','tests/test_viya_presentation.gd','preload("res://tests/test_viya_game065.gd").run(view,asset,verify)','pass'),
        ('game064_missing_e','assets/characters/pilot_32/game064_e_run/viya_game064_frames.tres','"name": &"run_e"','"name": &"run_missing_e"'),
        ('game064_uniform_phase','scripts/combat/viya_presentation.gd','clock=run_clock(view.art.resource("viya_battle"),visual.direction,_phase+float(row.phase_origin))','clock=floori(_phase*row.run.size())/71.212121212121'),
        ('game064_wrong_fallback','scripts/combat/viya_presentation.gd','if run_frame.has("texture"):expected=str(run_frame.texture)','if false:expected=str(run_frame.texture)'),
        ('viya_edge_filter','tools/viya_edge_filter.gd','var image:Image=clean(source)','var image:Image=source.duplicate()'),
        ('survivor_single_primitive','scripts/combat/viya_presentation.gd','canvas.draw_texture_rect_region(texture,box,source)','pass'),
        ('survivor_world_zoom','scripts/combat/oblique_projection.gd','_basis=raw','_basis=Transform2D(raw.x*1.7,raw.y*1.7,Vector2.ZERO)'),
        ('survivor_spawn_guard','scripts/combat/battle_view.gd','return world_view_size()*(1.0+2.0*camera.MAX_OFFSET_FRACTION)','return camera.guard_size(size)'),
        ('viya_phase_continuity','scripts/combat/viya_presentation.gd','_phase+sign*maxf(0,distance-_distance)','sign*distance'),
        ('viya_direction_chatter','scripts/combat/viya_presentation.gd','PI/8+deg_to_rad(float(config.direction_hysteresis_degrees))','0.0'),
        ('viya_full_body_attack','scripts/combat/viya_presentation.gd','selected="attack"','selected="idle"'),
        ('viya_motion_unregistered','tests/test_run_navigation.gd','res://tests/test_viya_presentation.gd','res://tests/missing.gd'),
        ('viya_motion_no_alpha','scripts/combat/viya_presentation.gd','if not transparent(visual.sample.texture):','if false:'),
        ('viya_motion_gait_reset','scripts/combat/viya_presentation.gd','var distance:float=float(visual.get("distance",0))','var distance:float=visual.clock'),
        ('viya_motion_still_legs','scripts/combat/viya_presentation.gd','("run" if visual.moving else "idle")','"attack"'),
        ('viya_motion_feet_origin','scripts/combat/viya_presentation.gd','muzzle(view.actor_art,visual,feet)-feet','Vector2.ZERO'),
        ('viya_motion_forced_walk','scripts/ui/mobile_main.gd','movement.direction().length_squared()>.001)','true)'),

        ('hero_size_viewport', 'scripts/combat/battle_view.gd', 'data.clock,size)', 'data.clock)'),
        ('hero_size_native_cap', 'scripts/ui/actor_assets.gd', 'minf(native.x,native.y)', '99.0'),
        ('hero_fixed_scale', 'data/actor_presentation.json', '85.56', '155'),
        ('hero_size_occlusion', 'scripts/combat/oblique_scenery.gd', 'renderer.hero_body)', 'Rect2())'),

        ('reset_unregistered', 'tests/test_run_navigation.gd', 'res://tests/test_stage_access_reset.gd', 'res://tests/missing.gd'),
        ('reset_no_journal', 'scripts/progression/account_reset.gd', 'file.store_string(INTENT)', 'file.store_string("")'),
        ('reset_delete_order', 'scripts/progression/account_reset.gd', 'battle_path+".tmp",battle_path,account_path+".tmp",account_path', 'account_path'),
        ('reset_write_block', 'scripts/main.gd', 'if _account_reset_pending:return false', 'if false:return false'),
        ('stage_launch_target', 'scripts/ui/mobile_main.gd', '_begin_campaign(_selected_stage)', '_begin_campaign(1)'),
        ('stage_replay_receipt', 'scripts/progression/gold_progress.gd', 'if run_id in paid_campaign:', 'if false:'),

        ('character_pilot_unregistered', 'tests/test_run_navigation.gd', 'res://tests/test_character_pilot.gd', 'res://tests/missing.gd'),
        ('character_pilot_slot', 'data/presentation_slots.json', 'res://assets/characters/pilot_32/game070_sw_run/viya_game070_frames.tres', ''),
        ('character_pilot_hurt_loop', 'assets/characters/pilot_32/resources/viya_directional_motion.tres', '"loop": false', '"loop": true'),
        ('character_pilot_timing', 'assets/characters/pilot_32/resources/viya_directional_motion.tres', '"speed": 50.0', '"speed": 5.0'),
        ('character_pilot_checksum', 'assets/characters/pilot_32/source_manifest.json', '11254fff2baec6de74bce61988544a4296a9753007f27bef2950788aea8b6a19', '0'*64),

        ('oblique_unregistered', 'tests/test_run_navigation.gd', 'res://tests/test_oblique_stage.gd', 'res://tests/missing.gd'),
        ('oblique_view_scope', 'scripts/combat/battle_view.gd', 'return high_angle and oblique_enabled and simulation!=null', 'return false'),
        ('oblique_inverse', 'scripts/combat/oblique_projection.gd', 'return transform(center,viewport).affine_inverse()*Rect2(Vector2.ZERO,viewport)', 'return Rect2(Vector2.ZERO,viewport)'),
        ('oblique_camera_drift', 'scripts/combat/battle_view.gd', 'simulation.player+lag*fraction', 'simulation.player+lag*2'),
        ('oblique_world_speed', 'scripts/combat/oblique_projection.gd', 'minf(1,direction.length())', '2.0'),
        ('oblique_occlusion', 'scripts/combat/oblique_scenery.gd', 'var alpha:float=.28 if faded else 1.0', 'var alpha:float=1.0'),
        ('oblique_telegraph', 'scripts/combat/approach_cues.gd', 'contains(enemy.p,visible,screen_test)', 'visible.has_point(enemy.p)'),

        ('portrait_unregistered', 'tests/test_run_navigation.gd', 'res://tests/test_portrait_reactions.gd', 'res://tests/missing.gd'),
        ('portrait_heal_changes_hp', 'scripts/combat/run_state.gd', 'feedback.trigger("heal") # Consumed', 'hp+=20;feedback.trigger("heal") # Consumed'),
        ('portrait_priority', 'scripts/combat/feedback_state.gd', '["hurt", "heal", "magic", "levelup"]', '["heal", "hurt", "magic", "levelup"]'),
        ('portrait_unbounded_assets', 'scripts/ui/portrait_assets.gd', 'value.viya.size() != EXPRESSIONS.size()', 'value.viya.size() < 0'),
        ('portrait_image_input', 'scripts/ui/feedback_panel.gd', 'portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE', 'portrait.mouse_filter = Control.MOUSE_FILTER_STOP'),
        ('portrait_ailment_reset', 'scripts/combat/feedback_state.gd', 'persistent_pain = false', 'persistent_pain = true'),

        ('purge_unregistered', 'tests/test_run_navigation.gd', 'res://tests/test_purge_feedback.gd', 'res://tests/missing.gd'),
        ('purge_actor_mutation', 'scripts/combat/run_state.gd', 'if kind=="purge":PurgeFeedback.attach(cues,purge_marks)', 'if kind=="purge":gold_collected+=10;PurgeFeedback.attach(cues,purge_marks)'),
        ('purge_mark_bound', 'scripts/combat/purge_feedback.gd', 'MAX_MARKS := 12', 'MAX_MARKS := 10000'),
        ('purge_boss_sampling', 'scripts/combat/purge_feedback.gd', 'enemy.kind == "boss" or not visible', 'not visible'),
        ('purge_render_mutation', 'scripts/combat/purge_feedback.gd', 'var fx := plan(view)', 'view.simulation.enemies.clear();var fx := plan(view)'),
        ('purge_audio_duplicate', 'scripts/combat/combat_audio.gd', 'or not grew(event):continue', ':continue'),

        ('route_unregistered', 'tests/test_run_navigation.gd', 'res://tests/test_route_queries.gd', 'res://tests/missing.gd'),
        ('route_blocking_hit', 'scripts/world/map_space.gd', 'from.distance_to(hit)/distance<1.0', 'from.distance_to(hit)/distance<0.9'),
        ('route_bin_bound', 'scripts/world/map_space.gd', 'MAX_AXIS_BIN_ENTRIES := 4096', 'MAX_AXIS_BIN_ENTRIES := 999999'),
        ('route_bin_inclusive', 'scripts/world/map_space.gd', 'floori(high/WALL_BIN_SIZE)+1', 'floori(high/WALL_BIN_SIZE)'),

        ('loot_unregistered', 'tests/test_run_navigation.gd', 'res://tests/test_loot_attraction.gd', 'res://tests/missing.gd'),
        ('loot_early_credit', 'scripts/combat/run_state.gd', 'return # Credit only on arrival', 'gold_collected+=100;return # Credit only on arrival'),
        ('loot_double_amount', 'scripts/combat/run_state.gd', 'amount=maxi(1,amount / 2)', 'amount=maxi(1,amount)'),
        ('loot_global_range', 'scripts/combat/loot_attraction.gd', 'if pickup.get("magnet", false):', 'if false:'),
        ('loot_unsafe_flag', 'scripts/combat/loot_attraction.gd', 'pickup.magnet is bool', 'true'),
        ('loot_retrofit', 'scripts/progression/run_snapshot.gd', 'candidate.run.loot_rules_version=0', 'candidate.run.loot_rules_version=1'),
        ('loot_forgot_production', 'scripts/ui/mobile_main.gd', 'else 0, 1):', 'else 0, 0):'),

        ('optimization_elite_observation', 'scripts/combat/actor_motion.gd', 'enemy.kind=="normal"', 'true'),
        ('optimization_visibility_margin', 'scripts/ui/mobile_main.gd', '.grow(180)', '.grow(0)'),

        ('optimization_unregistered', 'tests/test_run_navigation.gd', 'res://tests/test_combat_performance.gd', 'res://tests/missing.gd'),
        ('optimization_order', 'scripts/combat/spatial_candidates.gd', 'return a.order<b.order', 'return a.order>b.order'),
        ('flier_original_proof_changed', 'tests/fixtures/savefix001/flier_before.gd', 'if flier.life <= 0.0:', 'if flier.life < 0.000001:'),
        ('flier_corrected_golden_changed', 'tests/test_combat_performance.gd', '7450ea3a8ce3b39b7d5108a220e7c8f4f65051c368f99e0cb51b14b9160e02ad', '0000000000000000000000000000000000000000000000000000000000000000'),
        ('flier_expiry_reverted', 'scripts/combat/run_state.gd', 'if flier.life < 0.000001:', 'if flier.life <= 0.0:'),
        ('flier_expiry_overbroad', 'scripts/combat/run_state.gd', 'if flier.life < 0.000001:', 'if flier.life < 0.01:'),
        ('flier_expiry_unregistered', 'tests/test_run_navigation.gd', 'res://tests/test_flier_expiry.gd', 'res://tests/missing.gd'),
        ('gun_receipt_unregistered', 'tests/test_actor_animation.gd', 'res://tests/test_gun_receipt.gd', 'res://tests/missing.gd'),
        ('gun_receipt_skipped', 'scripts/combat/run_state.gd', '\tcues.record_gun_fire(direction, source)\n', ''),
        ('gun_receipt_before_commit', 'scripts/combat/run_state.gd', '\tshots += 1\n\tcues.record_gun_fire(direction, source)', '\tcues.record_gun_fire(direction, source)\n\tshots += 1'),
        ('gun_receipt_fragment', 'scripts/combat/weapon_modules.gd', 'bool(p.get("fragment",false))', 'false'),
        ('gun_receipt_stale', 'scripts/combat/actor_motion.gd', 'state.cues.gun_serial>int(hero.get("before_gun",state.cues.gun_serial))', 'state.cues.gun_serial>=0'),
        ('gun_receipt_ungated', 'scripts/combat/combat_cues.gd', 'not enabled or fragment or not direction.is_finite() or direction.is_zero_approx()', 'not enabled'),
        ('optimization_knockback', 'scripts/combat/weapon_modules.gd', 'state.projectile_target_moved(actor)', 'pass'),
        ('optimization_cache_boundary', 'scripts/combat/run_state.gd', '_bullet_candidates=null\n\nfunc _move_bullets_indexed', 'pass\n\nfunc _move_bullets_indexed'),
        ('optimization_route_tie','scripts/world/map_space.gd','next_index = index+1','next_index = 0'),
        ('optimization_cache_bound', 'scripts/world/map_space.gd', 'MAX_WALL_RADII := 16', 'MAX_WALL_RADII := 100000'),

        ('stage_unregistered', 'tests/test_combat_cues.gd', 'res://tests/test_stage_battlefield.gd', 'res://tests/missing.gd'),
        ('stage_old_map_retrofit', 'scripts/progression/run_snapshot.gd', 'return candidate # Preserve the exact published20', 'candidate.run.map_id="siege_battlefield";return candidate # Preserve the exact published20'),
        ('stage_all_departures', 'scripts/combat/stage_catalog.gd', 'number==1', 'number>=1'),
        ('stage_prologue_overwrite', 'scripts/world/map_catalog.gd', 'else data.get(id)', 'else battlefield.get("map")'),
        ('stage_visual_mutation', 'scripts/combat/battlefield_presentation.gd', 'var canvas=renderer.canvas', 'renderer.state.hp=1;var canvas=renderer.canvas'),
        ('stage_supply_rules', 'scripts/world/supply_catalog.gd', 'const DROP_CHANCE := 0.20', 'const DROP_CHANCE := 1.0'),

        ('pressure_unregistered', FILES[3], 'res://tests/test_campaign_pressure.gd', 'res://tests/missing_pressure.gd'),
        ('pressure_spawn_guard', 'scripts/combat/campaign_pressure.gd', 'not visible.grow(56).has_point(at)', 'true'),
        ('pressure_identity', 'scripts/combat/campaign_pressure.gd', 'enemy.p=at', 'enemy.hp=enemy.max_hp;enemy.p=at'),
        ('pressure_legacy_rules', 'scripts/combat/campaign_encounters_v19.gd', 'version==1', 'version==2'),
        ('pressure_save_policy', 'scripts/progression/run_snapshot.gd', 'return candidate # Keep existing policy0/1', 'candidate.run.encounter_version=2;return candidate # Keep existing policy0/1'),
        ('encounters_unregistered', FILES[3], 'res://tests/test_campaign_encounters.gd', 'res://tests/missing_encounters.gd'),
        ('encounters_cap', 'data/campaign_encounters.json', '640', '64000'),
        ('encounters_retrofit', 'scripts/progression/run_snapshot.gd', 'candidate.run.encounter_version=0', 'candidate.run.encounter_version=1'),
        ('chest_double_grant', 'scripts/combat/campaign_encounters.gd', 'state.chest_pickups.remove_at(i)', '# removed'),
        ('chest_persistence', 'scripts/main.gd', '_chest_serial', '_missing_serial'),
        ('stable_camera_unregistered', FILES[3], 'res://tests/test_camera_lead.gd', 'res://tests/missing_stable_camera.gd'),
        ('stable_camera_adapter', FILES[1], STABLE_CAMERA_VIEW_ADAPTER[0], ''),
        ('stable_camera_limit', 'scripts/combat/combat_camera.gd', 'const MAX_OFFSET_FRACTION := .08', 'const MAX_OFFSET_FRACTION := .8'),
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
        ('pattern_contact_guard', FILES[0], '\t\tif enemy.has("pattern") and enemy_patterns.locked(self,enemy):continue', ''),
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
