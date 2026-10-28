import docx,sys
from docx.shared import Inches
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
def fix(t, first=2.0, total=6.3):
    n=len(t.columns); rest=(total-first)/(n-1)
    ws=[first]+[rest]*(n-1)
    tblPr=t._tbl.tblPr
    lay=OxmlElement('w:tblLayout'); lay.set(qn('w:type'),'fixed'); tblPr.append(lay)
    g=t._tbl.tblGrid
    for gc,w in zip(g.findall(qn('w:gridCol')),ws): gc.set(qn('w:w'),str(int(w*1440)))
    for row in t.rows:
        for c,w in zip(row.cells,ws): c.width=Inches(w)
f=sys.argv[1]; idx=[int(i) for i in sys.argv[2].split(',')] if len(sys.argv)>2 and sys.argv[2] else None
d=docx.Document(f)
for i,t in enumerate(d.tables):
    if idx is None or i in idx: fix(t)
d.save(f)
