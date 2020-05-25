#!/bin/bash
sgmm_name=
discr_sgmm=  # the name of mmi trained SGMM model is needed
transform_model="scores_tri_fmllr_sat"


set -u # from train_am.sh and compile_lingware.sh and decode_nnet.sh
export LC_ALL=C # from compile_lingware.sh

## This script is a combination of compile_lingware.sh and decode_nnet.sh
#####################################
## For decoding SGMM-based models (compile_decode_sgmm.sh)
#####################################
## Assumed that the model is called sgmm!!
## First, we compile the lingware to run the decoder with certain input
## lexicon, language model, and acoustic models.
## Second, we extract features from test data.
## Finally, we decode the test data using the compiled graph.

# Get the general configuration variables
# (SPOKEN_NOISE_WORD, SIL_WORD and GRAPHEMIC_CLUSTERS)
. uzh/configuration.sh

# This call selects the tool used for parallel computing: ($train_cmd, $decode_cmd)
. cmd.sh

# This includes in the path the kaldi binaries:
. path.sh

# This parses any input option, if supplied.
. utils/parse_options.sh

# Relevant for decoding
num_jobs=32  # Number of jobs for parallel processing
spn_word='<SPOKEN_NOISE>'
sil_word='<SIL_WORD>'

#####################################
# Flags to choose with stages to run:
#####################################
do_compile_graph=1
do_data_prep=1
do_feature_extraction=1
do_decoding_sgmm=1
do_decoding_sgmm_discr=0

##################
# Input arguments:
##################

lm=$1
am_dir=$2 # am_out directory (output of train_AM.sh, usually am_out/)
# model_dir=$3 # model directory (it's assumed that model_dir contains 'tree' and 'final.mdl')
model_dir=$3 # all models general directory
dev_csv=$4 # dev csv for decoding
wav_dir=$5 # audio files for decoding
output_dir=$6 # can be shared between compile and decode
transcription=${7:-"orig"}

#################
# Existing files: cf. am_out/initial_data/ling/ vs am_out/data/lang/
#################

am_ling_dir="$am_dir/initial_data/ling/" # equivalent to data/local/lang (input)
# vocabulary="$am_dir/initial_data/tmp/vocabulary.txt" # initial vocab created by train_am
# lexicon="$am_dir/initial_data/ling/lexicon.txt" # lexicon created by train_am
phone_table="$am_dir/data/lang/phones.txt" # created by train_am
# tree="$am_dir/initial_data/ling/tree" NOT USED

###########################
# Intermediate Directories:
###########################

# lexicon="$tmp_dir/lexicon.txt" # created in train_am, removed to reduce repetition!
tmp_dir="$output_dir/tmp"
lexicon_tmp="$tmp_dir/lexicon"
prepare_lang_tmp="$tmp_dir/prepare_lang_tmp"
tmp_lang="$tmp_dir/lang"

# decode_dir="$output_dir/decode" # output dir for decoding
# decode_dir_fmllr="$output_dir/decode_fmllr" # output dir for decoding
lang_dir="$output_dir/lang" # output dir for intermediate language data
feats_dir="$output_dir/feats"
feats_log_dir="$output_dir/feats/log"
# wav_scp="$lang_dir/wav.scp" NOT USED !!!
transform_dir_decode="$output_dir/$transform_model/decode"
train_data_dir="/mnt/iuliia/models/archimob_r2/models/models/initial_data/data"

##########
## Output:
##########

wav_lst="$tmp_dir/wav.lst"
dev_transcriptions="$tmp_dir/text"

#####################################################################################

# check dependencies for compiling graph
for f in $lm $phone_table; do
    [[ ! -e $f ]] && echo -e "\n\tERROR: missing input $f\n" && exit 1
done

mkdir -p $output_dir $tmp_dir $lexicon_tmp $prepare_lang_tmp $tmp_lang $output_dir/$sgmm_name/decode $lang_dir $feats_dir $feats_log_dir

# . ./path.sh

START_TIME=$(date +%s) # record time of operations

###################
## 1. Compile graph
###################

