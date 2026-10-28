from lib import *
d=docx.Document('JHS_Online_Appendix_B_C.docx')
lab={x['code']:x['label'] for x in R('R1_coverage_audit.csv')}
lab.update({x['code']:x['label'] for x in R('R4_items_near_threshold.csv')})
lab.update({x['code']:x['label'] for x in R('R4_within_sd_threshold.csv')})
L=lambda c: lab.get(c,c)
def ph(prefix):
    for p in d.paragraphs:
        if any(r.font.highlight_color is not None for r in p.runs) and p.text.strip().startswith(prefix): return p
    raise SystemExit('missing '+prefix)
def insert_after(elm, text, style='Body Text'):
    np_=d.add_paragraph(text, style=style); elm.addnext(np_._p); return np_
def put(prefix, header, rows, mask=None, note=None, size=9):
    p=ph(prefix); t=make_table(d,p,header,rows,mask,size)
    if note: insert_after(t._tbl,'Note. '+note)
    p._p.getparent().remove(p._p)
B=lambda x: x=='TRUE'
fill(d,'R0: agreement','The baseline reproduces the published respondent-level coefficients closely: correlation 0.993 within and 0.998 between countries, median absolute difference 0.003 and 0.004, same sign for 28 of 29 within and 29 of 29 between coefficients. Because country-year standard errors are wider, 11 of the 14 published within-country associations and 2 of the 5 between-country associations reach BH q < .05 in this baseline (physical pain, freedom and healthcare satisfaction lose significance within countries; living standards, feelings about household income and freedom between countries). Variant results are judged against this baseline.')
# C1
r1=sorted(R('R1_coverage_audit.csv'),key=lambda x:float(x['share_cy_observed']))
put('Insert R1_coverage_audit.csv',['Predictor','Observed country-years','Countries observed','Countries with ≥ 3 observed waves','Country-mean fill','Never fielded'],
 [[x['label'],f"{x['cy_observed']} ({pct(x['share_cy_observed'])})",f"{x['countries_observed']} ({pct(x['share_countries_observed'])})",x['countries_3plus_observed_waves'],pct(x['share_cy_intermittent_fill'],1),pct(x['share_cy_never_fielded'],1)] for x in r1],
 note='Shares are of the 2,670 panel country-years and 168 countries. Country-mean fill covers intermittent gaps within a country; never fielded marks country-years in countries where the item was never asked, filled by the panel mean and flagged in the model.')
# C2
r2=R('R2_observed_only.csv'); W={x['code']:x for x in r2 if x['level']=='within'}; Bt={x['code']:x for x in r2 if x['level']=='between'}
cs=sorted(W,key=lambda c:-abs(float(W[c]['base_est'])))
rows=[];mask=[]
for c in cs:
    w=W[c]; b=Bt[c]
    rows.append([L(c),f3(w['base_est']),f3(w['est']),f3(w['est_obs_sd']),f3(b['base_est']),f3(b['est']),w['n_cy']])
    mask.append([0,B(w['base_sig']),B(w['sig']),B(w['sig']),B(b['base_sig']),B(b['sig']),0])
put('Insert R2_observed_only.csv',['Predictor','Within: baseline','Within: observed only','Within: per observed SD','Between: baseline','Between: observed only','Observed country-years'],rows,mask,
 note='Bold marks BH q < .05 within each specification. The per-SD column rescales the observed-only within coefficient to one standard deviation of observed within-country deviations, removing the attenuation from filled values.')
# C3
r3=R('R3_summary.csv')
def spec(s): 
    a=s.replace('cov>=','≥ ').replace('_cy',' of country-years').replace(' & >=',', ≥ ')+' countries' if 'countries' not in s else s.replace('cov>=','≥ ').replace('_cy',' of country-years').replace(' & >=',', ≥ ')
    return a
put('Insert R3_coverage_thresholds.csv',['Coverage threshold','Predictors retained','Baseline within associations in model','Keep sign and significance','Lose significance','Change sign'],
 [[spec(x['spec']),x['n_pred'],x['base_sig_present'],x['kept_sig'],x['lost'],x['flips']] for x in r3],
 note='Every predictor is observed in at least 52% of country-years and 155 countries, so none of these thresholds removes a predictor. Coefficient-level results for each threshold are in R3_coverage_thresholds.csv in the repository.')
# C4
r4=R('R4_summary.csv'); near=R('R4_items_near_threshold.csv')
lst=lambda s: '; '.join(L(c.strip()) for c in s.split(';') if c.strip()).replace('–','–') or '–'
p=ph('Insert R4_summary.csv')
t=make_table(d,p,['Within-SD threshold','Predictors','Added','Removed','Within','Between','Kept'],
 [[x['threshold'],x['n_predictors'],lst(x['added']),lst(x['removed']),x['n_sig_within'],x['n_sig_between'],x['base_sig_within_retained']] for x in r4],size=8)
n1=insert_after(t._tbl,'Note. Baseline threshold is .05. Within and Between give the number of established associations at each level; Kept counts baseline within-country associations that keep sign and significance among those still in the model. At .03 and .04 the four added associations are payroll employment, a good place to make friends, someone to count on for help (positive) and no health problems (negative).')
t2=make_table(d,n1,['Predictor','Weighted within-country SD','Country-years','Countries'],[[x['label'],f3(x['within_sd']),x['n_cyears'],x['n_countries']] for x in sorted(near,key=lambda x:float(x['within_sd']))])
cap=insert_after(n1._p,'Items with within-country SD between .03 and .10')
p._p.getparent().remove(p._p)
# C5
r5=R('R5_trends_fd_wide.csv'); K=['TWFE','TWFE + country trends','First differences (consecutive waves)','First differences (all gaps)']
r5.sort(key=lambda x:-abs(float(x['est_TWFE'])))
put('Insert R5_trends_fd_wide.csv',['Predictor','Two-way FE','+ Country trends','First differences (consecutive waves)','First differences (all gaps)'],
 [[x['label']]+[f3(x['est_'+k]) for k in K] for x in r5],[[0]+[B(x['sig_'+k]) for k in K] for x in r5],
 note='Bold marks BH q < .05 within each specification. All specifications include year effects and the missingness flags, and cluster errors by country.')
