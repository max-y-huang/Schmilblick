class BaseHandler:
    class State:
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
    
    def run(self):
        state = BaseHandler.State()
        self.pre_run(state)
        for obj, obj_type in self.get_targets(self.data):
            eval(f'self.handle_{obj_type}')(state, obj)
        return state

    def pre_run(self, state):
        pass

    def get_targets(self, obj):
        targets = {
            **self.targets,
            **self.default_targets,
        }
        ret = []
        matched_types = [(k, v) for k, v in targets.items() if v['match_fn'](obj)]
        for obj_type, type_data in matched_types:
            ret.append((obj, obj_type))
            if 'terminate' in type_data and type_data['terminate'] == True:
                return ret
        for child in obj:
            ret += self.get_targets(child)
        return ret

    ################################

    default_targets = {
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
