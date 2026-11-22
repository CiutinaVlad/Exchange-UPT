"""Turn raw ETC records into app courses + sessions.
Usage: python3 -I build.py data/raw.json data/etc_courses.json"""
import json, re, sys, unicodedata
from collections import defaultdict

raw = json.load(open(sys.argv[1]))
SYL = raw['syl']

def strip(s):
    return ''.join(ch for ch in unicodedata.normalize('NFD', s) if unicodedata.category(ch) != 'Mn').lower()

def norm(s):
    return re.sub(r'\s+', ' ', s or '').strip()

STOP = {'si', 'de', 'pentru', 'in', 'a', 'al', 'ale', 'la', 'cu', 'and', 'of', 'for', 'the', 'to', 'on', 'din', 'prin', 'or', 'sau'}

# ---------- which syllabus each series uses ----------
def series_info(f, p0, p1):
    """-> (tag, level, year, lang, programme, [(syllabus key, semester)], cohort_ok)"""
    if f in ('L1', 'L2'):
        y, sem = (1, 1) if f == 'L1' else (2, 3)
        coh = '2026' if f == 'L1' else '2025'
        if 'ENG' in p0:
            return 'E', 'B', y, 'EN', 'TST-EN', [(f'TSTEN-{coh}', sem)], True
        tag = 'A' if 'SERIA A' in p0 else 'B'
        return tag, 'B', y, 'RO', 'ETcTI', [(f'TST-{coh}', sem), (f'EA-{coh}', sem), (f'MON-{coh}', sem)], True
    if f in ('L3', 'L4'):
        y, sem = (3, 5) if f == 'L3' else (4, 7)
        if ' PI' in p0 or p0.endswith('PI'):
            return 'PI', 'B', y, 'EN', 'TST-EN', [('TSTEN-2025', sem)], False
        if 'EA' in p0:
            return 'EA', 'B', y, 'RO', 'EA', [('EA-2025', sem), ('TST-2025', sem), ('MON-2025', sem)], False
        if 'TST' in p0:
            return 'TST', 'B', y, 'RO', 'TST', [('TST-2025', sem), ('EA-2025', sem), ('MON-2025', sem)], False
        return 'OPT', 'B', y, 'RO', 'EA/TST', [('TST-2025', sem), ('EA-2025', sem), ('MON-2025', sem)], False
    # masters
    y, tagy, sem = (1, 'M2026', 1) if f == 'M1' else (2, 'M2025', 3)
    progs = {'ESI': 'ESI', 'AES': 'AES', 'EB': 'EB', 'IRT': 'IRT', 'CN': 'CN', 'TM': 'TM', 'ID': 'IDATA', 'TSAEA': 'AES'}
    m = re.search(r'(ESI|AES|EB|IRT|CN|TM|TSAeA|ID)\b', p1 or '', re.I)
    allkeys = [(f'{v}-{tagy}', sem) for v in dict.fromkeys(progs.values())]
    if m and 'optional' not in p0.lower():
        code = progs[m.group(1).upper()]
        lang = 'EN' if code in ('AES', 'CN') else 'RO'
        return code, 'M', y, lang, code, [(f'{code}-{tagy}', sem)] + allkeys, True
    return 'OPT', 'M', y, 'RO', 'Optional', allkeys, True

# ---------- cell text ----------
def parse_cell(v):
    v = v.replace('\r', '')
    m = re.match(r'^-\s{3,}(.+)$', v)
    if m:
        return [('even', m.group(1).strip())]
    parts = [p.strip() for p in v.split('\n') if p.strip()]
    typed = lambda s: re.search(r'\(\s*(c|s|l|p)\s*\)', s, re.I)
    if len(parts) == 2 and (('-' in parts) or all(typed(p) for p in parts)) and all(p == '-' or typed(p) for p in parts):
        out = []
        if parts[0] != '-': out.append(('odd', parts[0]))
        if parts[1] != '-': out.append(('even', parts[1]))
        return out
    return [('all', ' '.join(parts))]

ROOM_RE = re.compile(r'\b(A[12]\s?Chimie|A[12]\s?CH|PN Hidro|H\d\s+Hidro\w*|Mec\s?\d+|SPM\s?et\.?\s?\d|Constructii[^,]*?etaj \d|[A-DMN]\d{2,3}[a-d]?|D1)\b', re.I)

