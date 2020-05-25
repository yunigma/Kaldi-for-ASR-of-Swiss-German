#!/bin/bash

set -u

#
# This script is a wrapper to train nnet2 discriminative models, using as
# input basic nnet2 ones.
#

################
# Configuration:
################
# Note that these variables can be changed from the command line
nj=4  # Number of parallel jobs
cmd=run.pl  # Command to run parallel tasks
use_gpu=true

#####################################
# Flags to choose with stages to run:
#####################################
do_align=1
do_make_denlats=1
do_get_egs=1
do_nnet2_discriminative=1

. utils/parse_options.sh || exit 1;

echo $0 $@
if [[ $# -ne 4 ]]; then
    echo "Wrong call. Shoud be: $0 data_dir lang_dir nnet2_models_dir output_dir"
    exit 1
fi

###################
# Input parameters:
###################
data=$1
lang_dir=$2
nnet2_dir=$3
output_dir=$4

###############
# Intermediate:
###############
ali_dir="$output_dir/ali"
denlats_dir="$output_dir/denlats"
egs_dir="$output_dir/egs"

#########
# Output:
#########
models="$output_dir/nnet_disc"

##
# Get the alignments:
if [[ $do_align -ne 0 ]]; then
    steps/nnet2/align.sh --nj $nj --cmd $cmd $data $lang_dir $nnet2_dir \
			 $ali_dir

    [[ $? -ne 0 ]] && echo 'Error during nnet2 alignment' && exit 1
fi

##
# Create the denominator lattices:
if [[ $do_make_denlats -ne 0 ]]; then
    steps/nnet2/make_denlats.sh --nj $nj --cmd $cmd $data $lang_dir $nnet2_dir \
				$denlats_dir

    [[ $? -ne 0 ]] && echo 'Error making denominator lattices' && exit 1
fi


##
# Create nnet2 training samples:
if [[ $do_get_egs -ne 0 ]]; then
    steps/nnet2/get_egs_discriminative2.sh --cmd $cmd $data $lang_dir $ali_dir \
					   $denlats_dir $nnet2_dir/final.mdl \
					   $egs_dir

    [[ $? -ne 0 ]] && echo 'Error creating discriminative egs' && exit 1
fi

##
# Train the new neural network:
if [[ $do_nnet2_discriminative -ne 0 ]]; then

    if [[ $use_gpu == 'true' ]]; then
	num_threads=1
    else
	num_threads=`nproc`
    fi

    uzh/train_discriminative2.sh --cmd $cmd --num-threads $num_threads \
				 $egs_dir $models
fi

echo "Done: $0"
