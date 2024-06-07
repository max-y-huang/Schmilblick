from mxl_parser.parser_base import ParserBase

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
