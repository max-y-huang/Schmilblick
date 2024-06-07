import re

from collections import defaultdict

from mxl_parser.parser_base import ParserBase

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
