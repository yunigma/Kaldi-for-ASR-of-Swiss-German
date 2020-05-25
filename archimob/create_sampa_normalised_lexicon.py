#!/usr/bin/python3
# -*- coding: utf-8 -*-

"""
This program creates a lexicon using SAMPA transcriptions.
Example call:
    python3 create_sampa_normalised_lexicon.py -s norm2sampa.json -v normalised_vocabulary.txt -o normalised_lexicon.txt
"""

import sys
import re
import argparse
# from pathlib import Path
import json
from collections import Counter, defaultdict


def get_args():
    """
    Returns the command line arguments
    """

    my_desc = 'Generates pronunciations for an input vocabulary based on SAMPA data provided by URPP and Swisscom'

    parser = argparse.ArgumentParser(description=my_desc)

    parser.add_argument('--vocabulary', '-v', required=True,
                        help='Input vocabulary')

    parser.add_argument('--sampa_file', '-s', required=True,
                        help='JSON file containing dictionary of normalised words and their SAMPA pronunciations')

    parser.add_argument('--outfile', '-o',
                        help='Output lexicon', required=True)

    args = parser.parse_args()

    return args


def write_lexicon(vocab, outfile, sampa_dict):
    """
    Side effects: produces output file equivalent to 'lexicon.txt'. Multiple pronunciations for the same word are written to their own lines.
    format:
        <word> <pronunciation>
    ** Note **
        words containing multiple tokens in the input vocabulary are expected to be glued together with '_'.
    """

    no_pron = Counter()
    line_c = 0
    c = 0
    seen_pairs = set()

    with open(vocab, 'r', encoding='utf8') as inf, open(outfile, 'w', encoding='utf8') as outf:
        for line in inf:
            line_c += 1
            vocab_word = line.strip()
            prons = sampa_dict.get(vocab_word)
            if prons:
                c += 1
                for pron in prons:
                    # remove joining underscore from SAMPA pronunciation
                    pron = re.sub(r'\s?_\s?', ' ', pron)

                    # avoid duplicates in lexicon!
                    if not (vocab_word, pron) in seen_pairs:
                        outf.write('{} {}\n'.format(vocab_word, pron))
                        seen_pairs.add((vocab_word, pron))

            else:
                no_pron[vocab_word] += 1

    print('\nATTENTION: {} items in vocabulary of length {} have at least 1 pronunciation. ({:.2f}%)\n'.format(
        c, line_c, c/line_c*100))


def main():

    args = get_args()

    with open(args.sampa_file, 'r', encoding='utf8') as f:
        sampa_dict = json.load(f)

    # print(len(sampa_dict))
    # print(sum(len(i) for i in sampa_dict.values()))
    # convert all keys to lowercase!
    lowercased = defaultdict(list)
    for k, v in sampa_dict.items():
        for p in v:
            lowercased[k.lower()].append(p)
    # sampa_dict = {k.lower(): v for k, v in sampa_dict.items()}
    # print(len(lowercased))
    # print(sum(len(i) for i in lowercased.values()))
    print('SAMPA pronunication dictionary contains:')
    print('\t{} normalised forms'.format(len(lowercased)))
    print('\t{} pronunciation entries'.format(
        sum(len(i) for i in lowercased.values())))

    write_lexicon(args.vocabulary, args.outfile, lowercased)


if __name__ == '__main__':
    main()
