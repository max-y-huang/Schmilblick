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


_IN_MXL_DIR = './in/<TEST_CASE>/score.mxl'
_OUT_MIDI_DIR = './out/<TEST_CASE>/preview_<PART>.mid'
_OUT_DATA_DIR = './out/<TEST_CASE>/data_<PART>.json'


def import_mxl_as_xml(dir):
    # unzip file to temporary directory
    with zipfile.ZipFile(dir, 'r') as z:
        zip_dir = tempfile.mkdtemp()
        z.extractall(zip_dir)
        xml_fname = next(d for d in os.listdir(zip_dir) if d.endswith('.xml'))  # get first .xml file in zip_dir
        xml_dir = os.path.join(zip_dir, xml_fname)
    # get xml from temporary directory
    with open(xml_dir) as f:
        obj = ElementTree.parse(f)
    return obj


def save_notes_as_json(dir, notes, part_name):
    with open(dir, 'w') as f:
        note_data = [ note.as_json() for note in notes ]
        data = { 'part': part_name, 'notes': note_data }
        print(json.dumps(data), file=f)


def save_notes_as_midi(dir, notes):
    track, channel = 0, 0
    MyMIDI = midiutil.MIDIFile(1, deinterleave=False)
    MyMIDI.addTempo(track, channel, 60)  # 60 bpm = 1 beat per second
    for note in notes:
        MyMIDI.addNote(track, channel, note.data['pitch'], note.time, note.data['duration'], 127)
    with open(dir, 'wb') as f:
        MyMIDI.writeFile(f)


if __name__ == '__main__':

    arg_parser = argparse.ArgumentParser()
    arg_parser.add_argument('-tc', '--test_case', help='the test case to use', required=True)
    arg_parser.add_argument('-p', '--preview', help='preview a parsed part in MIDI', action='store_true')
    args = arg_parser.parse_args()

    test_case = args.test_case
    pathlib.Path(f'./out/{test_case}').mkdir(parents=True, exist_ok=True)

    in_mxl_dir = _IN_MXL_DIR.replace('<TEST_CASE>', test_case)
    score_obj = import_mxl_as_xml(in_mxl_dir).getroot()

    parts = mxl_parser.PartParser(score_obj).parse()
    for part in parts:
        out_data_dir = _OUT_DATA_DIR.replace('<TEST_CASE>', test_case).replace('<PART>', part['id'])
        out_midi_dir = _OUT_MIDI_DIR.replace('<TEST_CASE>', test_case).replace('<PART>', part['id'])
        notes = mxl_parser.NoteParser(part['obj']).parse()
        save_notes_as_json(out_data_dir, notes, part['name'])
        save_notes_as_midi(out_midi_dir, notes)
    
    if args.preview:
        selected_part_idx = 0
        if len(parts) > 1:
            print('Which part do you want to preview?')
            for i, part in enumerate(parts):
                print(f'\t[{i + 1}]: {part["name"]}')
            selected_part_idx = int(input('> ')) - 1
        out_midi_dir = _OUT_MIDI_DIR.replace('<TEST_CASE>', test_case).replace('<PART>', parts[selected_part_idx]['id'])
        os.system(f'start {out_midi_dir}')
