#!/bin/bash

#
# Configuration script with certain variables needed both for training and
# lingware generation
#

# Graphemic clusters for the pronunciations:
# export GRAPHEMIC_CLUSTERS='manual/clusters.txt'
export GRAPHEMIC_CLUSTERS='manual/clusters_extend.txt'
# Word to represent general speech events (like words without pronunciations,
# hesitations, truncations, ...)
export SPOKEN_NOISE_WORD='<SPOKEN_NOISE>'
# Word to represent silence and non-speech events (breathing, short noises
# without a speech like spectrum, ...)
export SIL_WORD='<SIL_WORD>'
export NOISE_WORD='<NOISE>'
