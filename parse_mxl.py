import os
import json
import pathlib
import argparse
import midiutil

from xml.etree import ElementTree


_IN_XML_FILE = './in/score.xml'
_OUT_MIDI_FILE = './out/preview.mid'
_OUT_NOTES_FILE = './out/notes.json'


class Note:
    def __init__(self, start, duration, pitch):
        self.start = start
        self.duration = duration
        self.pitch = pitch
    
    def as_json(self):
        return { 'start': self.start, 'duration': self.duration, 'pitch': self.pitch }


def preview(notes):
    track, channel = 0, 0
    MyMIDI = midiutil.MIDIFile(1)
    MyMIDI.addTempo(track, channel, 108 * 4)
    for note in notes:
        if type(note) is Note:
            MyMIDI.addNote(track, channel, note.pitch, note.start, note.duration, 127)
    with open(_OUT_MIDI_FILE, 'wb') as f:
        MyMIDI.writeFile(f)
    os.system(f'start {_OUT_MIDI_FILE}')  # FIXME: works on Windows only


def import_xml(dir):
    with open(dir) as f:
        xml = ElementTree.parse(f)
    return xml


def extract_note_xmls(xml):
    ret = []
    if xml.tag == 'note':
        ret.append(xml)
        # no nested notes
    else:
        for child in xml:
            ret += extract_note_xmls(child)
    return ret


def pitch_xml_to_int(xml):
    _STEP_OFFSET = { 'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11 }
    step = xml.find('step').text.strip()
    octave = int(xml.find('octave').text.strip())
    try:
        alter = int(xml.find('alter').text.strip())
    except:
        alter = 0
    return octave * 12 + _STEP_OFFSET[step] + alter


def parse_xml_part(xml):
    def parse_notes(xml):
        notes = []
        time = 0
        for xml_note in extract_note_xmls(xml):
            # get note information
            is_grace_note = xml_note.find('grace') is not None
            is_chord = xml_note.find('chord') is not None
            is_rest = xml_note.find('rest') is not None
            try:
                is_tied = xml_note.find('notations').find('tied').get('type') != 'start'
            except:
                is_tied = False
            # skip grace notes
            if is_grace_note:
                continue
            # handle start time for chord notes
            if is_chord:
                time -= notes[-1][0].duration
            # parse and save note
            duration = int(xml_note.find('duration').text.strip())
            if not is_rest:
                pitch = pitch_xml_to_int(xml_note.find('pitch'))
                notes.append((Note(time, duration, pitch), is_tied))
            # use up note duration
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
    
    return merge_tied_notes(parse_notes(xml))


def save_notes_as_json(notes):
    with open(_OUT_NOTES_FILE, 'w') as f:
        data = [ note.as_json() for note in notes ]
        print(json.dumps(data), file=f)



if __name__ == '__main__':

    arg_parser = argparse.ArgumentParser()
    arg_parser.add_argument('-p', '--preview', action='store_true', help='saves and plays a MIDI file corresponding to the parsed input')
    args = arg_parser.parse_args()

    pathlib.Path('./out').mkdir(parents=True, exist_ok=True) 

    xml_score = import_xml(_IN_XML_FILE)
    xml_parts = xml_score.findall('part')
    for xml_part in xml_parts:
        notes = parse_xml_part(xml_part)
        save_notes_as_json(notes)
        if args.preview:
            preview(notes)