if [[ $do_compile_graph -ne 0 ]]; then

    # # Generate the lexicon (text version):
    # echo ""
    # echo "#########################################"
    # echo "### BEGIN: GENERATE LEXICON $lexicon ###"
    # echo "#########################################"
    # echo ""
    #
    # archimob/create_simple_lexicon.py \
    #   -v $vocabulary \
    #   -c $GRAPHEMIC_CLUSTERS \
    #   -o $lexicon
    #
    # [[ $? -ne 0 ]] && echo -e "\n\tERROR: calling create_simple_lexicon.py\n" && exit 1

    # Add to the lexicon the mapping for the silence word:
    # echo -e "$SIL_WORD SIL\n$SPOKEN_NOISE_WORD SPN" | cat - $lexicon | sort -o $lexicon

    # copy lexicon.txt nonsilence_phones.txt optional_silence.txt  silence_phones.txt
    # to out_dir/tmp/lexicon

    # Generate the lexicon fst:

    for f in lexicon.txt nonsilence_phones.txt optional_silence.txt silence_phones.txt; do
        [[ ! -e $am_ling_dir/$f ]] && echo -e "\n\tERROR: missing $f in $am_ling_dir\n" && exit 1
        cp $am_ling_dir/$f $lexicon_tmp/
    done

    # cp $lexicon $lexicon_tmp/lexicon.txt
    # rm $lexicon_tmp/lexiconp.txt &> /dev/null

    CUR_TIME=$(date +%s)
    echo ""
    echo "TIME ELAPSED: $(($CUR_TIME - $START_TIME)) seconds"
    echo ""

    echo ""
    echo "######################################"
    echo "### BEGIN: PREPARING LANGUAGE DATA ###"
    echo "######################################"
    echo ""

    utils/prepare_lang.sh \
      --phone-symbol-table $phone_table \
      $lexicon_tmp \
      "$SPOKEN_NOISE_WORD" \
      $prepare_lang_tmp \
      $tmp_lang

    [[ $? -ne 0 ]] && echo -e "\n\tERROR: calling prepare_lang.sh\n" && exit 1

    CUR_TIME=$(date +%s)
    echo ""
    echo "TIME ELAPSED: $(($CUR_TIME - $START_TIME)) seconds"
    echo ""

    echo ""
    echo "##############################"
    echo "### BEGIN: GENERATE LM FST $tmp_lang/G.fst ###"
    echo "##############################"
    echo ""

    # Generate G.fst (grammar / language model):
    arpa2fst --disambig-symbol=#0 \
      --read-symbol-table=$tmp_lang/words.txt \
      $lm \
      $tmp_lang/G.fst

    [[ $? -ne 0 ]] && echo -e "\n\tERROR: generating $tmp_lang/G.fst\n" && exit 1


    set +e # don't exit on error
    fstisstochastic $tmp_lang/G.fst
    set -e # exit on error

    CUR_TIME=$(date +%s)
    echo ""
    echo "TIME ELAPSED: $(($CUR_TIME - $START_TIME)) seconds"
    echo ""

    echo ""
    echo "#############################"
    echo "### BEGIN: GENERATE GRAPH ###"
    echo "#############################"
    echo ""

    # Generate the complete cascade:
    # utils/mkgraph.sh $data/lang $models/sgmm $models/sgmm/graph || exit 1;
    utils/mkgraph.sh $tmp_lang $model_dir/$sgmm_name $output_dir/$sgmm_name

    [[ $? -ne 0 ]] && echo -e "\n\tERROR: calling mkgraph.sh\n" && exit 1

    CUR_TIME=$(date +%s)
    echo ""
    echo "TIME ELAPSED: $(($CUR_TIME - $START_TIME)) seconds"
    echo ""

    echo ""
    echo "#####################################"
    echo "### COMPLETED: CONSTRUCTING GRAPH ###"
    echo "#####################################"
    echo ""

fi

###########################
## 2. Prep DEVELOPMENT Data
###########################

