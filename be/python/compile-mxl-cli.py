#!/usr/bin/env python

import copy
import os
import json
import pathlib
import argparse
import midiutil

from mxl_compiler.compiler import MXLCompiler


_OUT_MIDI_DIR = './out/<SCORE>/<PART>.mid'
_OUT_DATA_DIR = './out/<SCORE>/<PART>.json'


def save_part_as_json(dir, part):
    with open(dir, 'w') as f:
        print(json.dumps(part), file=f)


def save_notes_as_midi(dir, notes):
    track, channel = 0, 0
    MyMIDI = midiutil.MIDIFile(1, deinterleave=False)
    MyMIDI.addTempo(track, channel, 60)  # 60 bpm = 1 beat per second
    for note in notes:
        MyMIDI.addNote(track, channel, note['pitch'], note['time'], note['duration'], 127)
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
    arg_parser.add_argument('-f', '--file', help='the MusicXML score to use', required=True)
    arg_parser.add_argument('-p', '--preview', help='preview a parsed part in MIDI', action='store_true')
    args = arg_parser.parse_args()

    score_name = os.path.basename(args.file).rstrip('.mxl')
    pathlib.Path(f'./out/{score_name}').mkdir(parents=True, exist_ok=True)

    parts = MXLCompiler.from_file(args.file).compile()
    for part in parts:
        out_data_dir = _OUT_DATA_DIR.replace('<SCORE>', score_name).replace('<PART>', part['id'])
        out_midi_dir = _OUT_MIDI_DIR.replace('<SCORE>', score_name).replace('<PART>', part['id'])
        save_part_as_json(out_data_dir, part['obj'])
        save_notes_as_midi(out_midi_dir, part['obj']['notes'])
    
    if args.preview:
        prompt_preview(score_name, parts)
