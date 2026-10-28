from lib import *
d=docx.Document('JHS_Revised_Manuscript_Blinded.docx')
# ---- abstract
fill(d,'Pooled, random-effects and country fixed-effects specifications each conceal',
 'In the same country-year data, a pooled model fails to establish six of the 11 associations that the decomposition establishes, and country fixed effects do not establish the GDP gradient.')
fill(d,'R5/R2: one sentence',
 'Within countries, living standards, food sufficiency and feelings about household income survive country-specific trends and first differences, and 10 of 11 associations survive estimation on observed country-years only.')
fill(d,'R7: and is compared',
 'and no higher than with undecomposed predictors (0.146)')
# ---- contribution
fill(d,'pooled and fixed-effects specifications that are standard in the field would each hide',
 'pooled and fixed-effects specifications that are standard in the field would each hide a part of the pattern reported here.')
# ---- R0
fill(d,'R0: agreement',
 'This baseline reproduces the published respondent-level coefficients closely: the correlation is 0.993 within and 0.998 between countries, the median absolute difference is 0.003 and 0.004, and GDP is 0.039 within and 0.327 between, against 0.045 and 0.326. Country-year standard errors are wider, so 11 of the 14 established within-country associations and 2 of the 5 between-country associations reach BH q < .05 in this baseline; physical pain, freedom and healthcare satisfaction keep their size but not their significance. The checks below are judged against these 11 and 2.')
# ---- R8
fill(d,'R8: pooled, RE and country-FE',
 'On the same panel and catalogue, pooled OLS with year effects and random effects without Mundlak means each return a single GDP slope (0.380 and 0.387 per pooled SD) that blends the two comparisons, and two-way country fixed effects, which use only within-country variation, do not establish GDP once errors are clustered by country (Appendix Table C9). Across the catalogue, the pooled model fails to establish six of the 11 associations that CRE establishes at one level or the other, and it reports a positive association for educational-system satisfaction whose within-country association is negative; country fixed effects establish four.')
# ---- 4.4
fill(d,'R1: range and median',
 'The share of the 2,670 country-years in which a predictor is genuinely observed ranges from 52% to 100% (median 98%), and each predictor is observed in 155 to 168 countries. No predictor is observed in fewer than half of the country-years: the least covered is weekly hours worked (52%), and all others are observed in at least 86%. Intermittent country-mean fill accounts for a median 2% of country-years (at most 47%, for hours worked) and the never-fielded fallback for a median 0% (at most 5%; Appendix Table C1).')
fill(d,'R2: number of the 14',
 'Estimated on observed country-years only, 10 of the 11 within-country associations established in this panel keep sign and significance; educational-system satisfaction loses significance and none changes sign. The median ratio of observed-only to baseline coefficients is 0.99 (range 0.86–1.14), and 0.99 per standard deviation of the observed within-country deviations, so filled country-years attenuate the estimates slightly rather than inflate them (Appendix Table C2).')
fill(d,'R3: which findings',
 'Because every predictor already exceeds 50% coverage, raising the threshold to 25% or 50% of country-years with at least 60 or 100 countries removes no predictor, and all 11 associations keep sign and significance (Appendix Table C3).')
fill(d,'R5: of the within-country',
 'With two-way fixed effects and errors clustered by country, the within-country point estimates are almost identical to the CRE baseline (for example 0.130 against 0.129 for living standards), but only four associations remain significant: living standards, food sufficiency, feelings about household income and roads. The number of established within-country associations is therefore sensitive to how clustering within countries enters the standard errors. Three of the four keep sign and significance with country-specific linear trends and with first differences across consecutive waves (living standards 0.123 and 0.129, food sufficiency 0.078 and 0.063, feelings about household income 0.069 and 0.073); roads keeps its sign but not its significance. The four negative within-country associations (shelter, confidence in financial institutions, air quality and the educational system) move to near zero with country trends, consistent with shared drift rather than substantive change. No placebo lead is significant among the 29 predictors (smallest q = .22), which argues against reverse timing (Appendix Tables C5 and C6).')
fill(d,'R4: number of retained items',
 'Lowering the within-SD screen to .03 or .04 admits seven items (36 predictors) and four further within-country associations (payroll employment, a good place to make friends, someone to count on, and a negative one for having no health problems), while all 11 baseline associations remain. Raising it to .06, .075 and .10 leaves 24, 10 and 6 predictors, and every baseline association still in the model keeps sign and significance. The screen changes which items are examined, not the conclusions about those that are (Appendix Table C4).')
fill(d,'R6a: how many',
 'First, removing all 18 perceptual predictors leaves 11 structural ones. All four structural within-country associations (food and shelter sufficiency, GDP and relative household income) and the between-country GDP gradient remain established, and GDP’s coefficients roughly double (0.603 between and 0.100 within, from 0.327 and 0.039) because they absorb variation previously shared with perceptual items (Appendix Table C7).')
fill(d,'R6b: regional distribution',
 'Second, ladder heaping differs across regions: the share of answers at 0 or 10 ranges from 6.2% in Europe and Central Asia to 15.0% in Latin America and the Caribbean, while the balanced acquiescence rate varies little (0.47 to 0.53). Third, entering time-varying heaping and acquiescence indicators, decomposed within and between countries, changes between-country coefficients by a median 10% and leaves both between-country associations established. Within countries, living standards, food sufficiency, feelings about household income, roads, GDP and relative income remain established, whereas the four negative associations and affordable housing lose significance, as they do under country trends. Excluding the 31 countries with the most extreme response styles leaves both between-country associations and 9 of the 11 within-country associations established (Appendix Table C8).')
