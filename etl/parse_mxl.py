#!/usr/bin/env python

import os
import json
import pathlib
import argparse
import midiutil
import zipfile
import tempfile

from xml.etree import ElementTree


_IN_MXL_DIR = './in/<TEST_CASE>/score.mxl'
_OUT_MIDI_DIR = './out/<TEST_CASE>/preview_<PART>.mid'
_OUT_DATA_DIR = './out/<TEST_CASE>/data_<PART>.json'


class Event:
    def __init__(self, time, data):
        self.time = time
        self.data = data
    
    def as_json(self):
        return { 'time': self.time, 'data': self.data }


class ParserBase:
    
    class ParseState:
        @property
        def time(self):
            return self._time
        
        @time.setter
        def time(self, value):
            self._prev_time = self._time
            self._time = value
        
        def get_prev_time(self):
            return self._prev_time

        def __init__(self):
            self.acc = []
            self._time = 0
            self.tempo = 108 * 2
            self.divisions = 1
        
        def normalize_duration(self, duration):
            beats_per_minute = self.tempo
            divisions_per_beat = self.divisions
            minutes_per_second = 1 / 60
            mult = 1 / (beats_per_minute * divisions_per_beat * minutes_per_second)  # in seconds per division
            return duration * mult

    def __init__(self, data):
        self.data = data
    
    def parse(self):
        state = self.ParseState()
        for obj, obj_type in self.get_objects(self.data):
            eval(f'self.handle_{obj_type}')(state, obj)
        return state.acc

    def get_objects(self, obj):
        objs_to_parse = {**self.objects_to_parse, **self.default_objects_to_parse}
        obj_type = next((key for key, val in objs_to_parse.items() if val(obj)), None)  # get matching type of interest
        if obj_type is not None:
            return [(obj, obj_type)]
        ret = []
        for child in obj:
            ret += self.get_objects(child)
        return ret

    ################################
    
    default_objects_to_parse = {
        'divisions': lambda x: x.tag == 'divisions',
        'tempo': lambda x: x.tag == 'sound' and 'tempo' in x.attrib,
        'backup': lambda x: x.tag == 'backup',
        'duration': lambda x: x.tag == 'duration'
    }

    def handle_divisions(self, state, obj):
        state.divisions = int(obj.text.strip())

    def handle_tempo(self, state, obj):
        state.tempo = float(obj.get('tempo').strip())

    def handle_backup(self, state, obj):
        duration = state.normalize_duration(int(obj.find('duration').text.strip()))
        state.time -= duration

    def handle_duration(self, state, obj):
        duration = state.normalize_duration(int(obj.text.strip()))
        state.time += duration


class PartParser(ParserBase):
    
    objects_to_parse = {
        'score_part': lambda x: x.tag == 'score-part',
        'part': lambda x: x.tag == 'part',
    }

    def handle_score_part(self, state, obj):
        part_id = obj.get('id').strip()
        part_name = obj.find('part-name').text.strip()
        state.acc.append({ 'id': part_id, 'name': part_name })
    
    def handle_part(self, state, obj):
        part_id = obj.get('id')
        for part in state.acc:
            if part['id'] == part_id:
                part['data'] = obj


class NoteParser(ParserBase):

    def parse(self):
        notes = super().parse()
        notes.sort(key=lambda x: x[0].time)  # sort notes chronologically before merging
        # merge tied notes
        merged_notes = []
        last_note_by_pitch = {}
        for note, is_tied in notes:
            pitch = note.data['pitch']
            if is_tied:
                last_note_by_pitch[pitch].data['duration'] += note.data['duration']
            else:
                last_note_by_pitch[pitch] = note
                merged_notes.append(note)
        return merged_notes

    objects_to_parse = {
        'note': lambda x: x.tag == 'note',
    }
    
    def handle_note(self, state, obj):
        # get note information
        is_grace_note = obj.find('grace') is not None
        is_chord = obj.find('chord') is not None
        is_pitched = obj.find('pitch') is not None
        is_rest = obj.find('rest') is not None
        is_tied = obj.find('.//tie[@type!="start"]') is not None
        # skip grace notes
        if is_grace_note:
            return
        duration = state.normalize_duration(float(obj.find('duration').text.strip()))
        # handle start time for chord notes
        if is_chord:
            state.time = state.get_prev_time()  # go to start time of previous note
        # save pitched notes
        if not is_rest and is_pitched:
            pitch = pitch_xml_to_int(obj.find('pitch'))
            state.acc.append((Event(state.time, {'duration': duration, 'pitch': pitch}), is_tied))
        # use up note duration
        state.time += duration


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


def pitch_xml_to_int(obj):
    _STEP_OFFSET = { 'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11 }
    step = obj.find('step').text.strip()
    octave = int(obj.find('octave').text.strip())
    try:
        alter = int(obj.find('alter').text.strip())
    except:
        alter = 0
    return 12 + octave * 12 + _STEP_OFFSET[step] + alter


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
        if type(note) is Event:
            MyMIDI.addNote(track, channel, note.data['pitch'], note.time, note.data['duration'], 127)
    with open(dir, 'wb') as f:
        MyMIDI.writeFile(f)


if __name__ == '__main__':

    arg_parser = argparse.ArgumentParser()
    arg_parser.add_argument('-tc', '--test_case', help='the test case to use', required=True)
    arg_parser.add_argument('-p', '--preview', help='the part to preview in MIDI form', action='store_true')
    args = arg_parser.parse_args()

    test_case = args.test_case
    pathlib.Path(f'./out/{test_case}').mkdir(parents=True, exist_ok=True)

    in_mxl_dir = _IN_MXL_DIR.replace('<TEST_CASE>', test_case)
    score_obj = import_mxl_as_xml(in_mxl_dir).getroot()

    parts = PartParser(score_obj).parse()
    for part in parts:
        out_data_dir = _OUT_DATA_DIR.replace('<TEST_CASE>', test_case).replace('<PART>', part['id'])
        out_midi_dir = _OUT_MIDI_DIR.replace('<TEST_CASE>', test_case).replace('<PART>', part['id'])
        notes = NoteParser(part['data']).parse()
        save_notes_as_json(out_data_dir, notes, part['name'])
        save_notes_as_midi(out_midi_dir, notes)
    
    if args.preview:
        print('Which part do you want to preview?')
        for i, part in enumerate(parts):
            print(f'\t[{i + 1}]: {part["name"]}')
        part = parts[int(input('> ')) - 1]['id']
        os.system(f'start {_OUT_MIDI_DIR.replace("<TEST_CASE>", test_case).replace("<PART>", part)}')