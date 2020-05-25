#!/usr/bin/python
#! -*- mode: python; coding: utf-8 -*-

"""
Script that takes as input out_AM/initial_data/ling/lexicon.txt created by
train_AM.sh and returns vocabulary of the train data with no: <SIL_WORD> SIL
and <SPOKEN_NOISE> SPN
"""

import sys
import argparse


def get_args():
    """
    Reads the command line options
    """

    my_desc = 'Scripts that prepares a vocabulary_train.txt file from the' \
              'lexicon.txt'

    parser = argparse.ArgumentParser(description=my_desc)

    parser.add_argument('--input-lexicon', '-i', help='Input lexicon txt file',
                        required=True)

    parser.add_argument('--output-file', '-o', help='Name of the output txt ' \
                        'file', required=True)

    args = parser.parse_args()

    return args


def main():
    """
    Main function from the program
    """
    # Get the command line options:
    args = get_args()

    # Create the output file:
    try:
        output_f = open(args.output_file, 'w')
    except IOError as err:
        sys.stderr.write('Error opening {0} ({1})\n'.format(args.output_file,
                                                            err))
        sys.exit(1)

    vocab = set()
    input_f = open(args.input_lexicon, "r")
    for line in input_f.readlines():
        if line.startswith("<") is False:
            vocab_word = line.split(" ")[0] + "\n"
            if vocab_word not in vocab:
                output_f.write(vocab_word)
                vocab.add(vocab_word)


    input_f.close()
    output_f.close()


if __name__ == '__main__':
    main()
