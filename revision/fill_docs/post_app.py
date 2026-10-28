import docx
from docx.shared import Pt, Inches
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
from docx.enum.text import WD_COLOR_INDEX
d=docx.Document('OUT_app.docx')
for p in d.paragraphs:
    if p.text.startswith('Note. The lead is the next wave'):
        r=p.add_run(' Insert R9_lead_lag_AIC.csv: AIC of contemporaneous, lagged and lead specifications on identical rows — pending run v5.'); r.font.highlight_color=WD_COLOR_INDEX.YELLOW
def fix(t, ws):
    tblPr=t._tbl.tblPr
    lay=OxmlElement('w:tblLayout'); lay.set(qn('w:type'),'fixed'); tblPr.append(lay)
    tw=tblPr.find(qn('w:tblW')); tw.set(qn('w:type'),'dxa'); tw.set(qn('w:w'),str(int(sum(ws)*1440)))
    for gc,w in zip(t._tbl.tblGrid.findall(qn('w:gridCol')),ws): gc.set(qn('w:w'),str(int(w*1440)))
    for row in t.rows:
        for c,w in zip(row.cells,ws):
            c.width=Inches(w)
            for p in c.paragraphs:
                pf=p.paragraph_format; pf.first_line_indent=Pt(0); pf.left_indent=Pt(0); pf.space_before=Pt(2); pf.space_after=Pt(2); pf.line_spacing=1.0
for i,t in enumerate(d.tables[4:],start=4):
    n=len(t.columns)
    if t.rows[0].cells[0].text=='Within-SD threshold': ws=[0.7,0.65,1.65,1.65,0.5,0.62,0.45]
    elif t.rows[0].cells[0].text=='Design': ws=[1.3,0.8,1.9,1.3,1.0]
    else: ws=[2.0]+[(6.3-2.0)/(n-1)]*(n-1)
    fix(t,ws)
d.save('OUT_app.docx')
