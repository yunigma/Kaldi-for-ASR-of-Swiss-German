#!/usr/bin/env python3
# -*- coding: utf8 -*-
# Tannon Kew

import sys
from pathlib import Path
import re
from collections import defaultdict

content = re.compile(r'%FLEXWER (\d+\.?\d+) (\[.*\])')
decode_dir = sys.argv[1]
outfile = Path(sys.argv[1]) / Path('scoring_kaldi/best_tann_flexwer')


def extract_score_from_flex(file):
    """
    %WER_FLEX 47.13 [7322 / 15537, 3041 ins, 310 del, 3971 sub] /mnt/tannon/processed/archimob_r2/orig/baseline/lw_out/decode/scoring_kaldi/penalty_0.0/1.txt
    """

    with open(str(file), 'r', encoding='utf8') as f:
        info = f.read()
        m = re.match(content, info)
        if m:
            return (float(m.group(1)), m.group(2))


scores = defaultdict(float)

for f in sorted(Path(decode_dir).iterdir()):
    if f.name.startswith('tann_flexwer_'):
        # print(f)
        # info, s =
        scores[str(f)] = extract_score_from_flex(f)

# print(scores)
best_score = list(sorted(scores.items(), key=lambda x: x[1][0]))[0]

# print(best_score[1][0], best_score[1][1], best_score[0])
with open(str(outfile), 'w', encoding='utf8') as outf:
    outf.write('%TANN_FLEXWER {} {} {}\n'.format(
        best_score[1][0], best_score[1][1], best_score[0]))
