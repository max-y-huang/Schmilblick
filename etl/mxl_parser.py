import copy

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
        self.pre_parse(state)
        for obj, obj_type in self.get_objects(self.data):
            eval(f'self.handle_{obj_type}')(state, obj)
        return state

    def pre_parse(self, state):
        pass

    def get_objects(self, obj):
        to_parse = {
            **self.objects_to_parse,
            **self.default_objects_to_parse,
        }
        ret = []
        matched_types = [(k, v) for k, v in to_parse.items() if v['match'](obj)]
        for (obj_type, type_data) in matched_types:
            ret.append((obj, obj_type))
            if 'terminate' in type_data and type_data['terminate'] == True:
                return ret
        for child in obj:
            ret += self.get_objects(child)
        return ret

    ################################

    default_objects_to_parse = {
        'divisions': {
            'match': lambda x: x.tag == 'divisions',
        },
        'tempo': {
            'match': lambda x: x.tag == 'sound' and 'tempo' in x.attrib,
        },
        'backup': {
            'match': lambda x: x.tag == 'backup' and x.find('duration') is not None,
        },
        'duration': {
            'match': lambda x: x.tag == 'note' and x.find('duration') is not None and x.find('chord') is None,
        },
    }

    def handle_divisions(self, state, obj):
        state.divisions = int(obj.text)

    def handle_tempo(self, state, obj):
        state.tempo = float(obj.get('tempo'))

    def handle_backup(self, state, obj):
        duration = state.normalize_duration(int(obj.find('duration').text))
        state.time -= duration

    def handle_duration(self, state, obj):
        duration = state.normalize_duration(int(obj.find('duration').text))
        state.time += duration


class PartParser(ParserBase):

    def pre_parse(self, state):
        state.parts = []
        
    objects_to_parse = {
        'score_part': {
            'match': lambda x: x.tag == 'score-part',
        },
        'part': {
            'match': lambda x: x.tag == 'part',
        },
    }

    def handle_score_part(self, state, obj):
        part_id = obj.get('id')
        part_name = obj.find('part-name').text
        state.parts.append({ 'id': part_id, 'name': part_name })
    
    def handle_part(self, state, obj):
        part_id = obj.get('id')
        for part in state.parts:
            if part['id'] == part_id:
                part['obj'] = obj


class MeasureParser(ParserBase):

    class Measure:
        def __init__(self, number, duration):
            self.parent_list = None
            self.number = number
            self.duration = duration
            self.notes = []
        
        @property
        def time(self):
            ret = 0
            for m in range(self.number):
                ret += self.parent_list[m].duration
            return ret
        
        def add(self, note):
            note.measure = self
            self.notes.append(note)
    
    class MeasureList:
        def __init__(self):
            self.num_measures = 0
            self.measures = {}
            self.repeats = []
        
        def __getitem__(self, key):
            return self.measures[key]

        def set_repeats(self, repeats):
            self.repeats = repeats
        
        def add(self, measure):
            if measure.number + 1 > self.num_measures:
                self.num_measures = measure.number + 1
            measure.parent_list = self
            self.measures[measure.number] = measure
        
        def flatten(self):
            ret = MeasureParser.MeasureList()
            m = 0
            m_itr = 0
            repeats = copy.deepcopy(self.repeats)
            while m_itr < self.num_measures:
                next_repeat = None if len(repeats) == 0 else repeats[0]

                measure_copy = copy.deepcopy(self.measures[m_itr])
                measure_copy.number = m
                ret.add(measure_copy)

                if next_repeat is not None and next_repeat[1] == m_itr:  # end repeat
                    m_itr = next_repeat[0]
                    repeats.pop(0)
                else:
                    m_itr += 1
                
                m += 1
            return ret
        
        def get_notes(self):
            ret = []
            flattened_measures = self.flatten()
            for m in range(flattened_measures.num_measures):
                measure = flattened_measures[m]
                ret += measure.notes
            return ret
        
        def as_json(self):
            ret = []
            flattened_measures = self.flatten()
            for m in range(flattened_measures.num_measures):
                measure = flattened_measures[m]
                ret.append({ 'time': measure.time, 'notes': [ n.as_json() for n in measure.notes ] })
            return ret

    def pre_parse(self, state):
        state.src = self.data
        state.measure_times = {}
        state.num_measures = 0
    
    def parse(self):
        state = super().parse()
        state.measures = MeasureParser.MeasureList()
        for m in range(state.num_measures):
            time = state.measure_times[m]
            next_time = state.time
            if m + 1 < state.num_measures:
                next_time = state.measure_times[m + 1]
            duration = next_time - time
            state.measures.add(MeasureParser.Measure(m, duration))
        return state
            
    
    objects_to_parse = {
        'measure': {
            'match': lambda x: x.tag == 'measure',
        },
    }

    def handle_measure(self, state, obj):
        number = int(obj.get('number')) - 1
        if number + 1 > state.num_measures:
            state.num_measures = number + 1
        
        state.measure_times[number] = state.time

        for note in obj.findall('note'):
            note.attrib['measure'] = number

class RepeatParser(ParserBase):
    # NOTE: assumes no nested repeats

    def pre_parse(self, state):
        state.repeats = []

    objects_to_parse = {
        'measure': {
            'match': lambda x: x.tag == 'measure',
        },
    }

    def handle_measure(self, state, obj):
        repeat = obj.find('.//repeat')
        if repeat is None:
            return
        
        number = int(obj.get('number')) - 1
        direction = repeat.get('direction')
        
        if direction == 'forward':
            state.repeats.append((number, None))
        else:
            if len(state.repeats) == 0:
                state.repeats.append((0, None))
            state.repeats[-1] = (state.repeats[-1][0], number)


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
        
        def as_json(self):
            return { 'time': self.time, 'time_offset': self.time_offset, 'duration': self.duration, 'pitch': self.pitch }
    
    def pre_parse(self, state):
        state.notes = []
        state.measures = self.measures
    
    def parse(self):
        # parse measures
        parsed_measures = MeasureParser(self.data).parse()
        self.data = parsed_measures.src
        self.measures = parsed_measures.measures
        self.measures.set_repeats(RepeatParser(self.data).parse().repeats)
        # parse notes
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
        return parsed.measures

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
            'match': lambda x: x.tag == 'note',
        }
    }
    
    def handle_note(self, state, obj):
        measure_num = obj.get('measure')
        measure = state.measures[measure_num]
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
