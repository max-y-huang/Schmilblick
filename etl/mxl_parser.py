from part_parser import PartParser
from measure_parser import MeasureParser
from repeat_parser import RepeatParser
from ds_al_coda_parser import DSAlCodaParser
from note_parser import NoteParser

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
