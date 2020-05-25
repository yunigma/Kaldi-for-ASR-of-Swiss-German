#!/usr/bin/python
# -*- coding: utf-8 -*-

"""
Script that takes as input a list of Exmaralda or XML transcription files and
the corresponding wavefiles, and processes them to make them more suitable for
acoustic model training.
input:

        python2 ${scripts_dir}/process_exmaralda_xml.py \
            -i ${archimob_files}/archimob_r2/xml_corrected/*.xml \
            -f xml \
            -o ${csv_files}/archimob_r2/archimob_r2.csv
"""

import sys
import os
import re

import xml.etree.ElementTree as ET

import argparse
import wave

from archimob_chunk import ArchiMobChunkEXB, ArchiMobChunkXML
from extract_wav_segment import extract_segment


def get_args():
    """
    Reads the command line options
    """

    my_desc = 'Scripts that prepares a set of Exmaralda files, and their ' \
              'waves, for acoustic model training'

    parser = argparse.ArgumentParser(description=my_desc)

    parser.add_argument('--input-annotation', '-i', help='Input XML/ EXB files',
                        nargs='+', required=True)

    parser.add_argument('--input-format', '-f', help='XML or EXB',
                        const='exb', nargs='?', choices=['exb', 'xml'],
                        type=str, required=True)

    parser.add_argument('--wav-dir', '-w', help='Folder with the wavefiles ' \
                        'corresponding to the input Exmaralda files. If not ' \
                        'given, only the transcriptions are processed',
                        default='')

    parser.add_argument('--output-file', '-o', help='Name of the output csv ' \
                        'file', required=True)

    parser.add_argument('--output-wav-dir', '-O', help='Output folder for the' \
                        ' chunked wavefiles. If not given, the wavefiles are' \
                        'just ignored', default='')

    args = parser.parse_args()

    if bool(args.wav_dir) != bool(args.output_wav_dir):
        sys.stderr.write('Error: the parameters -w and -O come together. ' \
                         'Either both of them are provided, or both of them ' \
                         'are ignored\n')
        sys.exit(1)

    return args


def get_timepoints(root):
    """
    Parses the header of the XML / EXB file to get the mapping among timepoint
    identifiers and the time they refer to (for example: TLI_0 => 0.00).
    input:
        * root (ElementTree): root of the xml tree.
    returns:
        * a dictionary mapping the timepoint identifiers in the annotations and
          the actual time they refer to.
    """

    output_dict = {}

    for time_p in root.iter('tli'):
        output_dict[time_p.get('id')] = float(time_p.get('time'))

    return output_dict


