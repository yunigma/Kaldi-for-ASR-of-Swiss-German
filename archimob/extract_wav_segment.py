#!/usr/bin/python

"""@package extract_wav_segment
Extracts segments from a wavefile taking as input the init and end times
"""

import sys
import os

import argparse
import wave


def extract_segment(wav_in, init_time, end_time, output_file):
    """
    Writes to a new wavefile a fragment from another one, as determined by
    and initial and an end time.
    input:
        * wav_in (Wave): wave object with the initial wavefile loaded.
        * init_time (float): initial time of the segment.
        * end_time (float): end time of the segment.
        * output_file (str): name of the output file.
    """

    try:
        wav_out = wave.open(output_file, 'w')
    except IOError:
        print 'Error creating file {0}.'.format(output_file)
        sys.exit(1)

    input_params = wav_in.getparams()
    frame_rate = input_params[2]

    wav_out.setparams(input_params)

    read_pos = int(init_time * frame_rate)
    samples = int(end_time * frame_rate) - read_pos

    wav_in.setpos(read_pos)

    wav_out.writeframes(wav_in.readframes(samples))

    wav_out.close()


def get_args():
    """
    Reads the command line options
    """

    example = '{0} -i original.wav -b 1.2 -e 2.4 -o segment.wav'

    parser = argparse.ArgumentParser(description=example)

    parser.add_argument('--ARGS-wav', '-i', help='ARGS wavefile',
                        required=True)

    parser.add_argument('--begin', '-b', help='Initial time, in seconds',
                        type=float, required=True)

    parser.add_argument('--end', '-e', help='Final time, in seconds',
                        type=float, required=True)

    parser.add_argument('--output-file', '-o', help='Output file',
                        required=True)

    return parser.parse_args()


def main():
    """
    Main function of the program
    """

    args = get_args()

    if not os.path.exists(args.ARGS_wav):
        print 'Error opening {0}'.format(args.ARGS_wav)
        sys.exit(1)

    try:
        wav_in = wave.open(args.ARGS_wav, 'r')
    except wave.Error, err:
        print 'Wrong format for ARGS wavefile {0}'.format(args.ARGS_wav)
        print err
        sys.exit(1)

    extract_segment(wav_in, args.begin, args.end, args.output_file)

    wav_in.close()


if __name__ == '__main__':
    main()
