from mxl_parser.parser_base import ParserBase

class NoteParser(ParserBase):

    class Note:
        def __init__(self, time_offset, duration, pitch):
            self.measure = None
            self.time_offset = time_offset
            self.duration = duration
            self.pitch = pitch
        
        @property
        def time(self):
            return self.measure.time + self.time_offset
        
        def to_json(self):
            return { 'time': self.time, 'duration': self.duration, 'pitch': self.pitch }
    
    def __init__(self, data, measure_list):
        super().__init__(data)
        self.measure_list = measure_list
    
    def pre_parse(self, state):
        state.notes = []
        state.measure_list = self.measure_list
    
    def parse(self):
        parsed = super().parse()
        notes = parsed.notes
        # merge tied notes
        last_note_by_pitch = {}
        for note, measure, is_tied in notes:
            if is_tied:
                last_note_by_pitch[note.pitch].duration += note.duration
                measure.notes.remove(note)
            else:
                last_note_by_pitch[note.pitch] = note
        return parsed.measure_list

    def pitch_xml_to_int(self, obj):
        _STEP_OFFSET = { 'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11 }
        step = obj.find('step').text
        octave = int(obj.find('octave').text)
        try:
            alter = int(obj.find('alter').text)
        except:
            alter = 0
        return 12 + octave * 12 + _STEP_OFFSET[step] + alter

    objects_to_parse = {
        'note': {
            'match_fn': lambda x: x.tag == 'note',
        }
    }
    
    def handle_note(self, state, obj):
        measure_num = obj.get('measure')
        measure = state.measure_list[measure_num]
        # get note information
        is_grace_note = obj.find('grace') is not None
        is_chord = obj.find('chord') is not None
        is_pitched = obj.find('pitch') is not None
        is_rest = obj.find('rest') is not None
        is_tied = obj.find('.//tie[@type!="start"]') is not None
        # skip grace notes
        if is_grace_note:
            return
        time = state.get_prev_time() if is_chord else state.time
        duration = state.normalize_duration(float(obj.find('duration').text))
        # save pitched notes
        if not is_rest and is_pitched:
            pitch = self.pitch_xml_to_int(obj.find('pitch'))
            time_offset = time - measure.time
            note = NoteParser.Note(time_offset, duration, pitch)
            measure.add(note)
            state.notes.append((note, measure, is_tied))