def chunk_transcriptions(root, chunk_basename,
                         input_format, namespace=None,
                         time_dict=None):
    """
    Extracts from the XML / EXB file the events from each tier, and creates
    chunks out of them.
    input:
        * root (ElementTree): root of the xml file.
        * time_dict (dict): dictionary with the timepoints.
        * chunk_basename (str): beginning of the chunk names
    returns:
        * a tuple with the list of chunks and the dictionary with the chunks
          that begin in each timepoint (used for overlapping)
    """

    verbose = False

    chunk_list = []
    overlap_dict = {}

    chunk_index = 1

    if input_format == 'exb':
        for tier in root.iter('tier'):

            current_spk = '{0}_{1}'.format(chunk_basename,
                                           tier.attrib.get('speaker'))

            if verbose:
                print 'New tier:'
                print '\tid = {0}'.format(tier.attrib.get('id'))
                print '\tspeaker = {0}'.format(current_spk)

            for event in tier.iter('event'):

                # Extract the info from the exb file:
                event_start = event.attrib.get('start')
                event_end = event.attrib.get('end')
                if event.text is None:
                    text = ''
                else:
                    text = event.text.strip()

                # Create the chunk object:
                chunk_key = ArchiMobChunkEXB.create_chunk_key(chunk_basename,
                                                              current_spk,
                                                              chunk_index)

                # Update the chunk index
                chunk_index += 1

                if time_dict[event_end] <= time_dict[event_start]:
                    sys.stderr.write('WARN: not positive duration for chunk {0} ' \
                                     '({1}, {2} - {3}. {4}). There is probably an' \
                                     ' error in the Exmaralda ' \
                                     'file\n'.format(chunk_key,
                                                     time_dict[event_start],
                                                     time_dict[event_end],
                                                     event_start, event_end))
                    continue

                new_chunk = ArchiMobChunkEXB(chunk_key, text,
                                             time_dict[event_start],
                                             time_dict[event_end],
                                             event_start,
                                             current_spk)

                if verbose:
                    print '\tNew event: {0}'.format(new_chunk)

                # Add the chunk to the output list:
                chunk_list.append(new_chunk)

                # Update the overlap dictionary:
                if event_start in overlap_dict:
                    overlap_dict[event_start].append(chunk_key)
                else:
                    overlap_dict[event_start] = [chunk_key]

    elif input_format == 'xml':
        for u in root.iter('{' + namespace + '}u'):

            if u.attrib.get('who') == "interviewer":
                current_spk = '{0}_{1}'.format(chunk_basename, "I")
            elif u.attrib.get('who') == "otherPerson":
                current_spk = '{0}_{1}'.format(chunk_basename, "A")
            else:
                spk_name = u.attrib.get('who')[10:11]
                current_spk = '{0}_{1}'.format(chunk_basename, spk_name)

            if verbose:
                print 'New tier:'
                print '\tid = {0}'.format(u.attrib.get('xml:id'))
                print '\tspeaker = {0}'.format(current_spk)

            event_start = u.attrib.get('start')
            event_start = event_start[15:]

            norm_utterance = []
            swiss_utterance = []

            for word in u.iter():
                if word.tag == '{' + namespace + '}w':
                    if word.text is not None and word.attrib.get('normalised').encode('utf-8') != u'==':
                        norm_utterance.append(word.attrib.get('normalised').encode('utf-8'))
                        swiss_utterance.append(word.text.encode('utf-8'))
                elif word.tag == '{' + namespace + '}pause':
                    if len(norm_utterance) > 0 or len(swiss_utterance) > 0:
                        norm_utterance.append("/")
                        swiss_utterance.append("/")

            # Create the chunk object:
            chunk_key = ArchiMobChunkXML.create_chunk_key(chunk_basename,
                                                          current_spk,
                                                          chunk_index)

            # Update the chunk index
            chunk_index += 1

            new_chunk = ArchiMobChunkXML(chunk_key,
                                         ' '.join(swiss_utterance).decode('utf-8'),
                                         ' '.join(norm_utterance).decode('utf-8'),
                                         current_spk,
                                         event_start)

            # if verbose:
            # print '\tNew event: {0}'.format(new_chunk)

            # Add the chunk to the output list:
            chunk_list.append(new_chunk)

            # Update the overlap dictionary:
            if event_start in overlap_dict:
                overlap_dict[event_start].append(chunk_key)
            else:
                overlap_dict[event_start] = [chunk_key]

    return (chunk_list, overlap_dict)


def write_chunk_transcriptions(chunk_list, overlap_dict,
                               input_format, output_f):
    """
    Writes the transcriptions of all the chunks to the output file.
    input:
        * chunk_list (list): list of chunks.
        * overlap_dict (dict): dictionary with the mapping from initial
          timepoints to chunks. When a timepoint corresponds to more than one
          chunk, overlapping is assumed.
        * output_f (file object): file object to write the transcriptions to.
    """

    for chunk in chunk_list:

        # Write the key and the transcription:
        output_f.write('{0},"{1}",'.format(chunk.key,
                                           chunk.trans.encode('utf8')))

        # Write the normalized transcription:
        if input_format == 'xml':
            output_f.write('"{0}",'.format(chunk.norm.encode('utf8')))

        # Write the speaker id:
        output_f.write('{0},'.format(chunk.spk_id))

        if input_format == 'xml':
            # Write the audio id:
            output_f.write('{0},'.format(chunk.audio_id))

            # Anonym - Non-anonym:
            if re.search("\*\*\*", chunk.trans) is not None:
                output_f.write('{0},'.format(1))
            else:
                output_f.write('{0},'.format(0))

            # Overlap - Non-overlap:
            if (len(overlap_dict[chunk.audio_id]) > 1 or
                '[speech_in_speech]' in chunk.trans):
                overlap = 1
            else:
                overlap = 0
            output_f.write('{0},'.format(overlap))

            # Missing audio file: is created as a column filled with nulls
            output_f.write('{0},'.format(0))

        # Speech - Non-speech:
        if (len(chunk.trans) == 0 or
            '[no_relevant_speech]' in chunk.trans or
            '[no-relevant-speech]' in chunk.trans or
            chunk.trans == '[music]' or
            '[noise]' in chunk.trans or
            '[speech-in-noise]' in chunk.trans):
            no_relevant_speech = 1
        else:
            no_relevant_speech = 0

        if input_format == 'exb':
            # Duration:
            duration = chunk.end - chunk.beg

            output_f.write('{0:.2f},'.format(duration))

            if (len(overlap_dict[chunk.init_timepoint]) > 1 or
                '[speech_in_speech]' in chunk.trans or
                '[speech-in-speech]' in chunk.trans or
                chunk.trans == '[speech-in-speech]'):
                overlap = 1
            else:
                overlap = 0

            output_f.write('{0},'.format(overlap))

        output_f.write('{0}\n'.format(no_relevant_speech))

        # output_f.write('\n')


