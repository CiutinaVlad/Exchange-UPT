"""Parse the ETC bundle (syllabus pages + timetable CSV/HTML) into raw records.
Usage: python3 -I parse.py <bundle.json> <out.json>"""
import csv, io, json, re, sys
from bs4 import BeautifulSoup

bundle = json.load(open(sys.argv[1]))
DAYS = ['LUNI', 'MARTI', 'MIERCURI', 'JOI', 'VINERI']
ROMAN = {'I': 1, 'II': 2, 'III': 3, 'IV': 4}


def norm(s):
    return re.sub(r'\s+', ' ', s or '').strip()


# ---------- syllabi ----------
def parse_syllabus(key, html):
    soup = BeautifulSoup(html, 'lxml')
    items, sem = [], 0
    master = '-M' in key
    title = ''
    m = re.search(r'Programul de Master\s*-\s*(.+?)\s*Promo', soup.get_text(' '))
    if m:
        title = norm(m.group(1))
    for el in soup.descendants:
        if isinstance(el, str):
            t = str(el)
            if master:
                mm = re.search(r'Semestrul\s+(IV|III|II|I|\d)\b', t)
                if mm and el.find_parent('tr') is None:
                    sem = ROMAN.get(mm.group(1)) or int(mm.group(1))
                if re.search(r'Op[țt]ional semestrul', t, re.I):
                    sem = -1
            continue
        if el.name != 'tr':
            continue
        cells = [norm(re.sub(r'\[EN\]|\[RO\]', '', c.get_text(' '))) for c in el.find_all(['td', 'th'])]
        line = ' | '.join(cells)
        if not master:
            sm = re.search(r'(?:sem\.?|Semestrul|Semester)\s*(\d)', line, re.I)
            if sm and not re.search(r'\d+\s*/\s*[A-Z]', line):
                sem = int(sm.group(1)); continue
            mm = re.match(r'^(\d+)\s*/\s*([A-Z*][A-Z\-*0-9]*)', cells[-1] if cells else '')
            if mm and len(cells) >= 4 and cells[0].isdigit():
                items.append([sem, cells[1], int(mm.group(1)), 0])
        else:
            mm = re.search(r'Semestrul\s+(IV|III|II|I)\b', line)
            if mm and not (cells and cells[0].isdigit()):
                sem = ROMAN[mm.group(1)]; continue
            if sem > 0 and len(cells) >= 3 and cells[0].isdigit() and cells[2].isdigit():
                name, e = cells[1], int(cells[2])
                om = re.match(r'^Op[țt]ional\s*[\d,\s]+\.?\s*(.*)$', name)
                if om:
                    for x in om.group(1).split('/'):
                        if x.strip():
                            items.append([sem, x.strip(), e, 1])
                else:
                    items.append([sem, name, e, 0])
    return {'title': title, 'items': items}


syl = {k: parse_syllabus(k, v) for k, v in bundle['syl'].items()}


# ---------- timetables ----------
def html_grid(html):
    soup = BeautifulSoup(html, 'lxml')
    rows = soup.select('table tbody tr')
    g = {}
    for ri, tr in enumerate(rows):
        ci = 0
        for td in tr.find_all(['td', 'th'], recursive=False):
            if td.name == 'th':
                continue
            while (ri, ci) in g:
                ci += 1
            rs, cs = int(td.get('rowspan', 1)), int(td.get('colspan', 1))
            for br in td.find_all('br'):
                br.replace_with('\n')
            txt = re.sub(r'[ \t]+', ' ', td.get_text()).strip()
            for a in range(rs):
                for b in range(cs):
                    g[(ri + a, ci + b)] = {'t': txt, 'rs': rs, 'cs': cs} if (a == 0 and b == 0) else {'ref': (ri, ci)}
            ci += cs
    nrows = len(rows)
    return g, nrows


