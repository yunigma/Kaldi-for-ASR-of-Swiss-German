#!/usr/bin/python
#! -*- mode: python; coding: utf-8 -*-

"""
This program creates a simple lexicon with a one to one grapheme to phoneme
mapping, besides some consonant clusters that are known to map to a single
phone
"""

import sys

import re
import argparse
import unicodedata

# Signs to exclude from the transcriptions (when --add-signs is not specified)
EXCLUDE_SET = set(["'", '-', '.'])

def get_args():
    """
    Returns the command line arguments
    """

    my_desc = 'Generates pronunciations for an input vocabulary by mapping ' \
              'clusters of graphemes to phonetic symbols'

    parser = argparse.ArgumentParser(description=my_desc)

    parser.add_argument('--vocabulary', '-v', help='Input vocabulary',
                        required=True)

    parser.add_argument('--cluster-file', '-c', help='File with the consonant' \
                        ' clusters', required=True)

    parser.add_argument('--map-diacritic', '-m', help='Map compound ' \
                        'diacritics to alternative character. If null, ' \
                        'just recombines', default=u'1')

    parser.add_argument('--output-file', '-o', help='Output lexicon',
                        required=True)

    args = parser.parse_args()

    if not args.map_diacritic:
        args.map_diacritic = None

    return args


def ProcessUnicodeCompounds(data, map_diacritic=None):
    """
    Correctly re-combines compound unicode characters.
    input:
        * data (str|list) Input unicode data. String or list.
        * map_diacritic (None|unicode) Unicode string to map all combining
          characters to.  Default to original character.
    returns:
        * a list of unicode characters, where all compounds have been
          recombined, either using the original, or the map_diacritic value.
    """
    for char in data:
        if not isinstance(char, unicode):
            raise TypeError, 'All chars in data must be ' \
                'valid unicode instances!'

    if map_diacritic != None and \
       not isinstance(map_diacritic, unicode):
        raise TypeError, 'map_diacritic MUST be None ' \
            'or a valid unicode string.'

    # Split into individual characters (not graphemes!)
    # it is necessary to recombine once, just in case the user
    # provided a list
    chars = [char for char in u''.join(data)]

    # Recombine unicode compounds. NOTE: unicodedata.normalize
    # does NOT cover all examples in the data, so we have to
    # do this manually.  The compound diacritics always follow
    # the letter they combine with.
    chars.reverse()
    chunk = []
    tmp_chars = []
    for char in chars:
        if unicodedata.combining(char):
            if map_diacritic:
                chunk.append(map_diacritic)
            else:
                chunk.append(char)
        else:
            chunk.append(char)
            chunk.reverse()
            tmp_chars.append(u''.join(chunk))
            chunk = []
    # After successful recombination we finally have a list
    # of actual graphemes
    chars = [char for char in tmp_chars]
    chars.reverse()

    return chars


def read_clusters(input_file):
    """
    Reads the file with the clusters
    input:
        * input_file (str) name of the input file, with the consonant
          clusters and their mappings to some phoneme name ("cluster" "phone")
    returns:
        * a dictionary with the clusters as keys, and the corresponding phones
          as values
    """

    verbose = False

    output = {}

    try:
        input_f = open(input_file, 'r')
    except IOError as err:
        sys.stderr.write('Error opening {0} ({1})\n'.format(input_file, err))
        sys.exit(1)

    if verbose:
        print 'In read_clusters:'

    for line in input_f:

        if verbose:
            print '\tLine = ' + line

        line = line.decode('utf8').rstrip()
        fields = re.split(r'\t', line)

        if len(fields) != 2:
            sys.stderr.write('Error: the file {0} must have exactly two ' \
                             'columns separated by tabs. ' \
                             'See {1}\n'.format(input_file, line))
            sys.exit(1)

        output[fields[0]] = re.split(r'\s*,\s*', fields[1])

        if verbose:
            print '\t' + '-'.join(re.split(r'\s*,\s*', fields[1])) + '\n'

    input_f.close()

    return output

def transcribe_simple(word, clusters, max_length_cluster, map_diacritic=None):
    """
    Transcribes a word mapping each grapheme to itself, besides some special
    clusters
    input:
        * word (str): Input word
        * cluster (dict): Dictionary mapping clusters of graphemes to single
          phones
        * max_length_cluster (int): maximum length of all the consonant
          clusters
    returns:
        * a string with a pseudo phonetic transcription of the input word
    """

    verbose = False
    word = ProcessUnicodeCompounds(word, map_diacritic)
    word_length = len(word)

    output = ['']

    graph_index = 0

    if verbose:
        print 'Input word: ' + word.encode('utf8')
        import pdb
        pdb.set_trace()

    while graph_index < word_length:

        if word[graph_index] in EXCLUDE_SET:
            if verbose:
                print 'Found sign {0}: skipping ' \
                    'it.'.format(word[graph_index])
            graph_index += 1
            continue

        transcribed = 0

        for index in range(graph_index + max_length_cluster - 1,
                           graph_index, -1):

            if verbose:
                print '\tIndex = {0}. Graph = {1}. ' \
                    'Length = {2}'.format(index, graph_index, word_length)

            if index >= word_length:
                continue

            current_clust = u''.join(word[graph_index:index + 1])

            if verbose:
                print '\tLooking for cluster ' + current_clust.encode('utf8')

            if current_clust in clusters:

                if verbose:
                    print '\tFound ' + current_clust

                interm_output = []
                for trans in clusters[current_clust]:
                    for multi in output:
                        interm_output.append(multi + ' ' + trans)

                output = interm_output

                #    output = output + ' ' + clusters[current_clust]
                graph_index += len(current_clust)
                transcribed = 1
                break

        if transcribed == 0:
            interm_output = []
            for multi in output:
                interm_output.append(multi + ' ' + word[graph_index])
            output = interm_output
            # output = output + ' ' + word[graph_index]

            graph_index += 1

            if verbose:
                for multi in output:
                    print '\tNo cluster: ' + multi.encode('utf8')

    if verbose:
        print 'Output: ' + ','.join(output)

    return [multi.strip() for multi in output]


def main():
    """
    Main function of the program
    """

    # Get the command line arguments:
    args = get_args()

    clusters = read_clusters(args.cluster_file)

    max_length_cluster = 0
    for clust in clusters:
        if len(clust) > max_length_cluster:
            max_length_cluster = len(clust)

    try:
        input_f = open(args.vocabulary, 'r')
    except IOError as err:
        sys.stderr.write('Error opening {0} ({1})\n'.format(args.vocabulary,
                                                            err))
        sys.exit(1)

    try:
        output_f = open(args.output_file, 'w')
    except IOError as err:
        sys.stderr.write('Error creating {0} ({1})\n'.format(args.output_file,
                                                             err))
        sys.exit(1)

    for word in input_f:
        word = word.rstrip().decode('utf8')
        if isinstance(args.map_diacritic, str):
            args.map_diacritic = args.map_diacritic.decode('utf8')

        transcription = transcribe_simple(word.lower(), clusters,
                                          max_length_cluster,
                                          args.map_diacritic)

        for multi in transcription:
            output_f.write('{0} {1}\n'.format(word.encode('utf8'),
                                              multi.encode('utf8')))

    output_f.close()
    input_f.close()

if __name__ == '__main__':
    main()
