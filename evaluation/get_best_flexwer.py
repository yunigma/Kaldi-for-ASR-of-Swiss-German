#!/usr/bin/env python3
# -*- coding: utf8 -*-

'''
Run:
get_best_flexwer.py -dir /Users/inigma/Documents/UZH_Master/MasterThesis/results/phon_recog/nnet_discr/ -m /Users/inigma/Documents/UZH_Master/MasterThesis/KALDI/kaldi_wrk_dir/data/corpus_data/norm2dieth.json
'''


import os
import argparse
from pathlib import Path
import re
import time
from collections import defaultdict
from compute_flexwer import set_args as set_flex_args, main as flexwer


content = re.compile(r'%FLEXWER (\d+\.?\d+) (\[.*\])')

start = time.time()


def set_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('-dir', required=True, help='Decoding direction.')
    parser.add_argument('-wip', nargs='+', required=False,
                        help='Word insertion penalty range.', type=float,
                        default=[0.0, 0.5, 1.0])
    parser.add_argument('-min-lmwt', required=False,
                        help='Language model weights min.', type=int,
                        default=7)
    parser.add_argument('-max-lmwt', required=False,
                        help='Language model weights max.', type=int,
                        default=17)
    parser.add_argument('-m', '--n2d_mapping', required=False,
                        help='If provided, flexible WER is calculated based on forms found in mapping.')

    return parser.parse_args()


def extract_score_from_flex(file):
    """
    %WER_FLEX 47.13 [7322 / 15537, 3041 ins, 310 del, 3971 sub] decode/scoring_kaldi/penalty_0.0/1.txt
    """

    with open(str(file), 'r', encoding='utf8') as f:
        info = f.read()
        m = re.match(content, info)
        if m:
            return (float(m.group(1)), m.group(2))


def main():
    args = set_args()
    flex_parser = set_flex_args()

    ref_path = Path(args.dir) / Path('scoring_kaldi/test_filt.txt')
    if args.n2d_mapping:
        mapping_path = args.n2d_mapping
    # try:
    #     os.stat(str(Path(args.dir) / Path('flex')))
    # except:
    #     os.mkdir(str(Path(args.dir) / Path('flex')))

    for wip in args.wip:
        for hyp_path in sorted((Path(args.dir) / Path('scoring_kaldi/penalty_{}'.format(wip))).iterdir()):
            if hyp_path.name.endswith('.txt') and not hyp_path.name.endswith('chars.txt'):
                if args.n2d_mapping:
                    flex_args = flex_parser.parse_args(['-ref', str(ref_path), '-hyp', str(hyp_path), '-m', mapping_path])
                    flex_result = flexwer(flex_args)
                    output_name = Path(args.dir) / Path('flex_{}_{}'.format(hyp_path.stem, wip))
                    try:
                        assert flex_result is not None
                    except AssertionError:
                        print("flex_result is EMPTY.")

                else:
                    wer_args = flex_parser.parse_args(['-ref', str(ref_path), '-hyp', str(hyp_path)])
                    wer_result = flexwer(wer_args)
                    output_name = Path(args.dir) / Path('ourwer_{}_{}'.format(hyp_path.stem, wip))
                    try:
                        assert wer_result is not None
                    except AssertionError:
                        print("wer_result is EMPTY.")

                with open(str(output_name), "w") as fout:
                    if args.n2d_mapping:
                        fout.write(flex_result)
                    else:
                        fout.write(wer_result)

    end_all_flex = time.time()
    print("Scoring is ended. Execution time: {}".format(end_all_flex - start))

    scores = defaultdict(float)

    for file in sorted((Path(args.dir)).iterdir()):
        if args.n2d_mapping:
            if file.name.startswith('flex_'):
                scores[str(file)] = extract_score_from_flex(file)
        else:
            if file.name.startswith('ourwer_'):
                scores[str(file)] = extract_score_from_flex(file)

    best_score = list(sorted(scores.items(), key=lambda x: x[1][0]))[0]

    if args.n2d_mapping:
        outfile = Path(args.dir) / Path('scoring_kaldi/best_flexwer')
        with open(str(outfile), 'w', encoding='utf8') as outf:
            outf.write('%FLEXWER {} {} {}\n'.format(
                best_score[1][0], best_score[1][1], best_score[0]))
    else:
        outfile = Path(args.dir) / Path('scoring_kaldi/best_ourwer')
        with open(str(outfile), 'w', encoding='utf8') as outf:
            outf.write('%OURWER {} {} {}\n'.format(
                best_score[1][0], best_score[1][1], best_score[0]))

    end = time.time()
    print("Done in {}".format(end - start))


if __name__ == "__main__":
    main()
