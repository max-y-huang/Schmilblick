from collections import defaultdict

from parser_base import ParserBase

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
