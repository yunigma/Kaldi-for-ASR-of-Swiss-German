# Description:

This folder contains the shared code base for the master's projects focusing on ASR for Swiss German.
The scripts are an implementation of a basic ASR framework based on Kaldi and were originally developed by Spitch AG, with the following functionality:

  * Neural networks acoustic model training.
  * WFST lingware compilation.
  * Evaluation.

The Kaldi recipe egs/wsj/s5 (commit 8cc5c8b32a49f8d963702c6be681dcf5a55eeb2e) was used as reference.

# Main scripts:

* train_AM.sh: acoustic models training.
* compile_lingware.sh: lingware compilation.
* decode_nnet.sh: evaluation.

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

# Models (all models are evaluated with the same test set):

 **model**  | **WER,%** | **data: n interviews minus test data** | **transcription** | **LM** |
| -------- | -------- | -------- | -------- | -------- |
| BASELINE  | 68.00 | how many interviews?| orig | on trainning data |
| all data + original | 54.38 | 43 interviews | orig | on trainning data |
| all data + normalised  | ... | 43 interviews | normalised | on trainning data |
| | | | | |
| | | | | |
| | | | | |


# 18.10.19 (Iuliia)

Steps:
- XML to .csv: with `archimob/process_exmaralda_xml.py`
- rename audio files and filter those audio files, which do not have corresponding transcription: with `archimob/rename_wavs.py`
- run `train_AM.sh`
- make `vocabulary_train.txt`: with `archimob/create_vocabulary.py`
- run `compile_lingware.sh`
- run `decode_nnet.sh`

Running example with approximate cmds:
1. XML to .csv

    ```
    python /home/code_base/archimob/process_exmaralda_xml.py \
    -i /home/ubuntu/data/archimob_r2/train_xml/*.xml \
    -format xml \
    -o /home/../data/processed/archimob.csv
    ```

    1.2. rename chunked wavs **Note**: This only needs to be done once!

    ```
    python /home/code_base/archimob/rename_wavs.py \
    -i /home/../data/processed/archimob.csv \
    -chw /home/ubuntu/data/archimob_r2/audio
    ```

    1.3. split train and test sets according to the test set utterances in JSON file
    ```
    python /home/code_base/archimob/split_data.py \
    -i /home/.../data/processed/archimob.csv \
    -o /home/.../data/processed \
    -t /home/ubuntu/data/archimob_r2/meta_info/test_set.json
    ```

    <!-- for train:

    ```
    /home/.../kaldi_wrk_dir/spitch_kaldi_UZH/archimob/process_exmaralda_xml.py \
    -i /home/.../data/original/train_xml/*.xml \
    -format xml \
    -o /home/.../data/processed/train.csv
    ```

    for test:
    ```
    /home/.../kaldi_wrk_dir/spitch_kaldi_UZH/archimob/process_exmaralda_xml.py \
    -i /home/../data/original/test_xml/*.xml \
    -format xml \
    -o /home/.../data/processed/test.csv
    ``` -->

3. Training AM

    ```
    nohup /home/.../kaldi_wrk_dir/spitch_kaldi_UZH/train_AM.sh \
    /home/.../data/processed/train.csv \
    /home/.../data/processed/wav_train \
    /home/.../kaldi_wrk_dir/spitch_kaldi_UZH/out_AM
    ```

4. Create vocabulary
    ```
    /home/.../kaldi_wrk_dir/spitch_kaldi_UZH/archimob/create_vocabulary.py \
    -i /home/.../kaldi_wrk_dir/spitch_kaldi_UZH/out_AM/initial_data/ling/lexicon.txt \
    -o /home/.../data/processed/vocabulary_train.txt
    ```

5. Lingware (no need of nohup actually, as it is fast...)
    ```
    nohup /home/.../kaldi_wrk_dir/spitch_kaldi_UZH/compile_lingware.sh \
    out_AM/initial_data/ling \
    /home/.../data/processed/vocabulary_train.txt \
    /home/.../data/processed/language_model/language_model.arpa \
    out_AM/models/discriminative/nnet_disc \
    out_ling
    ```

6. Decoding
    ```
    nohup /home/.../kaldi_wrk_dir/spitch_kaldi_UZH/decode_nnet.sh \
    /home/.../data/processed/test.csv \
    /home/.../data/processed/wav_test \
    out_AM/models/discriminative/nnet_disc \
    out_ling out_decode
    ```

# CHANGES

### 1) Preprocess the transcriptions

FILES THAT HAVE BEEN CHANGED for this step:
- `archimob/process_exmaralda_xml.py`
- `archimob/archimob_chunk.py`
- `archimob/prepare_Archimob_training_files.sh`
- `archimob/process_archimob_csv.py`

#### Descriptions
`archimob/process_exmaralda_xml.py`

