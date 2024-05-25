#!/usr/bin/env python

import os
import json
import pathlib
import argparse
import midiutil
import zipfile
import tempfile

from xml.etree import ElementTree


_IN_MXL_DIR = './in/score.mxl'
_OUT_MIDI_DIR = './out/preview_<ID>.mid'
_OUT_DATA_DIR = './out/data_<ID>.json'


class Note:
    def __init__(self, start, duration, pitch):
        self.start = start
        self.duration = duration
        self.pitch = pitch
    
    def as_json(self):
        return { 'start': self.start, 'duration': self.duration, 'pitch': self.pitch }


def import_mxl_as_xml(dir):
    _UNCOMPRESSED_SCORE_DIR = 'score.xml'
    # unzip file to temporary directory
    with zipfile.ZipFile(dir, 'r') as zip:
        zip_dir = tempfile.mkdtemp()
        zip.extractall(zip_dir)
    # get xml from temporary directory
    with open(os.path.join(zip_dir, _UNCOMPRESSED_SCORE_DIR)) as f:
        obj = ElementTree.parse(f)
    return obj


def pitch_xml_to_int(obj):
    _STEP_OFFSET = { 'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11 }
    step = obj.find('step').text.strip()
    octave = int(obj.find('octave').text.strip())
    try:
        alter = int(obj.find('alter').text.strip())
    except:
        alter = 0
    return octave * 12 + _STEP_OFFSET[step] + alter


def parse_xml_part(obj):
    def parse_notes(obj):
        notes = []
        prev_time, time = 0, 0
        for note_obj in obj.findall('.//note'):
            # get note information
            is_grace_note = note_obj.find('grace') is not None
            is_chord = note_obj.find('chord') is not None
            is_pitched = note_obj.find('pitch') is not None
            is_rest = note_obj.find('rest') is not None
            is_tied = note_obj.find('.//tie[@type!="start"]') is not None
            # skip grace notes
            if is_grace_note:
                continue
            # handle start time for chord notes
            if is_chord:
                time = prev_time
            # get duration
            duration = int(note_obj.find('duration').text.strip())
            # save pitched notes
            if not is_rest and is_pitched:
                pitch = pitch_xml_to_int(note_obj.find('pitch'))
                notes.append((Note(time, duration, pitch), is_tied))
            # use up note duration
            prev_time = time
            time += duration
        return notes
    
    def merge_tied_notes(notes):
        merged_notes = []
        last_note_by_pitch = {}
        for note, is_tied in notes:
            if is_tied:
                last_note_by_pitch[note.pitch].duration += note.duration
            else:
                last_note_by_pitch[note.pitch] = note
                merged_notes.append(note)
        return merged_notes
    
    return merge_tied_notes(parse_notes(obj))


def save_notes_as_json(notes, part, id):
    with open(_OUT_DATA_DIR.replace('<ID>', id), 'w') as f:
        note_data = [ note.as_json() for note in notes ]
        data = { 'part': part, 'notes': note_data }
        print(json.dumps(data), file=f)


def save_notes_as_midi(notes, id):
    track, channel = 0, 0
    MyMIDI = midiutil.MIDIFile(1)
    MyMIDI.addTempo(track, channel, 108 * 12)
    for note in notes:
        if type(note) is Note:
            MyMIDI.addNote(track, channel, note.pitch, note.start, note.duration, 127)
    with open(_OUT_MIDI_DIR.replace('<ID>', id), 'wb') as f:
        MyMIDI.writeFile(f)


if __name__ == '__main__':

    arg_parser = argparse.ArgumentParser()
    arg_parser.add_argument('-p', '--preview', help='the part to preview in MIDI form')
    args = arg_parser.parse_args()

    pathlib.Path('./out').mkdir(parents=True, exist_ok=True) 

    score_obj = import_mxl_as_xml(_IN_MXL_DIR)
    for part_obj in score_obj.findall('part'):
        part_id = part_obj.get('id')
        part_name = score_obj.find(f'.//score-part[@id="{part_id}"]/part-name').text
        notes = parse_xml_part(part_obj)
        save_notes_as_json(notes, part_name, part_id)
        save_notes_as_midi(notes, part_id)
    
    if args.preview:
        os.system(f'start {_OUT_MIDI_DIR.replace("<ID>", args.preview)}')