def parse_file(k):
    rows = list(csv.reader(io.StringIO(bundle['csv'][k])))
    W = max(len(r) for r in rows)
    C = lambda r, c: rows[r][c] if r < len(rows) and c < len(rows[r]) else ''
    g, hn = html_grid(bundle['html'][k])
    HW = max([c for (_, c) in g] + [0]) + 1
    tcols = [c for c in range(W) if sum(1 for r in range(len(rows)) if re.match(r'^\d\d-\d\d$', C(r, c).strip())) >= 10]
    # csv row -> day*100+hour
    cmap, cd = {}, -1
    for ri, row in enumerate(rows):
        for c in range(min(len(row), tcols[0] + 1)):
            if row[c].strip() in DAYS:
                cd = DAYS.index(row[c].strip())
        t = C(ri, tcols[0]).strip()
        if re.match(r'^\d\d-\d\d$', t):
            cmap[ri] = cd * 100 + int(t[:2])
    hmap, hd = {}, -1
    for ri in range(hn):
        for c in range(HW):
            x = g.get((ri, c))
            if x and 't' in x and x['t'] in DAYS:
                hd = DAYS.index(x['t'])
        for c in range(HW):
            x = g.get((ri, c))
            if x and 't' in x and re.match(r'^\d\d-\d\d$', x['t']):
                hmap[ri] = hd * 100 + int(x['t'][:2]); break
    hrow = {}
    for ri, key in sorted(hmap.items()):
        hrow.setdefault(key, ri)
    hsig = [{f"{hmap[ri]}|{norm(g[(ri, h)]['t'])}" for ri in hmap if 't' in g.get((ri, h), {})} for h in range(HW)]
    csig = [{f"{cmap[ri]}|{norm(C(ri, c))}" for ri in cmap if norm(C(ri, c))} for c in range(W)]
    colmap, last = {}, -1
    for h in range(HW):
        best, bs = -1, 0
        for c in range(last + 1, W):
            o = len(hsig[h] & csig[c])
            if o > bs:
                bs, best = o, c
        if best >= 0 and bs >= 2:
            colmap[best] = h; last = best
    recs, legend = [], {}
    last_time_row = max(cmap)
    for i, t in enumerate(tcols):
        end = tcols[i + 1] - 1 if i + 1 < len(tcols) else W
        cols = [c for c in range(t + 1, end) if (norm(C(2, c)) or norm(C(1, c))) and not re.search('ON LINE', norm(C(0, c)), re.I)]
        if not cols:
            continue
        prog_of, p0, p1 = {}, '', ''
        for c in range(t + 1, cols[-1] + 1):
            a = norm(C(0, c))
            if a and not a.isdigit() and 'ON LINE' not in a.upper():
                p0 = a
            b = norm(C(1, c))
            if b and not re.match('^GRUPA', b, re.I):
                p1 = b
            elif re.match('^GRUPA', b, re.I):
                p1 = ''
            prog_of[c] = (p0, p1)
        lab = lambda c: norm(C(2, c)) or norm(C(1, c))
        # legend below the grid: pairs "ABBR(l)", "room"
        for r in range(last_time_row + 1, len(rows)):
            for c in range(t + 1, end - 1):
                v = norm(C(r, c))
                if re.search(r'\((l|p)\)', v, re.I) and norm(C(r, c + 1)):
                    legend[(prog_of.get(c, (p0, ''))[0], re.sub(r'\s+', '', v.split('(')[0]).upper())] = norm(C(r, c + 1))
        for r in sorted(cmap):
            for c in cols:
                v = C(r, c).strip()
                if not v or re.match(r'^-+$', v):
                    continue
                dur, span, guessed = None, [c], 0
                h, hr = colmap.get(c), hrow.get(cmap[r])
                x = g.get((hr, h)) if h is not None and hr is not None else None
                if x and 't' in x:
                    dur = x['rs']
                    hc = set(range(h, h + x['cs']))
                    cs_ = [cc for cc in colmap if colmap[cc] in hc]
                    if cs_:
                        lo, hi = min(cs_), max(cs_)
                        span = [cc for cc in cols if lo <= cc <= hi]
                        vis = [cc for cc in cols if cc in colmap]
                        if vis and all(lo <= cc <= hi for cc in vis):
                            span = cols[:]
                if dur is None:
                    guessed, dur, rr = 1, 1, r + 1
                    while dur < 2 and rr in cmap and cmap[rr] // 100 == cmap[r] // 100 and not C(rr, c).strip():
                        dur += 1; rr += 1
                same_prog = [cc for cc in cols if prog_of[cc][1] == prog_of[c][1]]
                recs.append({'f': k, 'p0': prog_of[c][0], 'p1': prog_of[c][1], 'p1s': sorted({prog_of[cc][1] for cc in span}),
                             'day': cmap[r] // 100, 'start': cmap[r] % 100, 'dur': dur,
                             'grp': [lab(cc) for cc in span], 'all': len(span) >= len(same_prog), 'v': v, 'g': guessed})
    return recs, {f"{a}|{b}": v for (a, b), v in legend.items()}


out = {'syl': syl, 'files': {}}
for k in bundle['csv']:
    recs, legend = parse_file(k)
    out['files'][k] = {'recs': recs, 'legend': legend}
    print(k, len(recs), 'records,', sum(r['g'] for r in recs), 'guessed durations,', len(legend), 'legend rooms')
for k, v in syl.items():
    print(k, v['title'][:40], len(v['items']))
json.dump(out, open(sys.argv[2], 'w'), ensure_ascii=False)
