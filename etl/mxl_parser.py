import copy
import re

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
        matched_types = [(k, v) for k, v in to_parse.items() if v['match_fn'](obj)]
        for obj_type, type_data in matched_types:
            ret.append((obj, obj_type))
            if 'terminate' in type_data and type_data['terminate'] == True:
                return ret
        for child in obj:
            ret += self.get_objects(child)
        return ret

    ################################

    default_objects_to_parse = {
        'divisions': {
            'match_fn': lambda x: x.tag == 'divisions',
        },
        'tempo': {
            'match_fn': lambda x: x.tag == 'sound' and 'tempo' in x.attrib,
        },
        'backup': {
            'match_fn': lambda x: x.tag == 'backup' and x.find('duration') is not None,
        },
        'duration': {
            'match_fn': lambda x: x.tag == 'note' and x.find('duration') is not None and x.find('chord') is None,
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
        state.parts = {}
    
    def parse(self):
        state = super().parse()
        state.parts = list(state.parts.values())
        return state
        
    objects_to_parse = {
        'score_part': {
            'match_fn': lambda x: x.tag == 'score-part',
        },
        'part': {
            'match_fn': lambda x: x.tag == 'part',
        },
    }

    def handle_score_part(self, state, obj):
        part_id = obj.get('id')
        part_name = obj.find('part-name').text
        state.parts[part_id] = { 'id': part_id, 'name': part_name }
    
    def handle_part(self, state, obj):
        part_id = obj.get('id')
        state.parts[part_id]['obj'] = obj


class MeasureParser(ParserBase):

    class Measure:
        def __init__(self, number, duration):
            self.measure_list = None
            self.number = number
            self.duration = duration
            self.notes = []
        
        @property
        def time(self):
            ret = 0
            for m in range(self.number):
                ret += self.measure_list[m].duration
            return ret
        
        def add(self, note):
            note.measure = self
            self.notes.append(note)
        
        def to_json(self):
            return [ n.to_json() for n in self.notes ]
    
    class MeasureList:
        def __init__(self):
            self.num_measures = 0
            self.items = {}
            self.jumps = []
        
        def __getitem__(self, key):
            return self.items[key]

        def set_jumps(self, jumps):
            self.jumps = jumps
        
        def add(self, measure):
            if measure.number + 1 > self.num_measures:
                self.num_measures = measure.number + 1
            measure.measure_list = self
            self.items[measure.number] = measure
        
        def flatten(self):
            jumps = copy.deepcopy(self.jumps)
            ret = MeasureParser.MeasureList()
            itr, counter = 0, 0
            while itr < self.num_measures:
                next_jump = None if len(jumps) == 0 else jumps[0]

                measure_copy = copy.deepcopy(self.items[itr])
                measure_copy.number = counter
                ret.add(measure_copy)

                if next_jump is not None and next_jump.src == itr:  # handle jump
                    itr = next_jump.dst
                    jumps.pop(0)
                else:
                    itr += 1
                
                counter += 1
            return ret
        
        def get_notes(self):
            ret = []
            flattened_measures = self.flatten()
            for m in range(flattened_measures.num_measures):
                measure = flattened_measures[m]
                ret += measure.notes
            return ret
        
        def to_json(self):
            ret = []
            flattened_measures = self.flatten()
            for m in range(flattened_measures.num_measures):
                measure = flattened_measures[m]
                ret += measure.to_json()
            return ret

    def pre_parse(self, state):
        state.src = self.data
        state.measure_times = {}
        state.num_measures = 0
    
    def parse(self):
        state = super().parse()
        state.measure_list = MeasureParser.MeasureList()
        for m in range(state.num_measures):
            time = state.measure_times[m]
            next_time = state.time
            if m + 1 < state.num_measures:
                next_time = state.measure_times[m + 1]
            duration = next_time - time
            state.measure_list.add(MeasureParser.Measure(m, duration))
        return state
            
    
    objects_to_parse = {
        'measure': {
            'match_fn': lambda x: x.tag == 'measure',
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

    class Jump:
        def __init__(self, src, dst):
            self.src = src
            self.dst = dst

    def pre_parse(self, state):
        state.repeats = []
        state.repeat_start_itr = 0
        state.voltas = defaultdict(lambda: dict())  # self.voltas[repeat start measure][nth time through] = volta start measure
        state.volta_itr = None
        state.jumps = []
    
    def parse(self):
        # FIXME: assumes that the earliest volta (for a repeat) is for the 1st time through
        def add_repeat_jumps(repeat):
            start, end, volta_num = repeat
            state.jumps.append(RepeatParser.Jump(end, start))  # jump to repeat start
            if volta_num is not None:
                voltas = state.voltas[start]
                state.jumps.append(RepeatParser.Jump(voltas[1] - 1, voltas[volta_num + 1]))  # jump to correct volta
        
        state = super().parse()
        return state

    objects_to_parse = {
        'measure': {
            'match_fn': lambda x: x.tag == 'measure',
        },
    }

    def handle_measure(self, state, obj):
        number = int(obj.get('number')) - 1
        start_repeat = obj.find('.//repeat[@direction="forward"]')
        end_repeat = obj.find('.//repeat[@direction="backward"]')
        ending = obj.find('.//ending[@type="start"]')
        # set current repeat
        if start_repeat is not None:
            state.repeat_start_itr = number
            state.volta_itr = None
        # store repeat information
        if end_repeat is not None:
            state.repeats.append((state.repeat_start_itr, number, state.volta_itr))
        # store volta information
        if ending is not None:
            volta_num = int(ending.get('number'))
            state.voltas[state.repeat_start_itr][volta_num] = number
            state.volta_itr = volta_num


class DSAlCodaParser(ParserBase):

    def pre_parse(self, state):
        state.ds_al_codas = []
        state.segnos = defaultdict(lambda: None)           # self.segnos[symbol] = measure
        state.dalsegnos = defaultdict(lambda: None)        # self.dalsegnos[measure] = (segno symbol, coda text)
        state.tocodas = defaultdict(lambda: None)          # self.tocodas[symbol] = measure
        state.tocodas_by_text = defaultdict(lambda: None)  # self.tocodas_by_text[text] = symbol
        state.codas = defaultdict(lambda: None)            # self.codas[symbol] = measure

        state.segnos['_capo'] = 0  # reduce dacapo to dalsegno
    
    def parse(self):
        state = super().parse()
        for segno_src, (segno_symbol, coda_text) in state.dalsegnos.items():
            coda_symbol = state.tocodas_by_text[coda_text]
            segno_dst = state.segnos[segno_symbol]
            coda_src = state.tocodas[coda_symbol]
            coda_dst = state.codas[coda_symbol]
            state.ds_al_codas.append((segno_src, segno_dst, coda_src, coda_dst))
        return state

    objects_to_parse = {
        'measure': {
            'match_fn': lambda x: x.tag == 'measure',
        },
    }

    def handle_measure(self, state, obj):
        def extract_coda_text(text, regexp):
            split = re.split(regexp, text, flags=re.IGNORECASE)
            if len(split) == 1:
                return None
            return split[-1].strip().lower()
        
        number = int(obj.get('number')) - 1
        segno = obj.find('.//sound[@segno]')
        dalsegno = obj.find('.//sound[@dalsegno]')
        dalsegno_text = obj.find('.//sound[@dalsegno]..//words')
        coda = obj.find('.//sound[@coda]')
        tocoda = obj.find('.//sound[@tocoda]')
        tocoda_text = obj.find('.//sound[@tocoda]..//words')
        # store segno information
        if segno is not None:
            symbol = segno.get('segno')
            state.segnos[symbol] = number
        # store dalsegno information
        if dalsegno is not None:
            symbol = dalsegno.get('dalsegno')
            coda_text = extract_coda_text(dalsegno_text.text, "(^|\s)al\s")
            state.dalsegnos[number] = (symbol, coda_text)
        # store coda information
        if coda is not None:
            symbol = coda.get('coda')
            state.codas[symbol] = number
        # store tocoda information
        if tocoda is not None:
            symbol = tocoda.get('tocoda')
            text = extract_coda_text(tocoda_text.text, "(^|\s)to\s")
            state.tocodas[symbol] = number
            state.tocodas_by_text[text] = symbol


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


class MXLParser():

    def __init__(self, data):
        self.data = data
    
    def parse(self):

        p_parts = PartParser(self.data).parse()
        for part in p_parts.parts:
            p_measures = MeasureParser(part['obj']).parse()

            p_repeats = RepeatParser(part['obj']).parse()
            print(p_repeats.repeats)

            p_ds_al_codas = DSAlCodaParser(part['obj']).parse()
            print(p_ds_al_codas.ds_al_codas)

            p_notes = NoteParser(p_measures.src, p_measures.measure_list).parse()
            part['obj'] = p_notes

        return p_parts.parts
