import re

from collections import defaultdict

from mxl_parser.parser_base import ParserBase

class DSAlCodaParser(ParserBase):

    class DSAlCoda:
        def __init__(self, segno_src, segno_dst, coda_src, coda_dst):
            self.segno_src = segno_src
            self.segno_dst = segno_dst
            self.coda_src = coda_src
            self.coda_dst = coda_dst

    def pre_parse(self, state):
        state.dsalcodas = []
        state.segnos = defaultdict(lambda: None)           # self.segnos[symbol] = measure
        state.dalsegnos = defaultdict(lambda: None)        # self.dalsegnos[measure] = (segno symbol, coda text)
        state.tocodas = defaultdict(lambda: None)          # self.tocodas[symbol] = measure
        state.tocodas_by_text = defaultdict(lambda: None)  # self.tocodas_by_text[text] = symbol
        state.codas = defaultdict(lambda: None)            # self.codas[symbol] = measure

        state.segnos['_capo'] = 0            # reduce dacapo to dalsegno
        state.codas['_fine'] = float('inf')  # reduce fine to coda
    
    def parse(self):
        state = super().parse()
        for segno_src, (segno_symbol, coda_text) in state.dalsegnos.items():
            coda_symbol = state.tocodas_by_text[coda_text]
            segno_dst = state.segnos[segno_symbol]
            coda_src = state.tocodas[coda_symbol]
            coda_dst = state.codas[coda_symbol]
            state.dsalcodas.append(DSAlCodaParser.DSAlCoda(segno_src, segno_dst, coda_src, coda_dst))
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

        def handle_dalsegno(symbol, text):
            coda_text = extract_coda_text(text, "(^|\s)al\s")
            state.dalsegnos[number] = (symbol, coda_text)
        
        def handle_tocoda(symbol, text, extact_text=True):
            if extact_text:
                text = extract_coda_text(text, "(^|\s)to\s")
            state.tocodas[symbol] = number
            state.tocodas_by_text[text] = symbol
        
        number = int(obj.get('number')) - 1
        segno = obj.find('.//sound[@segno]')
        dalsegno = obj.find('.//sound[@dalsegno]')
        dalsegno_text = obj.find('.//sound[@dalsegno]..//words')
        dacapo = obj.find('.//sound[@dacapo="yes"]')                # TODO: check standard
        dacapo_text = obj.find('.//sound[@dacapo="yes"]..//words')  # TODO: check standard
        coda = obj.find('.//sound[@coda]')
        tocoda = obj.find('.//sound[@tocoda]')
        tocoda_text = obj.find('.//sound[@tocoda]..//words')
        fine = obj.find('.//sound[@fine="yes"]')                    # TODO: check standard
        # store segno information
        if segno is not None:
            symbol = segno.get('segno')
            state.segnos[symbol] = number
        # store dalsegno information
        if dalsegno is not None:
            handle_dalsegno(dalsegno.get('dalsegno'), dalsegno_text.text)
        # store dacapo information
        if dacapo is not None:
            handle_dalsegno('_capo', dacapo_text.text)
        # store coda information
        if coda is not None:
            symbol = coda.get('coda')
            state.codas[symbol] = number
        # store tocoda information
        if tocoda is not None:
            handle_tocoda(tocoda.get('tocoda'), tocoda_text.text)
        # store fine information
        if fine is not None:
            handle_tocoda('_fine', 'fine', extact_text=False)
