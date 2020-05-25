#!/bin/bash

set -u

#
# This script collects the commands to install the required sofware on the
# server provided by UZH, with Ubuntu 16.04.
#
# Note that it does not include the installation of SGE or Slurm.
#

install_dir=/home/ubuntu/programs

sudo apt-get update
sudo apt-get upgrade --yes

sudo apt-get install gcc g++
#sudo apt-get install gcc-5 g++-5 -y
sudo apt-get install libtool --yes

sudo apt-get install autoconf autoconf-archive -y
sudo apt-get install  zlib1g-dev subversion

##
# Install git:
sudo apt-get install --yes git-core

##
# Install Lapack:
sudo apt-get install --yes liblapack3gf
sudo apt-get install --yes liblapack-dev

##
# And libatlas
sudo apt-get install --yes libatlas*

##
# ffmpeg:
sudo apt-get install --yes ffmpeg

##
# Sox:
sudo apt-get install --yes sox

##
# MITLM:
cd $install_dir
git clone https://github.com/mitlm/mitlm.git
cd mitlm
autoreconf -i
./configure
make -j
sudo make install
sudo mv /usr/local/lib/libmitlm.* /usr/lib/.

##
# Kaldi:
cd /opt
sudo git clone https://github.com/kaldi-asr/kaldi.git
sudo chown -R ubuntu:ubuntu kaldi
cd kaldi
git checkout 8cc5c8b32a49f8d963702c6be681dcf5a55eeb2e
cd tools
make -j
cd ../src
./configure --shared
make depend -j
make -j

echo "Done: $0"
