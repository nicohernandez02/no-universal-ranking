import docx, csv, copy
from docx.shared import Pt
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
R=lambda f: list(csv.DictReader(open('/tmp/w/'+f)))
def f3(x):
    try: v=float(x)
    except: return '–'
    s='%.3f'%v
    return s.replace('-','−')
def pct(x,d=0): return ('%.'+str(d)+'f%%')%(100*float(x))
def allpars(d):
    for p in d.paragraphs: yield p
    for t in d.tables:
        for r in t.rows:
            for c in r.cells:
                for p in c.paragraphs: yield p
LOG=[]
def fill(d, prefix, new, keep_hl=False):
    n=0
    for p in allpars(d):
        for r in p.runs:
            if r.font.highlight_color is not None and r.text.strip().startswith(prefix):
                r.text=new
                if not keep_hl: r.font.highlight_color=None
                n+=1
    LOG.append((prefix[:50],n))
    if n==0: print('!! NOT FOUND:',prefix[:60])
    return n
def set_cell(cell, text, bold=False, size=10):
    p=cell.paragraphs[0]
    for r in list(p.runs): r._r.getparent().remove(r._r)
    run=p.add_run(text); run.bold=bold; run.font.size=Pt(size); run.font.highlight_color=None
def make_table(doc, after_par, header, rows, bold_mask=None, size=9):
    t=doc.add_table(rows=1+len(rows), cols=len(header))
    t.style=doc.styles['Table']
    for j,h in enumerate(header): set_cell(t.rows[0].cells[j], h, True, size)
    for i,row in enumerate(rows):
        for j,v in enumerate(row):
            b = bool(bold_mask and bold_mask[i][j])
            set_cell(t.rows[i+1].cells[j], v, b, size)
    for c in t.rows[0].cells: pass
    trPr=t.rows[0]._tr.get_or_add_trPr(); h=OxmlElement('w:tblHeader'); h.set(qn('w:val'),'true'); trPr.append(h)
    for row in t.rows:
        for c in row.cells:
            for p in c.paragraphs: p.style=doc.styles['Compact'] if 'Compact' in [s.name for s in doc.styles] else p.style
    after_par._p.addnext(t._tbl)
    return t
def add_note(doc, after_elm, text):
    p=copy.deepcopy(after_elm) if False else None
