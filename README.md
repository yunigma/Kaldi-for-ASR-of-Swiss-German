# Description:

The folder contains the shared code base for the master's projects (Iuliia Nigmatulina and Tannon Kew) focusing on ASR for Swiss German.

The Iuliia's thesis can be found under the link: [Acoustic modelling for Swiss German ASR](https://drive.switch.ch/index.php/apps/files/?dir=/&fileid=682773084#pdfviewer)

The scripts are an implementation of a basic ASR framework based on Kaldi and were originally developed by Spitch AG, with the following functionality:

  * Neural networks acoustic model training.
  * WFST lingware compilation.
  * Evaluation.

The Kaldi (version 5.5.) recipe egs/wsj/s5 (commit 8cc5c8b32a49f8d963702c6be681dcf5a55eeb2e) was used as reference. For the TDNN acoustic model, the egs/wsj/s5/local/chain/ recipe was used.

# Main scripts:

* The current scenarium:
  - run.sh: acoustic models training.
  - compile_decode_***.sh: lingware compilation and evaluation (different scripts for different acoustic models).

* The original scenarium:
  - train_AM.sh: acoustic models training.
  - compile_lingware.sh: lingware compilation.
  - decode_nnet.sh: evaluation.

# Configuration:

* path.sh: script to specify the Kaldi root directory and to add certain directories to the path.
* cmd.sh: script to select the way of running parallel jobs.

# Folders:

* Framework specific:
  - archimob: scripts related to processing the Archimob files.
  - uzh: secondary scripts not included in the Kaldi recipe.
  - manual: manually generated files.
  - install_uzh_server: scripts to install in Ubuntu 16.04 the software needed
    by the framework.
  - doc: documentation files.
* Kaldi:
  - conf: configuration files.
  - local: original recipe-specific files from egs/wsj/s5.
  - utils: utilities shared among all the Kaldi recipes.
  - steps: general scripts related to the different steps followed in the Kaldi
    recipes.

# Models (trained and evaluated on the second release of the ArchiMob corpus):

 **model**  | **WER,%** | **FlexWER,%** | **n of training utterances** | **transcription** | **LM** |
| -------- | -------- | -------- | -------- | -------- | -------- |
| NNET-DISC-2k10k | 55.18 | 32.59 | 67’693 | dialectal | 3-gram |
| NNET-DISC-4k40k | 54.39 | 32.09 | 67’693 | dialectal | 3-gram |
| TDNN-iVector-4k40k | 42.38 | 21.53 | 67’693 | dialectal | 3-gram |
| | | | | | |
| | | | | | |



## Steps
Data preparation:
- XML to .csv: with `archimob/process_exmaralda_xml.py`
- rename audio files and filter those audio files, which do not have corresponding transcription: with `archimob/sync_csv_wavs.py`
Training:
- run `run.sh`
Decoding:
- run `compile_decode_***.sh`

Running example with approximate cmds:
1. Data preparation

    1.1. XML to .csv
    ```
    # to process Exmaralda files (.exb)
    python ./archimob/process_exmaralda_xml.py \
      -i $data/ArchiMob/EXB/*.exb \
      -f exb \
      -w $data/original/all_wav/ \
      -o $data/processed/archimob.csv \
      -O $data/audio/chunked_wav_files


    # to process XML files (.xml)
    python ./archimob/process_exmaralda_xml.py \
      -i $data/archimob_r2/xml_corrected/*.xml \
      -f xml \
      -o $data/processed/archimob.csv
    ```

    1.2. rename chunked wavs **Note**: This only needs to be done once!

    ```
    /python ./archimob/sync_csv_wav.py \
      -i $data/processed/archimob.csv \
      -chw $data/audio/chunked_wav_files
    ```

    1.3. split train and test sets according to the test set utterances in JSON file
    ```
    python ./archimob/split_data.py \
      -i $data/processed/archimob.csv \
      -o $data/processed \
      -t $data/meta_info/test_set.json
    ```

    <!-- for train:

    ```
    python ./archimob/process_exmaralda_xml.py \
    -i $data/original/train_xml/*.xml \
    -f xml \
    -o $data/processed/train.csv
    ```

    for test:
    ```
    python ./archimob/process_exmaralda_xml.py \
    -i $data/original/test_xml/*.xml \
    -f xml \
    -o $data/processed/test.csv
    ``` -->

2. Training AM

    ```
    nohup \
        ./run.sh \
        --num_jobs 69 \
        $data/processed/train.csv \
        $data/audio/chunked_wav_files \
        $exp/models \
        "orig" \
        $data/lexicons/lexicon.txt
    ```

3. Decoding

    3.1. Makes decoding graph and decodes
    ```
    nohup \
      ./compile_decode_nnet.sh \
      $data/lms/language_model.arpa \
      $exp/models/ \
      $exp/models/discriminative/nnet_disc \
      $data/processed/dev.csv \
      $data/audio/chunked_wav_files \
      $exp/models/eval/nnet_disc/dev \
      "orig"
    ```

    3.2. Decodes with the TDNN model
    ```
    uzh/decode_tdnn.sh \
      --test-set "$exp/models/eval/test/nnet_disc/lang" \
      --test-affix "test_schawinski"
    ```


## Language Modeling

The script `simple_lm.sh` now accepts the new csv as input.
Example call:
```
bash ./archimob/simple_lm.sh \
  -o 3 \
  -c manual/clusters.txt \
  -t orig \
  $data/processed/train.csv \
  $data/lms/
```