def extract_wave_chunks(chunk_list, wave_in, output_dir):
    """
    Extracts the chunks from the main recording based on the timepoints of
    the chunks list
    input:
        * chunk_list (list): list with the chunks of the transcriptions
        * wave_in (Wave): wave object, with the complete recordings
          corresponding to the transcriptions.
        * output_dir (str): folder to write the chunked segments to.
    """

    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    for chunk in chunk_list:

        output_name = '{0}.wav'.format(os.path.join(output_dir, chunk.key))

        extract_segment(wave_in, chunk.beg, chunk.end,
                        output_name)


def main():
    """
    Main function of the program
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

    if args.input_format == 'exb':
        # Write the header:
        output_f.write('utt_id,transcription,speaker_id,duration,' \
                       'speech_in_speech,no_relevant_speech\n')
        # output_f.write('utt_id,transcription,normalized,speaker_id,audio_id,' \
        #                'anonymity,speech_in_speech,missing_audio,' \
        #                'no_relevant_speech\n')

        # Create the output folder:
        if args.output_wav_dir and not os.path.exists(args.output_wav_dir):
            os.makedirs(args.output_wav_dir)

    elif args.input_format == 'xml':
        # Write the header:
        output_f.write('utt_id,transcription,normalized,speaker_id,audio_id,' \
                       'anonymity,speech_in_speech,missing_audio,' \
                       'no_relevant_speech\n')

    # Process all the XML / EXB files:
    for input_file in args.input_annotation:

        # print 'Processing {0}'.format(input_file)

        if not os.path.exists(input_file):
            sys.stderr.write('The input file {0} does ' \
                             'not exist\n'.format(input_file))
            sys.exit(1)

        basename = os.path.splitext(os.path.split(input_file)[1])[0]

        # Read the xml tree:
        xml_tree = ET.parse(input_file)
        root = xml_tree.getroot()

        if args.input_format == 'exb':

            # Read the timepoints:
            time_dict = get_timepoints(root)

            (chunk_list, overlap_dict) = chunk_transcriptions(root, basename,
                                                              args.input_format,
                                                              time_dict=time_dict)

            write_chunk_transcriptions(chunk_list, overlap_dict,
                                       args.input_format, output_f)

            if args.wav_dir:
                # Finally, extract the waveforms corresponding to the chunks:
                input_wav = os.path.join(args.wav_dir,
                                         '{0}.wav'.format(basename))

                if not os.path.exists(input_wav):
                    sys.stderr.write('The wavefile {0}, corresponding to {1}, ' \
                                     'does not exist\n'.format(input_wav,
                                                               input_file))
                    sys.exit(1)


                # Create the wave object:
                try:
                    wave_in = wave.open(input_wav, 'r')
                except wave.Error as err:
                    sys.stderr.write('Wrong format for input wavefile {0} ' \
                                     '({1})\n'.format(input_wav, err))
                    sys.exit(1)

                extract_wave_chunks(chunk_list, wave_in, args.output_wav_dir)

                wave_in.close()

        elif args.input_format == 'xml':
            namespace = root.tag.split('}')[0].strip('{')
            print namespace
            (chunk_list, overlap_dict) = chunk_transcriptions(root, basename,
                                                              args.input_format,
                                                              namespace)
            write_chunk_transcriptions(chunk_list, overlap_dict,
                                       args.input_format, output_f)

    output_f.close()


if __name__ == '__main__':
    main()