NEW:
- A new argument, which defines the format of the input (EXB or XML) was introduced: `--input-format (-format)`.
OLD:
- input:
  - mandatory input is transcription files in EXB (Exmaralda) format
- output:
  - .csv built with the data from transcriptions: [utt_id, transcription, speaker_id, duration, speech-in-speech, no-relevant-speech]

##### to process exmaralda (.exb) and audio (.wav) files

```
archimob/process_exmaralda_xml.py \
-i data/original/all_exb/*.exb \
-w original/all_wav/ \
-o train.csv \
-O wav_train
```

NEW:
- A new argument is introduced: `--input-format (-format)`, which allows the choice of the input EXB or XML formats.

- input:
  - a) `-format exb` for transcription files in EXB (Exmaralda) format — the same as in the old version (is still default!!).
  - b) `-format xml` for transcription files in XML format.

- output:
  - a) for EXB, the same .csv output as in the old version
  - b) for XML, .csv contains the following fields:
    - utt_id
    - transcription
    - normalized
    - speaker_id
    - audio_id
    - anonymity
    - speech_in_speech
    - missing_audio
    - no-relevant-speech

##### to process Exmaralda files (.exb) !!! There is a bug here on line 111 !!!
```
archimob/process_exmaralda_xml.py \
-i data/ArchiMob/EXB/*.exb \
-format exb \
-o train.csv
```

##### to process XML files (.xml)
```
archimob/process_exmaralda_xml.py \
-i data/ArchiMob/XML/test/*.xml \
-format xml \
-o train.csv
```

**Note**: to switch from Dieth transcription to normalised, make change in `archimob/prepare_Archimob_training_files.sh`: line 100:

```
$scripts_dir/process_archimob_csv.py \
-i $input_csv \
-transcr original \
-f \
-p \
-t $output_trans \
-s $spn_word \
-n $sil_word \
-o $output_lst
```

#### IMPORTANT
**Filtering**: The script now also includes 4 columns, which enable further filtering. Filtering criteria are:
- anonymity
- speech_in_speech
- missing_audio
- no-relevant-speech

**Missing_audio** is filtered during the renaming step in `renaming_wavs.py`. This includes cases where audio file is present but is empty. The other three filtering criteria are already filtered during this step (with the information available from XML).

### 2) Rename chunked wav files (new script)


**NOTE** Skip this step if not running for the FIRST time! This only has to be done once for all data! The renamed wav files are currently in `/home/ubuntu/data/archimob_r2/audio`.

`archimob/rename_wavs.py`
  — renames chunked .wav files in accordance with their transcriptions. Information about the alignment between audio files and transcriptions is taken from .csv [audio_id] (in XML "media-pointer" information)

<!-- To run:

```
archimob/rename_wavs.py \
-i input_csv \
-chw dir_with_chunked_wavs
``` -->

### 3) Split data for training and testing

`split_data.py`
  - automatically splits the input csv into train, test and dev (if applicable) files
  - this script ensures that we are using a standardised test set for comparative evaluations
  - Input:
    - `archimob.csv` (output from `process_exmaralda_xml.py`)
    - `output directory` (train, test and dev (if applicable) files are written automatically)
    - `test_set.json` (JSON file containing utterances for test set)


### 4) Make vocabulary

`archimob/create_vocabulary.py`
  — creates `vocabulary_train.txt` file, which is used at the **LINGWARE** step (Language Model), based on the `lexicon.txt` file (created during the training step).

To run:

```
archimob/create_vocabulary.py \
-i out_AM/initial_data/ling/lexicon.txt \
-o data/processed/vocabulary_train_43.txt
```

### 5) Decoding

The script changed: `decode_nnet.sh` / `decode_nnet_ad.sh` (adapted further to supprot transcription type parameter)

WHAT: instead of `references.txt` the input argument was modified to be .csv test file (created in the same way as train.csv with `archimob/process_exmaralda_xml.py`)

OLD:
- `decode_nnet.sh` takes the `references.txt`, a file with a list of all test transcriptions and corresponding IDs, as one of its input arguments.

NEW:
- Not to create the `references.txt` file manually before the decoding is run, the `decode_nnet.sh` was modified.
- Now as an input argument, which would contain test transcription info, .csv test file instead of `references.txt` is taken (.csv for test data is created with the same script that is used for .csv train file: `archimob/process_exmaralda_xml.py`).
- input:
  - .csv as the first argument; other arguments stay unchanged.



### 6) Language Modeling

The script `simple_lm.sh` now accepts the new csv as input.
Example call:
```
bash ./archimob/simple_lm.sh \
-o 3 \
-c manual/clusters.txt \
-t orig \
$(wrk_dir)/train.csv \
$(out_dir)/lms
```
