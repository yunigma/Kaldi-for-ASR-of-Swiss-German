#!/usr/bin/env python3
# -*- coding: utf8 -*-
# Tannon Kew

"""
Compute minimal edit distance for sequences of arbitrary elements.
Example call:
python3 my_scripts/compute_cer.py -r ~/processed/trash/baseline/orig/decode1_out/decode/scoring_kaldi/test_filt.txt -h ~/processed/trash/baseline/orig/decode1_out/decode/scoring_kaldi/penalty_0.0/11.txt --mode cer --verbose
"""


import sys
from collections import Counter, defaultdict
import argparse
import re
import json


def set_args():
    ap = argparse.ArgumentParser()
    ap.add_argument('-ref', required=True,
                    help='File containing reference transcripions.')
    ap.add_argument('-hyp', required=True,
                    help='File containing system output hypotheses.')
    ap.add_argument('-m', '--n2d_mapping', required=False, help='If provided, flexible WER is calculated based on forms found in mapping.')
    # ap.add_argument('-f', '--flex', required=False, default=False,
                    # action='store_true', help='if set, flexible WER is calculated.')
    ap.add_argument('--verbose', required=False, action='store_true',
                    help='if provided, line by line results are printed.')

    return ap.parse_args()


def normalise_line(line):
    line = re.sub(r'^\S+?(\s|\t)', '', line)
    line = re.sub(r'\s+', ' ', line)
    return line.strip()


def align_pretty(source, target, outfile=sys.stdout):
    """
    Pretty-print the alignment of two sequences of strings.
    """
    i, j = 0, 0
    lines = [[] for _ in range(4)]  # 4 lines: source, bars, target, codes
    for code in opcodes(source, target):
        # print(code)
        code = code.upper()
        s, t = source[i], target[j]
        if code == 'D':  # Deletion: empty string on the target side
            t = '*'
        elif code == 'I':  # Insertion: empty string on the source side
            s = '*'
        elif code == 'E':  # Equal: omit the code
            code = ' '

        # Format all elements to the same width.
        width = max(len(x) for x in (s, t, code))
        for line, token in zip(lines, [s, '|', t, code]):
            line.append(token.center(width))  # pad to width with spaces

        # Increase the counters depending on the operation.
        if code != 'D':  # proceed on the target side, except for deletion
            j += 1
        if code != 'I':  # proceed on the source side, except for insertion
            i += 1

    # Print the accumulated lines.
    for line in lines:
        print(*line, file=outfile)


def opcodes(source, target, n2d_map=None, d2n_map=None):
    """
    Get a list of edit operations for converting source into target.
    """
    n = len(source)
    m = len(target)
    # Initisalise matrix with values None.
    d = [[None for _ in range(m+1)] for _ in range(n+1)]

    d[0][0] = 0

    # Fill in first collumn.
    for i in range(1, n+1):
        d[i][0] = d[i-1][0] + 1

    # Fill in first row.
    for j in range(1, m+1):
        d[0][j] = d[0][j-1] + 1

    # Fill in matrix
    for i in range(1, n+1):
        for j in range(1, m+1):

            if not d2n_map:
                d[i][j] = min(
                    d[i-1][j] + 1,  # del
                    d[i][j-1] + 1,  # ins
                    d[i-1][j-1] + (1 if source[i-1] !=
                                   target[j-1] else 0)  # sub
                )

            else:
                norm_forms = d2n_map[target[j-1]]

                dieth_forms = set()
                for f in norm_forms:
                    for dieth_form in n2d_map[f]:
                        dieth_forms.add(dieth_form)

                d[i][j] = min(
                    d[i-1][j] + 1,  # del
                    d[i][j-1] + 1,  # ins
                    d[i-1][j-1] + (1 if source[i-1]
                                   not in dieth_forms else 0)  # sub
                )

    # Get list of operations from backtrace function.
    return backtrace(d)


