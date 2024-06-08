import copy

from mxl_parser.parser_base import ParserBase

class MeasureParser(ParserBase):

    class Jump:
        def __init__(self, src, dst):
            self.src = src
            self.dst = dst

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
