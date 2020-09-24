#!/usr/bin/python
#! -*- mode: python; coding: utf-8 -*-

"""
This program takes
"""

import sys
import argparse
import os


def get_args():
    """
    Returns the command line arguments
    """

    my_desc = 'Program that prepares the wav.lst and wav.scp files for' \
              'transcribing with the existing ASR system'

    parser = argparse.ArgumentParser(description=my_desc)

    parser.add_argument('--audio-dir', '-a', help='Input wav dir path',
                        required=True)
    parser.add_argument('--audio-extension', '-ex', help='Audio extention',
                        type=str, default='wav', nargs='?',
                        choices=['wav', 'flac'])
    parser.add_argument('--output-dir', '-o', help='Name of the output folder',
                        required=True)

    return parser.parse_args()


def process_audio(wav_dir, output_w, output_u, extension):
    """
    Writes the content of the wav scp and utt2spk files.
    This is the typical configuration for decoding
    input:
        * wav_dir (str): absolute path of the folder with the wavefiles
        * output_w (file object): file object to write the wav scp content
        * output_u (file object): file object to write the utterance to
          speaker ids mappings
    returns:
        * a dictionary with the speaker to lists of utterance ids mappings
    Note: in this case no speaker id information is available. Therefore, the
          utt2spk and spk2utt information is created mapping each file to
          itself
    """
    spk2utt = {}

    # Open the audios file:
    for filename in sorted(os.listdir(wav_dir)):
        if not filename.startswith('.'):
            # print(filename)
            utt_id = filename.split('.')[0]
            # Write the entry in wav.scp:
            wav_path = os.path.join(wav_dir, utt_id.encode('utf8'))

            output_w.write('{0} sox {1}.{2} -r 16000 -t wav - |\n'.format(
                utt_id.encode('utf8'),
                wav_path,
                extension))
            # output_w.write('{0} {1}.{2}\n'.format(utt_id, wav_path,
            #                                       AUDIO_EXTENSION))

            # Write the entry in utt2spk:
            output_u.write('{0} {0}\n'.format(utt_id))
            # Add the utterance to spk2utt:
            spk2utt[utt_id] = [utt_id]

    return spk2utt


def main():
    # Get the command line arguments:
    args = get_args()

    # Get the absolute path for the input wavs folder:
    abs_wav_dir = os.path.abspath(args.audio_dir)
    aud_extension = args.audio_extension

    # Create the output folder:
    if not os.path.exists(args.output_dir):
        os.makedirs(args.output_dir)

    # Define the names of the output files:
    output_wav = os.path.join(args.output_dir, 'wav.scp')
    output_utt = os.path.join(args.output_dir, 'utt2spk')
    output_spk = os.path.join(args.output_dir, 'spk2utt')

    # Create the output files:
    try:
        output_w = open(output_wav, 'w')
    except IOError as err:
        sys.stderr.write('Error creating {0} ({1})\n'.format(output_wav, err))
        sys.exit(1)

    try:
        output_u = open(output_utt, 'w')
    except IOError as err:
        sys.stderr.write('Error creating {0} ({1})\n'.format(output_utt, err))
        sys.exit(1)

    spk2utt = process_audio(abs_wav_dir, output_w, output_u, aud_extension)

    output_w.close()
    output_u.close()

    # Finally, create the spk2utt file:
    try:
        output_s = open(output_spk, 'w')
    except IOError as err:
        sys.stderr.write('Error creating {0} ({1})\n'.format(output_spk, err))
        sys.exit(1)

    for spk_id in sorted(spk2utt):
        output_s.write('{0}'.format(spk_id.encode('utf8')))

        for utt_id in sorted(spk2utt[spk_id]):
            output_s.write(' {0}'.format(utt_id.encode('utf8')))

        output_s.write('\n')

    output_s.close()


if __name__ == '__main__':
    main()