def backtrace(d):
    i = len(d) - 1
    j = len(d[0]) - 1
    steps = []
    # While not in the top left cell, calculate the cheapest step and when found move to that cell and insert operation to steps list.
    while i > 0 and j > 0:
        cheapest_step = min(d[i-1][j-1], d[i][j-1], d[i-1][j])

        if cheapest_step == d[i-1][j-1]:
            if d[i-1][j-1] == d[i][j]:
                steps.insert(0, "e")  # cell to upper left is equal
                i -= 1
                j -= 1
                continue

            else:
                steps.insert(0, "s")  # cell to upper left is cheapest via sub
                i -= 1
                j -= 1
                continue

        # Cell to left is min
        elif cheapest_step == d[i][j-1]:
            steps.insert(0, "i")
            j -= 1
            continue

        # Cell above is min
        elif cheapest_step == d[i-1][j]:
            steps.insert(0, "d")
            i -= 1
            continue

    # Moving up (no cell to the left)
    if i > 0 and j == 0:
        for i in reversed(range(i)):
            steps.insert(0, "d")
            i -= 1

    # Moving left (no cell above)
    if i == 0 and j > 0:
        for j in reversed(range(j)):
            steps.insert(0, "i")
            j -= 1

    return steps


def get_mappings(n2d_map_file, verbose=0):
    """
    Converts norm2dieth mapping to dieth2norm mapping, which speeds up searches for Dieth transcription word forms produced in decoding.
    """
    d2n_map = defaultdict(set)
    duplicates = 0
    with open(n2d_map_file, 'r', encoding='utf8') as f:
        n2d_map = json.load(f)
        for k, v in n2d_map.items():
            for w in v:
                d2n_map[w].add(k)

    if verbose >= 3:
        print('\nNORM-TO-DIETH mapping sample:')
        sample_keys = random.sample(list(n2d_map), 10)
        for k in sample_keys:
            print('{}\t{}'.format(k, n2d_map[k]))

        print('\nDIETH-TO-NORM mapping sample:')
        sample_keys = random.sample(list(d2n_map), 10)
        for k in sample_keys:
            print('{}\t{}'.format(k, d2n_map[k]))

        multiple_values = sum([1 for v in d2n_map.values() if len(v) > 1])

        print('\nWARNING: {} Dieth transcriptions have multiple corresponding normalised transcriptions.\n'.format(
            multiple_values))

    return n2d_map, d2n_map


def main():

    args = set_args()

    if args.n2d_mapping:
        n2d_map, d2n_map = get_mappings(args.n2d_mapping)
    else:
        n2d_map, d2n_map = None, None

    total_ops = Counter()
    # total_score = 0
    line_count = 0

    with open(args.ref, 'r', encoding='utf8') as r_file, open(args.hyp, 'r', encoding='utf8') as h_file:
        all_refs = sorted(r_file.readlines())
        all_hyps = sorted(h_file.readlines())
        for line in range(len(all_refs)):
            line_count += 1
            ref = normalise_line(all_refs[line].strip())
            hyp = normalise_line(all_hyps[line].strip())
            # print(ref, '||', hyp)
            # align_pretty(s, t)

            if n2d_map and d2n_map:
                ops = opcodes(ref.split(), hyp.split(), n2d_map, d2n_map)
            else:
                ops = opcodes(ref.split(), hyp.split())

            if args.verbose:
                ops = Counter(ops)
                line_error = (ops['d'] + ops['s'] +
                              ops['i']) / sum(ops.values())
                print('{} || {} || {:.2f}%'.format(ref, hyp, line_error*100))

            total_ops += Counter(ops)
            # line_ops = compute_score(ops)
            # total_ops += line_ops
            # total_score += line_score

    op_count = total_ops['d'] + total_ops['s'] + total_ops['i']

    error_rate = (op_count) / sum(total_ops.values())*100

    if args.n2d_mapping:
        print('%{} {:.2f} [ {} / {}, {} ins, {} del, {} sub ] {}'.format('FLEXWER',
                                                                        error_rate,
                                                                        op_count,
                                                                        sum(total_ops.values(
                                                                        )),
                                                                        total_ops['i'],
                                                                        total_ops['d'],
                                                                        total_ops['s'],
                                                                        args.hyp
                                                                        ))

    else:
        print('%{} {:.2f} [ {} / {}, {} ins, {} del, {} sub ] {}'.format('FLEXWER',
                                                                         error_rate,
                                                                         op_count,
                                                                         sum(total_ops.values(
                                                                         )),
                                                                         total_ops['i'],
                                                                         total_ops['d'],
                                                                         total_ops['s'],
                                                                         args.hyp
                                                                         ))


if __name__ == "__main__":
    main()
