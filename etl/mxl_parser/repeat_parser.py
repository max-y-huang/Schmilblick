from collections import defaultdict

from mxl_parser.parser_base import ParserBase

class RepeatParser(ParserBase):
    # NOTE: assumes no nested repeats
    
    class Repeat:
        def __init__(self, start, end, nth_volta):
            self.start = start
            self.end = end
            self.nth_volta = nth_volta

    def pre_parse(self, state):
        state.repeats = []
        state.repeat_start_itr = 0
        state.voltas = defaultdict(lambda: dict())  # self.voltas[repeat start measure][nth time through] = volta start measure
        state.volta_itr = None

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
            state.repeats.append(RepeatParser.Repeat(state.repeat_start_itr, number, state.volta_itr))
        # store volta information
        if ending is not None:
            volta_num = int(ending.get('number'))
            state.voltas[state.repeat_start_itr][volta_num] = number
            state.volta_itr = volta_num
