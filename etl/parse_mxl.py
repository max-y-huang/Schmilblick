#!/usr/bin/env python

import os
import json
import pathlib
import argparse
import midiutil
import zipfile
import tempfile

from xml.etree import ElementTree

import mxl_parser


_IN_MXL_DIR = './in/<SCORE>.mxl'
_OUT_MIDI_DIR = './out/<SCORE>/<PART>.mid'
_OUT_DATA_DIR = './out/<SCORE>/<PART>.json'


def import_mxl_as_xml(dir):
    # unzip file to temporary directory
    with zipfile.ZipFile(dir, 'r') as z:
        zip_dir = tempfile.mkdtemp()
        z.extractall(zip_dir)
        xml_fname = next(d for d in os.listdir(zip_dir) if d.endswith('.xml') or d.endswith('.musicxml'))  # get first .xml or .musicxml file in zip_dir
        xml_dir = os.path.join(zip_dir, xml_fname)
    # get xml from temporary directory
    with open(xml_dir) as f:
        obj = ElementTree.parse(f)
    return obj


def save_notes_as_json(dir, notes):
    with open(dir, 'w') as f:
        print(json.dumps(notes.to_json()), file=f)


def save_notes_as_midi(dir, notes):
    track, channel = 0, 0
    MyMIDI = midiutil.MIDIFile(1, deinterleave=False)
    MyMIDI.addTempo(track, channel, 60)  # 60 bpm = 1 beat per second
    for note in notes.get_notes():
        MyMIDI.addNote(track, channel, note.pitch, note.time, note.duration, 127)
    with open(dir, 'wb') as f:
        MyMIDI.writeFile(f)


def prompt_preview(score_name, parts):
    selected_part_idx = 0
    if len(parts) > 1:
        print('Which part do you want to preview?')
        for i, part in enumerate(parts):
            print(f'\t[{i + 1}]: {part["name"]}')
        try:
            selected_part_idx = int(input('> ')) - 1
        except:
            # return on invalid choice
            print('Preview cancelled.')
            return
    part_id = parts[selected_part_idx]['id']
    out_midi_dir = _OUT_MIDI_DIR.replace('<SCORE>', score_name).replace('<PART>', part_id)
    os.system(f'start {out_midi_dir}')


if __name__ == '__main__':

    arg_parser = argparse.ArgumentParser()
    arg_parser.add_argument('-s', '--score', help='the MusicXML score to use', required=True)
    arg_parser.add_argument('-p', '--preview', help='preview a parsed part in MIDI', action='store_true')
    args = arg_parser.parse_args()

    score_name = args.score
    pathlib.Path(f'./out/{score_name}').mkdir(parents=True, exist_ok=True)

    in_mxl_dir = _IN_MXL_DIR.replace('<SCORE>', score_name)
    score = import_mxl_as_xml(in_mxl_dir).getroot()

    parts = mxl_parser.PartParser(score).parse().parts
    for part in parts:
        out_data_dir = _OUT_DATA_DIR.replace('<SCORE>', score_name).replace('<PART>', part['id'])
        out_midi_dir = _OUT_MIDI_DIR.replace('<SCORE>', score_name).replace('<PART>', part['id'])
        notes = mxl_parser.NoteParser(part['obj']).parse()
        save_notes_as_json(out_data_dir, notes)
        save_notes_as_midi(out_midi_dir, notes)
    
    if args.preview:
        prompt_preview(score_name, parts)
