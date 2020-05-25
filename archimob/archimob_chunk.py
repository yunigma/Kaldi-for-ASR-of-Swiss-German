#!/usr/bin/python

"""
Definitions of the classes ArchiMobChunkEXB and ArchiMobChunkXML, which are
basic containers for the information of a segment of the transcriptions
generated with the Folker and Exmaralda programs.

.EXB: key, transcription, start, end, speaker_id, initial timepoint
.XML: key, transcription, normalized, speaker_id
"""


class ArchiMobChunkEXB(object):
    """
    Container class that collects the information of a chunk of the
    ArchiMob corpus from EXB annotations
    """

    def __init__(self, key=None,
                 trans=None,
                 beg=None,
                 end=None,
                 init_timepoint=None,
                 spk=None):
        """
        Init function of the class
        input:
            * key: unique identifier of the chunk.
            * trans: transcription corresponding to the chunk.
            * beg: initial time of the chunk.
            * end: final time.
            * init_timepoint: identifier of the initial timepoint. It is
              used to control overlapping chunks.
            * spk: speaker id.
        """

        ## Unique identifier of the chunk.
        self.key = key
        ## Transcription corresponding to the chunk.
        self.trans = trans
        ## Initial time of the chunk.
        self.beg = beg
        ## Final time of the chunk.
        self.end = end
        ## Speaker id:
        self.spk_id = spk
        ## Identifier of the initial timepoint
        self.init_timepoint = init_timepoint

    def __str__(self):
        """
        ArchiMob to str
        """

        return '{0} ({1} {2}) : {3}'.format(self.key, self.beg, self.end,
                                            self.trans.encode('utf8'))

    @staticmethod
    def create_chunk_key(basename, spk_id, utt_index, index_size=4):
        """
        Uses a basename (usually dependent on the name of the input folker
        file with the annotations), a spk_id, and an index, to create the
        identifier of the current chunk within the whole corpus
        input:
            * basename (str): beginning of the identifier.
            * spk_id (str): speaker id.
            * utt_index (int): index of the utterance.
            * index_size (int): total size of the index. For example, if
              the index is 1, and the size is 4, the index would be 0001.
        returns:
            * a unique identifier for the current chunk.

        NOTE: Kaldi needs the speaker id to be a prefix of the utterance id,
        because of sorting issues that help speed up training.
        """

        complete = index_size - len(str(utt_index))
        if complete > 0:
            output_index = '0' * complete + str(utt_index)
        else:
            output_index = utt_index

        return '{0}-{1}-{2}'.format(spk_id, basename, output_index)


class ArchiMobChunkXML(object):
    """
    Container class that collects the information of a chunk of the
    ArchiMob corpus from XML annotations
    """

    def __init__(self, key=None,
                 trans=None,
                 norm=None,
                 spk=None,
                 audio=None,
                 anonym=None):
        """
        Init function of the class
        input:
            * key: unique identifier of the chunk.
            * trans: transcription corresponding to the chunk.
            * norm: normalized transcription corresponding to the chunk.
            * spk: speaker id.
        """

        ## Unique identifier of the chunk.
        self.key = key
        ## Corresponding Audio file number
        self.audio_id = audio
        ## Transcription corresponding to the chunk.
        self.trans = trans
        ## Normalized transcription corresponding to the chunk.
        self.norm = norm
        ## Speaker id:
        self.spk_id = spk
        ## Identifier of the anonymity
        # self.anonym = anonym
        ## Identifier of the initial timepoint
        # self.init_timepoint = init_timepoint

    def __str__(self):
        """
        ArchiMob to str
        """

        return '{0}, "{1}", "{2}", "{3}"'.format(self.key,
                                                 self.audio_id,
                                                 self.trans.encode('utf8'),
                                                 self.norm.encode('utf8'))

    @staticmethod
    def create_chunk_key(basename, spk_id, utt_index, index_size=4):
        """
        Uses a basename (usually dependent on the name of the input folker
        file with the annotations), a spk_id, and an index, to create the
        identifier of the current chunk within the whole corpus
        input:
            * basename (str): beginning of the identifier.
            * spk_id (str): speaker id.
            * utt_index (int): index of the utterance.
            * index_size (int): total size of the index. For example, if
              the index is 1, and the size is 4, the index would be 0001.
        returns:
            * a unique identifier for the current chunk.
        NOTE: Kaldi needs the speaker id to be a prefix of the utterance id,
        because of sorting issues that help speed up training.
        """

        complete = index_size - len(str(utt_index))
        if complete > 0:
            output_index = '0' * complete + str(utt_index)
        else:
            output_index = utt_index

        return '{0}-{1}-{2}'.format(spk_id, basename, output_index)
