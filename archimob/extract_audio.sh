#!/bin/bash

# This script extracts the audio from a set of input videos, and converts it
# to one channel linear pcm, 16 bits, 8KHz.
#
# Input:
#    1.- input_dir: folder to take the input videos. Note that only the files
#      with .mp4 extension will be processed. Change $INPUT_EXTENSION below to
#      consider other extensions (note the actual supported ones depends on
#      ffmpeg)
#    2.- output_folder: folder to write the wavefiles. The name will be the
#      one of the original videos, with .wav extension.
#

################
# Configuration:
################
INPUT_EXTENSION='mp4'
SAMPLE_RATE=8000
CODEC=pcm_s16le  # Check ffmpeg -codecs for other possibilities

echo $0 $@
if [[ $# -ne 2 ]]; then
    echo "$0 input_files_dir output_folder"
    exit 1
fi

###################
# Input parameters:
###################
input_dir=$1
output_dir=$2

###############
# Intermediate:
###############
log_dir="$output_dir/wav_log"

# Check whether ffmpeg is installed:
type ffmpeg &> /dev/null
[[ $? -ne 0 ]] && echo 'Error: ffmpeg is not installed' && exit 1

# Check whether the input folder actually exists:
[[ ! -d $input_dir ]] && echo "Error: missing input folder $input_dir" && exit 1

# Create output folders:
mkdir -p $output_dir $log_dir

# Process the videos:
for f in `ls $input_dir/*.$INPUT_EXTENSION`; do

    echo "Processing $f..."
    input_filename=`basename $f`
    base_output="${input_filename%.*}"
    output_file=$output_dir/$base_output.wav
    log_file="$log_dir/$base_output.log"
    echo $output_file

    ffmpeg -i $f -vn -ac 1 -acodec $CODEC -ar $SAMPLE_RATE -y $output_file \
	&> $log_file

    [[ $? -ne 0 ]] && echo "Error processing $f. See $log_file" \ && exit 1

done

echo "Done: $0"
