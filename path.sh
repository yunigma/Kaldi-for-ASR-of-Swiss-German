# export KALDI_ROOT='/Users/inigma/Documents/UZH_Master/MasterThesis/KALDI/kaldi'  # Kaldi local
# export KALDI_ROOT='/opt/kaldi'  # Kaldi 5.3.
# export KALDI_ROOT='/home/thaya/kaldi'  # Kaldi 5.5.
# export KALDI_ROOT='/home/iuliia/kaldi'  # Kaldi 5.5. the newest with GPU
export KALDI_ROOT='/home/ubuntu/kaldi'  # Kaldi 5.5. the newest with GPU iuliia_gpu instance

if [[ -z "$KALDI_ROOT" ]]; then
    echo 'Error: KALDI_ROOT is not set in path.sh. Please set it with the path to the local Kaldi folder'
    exit 1
fi

[ -f $KALDI_ROOT/tools/env.sh ] && . $KALDI_ROOT/tools/env.sh
export PATH=$PWD/utils/:$KALDI_ROOT/tools/openfst/bin:$PWD:$PATH
[ ! -f $KALDI_ROOT/tools/config/common_path.sh ] && echo >&2 "The standard file $KALDI_ROOT/tools/config/common_path.sh is not present -> Exit!" && exit 1
. $KALDI_ROOT/tools/config/common_path.sh
export LC_ALL=C
