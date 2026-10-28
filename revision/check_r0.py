import csv,statistics as st
O='outputs_v26_one_shot_final/revision/'
lab={r['code']:r['label'] for r in csv.DictReader(open(O+'R1_coverage_audit.csv'))}
pub={r['label']:r for r in csv.DictReader(open('revision/published_A11.csv'))}
base=list(csv.DictReader(open(O+'R0_baseline_collapsed_cre.csv')))
def corr(a,b):
    ma,mb=st.mean(a),st.mean(b); 
    return sum((x-ma)*(y-mb) for x,y in zip(a,b))/ (sum((x-ma)**2 for x in a)*sum((y-mb)**2 for y in b))**.5
for lev,k in [('within','w'),('between','b')]:
    a=[];b=[];agree=0;n=0;sigs=[]
    for r in base:
        if r['level']!=lev: continue
        L=lab.get(r['code']); p=pub.get(L)
        if not p: print('NO MATCH',r['code'],L); continue
        e=float(r['est']); q=float(p[k+'_est']); a.append(e); b.append(q)
        ps=p[k+'_grade']!='Not established'; bs=r['sig']=='TRUE'
        agree+= (ps==bs); n+=1
        if ps or bs: sigs.append((L[:30],round(q,3),round(e,3),p[k+'_grade'][:4],bs))
    print(lev,'n',n,'corr %.3f'%corr(a,b),'median|diff| %.3f'%st.median([abs(x-y) for x,y in zip(a,b)]),'sig agreement',agree,'/',n, 'same sign',sum((x>0)==(y>0) for x,y in zip(a,b)))
    for s in sigs: print('   ',s)