def split_entry(t):
    m = re.match(r'^(.*?)\s*\(\s*(c|s|l|p)\s*\)\s*(.*)$', t, re.I)
    if m:
        abbr, typ, rest = m.group(1), m.group(2).lower(), m.group(3)
    else:
        abbr, typ, rest = t, ('s' if re.search('sport', t, re.I) else 'c'), ''
        rm = ROOM_RE.search(abbr)
        if rm and rm.start() > 0:
            rest = abbr[rm.start():]; abbr = abbr[:rm.start()]
    wk = re.search(r'\b[sS](\d{1,2})\s*-\s*[sS]?(\d{1,2})\b', t)
    rm = ROOM_RE.search(rest)
    lm = re.search(r'([A-ZȘȚĂÎÂ]\.\s?-?[A-ZȘȚĂÎÂ][a-zăâîșțşţA-ZȘȚĂÎÂ\-]+)', rest)
    abbr = re.sub(r'^[-\s]+|[,\s.-]+$', '', abbr)
    return {'abbr': norm(abbr), 'type': typ, 'room': norm(rm.group(1)) if rm else '',
            'lect': re.sub(r'\.\s?', '. ', lm.group(1), count=1) if lm else '',
            'weeks': f'{wk.group(1)}-{wk.group(2)}' if wk else None}

# ---------- abbreviation -> syllabus item ----------
def words(name):
    n = re.sub(r'\(.*?\)', ' ', strip(name))
    w = [x for x in re.split(r'[\s,.\-–/]+', n) if x]
    num = w[-1] if w and re.fullmatch(r'\d', w[-1]) else ''
    ws = w[:-1] if num else w
    return ws, [x for x in ws if x not in STOP], num

def score(abbr, name):
    a = strip(abbr)
    ak = re.sub(r'[^a-z0-9]', '', a)
    if not ak:
        return 0
    ws, sig, num = words(name)
    full = re.sub(r'[^a-z0-9]', '', strip(re.sub(r'\(.*?\)', '', name)))
    if full == ak:
        return 10
    ini, ini_all = ''.join(x[0] for x in sig) + num, ''.join(x[0] for x in ws) + num
    if ak in (ini, ini_all):
        return 9
    pieces = [p for p in re.split(r'[.\s]+', a) if p]
    if pieces and len(pieces) <= len(ws) and all(ws[i].startswith(re.sub(r'\d$', '', p)) for i, p in enumerate(pieces)):
        return 8
    if not re.search(r'\d$', ak) and ak == ini.rstrip('0123456789'):
        return 7
    # letters must be initials of words, in order (skipping words allowed)
    letters = re.sub(r'\d$', '', ak)
    i = 0
    for wd in sig:
        if i < len(letters) and wd[0] == letters[i]:
            i += 1
    if len(letters) >= 2 and i == len(letters) and sig and sig[0][0] == letters[0]:
        return 4
    return 0

SKIP = re.compile(r'^(tutor|unif|psih|pedagog|b\d{3}|cel\d)', re.I)
LANG = re.compile(r'^(lb\.?|limba|limbi)\b', re.I)
SPORT = re.compile(r'^(ed\.?\s*fizic|sport|educ)', re.I)
RP = re.compile(r'^(practica de cercetare|practica cercetare|research pract|practica profesionala)', re.I)