if [[ $do_data_prep -ne 0 ]]; then
    # 1.- Create the transcriptions and wave list:
    echo ""
    echo "#######################################################"
    echo "### BEGIN: EXTRACT DEV TRANSCRIPTIONS AND WAVE LIST ###"
    echo "#######################################################"
    echo ""
    # Note the options -f and -p: we are rejecting files with no-relevant-speech or
    # overlapping speech; also, Archimob markers (hesitations, coughing, ...) are
    # mapped to less specific classes (see process_archimob.csv.py)
    # echo "Processing $dev_csv:"
    archimob/process_archimob_csv.py \
      -i $dev_csv \
      -trans $transcription \
      -f \
      -p \
      -t $dev_transcriptions \
      -s $spn_word \
      -n $sil_word \
      -o $wav_lst

    [[ $? -ne 0 ]] && echo -e "\n\tERROR: calling process_archimob_csv.py\n" && exit 1

    # Sort them the way Kaldi likes it:
    sort $dev_transcriptions -o $dev_transcriptions
    sort $wav_lst -o $wav_lst

    # 2. Create the secondary files needed by Kaldi (wav.scp, utt2spk, spk2utt):
    echo ""
    echo "###############################################"
    echo "### BEGIN: CREATE SECONDARY FILES FOR KALDI ###"
    echo "###############################################"
    echo ""
    archimob/create_secondary_files.py \
      -w $wav_dir \
      -o $lang_dir \
      decode \
      -t $dev_transcriptions

    [[ $? -ne 0 ]] && echo -e "\n\tERROR: calling create_secondary_files.py\n" && exit 1

    CUR_TIME=$(date +%s)
    echo ""
    echo "TIME ELAPSED: $(($CUR_TIME - $START_TIME)) seconds"
    echo ""

fi

#######################
## 3. Extract features:
#######################

if [[ $do_feature_extraction -ne 0 ]]; then
    echo ""
    echo "#################################"
    echo "### BEGIN: FEATURE EXTRACTION ###"
    echo "#################################"
    echo ""
    # This extracts MFCC features. See conf/mfcc.conf for the configuration
    # Note: the $train_cmd variable is defined in cmd.sh
    steps/make_mfcc.sh --cmd "$train_cmd" --nj $num_jobs $lang_dir \
              $feats_log_dir $feats_dir

    [[ $? -ne 0 ]] && echo -e "\n\tERROR: during feature extraction\n" && exit 1

    # This extracts the Cepstral Mean Normalization features:
    steps/compute_cmvn_stats.sh $lang_dir $feats_log_dir $feats_dir

    [[ $? -ne 0 ]] && echo -e "\n\tERROR: during cmvn computation\n" && exit 1

    CUR_TIME=$(date +%s)
    echo ""
    echo "TIME ELAPSED: $(($CUR_TIME - $START_TIME)) seconds"
    echo ""

fi

##############
## 4. Decoding
##############

# dependencies for decoding
# for f in $dev_transcriptions $wav_dir $model_dir ; do
#     [[ ! -e $f ]] && echo "Error. Missing input $f" && exit 1
# done

# $output_dir --> graphdir=$1
# srcdir=`dirname $dir`; # Assume model directory one level up from decoding directory
# $lang_dir --> data=$2
# $decode_dir --> dir=$3
# $model_dir --> srcdir=$4

