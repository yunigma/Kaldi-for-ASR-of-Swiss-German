#!/bin/bash

set -u

## Authors: Iuliia Nigmatulina & Tannon Kew

#
# This is an adaptation of the Kaldi (http://kaldi-asr.org/) recipe
# egs/wsj/s5 (commit 8cc5c8b32a49f8d963702c6be681dcf5a55eeb2e) to do acoustic
# model training on the ArchiMob Spoken Swiss German corpus.
#
#
# Input:
#     * input_csv: csv file with all the information from the Archimob corpus
#                  (typically generated with process_exmaralda_xml.py)
#     * input_wav: folder with the wavefiles from the utterances appearing in
#                  input_csv. Note that these wavefiles are actually small
#                  audio segments from the original Archimob videos (also
#                  generated with process_exmaralda_xml.py)
#     * output_dir: folder to write the output files to
#     * translation_type: orig (Dieth transcriptions) or
#     norm (Normalised annotations)
#     * lexicon: pronunciation lexicon for AM training/decoding
#

################
# Configuration:
################
# All these options can be changed from the command line. For example:
# --num-jobs 16 --use-gpu true ...
num_jobs=32  # Number of jobs for parallel processing
use_gpu=false  # either true or false
num_senones=4000  # Number of senones for the triphone stage
num_gaussians=40000  # Number of Gaussians for the triphone stage

#####################################
# Flags to choose with stages to run:
#####################################
## This is helpful when running an experiment in several steps, to avoid
# recomputing again all the stages from the very beginning.
do_archimob_preparation=0
do_data_preparation=0

do_feature_extraction=0

do_train_monophone=0
do_train_triphone=0
do_train_triphone_lda=0
do_train_mmi=0
do_train_mpe=0
do_train_sat=0
do_train_sgmm=0
do_train_sgmm_mmi=0
do_nnet2=0
do_nnet2_discriminative=1
do_train_tdnn=0

# This call selects the tool used for parallel computing: ($train_cmd)
. cmd.sh

# This includes in the path the kaldi binaries:
. path.sh

# This parses any input option, if supplied.
. utils/parse_options.sh

