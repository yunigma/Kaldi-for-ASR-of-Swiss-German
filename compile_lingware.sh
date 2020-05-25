#!/bin/bash

set -u
export LC_ALL=C

#
# This script compiles the lingware to run the decoder with certain input
# lexicon, language model, and acoustic models. In practice, it is
# basically a wrapper for utils/mkgraph.sh
#
# Clarify the difference between am_ling_dir and am_lang_dir
#

echo $0 $@
if [[ $# -ne 5 ]]; then
    echo "Wrong call. Should be: $0 am_ling_dir vocabulary language_model acoustic_models_dir output_dir"
    exit 1
fi

# Get the general configuration variables (SPOKEN_NOISE_WORD, SIL_WORD, and
# GRAPHEMIC_CLUSTERS)
. uzh/configuration.sh

##################
# Input arguments:
##################
am_ling_dir=$1
vocabulary=$2
lm=$3
am_dir=$4
output_dir=$5

###############
# Intermediate:
###############
tmp_dir="$output_dir/tmp"
phone_table="$am_dir/phones.txt"
lexicon="$tmp_dir/lexicon.txt"
lexicon_tmp="$tmp_dir/lexicon"
prepare_lang_tmp="$tmp_dir/prepare_lang_tmp"
tmp_lang="$tmp_dir/lang"
# tree="$am_dir/tree"

. path.sh

for f in $vocabulary $lm; do
    [[ ! -e $f ]] && echo "Error: missing input $f" && exit 1
done

mkdir $output_dir $tmp_dir $lexicon_tmp $prepare_lang_tmp

##
# Generate the lexicon (text version):
echo "Generating the lexicon: $lexicon"
archimob/create_simple_lexicon.py \
        -v $vocabulary \
        -c $GRAPHEMIC_CLUSTERS \
        -o $lexicon

[[ $? -ne 0 ]] && echo 'Error calling create_simple_lexicon.py' && exit 1

##
# Add to the lexicon the mapping for the silence word:
echo -e "$SIL_WORD SIL\n$SPOKEN_NOISE_WORD SPN" | cat - $lexicon | \
    sort -o $lexicon

##
# Generate the lexicon fst:
for f in nonsilence_phones.txt optional_silence.txt silence_phones.txt; do
    [[ ! -e $am_ling_dir/$f ]] && echo "Error: missing $f in $am_ling_dir" && \
	exit 1
    cp $am_ling_dir/$f $lexicon_tmp/
done

cp $lexicon $lexicon_tmp/lexicon.txt
rm $lexicon_tmp/lexiconp.txt &> /dev/null

utils/lang/prepare_lang.sh \
        --phone-symbol-table $phone_table \
        $lexicon_tmp \
        "$SPOKEN_NOISE_WORD" \
        $prepare_lang_tmp \
        $tmp_lang

[[ $? -ne 0 ]] && echo 'Error calling prepare_lang.sh' && exit 1

##
# Generate G.fst (grammar / language model):
echo "Generating the language model fst: $tmp_lang/G.fst"
arpa2fst --disambig-symbol=#0 \
         --read-symbol-table=$tmp_lang/words.txt \
	     $lm \
         $tmp_lang/G.fst

[[ $? -ne 0 ]] && echo "Error generating $tmp_lang/G.fst" && exit 1

set +e
fstisstochastic $tmp_lang/G.fst
set -e

##
# Generate the complete cascade:
utils/mkgraph.sh $tmp_lang $am_dir $output_dir

[[ $? -ne 0 ]] && echo 'Error calling mkgraph.sh' && exit 1

echo "Done: $0"