# Manual expansions where the abbreviation isn't initials of the syllabus name. Value: text to find in the syllabi.
OVERRIDE = {
    'AEMEA': 'Aparate electronice de măsură și control', 'AEMTC': 'Aparate electronice de măsură și control',
    'MICROEC': 'Microeconomie', 'TCRME': 'Tehnici CAD',
    'CS': 'Communications Systems', 'EIM': 'Electronic Instrumentation for Measurement', 'EI': 'Electronic Instrumentation for Measurement',
    'VI': 'Virtual Instrumentation for Electronics', 'VIE': 'Virtual Instrumentation for Electronics',
    'MICROW': 'Microwaves', 'ITT': 'Information Transmission Theory', 'RC': 'Radiocommunications',
    'PS': 'Procesoare de semnal', 'SAC': 'Sisteme electronice de acționare', 'EEI': 'Echipamente electronice de interfațare',
    'SWEA': 'Software pentru electronică aplicată', 'RC2': 'Radiocomunicații 2', 'RNI': 'Rețele numerice integrate',
    'CTC': 'Circuite de telecomunicații', 'TMM': 'Tehnologii multimedia', 'GC': 'Grafică computerizată',
    'TETC': 'Testarea echipamentelor electronice pentru telecomunicații', 'SWTC': 'Software pentru telecomunicații',
    'DVDT': 'Digital VLSI Design Techniques', 'EET': 'Electronic Equipment Testing', 'EETT': 'Electronic Equipment Testing',
    'IDN': 'Integrated Digital Networks', 'MC': 'Mobile Communications', 'MICROELECTR': 'Technological Fundamentals of Microelectronics',
    'C2CC': 'Car to Car Communication', 'PSA': 'Procesoare și sisteme de achiziție', 'MSS@M': 'Modelare statistică și stocastică',
    'SSNC': 'Semnale și sisteme numerice de comunicații', 'DCEPC': 'Digital Control of Electronic Power Converters',
    'LPES': 'Low Power Electronic Systems', 'OEPSP': 'Optimization of Electronic Products', 'OPTIM': 'Optimization of Electronic Products',
    'PL1': 'Programming Languages 1', 'GAC': 'Computer Aided Graphics', 'AI1': 'Applied informatics 1',
    'LP1': 'Limbaje de programare 1', 'ASC': 'Analiza și sinteza circuitelor', 'ML': 'Machine Learning',
}
# Names that come from the same text in the timetable, kept as they are written there (no syllabus entry).
LITERAL = {'MICROEC': ('Microeconomie', 'Microeconomics')}

def find_name(text, keys):
    t = strip(text)
    for k, sem in keys:
        for it in SYL.get(k, {}).get('items', []):
            if t in strip(it[1]) and it[0] == sem:
                return it, True
    for k in SYL:
        for it in SYL[k]['items']:
            if t in strip(it[1]):
                return it, False
    return None, False

def resolve(abbr, info):
    tag, level, year, lang, prog, keys, cohort_ok = info
    key = re.sub(r'[^A-Z0-9]', '', strip(abbr).upper())
    if SKIP.match(abbr):
        return 'skip'
    if LANG.match(abbr):
        it, ok = find_name('Limbi moderne 1' if lang == 'RO' else 'Foreign Language 1', keys)
        return (it, ok) if it else None
    if SPORT.match(abbr):
        it, ok = find_name('sport', keys)
        return (it, ok) if it else None
    if RP.match(abbr):
        it, ok = find_name('Research Practice' if lang == 'EN' else 'Practica', keys)
        return (it, ok) if it else None
    ov = OVERRIDE.get(key + ('@M' if level == 'M' else '')) or OVERRIDE.get(key)
    if ov:
        it, ok = find_name(ov, keys)
        if it:
            return it, ok
        if key in LITERAL:
            return ('literal', LITERAL[key])
    best, bs, tie = None, 0, False
    for k, sem in keys:
        for it in SYL.get(k, {}).get('items', []):
            if it[0] != sem:
                continue
            s = score(abbr, it[1])
            if s > bs:
                best, bs, tie = it, s, False
            elif s == bs and s > 0 and best and strip(best[1]) != strip(it[1]):
                tie = True
    if best and bs >= 4 and not tie:
        return best, True
    return None

# ---------- build ----------
courses = {}        # (level, year, lang, canonical name) -> course dict
sessions = []
unresolved = defaultdict(int)
seen_tags = defaultdict(set)

def gid(label):
    m = re.search(r'(\d)\s*\.\s*(\d)', label)
    return f'{m.group(1)}.{m.group(2)}' if m else re.sub(r'\s+', '', label)

