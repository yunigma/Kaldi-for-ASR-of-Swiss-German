#!/bin/bash

set -u

#
# Adaptation of local/nnet2/run_5d.sh, the main nnet2 recipe at the moment
# (the most advanced still keeping compatibility with the Spitch Web
# Development Portal)
#
# Summary: pnorm neural net training.
#

################
# Configuration:
################
# Note that the values can be changes from the command line (see
# parse_options.sh)
use_gpu=no
num_jobs_nnet=5
mix_up=8000
initial_learning_rate=0.02
final_learning_rate=0.004
num_hidden_layers=4
pnorm_input_dim=2000
pnorm_output_dim=400

. utils/parse_options.sh

echo $0 $@
if [[ $# -ne 4 ]]; then
    echo "Wrong call. Should be: $0 data_dir lang_dir align_dir output_dir"
    exit 1
fi

###################
# Input parameters:
###################
data=$1
lang_dir=$2
ali_dir=$3
output_dir=$4

if $use_gpu; then
  if ! cuda-compiled; then
    cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
  fi
  parallel_opts=
  num_threads=1
  minibatch_size=512
else
  # Use 4 nnet jobs just like run_4d_gpu.sh so the results should be
  # almost the same, but this may be a little bit slow.
  num_threads=16
  parallel_opts="--num-threads $num_threads"
  minibatch_size=128
fi

. ./cmd.sh
. ./path.sh


steps/nnet2/train_pnorm_fast.sh \
    --samples-per-iter 400000 \
    --parallel-opts "$parallel_opts" \
    --num-threads "$num_threads" \
    --minibatch-size "$minibatch_size" \
    --num-jobs-nnet $num_jobs_nnet  --mix-up $mix_up \
    --initial-learning-rate $initial_learning_rate \
    --final-learning-rate $final_learning_rate \
    --num-hidden-layers $num_hidden_layers \
    --pnorm-input-dim $pnorm_input_dim --pnorm-output-dim $pnorm_output_dim \
    --cmd "$decode_cmd" \
    $data $lang_dir $ali_dir $output_dir || exit 1

wait;

