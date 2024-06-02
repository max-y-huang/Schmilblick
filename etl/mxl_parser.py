from collections import defaultdict

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
        if self.parse_in_place:
            return self.data
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
    
    parse_in_place = False

    default_objects_to_parse = {
        'divisions': lambda x: x.tag == 'divisions',
        'tempo': lambda x: x.tag == 'sound' and 'tempo' in x.attrib,
        'backup': lambda x: x.tag == 'backup',
        'duration': lambda x: x.tag == 'duration'
    }

    def handle_divisions(self, state, obj):
        state.divisions = int(obj.text)

    def handle_tempo(self, state, obj):
        state.tempo = float(obj.get('tempo'))

    def handle_backup(self, state, obj):
        duration = state.normalize_duration(int(obj.find('duration').text))
        state.time -= duration

    def handle_duration(self, state, obj):
        duration = state.normalize_duration(int(obj.text))
        state.time += duration


class PartParser(ParserBase):
    
    objects_to_parse = {
        'score_part': lambda x: x.tag == 'score-part',
        'part': lambda x: x.tag == 'part',
    }

    def handle_score_part(self, state, obj):
        part_id = obj.get('id')
        part_name = obj.find('part-name').text
        state.acc.append({ 'id': part_id, 'name': part_name })
    
    def handle_part(self, state, obj):
        part_id = obj.get('id')
        for part in state.acc:
            if part['id'] == part_id:
                part['obj'] = obj


class MeasureParser(ParserBase):

    parse_in_place = True
    
    objects_to_parse = {
        'measure': lambda x: x.tag == 'measure',
    }

    def handle_measure(self, state, obj):
        number = int(obj.get('number')) - 1
        for note in obj.findall('note'):
            note.attrib['measure'] = number


class RepeatParser(ParserBase):
    # NOTE: assumes no nested repeats

    objects_to_parse = {
        'measure': lambda x: x.tag == 'measure',
    }

    def handle_measure(self, state, obj):
        repeat = obj.find('.//repeat')
        if repeat is None:
            return
        print(obj.get('number'), repeat.get('direction'))


class NoteParser(ParserBase):

    class Note:
        def __init__(self, time, duration, pitch):
            self.time = time
            self.duration = duration
            self.pitch = pitch
        
        def as_json(self):
            return { 'time': self.time, 'duration': self.duration, 'pitch': self.pitch }
    
    class NoteList:
        def __init__(self):
            self.notes = defaultdict(lambda: [])
            self.last_measure = 0
            self.repeats = []

        def add(self, note, measure):
            if measure > self.last_measure:
                self.last_measure = measure
            self.notes[measure].append(note)
        
        def set_repeats(self, repeats):
            self.repeats = repeats
        
        def flatten(self):
            # ret = []
            # measure = 0
            # while measure <= self.last_measure:
            #     next_repeat = None if len(self.repeats) == 0 else self.repeats[0]

            #     ret += self.notes[measure]

            #     if next_repeat is not None and next_repeat[1] == measure:  # end repeat
            #         measure = next_repeat[0]
            #         self.repeats.pop(0)
            #     else:
            #         measure += 1
            ret = []
            for measure in range(self.last_measure + 1):
                ret += [n for n in self.notes[measure]]
            return ret
        
        def as_json(self):
            ret = []
            for measure in range(self.last_measure + 1):
                ret.append([n.as_json() for n in self.notes[measure]])
            return ret
                

    def parse(self):
        RepeatParser(self.data).parse()
        self.data = MeasureParser(self.data).parse()
        notes = super().parse()
        notes.sort(key=lambda x: x[0].time)  # sort notes chronologically before merging
        # merge tied notes
        merged_notes = []
        last_note_by_pitch = {}
        for note, measure, is_tied in notes:
            if is_tied:
                last_note_by_pitch[note.pitch].duration += note.duration
            else:
                last_note_by_pitch[note.pitch] = note
                merged_notes.append((note, measure))
        notes = merged_notes
        # add notes to note list
        note_list = NoteParser.NoteList()
        for note, measure in notes:
            note_list.add(note, measure)
        return note_list

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
        'note': lambda x: x.tag == 'note',
    }
    
    def handle_note(self, state, obj):
        # get note information
        measure = obj.get('measure')
        is_grace_note = obj.find('grace') is not None
        is_chord = obj.find('chord') is not None
        is_pitched = obj.find('pitch') is not None
        is_rest = obj.find('rest') is not None
        is_tied = obj.find('.//tie[@type!="start"]') is not None
        # skip grace notes
        if is_grace_note:
            return
        duration = state.normalize_duration(float(obj.find('duration').text))
        # handle start time for chord notes
        if is_chord:
            state.time = state.get_prev_time()  # go to start time of previous note
        # save pitched notes
        if not is_rest and is_pitched:
            pitch = self.pitch_xml_to_int(obj.find('pitch'))
            state.acc.append((NoteParser.Note(state.time, duration, pitch), measure, is_tied))
        # use up note duration
        state.time += duration