# ---- 4.7
for p in d.paragraphs:
    if p.text.startswith('The baselines show what the level-separated architecture contributes.'):
        for r in p.runs:
            if 'The baselines show what the level-separated architecture contributes.' in r.text:
                r.text=r.text.replace('The baselines show what the level-separated architecture contributes.','The baselines show where the transferable signal lies.')
fill(d,'R7: respondent-level and country-year',
 'With the same linear learner and the same development-stratified splits, respondent-level R-squared is .120 with GDP alone, .132 with country means only, .001 with within-country deviations only, .146 with undecomposed predictors and .143 with the full level-separated specification; at the country-year level the values are .599, .661, −.006, .738 and .717. Almost all transferable signal therefore comes from differences between countries, and separating the levels does not improve prediction over undecomposed predictors. Its contribution is to show at which level each association is located, not to predict better.')
fill(d,'R7: n','10 development-stratified')
# ---- conclusion
fill(d,'Pooled and fixed-effects specifications that are standard in the field would each have concealed',
 'Pooled and fixed-effects specifications that are standard in the field would each have concealed part of this pattern.')
fill(d,'R5/R2: one clause',
 'The material core of the within-country map (living standards, food sufficiency and feelings about household income) survives country-specific trends, first differences and observed-only estimation, whereas the negative within-country associations do not survive country trends.')
# ---- Table 5 (R7)
vals={'GDP only':('.120','.599'),'Country means only':('.132','.661'),'Within-country deviations only':('.001','−.006'),'Undecomposed (pooled) predictors':('.146','.738'),'Full CRE (within + between)':('.143','.717')}
t=d.tables[4]
for row in t.rows[1:]:
    k=row.cells[0].text.strip(); a,b=vals[k]; set_cell(row.cells[1],a); set_cell(row.cells[2],b)
# ---- summary table
t=d.tables[5]
for row in t.rows:
    c=row.cells[1]
    if c.text.strip()=='R8': set_cell(c,'Pooled fails to establish 6/11 and reverses educational system; country FE establishes 4/11 and not GDP')
    elif c.text.strip()=='R2/R3/R5': set_cell(c,'10/11 observed-only; 11/11 at ≥ 50% coverage; living standards, food and income feelings survive trends and FD; 0/29 placebo leads')
    elif 'R7' in c.text: set_cell(c,'Unseen-country R² .143–.152; GDP alone .120, undecomposed .146')
# ---- Table 4 (per predictor)
base={(x['code'],x['level']):x for x in R('R0_baseline_collapsed_cre.csv')}
obs={x['code']:x for x in R('R2_observed_only.csv') if x['level']=='within'}
cov={x['code']:x for x in R('R3_coverage_thresholds.csv') if x['level']=='within' and x['spec']=='cov>=50%_cy & >=100 countries'}
r5={x['code']:x for x in R('R5_trends_fd_wide.csv')}
lead={x['code']:x for x in R('R5_trends_fd_leads_long.csv') if x['spec']=='Placebo lead'}
lab={x['code']:x['label'] for x in R('R1_coverage_audit.csv')}
pub=[x['label'] for x in csv.DictReader(open('/tmp/w/published_A11.csv')) if x['w_grade']!='Not established']
code_of={v:k for k,v in lab.items()}
codes=[code_of[l] for l in pub]
codes.sort(key=lambda c:-abs(float(base[(c,'within')]['est'])))
t=d.tables[3]
proto=t.rows[1]._tr
for c in codes:
    tr=copy.deepcopy(proto); t._tbl.append(tr)
from docx.table import _Row
t._tbl.remove(proto)
for i,c in enumerate(codes):
    row=t.rows[1+i]; b=base[(c,'within')]
    cells=[(lab[c],False),(f3(b['est']),b['sig']=='TRUE'),(f3(obs[c]['est']),obs[c]['sig']=='TRUE'),(f3(cov[c]['est']),cov[c]['sig']=='TRUE'),
           (f3(r5[c]['est_TWFE + country trends']),r5[c]['sig_TWFE + country trends']=='TRUE'),(f3(r5[c]['est_First differences (consecutive waves)']),r5[c]['sig_First differences (consecutive waves)']=='TRUE'),
           (f3(lead[c]['est']),lead[c]['sig']=='TRUE')]
    for j,(v,bo) in enumerate(cells): set_cell(row.cells[j],v,bo)
print('table4 rows',len(t.rows)-1)
# note for table 4: mention TWFE clustered
for p in d.paragraphs:
    if p.text.startswith('Note. Entries are coefficients; bold marks BH q < .05 within each specification.'):
        p.runs[-1].text = p.runs[-1].text + ' Rows are the 14 within-country associations established in the published respondent-level model; country trends and first differences use two-way fixed effects with errors clustered by country, first differences across consecutive waves.' if False else p.runs[-1].text
        p.add_run(' Rows are the 14 within-country associations established in the respondent-level model. Trend, first-difference and lead specifications cluster errors by country; first differences are across consecutive waves.')
d.save('OUT_ms.docx'); print(LOG)
