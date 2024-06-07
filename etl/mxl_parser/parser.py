from mxl_parser.part_parser import PartParser
from mxl_parser.measure_parser import MeasureParser
from mxl_parser.repeat_parser import RepeatParser
from mxl_parser.dsalcoda_parser import DSAlCodaParser
from mxl_parser.note_parser import NoteParser

class MXLParser():

    def __init__(self, data):
        self.data = data
    
    def parse(self):

        p_parts = PartParser(self.data).parse()
        for part in p_parts.parts:
            p_measures = MeasureParser(part['obj']).parse()

            p_repeats = RepeatParser(part['obj']).parse()
            print(p_repeats.repeats)

            p_dsalcodas = DSAlCodaParser(part['obj']).parse()
            print(p_dsalcodas.dsalcodas)

            p_measures.measure_list.set_jumps(self.generate_jumps(p_repeats, p_dsalcodas))

            p_notes = NoteParser(p_measures.src, p_measures.measure_list).parse()
            part['obj'] = p_notes

        return p_parts.parts

    def generate_jumps(self, p_repeats, p_dsalcodas):
        jumps = []
        def add_repeat_jumps(repeat):
            start, end, volta_num = repeat
            jumps.append(RepeatParser.Jump(end, start))  # jump to repeat start
            if volta_num is not None:
                voltas = p_repeats.voltas[start]
                jumps.append(RepeatParser.Jump(voltas[1] - 1, voltas[volta_num + 1]))  # jump to correct volta
        for repeat in p_repeats.repeats:
            add_repeat_jumps(repeat)
        return jumps
