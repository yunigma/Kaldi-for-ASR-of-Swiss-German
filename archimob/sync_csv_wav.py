#!/usr/bin/python
# -*- coding: utf-8 -*-

"""
Script takes as input a csv file with transcriptions and directory with
chuncked wavefiles, and renames wavefiles to make them correspond to the
transcription and to the Kaldi.
input: .csv, wav-dir
Example call:
        python ${scripts_dir}/sync_csv_wav.py \
            -i ${csv_files}/archimob_r2/archimob_r2.csv \
            -chw ${archimob_files}/archimob_r2/audio
"""

import os
import os.path
import shutil
import argparse
import csv
import re
from collections import OrderedDict

def get_args():
    """
    Reads the command line options
    """

    my_desc = 'Scripts that prepares a set of Exmaralda files, and their ' \
              'waves, for acoustic model training'

    parser = argparse.ArgumentParser(description=my_desc)

    parser.add_argument('--input-csv', '-i', help='Input csv file',
                        nargs='?', required=True)

    parser.add_argument('--chuncked-wav-dir', '-chw', help='Folder with the' \
                        'chuncked wavefiles if they already exist but should' \
                        'be renamed', required=True)

    parser.add_argument('--verbose', required=False, action='store_true')

    args = parser.parse_args()

    return args


def main():
    """
    Main function of the program
    """

    # Get the command line options:
    args = get_args()
    directory = args.chuncked_wav_dir
    input_csvfile = args.input_csv

    annotation_dictionary = []

    with open(input_csvfile, 'r') as csvfile:

        csv_annotation = csv.reader(csvfile, delimiter=',')

        header = next(csv_annotation)

        prev_audio = ''
        prev_id = ''
        n_overlap = 0
        n_transcription_only = 0
        n_audio_only = 0

        for phrase in csv_annotation: # phrase == row in csv file

            phrase = OrderedDict(zip(header, phrase))

            current_id = phrase['utt_id']
            # if not renamed yet
            current_audio = re.sub('-', '_', phrase['audio_id'])

            curr_audio_unrenamed = os.path.join(directory,
                                    "{}{}".format(current_audio, ".wav"))
            target_name = os.path.join(directory,
                                         "{}{}".format(current_id, ".wav"))
            # if has been already renamed
            curr_audio_renamed = os.path.join(directory,
                                              "{}{}".format(current_id,
                                                            ".wav"))

            if os.path.exists(curr_audio_unrenamed):
                if os.path.getsize(curr_audio_unrenamed) != 0:
                    phrase['missing_audio'] = '0'
                    if current_audio != prev_audio:
                        os.rename(curr_audio_unrenamed, target_name)
                    else:
                        n_overlap += 1
                        if args.verbose:
                            print("WARNING: {} and {} refer to the same audio {}.".format(prev_id,current_id,current_audio))
                else:
                    n_transcription_only += 1
                    phrase['missing_audio'] = '1'
                    if args.verbose:
                        print("WARNING: there is no audio for the fragment {}".format(current_id))

            elif os.path.exists(curr_audio_renamed):
                if os.path.getsize(curr_audio_renamed) != 0:
                    phrase['missing_audio'] = '0'

            else:
                n_transcription_only += 1
                phrase['missing_audio'] = '1'
                if args.verbose:
                    print("WARNING: there is no audio for the fragment {}".format(current_id))

            prev_audio = current_audio
            prev_id = current_id
            annotation_dictionary.append(phrase)

        for wav_file in os.listdir(directory):
            if wav_file.startswith("d"):
                n_audio_only += 1
                if args.verbose:
                    print("WARNING: audio file {} has no corresponding annotation".format(wav_file))
                if not os.path.exists(os.path.join(directory, "../empty_wavs")):
                    os.makedirs(os.path.join(directory, "../empty_wavs"))
                shutil.copyfile(os.path.join(directory, wav_file),
                                os.path.join(directory, "../empty_wavs/", wav_file))
                os.remove(os.path.join(directory, wav_file))

        print("\nINFO:\n")
        print("{} overlappings\n".format(n_overlap))
        print("{} transcriptions do not have corresponding audio files\n".format(n_transcription_only))
        print("{} audio files do not have corresponding transcriptions\n".format(n_audio_only))

    with open(input_csvfile, 'w') as csvfile_out:
        writer = csv.DictWriter(csvfile_out, annotation_dictionary[0].keys())
        writer.writeheader()
        writer.writerows(annotation_dictionary)


if __name__ == '__main__':
    main()
