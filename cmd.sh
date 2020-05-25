#
# This script selects the command used to run all the parallel jobs along the
# recipe:
# - queue.pl: for parallel computing in a server network connected with SGE
#             (Sun Grid Engine), and assuming that everything is run on a drive
#             shared via NFS with all the nodes.
# - slurm.pl: for parallel computing with a Slurm connected server network.
# - run.pl: for local parallel computing (typically used for debugging, or
#           when training / decoding with very small databases)
#
# Note that Kaldi although Kaldi includes its own version of these scripts, the
# ones under the uzh folder should be used. This is because queue.pl has been
# adapted to be more robust to some NFS failures related to the heavy I/O
# operations of the recipe.
#

export train_cmd=uzh/run.pl
export decode_cmd=uzh/run.pl

#export train_cmd=uzh/queue.pl
#export decode_cmd=uzh/queue.pl
