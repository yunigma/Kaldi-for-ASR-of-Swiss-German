#!/usr/bin/python
# -*- coding: utf-8 -*-

# usage example with a single file:  python archi_xml_to_text.py Archimob_Release_2/1007.xml

# written by C. Bless, adapted by T. Samardzic

# usage example with a folder:  python archi_xml_to_text.py Archimob_Release_2/


import sys, os
from lxml import etree as ET

fileid = ""


# to print the column format : doc_name, word, normalisation, tag
def print_text(xml_tree, ns):
    for u in tree.getroot().iter("{" + ns + "}u"):
        print
        for w in u.findall("{" + ns + "}w"):
            norm = w.get('normalised')
            tag = w.get('tag')
            print fileid + "\t" + w.text.encode('utf8') + "\t"
            + norm.encode('utf8') + "\t" + tag

# to print simple text
        #utterance=[w.text for w in u.findall("{"+ns+"}w")]
        #output_u=" ".join(utterance)
        #print output_u.encode("utf-8")


inp = sys.argv[1]

if inp.endswith(".xml"):
    tree = ET.parse(inp)
    namespace = tree.getroot().nsmap[None]
    fileid = inp[:-4]
    print_text(tree, namespace)

else:
    for f in os.listdir(inp):
        if f.endswith(".xml"):
            tree = ET.parse(inp + "/" + f)
            namespace = tree.getroot().nsmap[None]
            fileid = f[:-4]
            print_text(tree, namespace)
