#!/usr/bin/python
# -*- coding: utf-8 -*-

"""
Splits training and test data according to json provided as input
Example call:
        python ${scripts_dir}/split_data.py \
            -i ${csv_files}/archimob_r2/archimob_r2.csv \
            -o ${csv_files}/archimob_r2/ \
            --test ${archimob_files}/archimob_r2/meta_info/testset_utterances.json \
            --dev dev_set.json (if available)
"""

import sys
import json
import csv
import argparse
import os


def set_args():
    ap = argparse.ArgumentParser()
    ap.add_argument('--train', required=False, help='JSON file containing utterance ids for training set utterances.')
    ap.add_argument('--test', required=False, help='JSON file containing utterance ids for test set utterances.')
    ap.add_argument('--dev', required=False, help='JSON file containing utterance ids for dev set utterances.')
    ap.add_argument('-o', '--outpath', required=True, help='Output directory for train directory and test directory.')
    ap.add_argument('-i', '--input-csv', required=True, help='Input directory containing exmaralda XML')

    return ap.parse_args()


def parse_json(utterance_json_file):

    with open(utterance_json_file, 'r') as inf:

        utterances = json.load(inf, encoding='utf8')

    if not utterances:
        sys.stderr.write('Problem loading utterances from JSON file.')
        sys.exit(1)

    return set([entry['start'] for entry in utterances['utterances']])


def main():
    args = set_args()

    # read in train split data
    if args.train:
        train_utterances = parse_json(args.train)
        sys.stderr.write('Collected {0} utterances from {1}\n'.format(
            len(train_utterances), args.train))
    else:
        train_utterances = set()

    # read in test split data
    if args.test:
        test_utterances = parse_json(args.test)
        sys.stderr.write('Collected {0} utterances from {1}\n'.format(
            len(test_utterances), args.test))
    else:
        test_utterances = set()

    # read in dev split data
    if args.dev:
        dev_utterances = parse_json(args.dev)
        sys.stderr.write('Collected {0} utterances from {1}\n'.format(
            len(test_utterances), args.dev))
    else:
        dev_utterances = set()

    # establish output csv files
    if not os.path.exists(args.outpath):
        os.makedirs(args.outpath)

    outfiles = []

    train_file = args.outpath+'/'+'train.csv'
    train_file_handle = open(train_file, 'w', encoding='utf8')
    train_file_writer = csv.writer(train_file_handle)
    outfiles.append(train_file_handle)

    if args.test:
        test_file = args.outpath+'/'+'test.csv'
        test_file_handle = open(test_file, 'w', encoding='utf8')
        test_file_writer = csv.writer(test_file_handle)
        outfiles.append(test_file_handle)

    if args.dev:
        dev_file = args.outpath+'/'+'dev.csv'
        dev_file_handle = open(dev_file, 'w', encoding='utf8')
        dev_file_writer = csv.writer(dev_file_handle)
        outfiles.append(dev_file_handle)

    # initialise counter variables for logging
    train_c = 0
    test_c = 0
    dev_c = 0

    with open(args.input_csv, 'r', encoding='utf8') as input_csv:
        # no_relevant_speech, transcription, normalized, missing_audio, anonymity,
        # utt_id, speech_in_speech, audio_id, speaker_id
        reader = csv.reader(input_csv)

        # skip header
        col_names = next(reader)

        # write headers
        train_file_writer.writerow(col_names)
        if args.test:
            test_file_writer.writerow(col_names)
        if args.dev:
            dev_file_writer.writerow(col_names)

        for row in reader:
            labelled_row = dict(zip(col_names, row))
            # row = dict(zip(col_names, row))
            # print(row['utt_id'])


            if labelled_row['audio_id'] in test_utterances:
                test_file_writer.writerow(row)
                test_c += 1

            elif args.dev and labelled_row['audio_id'] in dev_utterances:
                dev_file_writer.writerow(row)
                dev_c += 1

            else:
                # if a restriction on training utterances is provided, only add relevant utterances.
                if len(train_utterances) != 0:
                    if labelled_row['audio_id'] in train_utterances:
                        train_file_writer.writerow(row)
                        train_c += 1

                # if no restriction is given for training utterances, take all of them
                else:
                    train_file_writer.writerow(row)
                    train_c += 1

    # close all opened files
    for f in outfiles:
        f.close()

    # print out number of utterances for logging
    sys.stderr.write('{} utterances writen to train csv.\n'.format(train_c))
    sys.stderr.write('{} utterances writen to test csv.\n'.format(test_c))
    sys.stderr.write('{} utterances writen to dev csv.\n'.format(dev_c))


if __name__ == '__main__':
    main()
