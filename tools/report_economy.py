#!/usr/bin/env python3
"""Estimate discrete play/payout time from real balance samples; no game writes.
Income is held at measured none/full averages. This is not a live-service forecast.
"""
from __future__ import annotations
import argparse
import ast
import csv
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

def native_result(path: Path) -> dict:
    records = [json.loads(s) for s in path.read_text().splitlines() if s.startswith('{')]
    if not records or 'runs' not in records[-1]:
        raise ValueError(f'No completed native measurement: {path}')
    result = records[-1]
    if len(result['runs']) != 5 or any(r['outcome'] not in ('cleared', 'timeout', 'defeat') for r in result['runs']):
        raise ValueError(f'Incomplete/unsupported samples: {path}')
    return result

def purchase_targets() -> tuple[list[int], dict[str, int], str]:
    source = (ROOT / 'scripts/progression/account_talents.gd').read_text()
    def array(name: str) -> list:
        return ast.literal_eval(re.search(r'const ' + name + r' := (\[[^\n]+\])', source)[1])
    costs = array('ATTACK_COSTS')
    roots = array('ROOT_IDS')
    rest = ast.literal_eval(re.search(r'const IDS := ROOT_IDS \+ (\[[^\n]+\])', source)[1])
    if len(costs) != 3 or len(set(roots + rest)) != 18:
        raise ValueError('Review economy schema before estimating new trait structure')
    cumulative = [sum(costs[:i]) for i in (1, 2, 3)]
    targets = {f'root_Lv{i}': cumulative[i - 1] for i in (1, 2, 3)}
    targets.update({f'all18_Lv{i}': 18 * cumulative[i - 1] for i in (1, 2, 3)})
    targets['depth3_chain_Lv3'] = 3 * cumulative[2]
    return costs, targets, hashlib.sha256(source.encode()).hexdigest()

def simulate(cost: int, daily_campaigns: int, dungeon: dict, campaign: dict) -> dict:
    balance = 0.0
    active = choices = 0.0
    gold_runs = campaign_runs = 0
    for day in range(1, 10001):
        for mode in ['gold'] * 2 + ['campaign'] * daily_campaigns:
            sample = dungeon if mode == 'gold' else campaign
            balance += sample['mean_reward_per_attempt']
            active += sample['mean_active_seconds']
            choices += sample['mean_choices']
            gold_runs += mode == 'gold'
            campaign_runs += mode == 'campaign'
            if balance >= cost:
                return {'days': day, 'dungeon_runs': gold_runs, 'campaign_attempts': campaign_runs,
                        'active_minutes': round(active / 60, 2),
                        'minutes_if_3_seconds_per_choice': round((active + choices * 3) / 60, 2),
                        'expected_balance': round(balance, 2)}
    raise ValueError('Target unreachable within10000days under this scenario')

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True, help='Folder of final-map-profile.log measurements')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    costs, targets, cost_hash = purchase_targets()
    income = {}
    inputs = {}
    for profile in ('none', 'full'):
        income[profile] = {}
        for mode in ('prologue_wall', 'outskirts_trial', 'gold_slime'):
            path = args.input / f'final-{mode}-{profile}.log'
            result = native_result(path)
            runs = result['runs']
            income[profile][mode] = {
                'attempts': len(runs), 'clears': sum(r['outcome'] == 'cleared' for r in runs),
                'mean_reward_per_attempt': sum(r['gold_reward'] for r in runs) / len(runs),
                'mean_active_seconds': sum(r['elapsed'] for r in runs) / len(runs),
                'mean_choices': sum(r['choices'] for r in runs) / len(runs)}
            inputs[str(path)] = hashlib.sha256(path.read_bytes()).hexdigest()
    rows = []
    for profile, modes in income.items():
        # Equal attempt weighting across the two available campaign maps. Failed
        # attempts keep zero reward; this is not a successful-runs-only estimate.
        campaign = {key: sum(modes[m][key] for m in ('prologue_wall', 'outskirts_trial')) / 2
                    for key in ('mean_reward_per_attempt', 'mean_active_seconds', 'mean_choices')}
        dungeon = modes['gold_slime']
        for campaigns in (1, 3, 9):
            for label, target in targets.items():
                rows.append({'income_profile': profile, 'daily_dungeon_limit': 2,
                             'daily_campaign_attempts': campaigns, 'target': label, 'cost': target,
                             'daily_expected_gold': round(2 * dungeon['mean_reward_per_attempt'] + campaigns * campaign['mean_reward_per_attempt'], 2),
                             **simulate(target, campaigns, dungeon, campaign)})
    report = {'status': 'CALCULATED', 'prices_each_rank': costs, 'targets_cumulative': targets,
              'account_talents_source_sha256': cost_hash, 'income': income, 'scenarios': rows,
              'assumptions': ['Start wallet0; two dungeon attempts/day then1,3or9campaign attempts/day.',
                              'Payout only after each whole run; partial runs never buy traits early.',
                              'Income fixed at none/full sample averages; purchases do not dynamically change income.',
                              'Campaign means include failed attempts with0reward; two maps equally weighted.',
                              'Active time excludes menus/choice pauses; optional3seconds/choice is an explicit timing assumption.',
                              'Human variance, future stages, device pauses and final economic approval are not established.'],
              'inputs_sha256': inputs}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    with args.output.with_suffix('.csv').open('w', newline='') as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    print(json.dumps({'status': report['status'], 'prices': costs, 'targets': targets, 'scenarios': len(rows)}, ensure_ascii=False))

if __name__ == '__main__':
    main()
