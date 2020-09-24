#!/usr/bin/env bash

# '''
# The program takes the folder with test wav files (without transcription)
# and transcribe speech to text with the given ASR model
#
# transcribe_audio.sh --model_dir "models/model" \
#                     --audio_dir "data/wavs" \
#                     --test-affix "test1" \
#                     --lm "lms/language_model.arpa" \
#                     --lmtype "lm1"
# '''


stage=0
nj=4
audio_dir="/mnt/SDATS/data/wav"
# audio_dir="/mnt/SWISSTEXT2020/SwissText2020/test_data/clips"
test_affix=sdats1
audio_extension="wav"

model_dir="/mnt/iuliia/models/archimob_r2/models/models/ivector"
lm="/mnt/INTERSPEECH2020/lms/dieth_90000_open_mkn3.arpa"
lmtype=dieth90k

compiled_graphs=""

. ./cmd.sh
. ./path.sh
. utils/parse_options.sh

START_TIME=$(date +%s) # record time of operations

data=${model_dir}/data
exp=${model_dir}/exp
ali_dir=$exp/${gmm}_ali_train_set_sp

nnet3_affix=_online_cmn   # affix for exp dirs, e.g. it was _cleaned in tedlium.
affix=1i   #affix for TDNN+LSTM directory e.g. "1a" or "1b", in case we change the configuration.
dir=$exp/chain${nnet3_affix}/tdnn${affix}_sp
tree_dir=$exp/chain${nnet3_affix}/tree_a_sp

wav_lst="$data/wav.lst"
lang_dir="$data/${test_affix}_set_hires"

# training chunk-options
chunk_width=140,100,160

echo "$0 $@"  # Print the command line for logging



if [ $stage -le 1 ]; then
    # Create the secondary files needed by Kaldi (wav.scp, utt2spk, spk2utt):
    echo ""
    echo "#######################################################"
    echo "### BEGIN: CREATE SECONDARY FILES FOR KALDI ###"
    echo "#######################################################"
    echo ""
    archimob/process_raw_audio.py \
      -a $audio_dir \
      -ex $audio_extension \
      -o $lang_dir

    [[ $? -ne 0 ]] && echo -e "\n\tERROR: calling process_raw_audio.py\n" && exit 1

    # Sort the utterance to speaker and the wav scp files the way Kaldi likes:
    # sort $lang_dir/wav.scp -o $lang_dir/wav.scp
    # sort $lang_dir/utt2spk -o $lang_dir/utt2spk

    CUR_TIME=$(date +%s)
    echo ""
    echo "TIME ELAPSED: $(($CUR_TIME - $START_TIME)) seconds"
    echo ""

fi


if [ $stage -le 2 ]; then
    echo "$0: creating high-resolution MFCC features"

    steps/make_mfcc.sh --nj $nj --mfcc-config conf/mfcc_hires.conf \
    --cmd "$train_cmd" $data/${test_affix}_set_hires \
    $data/${test_affix}_set_hires/feats/log \
    $data/${test_affix}_set_hires/feats
    [[ $? -ne 0 ]] && echo -e "\n\tERROR: during feature extraction\n" && exit 1

    steps/compute_cmvn_stats.sh $data/${test_affix}_set_hires \
    $data/${test_affix}_set_hires/feats/log \
    $data/${test_affix}_set_hires/feats

    utils/fix_data_dir.sh $data/${test_affix}_set_hires
    [[ $? -ne 0 ]] && echo -e "\n\tERROR: during cmvn computation\n" && exit 1

fi

if [ $stage -le 3 ]; then
    # Extract iVectors for the test data, but in this case we don't need the speed
    # perturbation (sp).
    nspk=$(wc -l <$data/${test_affix}_set_hires/spk2utt)
    # nspk=133
    steps/online/nnet2/extract_ivectors_online.sh --cmd "$train_cmd" --nj "${nspk}" \
    $data/${test_affix}_set_hires $exp/nnet3${nnet3_affix}/extractor \
    $exp/nnet3${nnet3_affix}/ivectors_${test_affix}_set_hires
fi

if [ $stage -le 4 ]; then
  frames_per_chunk=$(echo $chunk_width | cut -d, -f1)
  rm $dir/.error 2>/dev/null || true

  # Test data
    nspk=$(wc -l <$data/${test_affix}_set_hires/spk2utt)
    # for lmtype in tgpr bd_tgpr; do
    for lmtype in $lmtype; do
      uzh/decode_nnet3_wer_cer.sh \
        --acwt 1.0 --post-decode-acwt 10.0 \
        --extra-left-context 0 --extra-right-context 0 \
        --extra-left-context-initial 0 \
        --extra-right-context-final 0 \
        --only-audio "yes" \
        --stop_stage 4 \
        --frames-per-chunk $frames_per_chunk \
        --nj $nspk --cmd "$decode_cmd"  --num-threads 4 \
        --online-ivector-dir $exp/nnet3${nnet3_affix}/ivectors_${test_affix}_set_hires \
        $tree_dir/graph_${lmtype} \
        $data/${test_affix}_set_hires \
        ${dir}/decode_${lmtype}_${test_affix} || exit 1
    done

fi