if [[ $do_decoding_sgmm -ne 0 ]]; then

    echo ""
    echo "#######################"
    echo "### BEGIN: DECODING ###"
    echo "#######################"
    echo ""

    rm -rf $output_dir/$sgmm_name/decode/*

    # In this case transform-dir must be a decode direction:
    # hence, containing transforms for the test data
    uzh/decode_sgmm_wer_cer.sh --nj $num_jobs --cmd "$decode_cmd" \
        --transform-dir $transform_dir_decode \
        $output_dir/$sgmm_name \
        $lang_dir \
        $output_dir/$sgmm_name/decode \
        $model_dir/$sgmm_name || exit 1;

    CUR_TIME=$(date +%s)
    echo ""
    echo "TIME ELAPSED: $(($CUR_TIME - $START_TIME)) seconds"
    echo ""

    # uzh/decode_sgmm_wer_cer.sh --use-fmllr true --nj $num_jobs --cmd "$decode_cmd" \
    #   --transform-dir $transform_dir_decode  \
    #   $output_dir/$sgmm_name \
    #   $lang_dir \
    #   $output_dir/$sgmm_name/decode_fmllr \
    #   $model_dir/$sgmm_name || exit 1;


    # [[ $? -ne 0 ]] && echo -e "\n\tERROR: during sgmm decoding\n" && exit 1

    # Copy the results to the output folder:
    # cp $output_dir/$sgmm_name/decode/scoring_kaldi/best_wer $output_dir/$sgmm_name
    # cp -r $output_dir/$sgmm_name/decode/scoring_kaldi/wer_details $output_dir/$sgmm_name /

    CUR_TIME=$(date +%s)
    echo ""
    echo "TIME ELAPSED: $(($CUR_TIME - $START_TIME)) seconds"
    echo ""
fi


if [[ $do_decoding_sgmm_discr -ne 0 ]]; then
    echo ""
    echo "#######################"
    echo "### BEGIN: discriminative SGMM DECODING ###"
    echo "#######################"
    echo ""

    for iter in 1 2 3 4; do
        steps/decode_sgmm2_rescore.sh --cmd "$decode_cmd" --iter $iter \
            --transform-dir $transform_dir_decode \
            $tmp_lang \
            $lang_dir \
            $output_dir/$sgmm_name/decode \
            $output_dir/$discr_sgmm/decode_it$iter \
            $model_dir/sgmm_mmi &
    done
    (
     steps/train_mmi_sgmm2.sh --cmd "$decode_cmd" \
            --transform-dir $transform_dir_decode \
            --boost 0.2 --drop-frames true \
            $train_data_dir \
            $tmp_lang \
            $model_dir/sgmm_ali \
            $model_dir/sgmm_denlats \
            $model_dir/sgmm_mmi_b0.2_x

     for iter in 1 2 3 4; do
      steps/decode_sgmm2_rescore.sh --cmd "$decode_cmd" --iter $iter \
        --transform-dir $transform_dir_decode \
        $tmp_lang \
        $lang_dir \
        $output_dir/$sgmm_name/decode \
        $output_dir/sgmm_mmi_b0.2_x/decode_it$iter \
        $model_dir/sgmm_mmi_b0.2_x &
     done
    )
    wait
    # steps/decode_combine.sh $lang_dir \
    #                         $tmp_lang \
    #                         exp/tri1/decode \
    #                         exp/tri2a/decode \
    #                         $output_dir/combine_1_2a/decode || exit 1;
    steps/decode_combine.sh $lang_dir \
                        $tmp_lang \
                        $output_dir/$sgmm_name/decode \
                        $output_dir/score_tri_mmi_4000/decode \
                        $output_dir/combine_sgmm_3mmi_4k40k/decode || exit 1;

    # combining the sgmm run and the best MMI+fMMI run.
    # steps/decode_combine.sh $lang_dir \
    #                         $tmp_lang \
    #                         $output_dir/$sgmm_name/decode \
    #                         exp/tri3b_fmmi_c/decode_it5 \
    #                         exp/combine_sgmm2_4a_3b_fmmic5/decode || exit 1;

    # steps/decode_combine.sh $lang_dir \
    #                         $tmp_lang \
    #                         $output_dir/sgmm_mmi_b0.2/decode_it4 \
    #                         exp/tri3b_fmmi_c/decode_it5 \
    #                         $output_dir/combine_sgmm_mmi_3b_fmmic5/decode || exit 1;


    [[ $? -ne 0 ]] && echo -e "\n\tERROR: during discr sgmm decoding\n" && exit 1

fi

CUR_TIME=$(date +%s)
echo ""
echo "TIME ELAPSED: $(($CUR_TIME - $START_TIME)) seconds"
echo ""
echo ""
echo "### DONE: $0 ###"
echo ""