for f, fd in raw['files'].items():
    legend = fd['legend']
    for r in fd['recs']:
        info = series_info(f, r['p0'], r['p1'])
        tag, level, year, lang, prog, keys, cohort_ok = info
        for weeks, text in parse_cell(r['v']):
            e = split_entry(text)
            if not e['abbr']:
                continue
            res = resolve(e['abbr'], info)
            if res == 'skip':
                continue
            if res is None:
                unresolved[f"{f}|{tag}|{e['abbr']}"] += 1
                continue
            if res[0] == 'literal':
                name, en = res[1]; ects = None; is_en = lang == 'EN'
            else:
                it, ok = res
                name = re.sub(r'\s*\(.*?\)\s*$', '', it[1]).strip() if not re.search(r'\((C|Python|OOP)\)$', it[1]) else it[1]
                if name.lower().startswith('educație fizică și sport') and lang == 'EN':
                    name = re.sub(r'^.*-\s*', '', name)
                ects = it[2] if (ok and cohort_ok) else None
                en = ''
            ckey = (level, year, lang, strip(name))
            c = courses.get(ckey)
            if not c:
                c = courses[ckey] = {'name': name, 'level': level, 'year': year, 'lang': lang, 'progs': [], 'lects': [], 'ects': ects, 'abbr': e['abbr']}
            if prog not in c['progs']:
                c['progs'].append(prog)
            if e['lect'] and e['type'] == 'c' and e['lect'] not in c['lects']:
                c['lects'].append(e['lect'])
            if c['ects'] is None and ects is not None:
                c['ects'] = ects
            room = e['room']
            if not room and e['type'] in ('l', 'p'):
                room = legend.get(f"{r['p0']}|{re.sub(r'[^A-Za-z0-9]', '', e['abbr']).upper()}", '')
            wk = weeks if weeks != 'all' else (e['weeks'] or 'all')
            grp = [f"{'' if tag in ('A', 'B', 'E') else tag + ' '}{tag if tag in ('A', 'B', 'E') else ''}{gid(g)}".strip() for g in r['grp']]
            sessions.append({'c': ckey, 'type': e['type'], 'day': r['day'], 'start': r['start'], 'end': r['start'] + r['dur'],
                             'whole': r['all'], 'tag': tag, 'grp': grp, 'room': room, 'weeks': wk, 'guess': r['g']})
            if r['all']:
                seen_tags[ckey].add(tag)

# groups: a whole-series session is "*" when the course is taught to one series only, else the series tag
out_sessions = []
for s in sessions:
    if s['whole']:
        g = '*' if len(seen_tags[s['c']]) <= 1 else s['tag']
    else:
        g = ','.join(dict.fromkeys(s['grp']))
    s['groups'] = g
seen = set()
for s in sessions:
    k = (s['c'], s['type'], s['day'], s['start'], s['end'], s['groups'], s['weeks'])
    if k in seen:
        continue
    seen.add(k)
    out_sessions.append(s)

# codes
used = set()
def make_code(c):
    base = re.sub(r'[^A-Z0-9]', '', strip(c['abbr']).upper())[:6] or 'C'
    if len(base) < 2 or base in ('LB', 'LBENGL', 'LBGERM', 'EDFIZI', 'SPORT'):
        base = ''.join(w[0] for w in words(c['name'])[1]).upper()[:5] or base
    pre = f"ETC{'M' if c['level'] == 'M' else ''}{c['year']}"
    code = f'{base}-{pre}'
    i = 2
    while code in used:
        code = f'{base}{i}-{pre}'; i += 1
    used.add(code)
    return code

codes = {}
for k, c in sorted(courses.items(), key=lambda kv: (kv[1]['level'], kv[1]['year'], kv[1]['lang'], kv[1]['name'])):
    codes[k] = make_code(c)

result = {
    'courses': [[codes[k], c['name'], c['year'], ', '.join(c['lects'][:2]), c['lang'], '/'.join(c['progs']), '', 'ETC', c['ects'], c['level']]
                for k, c in courses.items()],
    'sessions': [[codes[s['c']], s['type'], s['day'], s['start'], s['end'], s['groups'], s['room'], s['weeks']] for s in out_sessions],
    'unresolved': dict(unresolved),
    'guessed': sum(s['guess'] for s in out_sessions),
}
json.dump(result, open(sys.argv[2], 'w'), ensure_ascii=False, indent=0)
print(len(result['courses']), 'courses', len(result['sessions']), 'sessions', result['guessed'], 'with guessed length')
print('unresolved:', result['unresolved'])
