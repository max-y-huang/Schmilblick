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
            p_dsalcodas = DSAlCodaParser(part['obj']).parse()
            jumps = self.generate_jumps(p_repeats.repeats, p_repeats.voltas, p_dsalcodas.dsalcodas, p_measures.num_measures)
            p_measures.measure_list.set_jumps(jumps)

            p_notes = NoteParser(p_measures.src, p_measures.measure_list).parse()
            part['obj'] = p_notes

        return p_parts.parts

    def generate_jumps(self, repeats, voltas, dsalcodas, num_measures):

        def add_volta_jump(repeat_start, target_volta):  # target_volta = -1 for last volta
            curr_voltas = voltas[repeat_start]
            earliest_volta = min(curr_voltas.items(), key=lambda x: x[1])[0]
            if target_volta == -1:
                target_volta = max(curr_voltas.keys())
            jumps.append(MeasureParser.Jump(curr_voltas[earliest_volta] - 1, curr_voltas[target_volta]))
        
        jumps = []
        for itr in range(num_measures):
            # handle repeat
            repeat = next((x for x in repeats if x.end == itr), None)
            if repeat is not None:
                jumps.append(MeasureParser.Jump(repeat.end, repeat.start))  # jump to repeat start
                if repeat.nth_volta is not None:
                    add_volta_jump(repeat.start, repeat.nth_volta + 1)
            # handle ds al coda
            dsalcoda = next((x for x in dsalcodas if x.segno_src == itr), None)
            if dsalcoda is not None:
                jumps.append(MeasureParser.Jump(dsalcoda.segno_src, dsalcoda.segno_dst))  # jump to segno
                # take last volta for repeated repeats
                for m in range(dsalcoda.segno_dst, itr + 1):
                    if len(voltas[m].keys()) > 0:
                        add_volta_jump(m, -1)
                jumps.append(MeasureParser.Jump(dsalcoda.coda_src, dsalcoda.coda_dst))  # jump to coda
        
        return jumps
