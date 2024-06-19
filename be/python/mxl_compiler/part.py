from mxl_compiler.base import BaseHandler


class PartHandler(BaseHandler):

    def pre_run(self, state):
        state.parts = {}
    
    def run(self):
        state = super().run()
        state.parts = list(state.parts.values())
        return state
        
    targets = {
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