# C6
ll=[x for x in R('R5_trends_fd_leads_long.csv') if x['spec']=='Placebo lead']; ll.sort(key=lambda x:float(x['p_fdr']))
put('Insert the placebo-lead rows',['Predictor','Lead coefficient','SE','BH q','Current-wave coefficient (with lead)'],
 [[L(x['code']),f3(x['est']),f3(x['se']),'%.2f'%float(x['p_fdr']),f3(x['contemp_with_lead'])] for x in ll],[[0,B(x['sig']),0,0,0] for x in ll],
 note='The lead is the next wave’s value of the predictor, entered alongside its current value in the two-way fixed-effects model. No lead reaches BH q < .05.')
# C7
a=R('R6a_perceptual_excluded.csv')
put('Insert R6a_perceptual_excluded.csv',['Predictor','Level','Baseline','Structural predictors only','Status'],
 [[x['label'],x['level'],f3(x['base_est']),f3(x['est']),x['status']] for x in a],[[0,0,B(x['base_sig']),B(x['sig']),0] for x in a],
 note='The model drops all 18 perceptual predictors and keeps the 11 structural ones. Bold marks BH q < .05.')
# C8
reg=R('R6b_response_distributions_by_region.csv')
p=ph('Insert R6b_response_style_by_country.csv')
t=make_table(d,p,['Region','Countries','Mean ladder','Share at 0 or 10','Share at 5','Balanced yes-rate'],
 [[x['region'] or 'Unclassified',x['countries'],'%.2f'%float(x['cantril_mean']),pct(float(x['share_0'])+float(x['share_10']),1),pct(x['share_5'],1),'%.2f'%float(x['yes_balanced'])] for x in reg])
n1=insert_after(t._tbl,'Note. Country-level indicators (R6b_response_style_by_country.csv in the repository) are averaged over country-years and then over countries in each region.')
m=R('R6b_response_style_models.csv'); S1='controlling response style'; S2='excluding 31 high response-style countries'
idx={(x['spec'],x['code'],x['level']):x for x in m}
codes=sorted({x['code'] for x in m},key=lambda c:-abs(float(idx[(S1,c,'within')]['base_est'])))
rows=[];mask=[]
for c in codes:
    w1,w2,b1,b2=idx[(S1,c,'within')],idx[(S2,c,'within')],idx[(S1,c,'between')],idx[(S2,c,'between')]
    rows.append([L(c),f3(w1['base_est']),f3(w1['est']),f3(w2['est']),f3(b1['base_est']),f3(b1['est']),f3(b2['est'])])
    mask.append([0,B(w1['base_sig']),B(w1['sig']),B(w2['sig']),B(b1['base_sig']),B(b1['sig']),B(b2['sig'])])
t2=make_table(d,n1,['Predictor','Within: baseline','Within: style controls','Within: excl. 31 countries','Between: baseline','Between: style controls','Between: excl. 31 countries'],rows,mask,size=8)
insert_after(t2._tbl,'Note. Style controls are country-year ladder heaping (share at 0 or 10) and balanced acquiescence, each decomposed into within- and between-country components. The excluded countries are the 31 with the most extreme values on either indicator. Bold marks BH q < .05.')
p._p.getparent().remove(p._p)
# C9
w8=R('R8_conventional_vs_cre_wide.csv'); K8=['CRE between','CRE within','Pooled OLS (year FE)','Random effects (no Mundlak means)','Country FE (two-way)']
w8.sort(key=lambda x:-abs(float(x['est_CRE within'])))
put('Insert R8_conventional_vs_cre_wide.csv',['Predictor','CRE between','CRE within','Pooled OLS (year FE)','Random effects (no Mundlak means)','Two-way country FE'],
 [[x['label']]+[f3(x['est_'+k]) for k in K8] for x in w8],[[0]+[B(x['sig_'+k]) for k in K8] for x in w8],
 note='CRE components are on the published scale. Pooled, random-effects and fixed-effects coefficients are per pooled SD of each predictor, so their magnitudes are not directly comparable with the CRE columns; signs and significance are. Pooled OLS and two-way FE cluster errors by country. Bold marks BH q < .05 within each specification.')
# C10
s7=R('R7_predictive_baselines_summary.csv')
put('Insert R7_predictive_baselines_summary.csv',['Design','Learner','Feature set','Respondent-level R² (SD)','Country-year R²'],
 [[x['design'],{'lin':'Linear','enet':'Elastic net'}[x['model']],x['features'][3:],'%s (%s)'%(f3(x['r2_respondent'])[1:] if float(x['r2_respondent'])>=0 else f3(x['r2_respondent']),f3(x['r2_respondent_sd'])[1:]),f3(x['r2_country_year'])] for x in s7],
 note='Means over 10 repetitions of each design; repetition-level results are in R7_predictive_baselines_all_reps.csv in the repository. Respondent-level R-squared is unweighted; country-year R-squared weights each country-year by its summed survey weight.')
# C6 title: drop AIC mention
for p in d.paragraphs:
    if p.text.strip()=='Placebo Leads and AIC Lead–Lag Comparison':
        pass
d.save('OUT_app.docx'); print(LOG)
