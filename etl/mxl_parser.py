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
        state = ParserBase.ParseState()
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
                part['obj'] = obj


class NoteParser(ParserBase):

    class Note:
        def __init__(self, time, data):
            self.time = time
            self.data = data
        
        def as_json(self):
            return { 'time': self.time, 'data': self.data }

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

    def pitch_xml_to_int(self, obj):
        _STEP_OFFSET = { 'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11 }
        step = obj.find('step').text.strip()
        octave = int(obj.find('octave').text.strip())
        try:
            alter = int(obj.find('alter').text.strip())
        except:
            alter = 0
        return 12 + octave * 12 + _STEP_OFFSET[step] + alter

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
            pitch = self.pitch_xml_to_int(obj.find('pitch'))
            state.acc.append((NoteParser.Note(state.time, {'duration': duration, 'pitch': pitch}), is_tied))
        # use up note duration
        state.time += duration
