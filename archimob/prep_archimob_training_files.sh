#!/bin/bash

set -u
export LC_ALL=C

#
# This script creates the files that the Kaldi recipe needs to train acoustic
# models:
# - Transcriptions
# - Wavelist
# - lexicon.txt
# - silence_phones.txt
# - nonsilence_phones.txt
# - optional_silence.txt
# - extra_questions.txt
#
# Input arguments:
# - csv file: input csv file, as generated with process_exmaralda.py
# - clusters: file with the graphemic clusters for the pronunciations
# - output_dir: folder to write the output files to
#

################
# Configuration:
################
scripts_dir=`dirname $0`
spn_word='<SPOKEN_NOISE>'
sil_word='<SIL_WORD>'
nsn_word='<NOISE>'
trans='orig'
lexicon='' # default: none - will create lexicon from vocabulary for Dieth transcriptions

echo $0 $@
while getopts 's:n:m:t:l:h' option; do
    case $option in
    s)
        spn_word=${OPTARG}
        ;;
    n)
        sil_word=${OPTARG}
        ;;
    m)
        nsn_word=${OPTARG}
        ;;
    t)
        trans=${OPTARG} # allows to select original (orig) or normalised (norm)
        ;;
    l)
        lexicon=${OPTARG} # specify input lexicon
        ;;
    h)
        echo "$0 [-s '<SPOKEN_NOISE>'] [-n '<SIL_WORD>'] [-m '<NOISE>'] [-t 'orig'/'norm'] [-l 'lexicon.txt'] input_csv  input_wav_dir output_dir"
      # echo "$0 [-s '<SPOKEN_NOISE>'] [-n '<SIL_WORD>'] [-m '<NOISE>'] [-t orig'/'norm'] [-p 'norm2dieth.json'] input_csv graphemic_clusters output_dir"
        exit 0
        ;;
    \?)
        echo "Option not supported: -$OPTARG" >$2
        exit 1
        ;;
    :)
        echo "Option -$OPTARG requires an argument." >&2
        exit 1
        ;;
    esac
done
shift $((OPTIND-1))

if [[ $# -lt 3 ]]; then
    echo "Wrong call. Should be: $0 [-s '<SPOKEN_NOISE>'] [-n '<SIL_WORD>'] [-m '<NOISE>'] [-t 'orig'/'norm'] [-l lexicon.txt] input_csv input_wav_dir output_dir"
    exit 1
fi

##################
# Input arguments:
##################
input_csv=$1
input_wav_dir=$2
# input_clusters=$3
output_dir=$3

###############
# Intermediate:
###############
data_dir="$output_dir/data"
ling_dir="$output_dir/ling"

#########
# Output:
#########
output_trans="$data_dir/text"
output_lst="$data_dir/wav.lst"
output_lexicon="$ling_dir/lexicon.txt"
output_phoneset="$ling_dir/nonsilence_phones.txt"
output_silences="$ling_dir/silence_phones.txt"
output_optional_silence="$ling_dir/optional_silence.txt"
output_questions="$ling_dir/extra_questions.txt"

for f in $input_csv; do
    [[ ! -e $f ]] && echo -e "\n\tERROR: missing input file $f" && exit 1
done

# if [[ $trans == "norm" && -z $lexicon ]]; then
#     echo "ERROR: Using normalised transcriptions requires a pronunciation lexicon" && exit 1
# fi

mkdir -p $output_dir $data_dir $ling_dir

echo -e "\nTRANSCRIPTION TYPE = $trans\n"


##
# 1.- Create the transcriptions and wave list:
# Note the options -f and -p: we are rejecting files with no-relevant-speech or
# overlapping speech; also, Archimob markers (hesitations, coughing, ...) are
# mapped to less specific classes (see process_archimob.csv.py)
echo "Processing $input_csv:"
# Use -trans option only when the original input was XML!!
$scripts_dir/process_archimob_csv.py \
    -i $input_csv \
    -trans $trans \
    -f \
    -p \
    -t $output_trans \
    --spn-word $spn_word \
    --sil-word $sil_word \
    --nsn-word $nsn_word \
    -o $output_lst

[[ $? -ne 0 ]] && echo -e "\n\tERROR calling process_archimob_csv.py" && exit 1

# Sort them the way Kaldi likes it:
sort $output_trans -o $output_trans
sort $output_lst -o $output_lst

##
# 2.- Create the wav.scp, spk2utt, and utt2spk files:
$scripts_dir/create_secondary_files.py \
    -w $input_wav_dir \
    -o $data_dir \
    train \
    -i $input_csv \
    -l $output_lst

[[ $? -ne 0 ]] && echo -e "\n\tERROR calling create_secondary_files.py" && exit 1

# Sort the utterance to speaker and the wav scp files the way Kaldi likes:
sort $data_dir/wav.scp -o $data_dir/wav.scp
sort $data_dir/utt2spk -o $data_dir/utt2spk


# 4.- Create nonsilence_phones.txt:
# Note that here we are basically collecting the phones appearing in the
# lexicon, which is quite a counter-intuitive way of working (usually the
# phonesets are pre-designed in advance). This approach is a consequence of the
# naive way of generating the pronunciations from the Dieth data: everything
# not appearing in the clusters file is just mapped to itself.
echo "Extracting the phoneset: $output_phoneset"
cut -d' ' -f 2- $lexicon | perl -pe 's#\s+#\n#g' | sort -u > $output_phoneset

# 5.- Create the silence list:
(echo SIL; echo SPN; echo NSN) > $output_silences

# 6.- Create the optional silence file:
echo SIL > $output_optional_silence

# 7.- The extra questions for tree building:
cat $output_silences | awk ' { printf("%s ", $1) } END { printf "\n" } ' > $output_questions

# 8.- Add to the lexicon the mapping for the silence words,
# etc.
echo -e "$sil_word SIL\n$spn_word SPN\n$nsn_word NSN" | cat - $lexicon | sort | uniq | sort -o $output_lexicon

# # 9.- Safety remove:
# # This will force Kaldi to recompute the lexicon (it creates it in the source
# # folder, in prepare_lang.sh)
# rm -rf $tmp_lexiconp

echo ""
echo "### DONE: $0 ###"
echo ""
