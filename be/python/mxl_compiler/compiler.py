import zipfile
import tempfile
import os

from xml.etree import ElementTree

from mxl_compiler.part import PartHandler
from mxl_compiler.measure import MeasureHandler
from mxl_compiler.repeat import RepeatHandler
from mxl_compiler.dsalcoda import DSAlCodaHandler
from mxl_compiler.note import NoteHandler


class Jump:
    def __init__(self, src, dst):
        self.src = src
        self.dst = dst


class MXLCompiler():

    def __init__(self, data):
        self.data = data
    
    @classmethod
    def from_file(cls, dir):
        # unzip file to temporary directory
        with zipfile.ZipFile(dir, 'r') as z:
            zip_dir = tempfile.mkdtemp()
            z.extractall(zip_dir)
            xml_fname = next(d for d in os.listdir(zip_dir) if d.endswith('.xml') or d.endswith('.musicxml'))  # get first .xml or .musicxml file in zip_dir
            xml_dir = os.path.join(zip_dir, xml_fname)
        # get xml data from temporary directory
        with open(xml_dir) as f:
            obj = ElementTree.parse(f)
            obj = obj.getroot()
        return cls(obj)
    
    def compile(self):

        p_parts = PartHandler(self.data).run()
        for part in p_parts.parts:
            p_measures = MeasureHandler(part['obj']).run()

            p_repeats = RepeatHandler(part['obj']).run()
            p_dsalcodas = DSAlCodaHandler(part['obj']).run()
            jumps = self.generate_jumps(p_repeats.repeats, p_repeats.voltas, p_dsalcodas.dsalcodas, p_measures.num_measures)
            p_measures.measure_list.set_jumps(jumps)

            p_notes = NoteHandler(p_measures.src, p_measures.measure_list).run()
            part['obj'] = p_notes

        return p_parts.parts

    def generate_jumps(self, repeats, voltas, dsalcodas, num_measures):

        def add_volta_jump(repeat_start, target_volta):  # target_volta = -1 for last volta
            curr_voltas = voltas[repeat_start]
            earliest_volta = min(curr_voltas.items(), key=lambda x: x[1])[0]
            if target_volta == -1:
                target_volta = max(curr_voltas.keys())
            jumps.append(Jump(curr_voltas[earliest_volta] - 1, curr_voltas[target_volta]))
        
        jumps = []
        for itr in range(num_measures):
            # handle repeat
            repeat = next((x for x in repeats if x.end == itr), None)
            if repeat is not None:
                jumps.append(Jump(repeat.end, repeat.start))  # jump to repeat start
                if repeat.nth_volta is not None:
                    add_volta_jump(repeat.start, repeat.nth_volta + 1)
            # handle ds al coda
            dsalcoda = next((x for x in dsalcodas if x.segno_src == itr), None)
            if dsalcoda is not None:
                jumps.append(Jump(dsalcoda.segno_src, dsalcoda.segno_dst))  # jump to segno
                # take last volta for repeated repeats
                for m in range(dsalcoda.segno_dst, itr + 1):
                    if len(voltas[m].keys()) > 0:
                        add_volta_jump(m, -1)
                if dsalcoda.coda_dst is not None:
                    jumps.append(Jump(dsalcoda.coda_src, dsalcoda.coda_dst))  # jump to coda
        
        return jumps
