import docx,sys
def paras(d):
    for p in d.paragraphs: yield p
    for t in d.tables:
        for r in t.rows:
            for c in r.cells:
                for p in c.paragraphs: yield p
for f in sys.argv[1:]:
    d=docx.Document(f); n=0; seen=set()
    print('=====',f)
    for p in paras(d):
        if p._p in seen: continue
        hl=[r.text for r in p.runs if r.font.highlight_color is not None and r.text.strip()]
        if hl:
            seen.add(p._p); n+=1
            print(f'[{n}] HL:', ' || '.join(hl)[:300])
            print('    CTX:', p.text[:600])
    print('TOTAL',n)