echo $0 $@
if [[ $# -lt 5 ]]; then
    echo "Wrong call. Should be: $0 input_csv input_wav output_dir translation_type lexicon"
    exit 1
fi

##################
# Input arguments:
##################
input_csv=$1
input_wav_dir=$2
output_dir=$3
trans=$4
lexicon=$5

# provide directory containing dev data
dev_data=${6:-"/mnt/SWISSTEXT2020/model/eval/dev/tri_mmi/lang"}  # dev data dir for tdnn training only


###############
# Intermediate:
###############
tmp_dir="$output_dir/tmp"
initial_data="$output_dir/initial_data"
lang_tmp="$tmp_dir/lang_tmp"
data="$output_dir/data"
feats_dir="$output_dir/feats"
feats_log_dir="$output_dir/feats/log"
models=$output_dir/models
phone_table="$data/lang/phones.txt"

# Get the general configuration variables (SPOKEN_NOISE_WORD, SIL_WORD, NOISE,
# and GRAPHEMIC_CLUSTERS)
. uzh/configuration.sh

START_TIME=$(date +%s) # record time of operations

for f in $input_csv $input_wav_dir $lexicon; do
    [[ ! -e $f ]] && echo "Error: missing $f" && exit 1
done

# if [[ $use_gpu != 'true' && $use_gpu != 'false' ]]; then
#     echo "Error: use_gpu must be true or false. Got $use_gpu"
#     exit 1
# fi

mkdir -p $output_dir

if [[ $do_archimob_preparation -ne 0 ]]; then

    archimob/prep_archimob_training_files.sh \
        -s "$SPOKEN_NOISE_WORD" \
        -n "$SIL_WORD" \
        -m "$NOISE_WORD" \
        -t $trans \
        -l $lexicon \
        $input_csv \
        $input_wav_dir \
        $initial_data

    [[ $? -ne 0 ]] && echo 'Error preparing Archimob training files' && exit 1

fi

# From this moment on, all the data is organized the way Kaldi likes

if [[ $do_data_preparation -ne 0 ]]; then

    echo ""
    echo "#####################################"
    echo "### BEGIN: KALDI DATA PREPARATION ###"
    echo "#####################################"
    echo ""

    utils/prepare_lang.sh \
      $initial_data/ling \
      $SPOKEN_NOISE_WORD \
      $lang_tmp \
      $data/lang

    [[ $? -ne 0 ]] && echo -e "\n\tERROR: calling prepare_lang.sh\n" && exit 1

    CUR_TIME=$(date +%s)
    echo ""
    echo "TIME ELAPSED: $(($CUR_TIME - $START_TIME)) seconds"
    echo ""

fi

if [[ $do_feature_extraction -ne 0 ]]; then

    echo ""
    echo "#################################"
    echo "### BEGIN: FEATURE EXTRACTION ###"
    echo "#################################"
    echo ""

    # This extracts MFCC features. See conf/mfcc.conf for the configuration
    # Note: the $train_cmd variable is defined in cmd.sh
    steps/make_mfcc.sh --cmd "$train_cmd" --nj $num_jobs $initial_data/data \
               $feats_log_dir $feats_dir

    [[ $? -ne 0 ]] && echo 'Error during feature extraction' && exit 1

    # This extracts the Cepstral Mean Normalization features:
    steps/compute_cmvn_stats.sh $initial_data/data $feats_log_dir $feats_dir

    [[ $? -ne 0 ]] && echo 'Error during cmvn computation' && exit 1
    CUR_TIME=$(date +%s)
    echo ""
    echo "TIME ELAPSED: $(($CUR_TIME - $START_TIME)) seconds"
    echo ""

fi

if [[ $do_train_monophone -ne 0 ]]; then

    echo ""
    echo "#################################"
    echo "### BEGIN: MONOPHONE TRAINING ###"
    echo "#################################"
    echo ""

    steps/train_mono.sh --boost-silence 1.25 --nj $num_jobs --cmd "$train_cmd" \
            $initial_data/data $data/lang $models/mono

    [[ $? -ne 0 ]] && echo 'Error in monophone training' && exit 1

    # Copy the phone table to the models folder. This will help later when
    # generating the lingware (see compile_lingware.sh)
    cp $phone_table $models/mono

    CUR_TIME=$(date +%s)
    echo ""
    echo "TIME ELAPSED: $(($CUR_TIME - $START_TIME)) seconds"
    echo ""

fi

if [[ $do_train_triphone -ne 0 ]]; then

    echo ""
    echo "##################################"
    echo "### BEGIN: MONOPHONE ALIGNMENT ###"
    echo "##################################"
    echo ""

    steps/align_si.sh --boost-silence 1.25 --nj $num_jobs --cmd "$train_cmd" \
      $initial_data/data $data/lang $models/mono $models/mono/ali

    [[ $? -ne 0 ]] && echo 'Error in monophone aligment' && exit 1

    CUR_TIME=$(date +%s)
    echo ""
    echo "TIME ELAPSED: $(($CUR_TIME - $START_TIME)) seconds"
    echo ""

    echo ""
    echo "################################"
    echo "### BEGIN: TRIPHONE TRAINING ###"
    echo "################################"
    echo ""

    steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" $num_senones \
              $num_gaussians $initial_data/data $data/lang \
              $models/mono/ali $models/tri

    [[ $? -ne 0 ]] && echo 'Error in triphone training' && exit 1

    # Copy the phone table to the models folder. This will help later when
    # generating the lingware (see compile_lingware.sh)
    cp $phone_table $models/tri

    CUR_TIME=$(date +%s)
    echo ""
    echo "TIME ELAPSED: $(($CUR_TIME - $START_TIME)) seconds"
    echo ""

fi

if [[ $do_train_triphone_lda -ne 0 ]]; then

    echo ""
    echo "#################################"
    echo "### BEGIN: TRIPHONE ALIGNMENT ###"
    echo "#################################"
    echo ""

    steps/align_si.sh --nj $num_jobs --cmd "$train_cmd" \
      $initial_data/data $data/lang $models/tri $models/tri/ali

    [[ $? -ne 0 ]] && echo 'Error in triphone alignment' && exit 1

    CUR_TIME=$(date +%s)
    echo ""
    echo "TIME ELAPSED: $(($CUR_TIME - $START_TIME)) seconds"
    echo ""

    echo ""
    echo "####################################"
    echo "### BEGIN: TRIPHONE LDA TRAINING ###"
    echo "####################################"
    echo ""

    steps/train_lda_mllt.sh --cmd "$train_cmd" \
      --splice-opts "--left-context=3 --right-context=3" \
      $num_senones \
      $num_gaussians \
      $initial_data/data \
      $data/lang \
      $models/tri/ali \
      $models/tri_lda

    [[ $? -ne 0 ]] && echo 'Error in triphone-lda training' && exit 1

    # Copy the phone table to the models folder. This will help later when
    # generating the lingware (see compile_lingware.sh)
    cp $phone_table $models/tri_lda

    CUR_TIME=$(date +%s)
    echo ""
    echo "TIME ELAPSED: $(($CUR_TIME - $START_TIME)) seconds"
    echo ""

fi


if [[ $do_train_mmi -ne 0 ]]; then

    echo ""
    echo "#####################################"
    echo "### BEGIN: TRIPHONE LDA ALIGNMENT ###"
    echo "#####################################"
    echo ""

    steps/align_si.sh --nj $num_jobs --cmd "$train_cmd" \
                  $initial_data/data $data/lang $models/tri_lda \
                  $models/tri_lda/ali

    [[ $? -ne 0 ]] && echo 'Error in triphone-lda alignment' && exit 1

    echo ""
    echo "########################################"
    echo "### BEGIN: MAKE DENOMINATOR LATTICES ###"
    echo "########################################"
    echo ""

    # Create denominator lattices for discriminative MMI/MPE training.
    steps/make_denlats.sh --nj $num_jobs --cmd "$train_cmd" \
                  $initial_data/data $data/lang $models/tri_lda \
                  $models/tri_lda/denlats

    [[ $? -ne 0 ]] && echo 'Error creating denominator lattices' && exit 1

    echo ""
    echo "####################################"
    echo "### BEGIN: TRIPHONE MMI TRAINING ###"
    echo "####################################"
    echo ""

    steps/train_mmi.sh --cmd "$train_cmd" --boost 0.1 \
               $initial_data/data $data/lang $models/tri_lda/ali \
               $models/tri_lda/denlats \
               $models/tri_mmi

    [[ $? -ne 0 ]] && echo 'Error in triphone-mmi training' && exit 1

    # Copy the phone table to the models folder. This will help later when
    # generating the lingware (see compile_lingware.sh)
    cp $phone_table $models/tri_mmi

    CUR_TIME=$(date +%s)
    echo ""
    echo "TIME ELAPSED: $(($CUR_TIME - $START_TIME)) seconds"
    echo ""

fi

if [[ $do_train_mpe -ne 0 ]]; then

    echo ""
    echo "###########################"
    echo "### BEGIN: MPE TRAINING ###"
    echo "###########################"
    echo ""

    # steps/align_si.sh --nj $num_jobs --cmd "$train_cmd" \
    #               $initial_data/data $data/lang $models/tri_lda \
    #               $models/tri_lda/ali

    # [[ $? -ne 0 ]] && echo 'Error in triphone-lda alignment' && exit 1

    # # Create denominator lattices for discriminative MMI/MPE training.
    # steps/make_denlats.sh --nj $num_jobs --cmd "$train_cmd" \
    #               $initial_data/data $data/lang $models/tri_lda \
    #               $models/tri_lda/denlats

    # [[ $? -ne 0 ]] && echo 'Error creating denominator lattices' && exit 1

    steps/train_mpe.sh --cmd "$train_cmd" --boost 0.1 \
               $initial_data/data \
               $data/lang \
               $models/tri_lda/ali \
               $models/tri_lda/denlats \
               $models/tri_mpe

    [[ $? -ne 0 ]] && echo 'Error in triphone-mpe training' && exit 1

    # Copy the phone table to the models folder. This will help later when
    # generating the lingware (see compile_lingware.sh)
    cp $phone_table $models/tri_mpe

    CUR_TIME=$(date +%s)
    echo ""
    echo "TIME ELAPSED: $(($CUR_TIME - $START_TIME)) seconds"
    echo ""

fi

if [[ $do_train_sat -ne 0 ]]; then

    echo ""
    echo "###########################"
    echo "### BEGIN: SAT TRAINING ###"
    echo "###########################"
    echo ""

    steps/align_fmllr.sh --nj $num_jobs --cmd "$train_cmd" \
                    $initial_data/data \
                    $data/lang \
                    $models/tri_mmi \
                    $models/tri_mmi/fmllr_ali

    [[ $? -ne 0 ]] && echo 'Error in triphone alignment' && exit 1

    steps/train_sat.sh --cmd "$train_cmd" \
      5000 \
      80000 \
      $initial_data/data \
      $data/lang \
      $models/tri_mmi/fmllr_ali \
      $models/tri_fmllr_sat

    [[ $? -ne 0 ]] && echo 'Error in triphone-sat training' && exit 1

    # Copy the phone table to the models folder. This will help later when
    # generating the lingware (see compile_lingware.sh)
    cp $phone_table $models/tri_fmllr_sat

    CUR_TIME=$(date +%s)
    echo ""
    echo "TIME ELAPSED: $(($CUR_TIME - $START_TIME)) seconds"
    echo ""

fi


if [[ $do_train_sgmm -ne 0 ]]; then
    # following the recipe rm/s5/local/run_sgmm2.sh

    echo ""
    echo "############################"
    echo "### BEGIN: SGMM TRAINING ###"
    echo "############################"
    echo ""

    steps/align_fmllr.sh --nj $num_jobs --cmd "$train_cmd" \
                    $initial_data/data \
                    $data/lang \
                    $models/tri_lda \
                    $models/tri_lda/fmllr_ali

    # Train full UBM model.
    steps/train_ubm.sh --silence-weight 0.5 --cmd "$train_cmd" 400 \
            $initial_data/data \
            $data/lang \
            $models/tri_lda/fmllr_ali \
            $models/tri_lda/full_ubm

    [[ $? -ne 0 ]] && echo 'Error in UBM training' && exit 1;

    steps/train_sgmm2.sh --cmd "$train_cmd" \
        5000 \
        8000 \
        $initial_data/data \
        $data/lang \
        $models/tri_lda/fmllr_ali \
        $models/tri_lda/full_ubm/final.ubm \
        $models/sgmm

    [[ $? -ne 0 ]] && echo 'Error in sgmm training' && exit 1

    # Copy the phone table to the models folder. This will help later when
    # generating the lingware (see compile_lingware.sh)
    cp $phone_table $models/sgmm

    CUR_TIME=$(date +%s)
    echo ""
    echo "TIME ELAPSED: $(($CUR_TIME - $START_TIME)) seconds"
    echo ""

fi


    # utils/mkgraph.sh $data/lang $models/sgmm $models/sgmm/graph || exit 1;

    # steps/decode_sgmm2.sh --config conf/decode.config --nj 20 --cmd "$decode_cmd" \
    #     --transform-dir $models/tri_lda/decode \
    #     $models/sgmm/graph \
    #     $data/test \
    #     $models/sgmm/decode || exit 1;

    # steps/decode_sgmm2.sh --use-fmllr true --config conf/decode.config --nj 20 --cmd "$decode_cmd" \
    #   --transform-dir $models/tri_lda/decode  \
    #   $models/sgmm/graph \
    #   $data/test \
    #   $models/sgmm/decode_fmllr || exit 1;


if [[ $do_train_sgmm_mmi -ne 0 ]]; then

    echo ""
    echo "################################"
    echo "### BEGIN: SGMM MMI TRAINING ###"
    echo "################################"
    echo ""

     # Now we'll align the SGMM system to prepare for discriminative training.
     # use --transform-dir $models/tri_lda only on the tip of SAT
    steps/align_sgmm2.sh --nj $num_jobs --cmd "$train_cmd" \
            --transform-dir $models/tri_lda/fmllr_ali \
            --use-graphs true --use-gselect true \
            $initial_data/data \
            $data/lang \
            $models/sgmm \
            $models/sgmm_ali || exit 1;

    # Create denominator lattices for discriminative MMI/MPE training.
    steps/make_denlats_sgmm2.sh --nj $num_jobs --sub-split 20 --cmd "$decode_cmd" \
            --transform-dir $models/tri_lda/fmllr_ali \
            $initial_data/data \
            $data/lang \
            $models/sgmm_ali \
            $models/sgmm_denlats

    steps/train_mmi_sgmm2.sh --cmd "$decode_cmd" \
        --transform-dir $models/tri_lda/fmllr_ali --boost 0.2 \
        $initial_data/data \
        $data/lang \
        $models/sgmm_ali \
        $models/sgmm_denlats \
        $models/sgmm_mmi

    CUR_TIME=$(date +%s)
    echo ""
    echo "TIME ELAPSED: $(($CUR_TIME - $START_TIME)) seconds"
    echo ""

fi

# for iter in 1 2 3 4; do
#     steps/decode_sgmm2_rescore.sh --cmd "$decode_cmd" --iter $iter \
#         --transform-dir $models/tri_lda/decode \
#         $data/lang \
#         $data/test \
#         $models/sgmm/decode \
#         $models/sgmm_mmi/decode_it$iter &
# done
# (
#  steps/train_mmi_sgmm2.sh --cmd "$decode_cmd" --transform-dir exp/tri3b --boost 0.2 --drop-frames true \
#    data/train data/lang exp/sgmm2_4a_ali exp/sgmm2_4a_denlats exp/sgmm2_4a_mmi_b0.2_x

#  for iter in 1 2 3 4; do
#   steps/decode_sgmm2_rescore.sh --cmd "$decode_cmd" --iter $iter \
#     --transform-dir exp/tri3b/decode data/lang data/test exp/sgmm2_4a/decode exp/sgmm2_4a_mmi_b0.2_x/decode_it$iter &
#  done
# )
# wait
# steps/decode_combine.sh data/test data/lang exp/tri1/decode exp/tri2a/decode exp/combine_1_2a/decode || exit 1;
# steps/decode_combine.sh data/test data/lang exp/sgmm2_4a/decode exp/tri3b_mmi/decode exp/combine_sgmm2_4a_3b/decode || exit 1;
# # combining the sgmm run and the best MMI+fMMI run.
# steps/decode_combine.sh data/test data/lang exp/sgmm2_4a/decode exp/tri3b_fmmi_c/decode_it5 exp/combine_sgmm2_4a_3b_fmmic5/decode || exit 1;

# steps/decode_combine.sh data/test data/lang exp/sgmm2_4a_mmi_b0.2/decode_it4 exp/tri3b_fmmi_c/decode_it5 exp/combine_sgmm2_4a_mmi_3b_fmmic5/decode || exit 1;


if [[ $do_nnet2 -ne 0 ]]; then

    echo ""
    echo "#############################"
    echo "### BEGIN: NNET2 TRAINING ###"
    echo "#############################"
    echo ""

    # Input alignments:
    # steps/align_si.sh --nj $num_jobs --cmd "$train_cmd" \
    #              $initial_data/data \
    #              $data/lang \
    #              $models/tri_mmi \
    #              $models/tri_mmi/ali

    # [[ $? -ne 0 ]] && echo 'Error in triphone-mmi alignment' && exit 1

    # Neural network training:
    uzh/run_5d.sh --use-gpu $use_gpu $initial_data/data $data/lang \
          $models/tri_mmi/ali $models/nnet2

    [[ $? -ne 0 ]] && echo 'Error in nnet2 training' && exit 1

    # Copy the phone table to the models folder. This will help later when
    # generating the lingware (see compile_lingware.sh)
    cp $phone_table $models/nnet2

    CUR_TIME=$(date +%s)
    echo ""
    echo "TIME ELAPSED: $(($CUR_TIME - $START_TIME)) seconds"
    echo ""

fi

if [[ $do_nnet2_discriminative -ne 0 ]]; then

    echo ""
    echo "############################################"
    echo "### BEGIN: NNET2 DISCRIMINATIVE TRAINING ###"
    echo "############################################"
    echo ""

    uzh/run_nnet2_discriminative.sh --nj $num_jobs --cmd "$train_cmd" \
                    --use-gpu $use_gpu \
                    $initial_data/data $data/lang \
                    $models/nnet2 $models/discriminative

    [[ $? -ne 0 ]] && echo 'Error in nnet2 discriminative training' && exit 1

    # Copy the phone table to the models folder. This will help later when
    # generating the lingware (see compile_lingware.sh)
    cp $phone_table $models/discriminative/nnet_disc

    CUR_TIME=$(date +%s)
    echo ""
    echo "TIME ELAPSED: $(($CUR_TIME - $START_TIME)) seconds"
    echo ""

fi

if [[ $do_train_tdnn -ne 0 ]]; then

    # # Input alignments:
    # steps/align_si.sh \
    #           --nj $num_jobs \
    #           --cmd "$train_cmd" \
    #           $initial_data/data \
    #           $data/lang \
    #           $models/tri_mmi \
    #           $models/tri_mmi/ali

    # [[ $? -ne 0 ]] && echo 'Error in triphone-mmi alignment' && exit 1

    uzh/run_tdnn.sh $initial_data/data \
                    $data/lang \
                    $dev_data \
                    $models/tri_mmi/ali \
                    $models/ivector

    [[ $? -ne 0 ]] && echo 'Error in tdnn training' && exit 1

    # Copy the phone table to the models folder. This will help later when
    # generating the lingware (see compile_lingware.sh)
    if [ -f $phone_table ]; then cp $phone_table $models/ivector/chain/tdnn; fi

fi

CUR_TIME=$(date +%s)
echo ""
echo "TIME ELAPSED: $(($CUR_TIME - $START_TIME)) seconds"
echo ""
echo ""
echo "Done: $0"
echo ""
