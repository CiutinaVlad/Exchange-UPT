"""Generates 5 sample Learning Agreements for testing the app (python3 -I make_las.py OUTDIR)."""
import sys
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

# DejaVu covers ă, ș, ț, ü, é…
for name, f in [('DV', 'DejaVuSans.ttf'), ('DVB', 'DejaVuSans-Bold.ttf')]:
    pdfmetrics.registerFont(TTFont(name, f'/usr/share/fonts/truetype/dejavu/{f}'))

OUT = sys.argv[1]
NAVY = colors.HexColor('#0E1C5F')

STUDENTS = [
    dict(file='LA_Patrick_OSullivan.pdf', name="Patrick O'Sullivan", country='Ireland', eu=True,
         nationality='Irish', home='Atlantic Technological Institute of Computing (sample)', city='Galway, Ireland',
         prefix='CS', year=3, lang='English', courses=[
            ('CS-3101', 'Databases', 5), ('CS-3102', 'Artificial Intelligence Fundamentals', 5),
            ('CS-3103', 'Software Systems Design', 5), ('CS-3104', 'System Theory and Automation', 5),
            ('CS-3105', 'Image Processing and Recognition', 5), ('CS-3106', 'Parallel and Distributed Algorithms', 5)]),
    dict(file='LA_Sergiu_Ceban.pdf', name='Sergiu Ceban', country='Moldova', eu=False,
         nationality='Moldovan', home='Chișinău Technical University of Informatics (sample)', city='Chișinău, Moldova',
         prefix='TI', year=3, lang='English', courses=[
            ('TI-301', 'Object-Oriented Programming', 5), ('TI-302', 'Computer Engineering and Testing', 5),
            ('TI-303', 'Database Design', 5), ('TI-304', 'Data Structures and Algorithms', 5),
            ('TI-305', 'Modelling and Simulation', 5), ('TI-306', 'Mechanical Engineering and Robotics', 5)]),
    dict(file='LA_Denis_Moreau.pdf', name='Denis Moreau', country='France', eu=True,
         nationality='French', home='École Supérieure d’Informatique de Lyon (sample)', city='Lyon, France',
         prefix='INF', year=4, lang='English', courses=[
            ('INF-401', 'Web Application Design', 5), ('INF-402', 'Database Design', 5),
            ('INF-403', 'Mobile Systems and Applications', 5), ('INF-404', 'Parallel and Distributed Algorithms', 5),
            ('INF-405', 'Concurrent and Event-Based Programming', 5), ('INF-406', 'Management and Marketing', 3)]),
    dict(file='LA_Alex_Becker.pdf', name='Alex Becker', country='Germany', eu=True,
         nationality='German', home='Hochschule für Angewandte Informatik Rhein (sample)', city='Köln, Germany',
         prefix='MOD', year=2, lang='German', courses=[
            ('MOD-21', 'Rechnerarchitektur', 5), ('MOD-22', 'Algebra und Geometrie', 5),
            ('MOD-23', 'Elektrotechnik', 5), ('MOD-24', 'Integrierte Schaltkreise', 5),
            ('MOD-25', 'Objektorientierte Programmierung', 5), ('MOD-26', 'Datenstrukturen und Algorithmen', 5)]),
    dict(file='LA_Anon_Srisuk.pdf', name='Anon Srisuk', country='Thailand', eu=False,
         nationality='Thai', home='Bangkok Institute of Computer Engineering (sample)', city='Bangkok, Thailand',
         prefix='CPE', year=3, lang='English', courses=[
            ('CPE-331', 'Fundamental Concepts of Programming Languages', 5), ('CPE-332', 'System Theory and Automation', 5),
            ('CPE-333', 'Software Systems Design', 5), ('CPE-334', 'Modelling and Simulation', 5),
            ('CPE-335', 'Computer Aided Design', 5), ('CPE-336', 'Verification and Validation of Hardware Systems', 5)]),
]

ss = getSampleStyleSheet()
H1 = ParagraphStyle('h1', parent=ss['Title'], fontName='DVB', fontSize=17, textColor=NAVY, spaceAfter=2)
H2 = ParagraphStyle('h2', parent=ss['Heading2'], fontName='DVB', fontSize=11.5, textColor=NAVY, spaceBefore=10, spaceAfter=4)
P = ParagraphStyle('p', parent=ss['Normal'], fontName='DV', fontSize=9, leading=12)
SMALL = ParagraphStyle('s', parent=P, fontSize=7.5, leading=10, textColor=colors.HexColor('#555555'))
CELL = ParagraphStyle('c', parent=P, fontSize=9, leading=11)


def grid(data, widths, header=True):
    t = Table(data, colWidths=widths)
    st = [('FONTNAME', (0, 0), (-1, -1), 'DV'), ('FONTSIZE', (0, 0), (-1, -1), 9),
          ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#9AA3C7')),
          ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'), ('TOPPADDING', (0, 0), (-1, -1), 4), ('BOTTOMPADDING', (0, 0), (-1, -1), 4)]
    if header:
        st += [('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#E6E9F5')), ('FONTNAME', (0, 0), (-1, 0), 'DVB')]
    t.setStyle(TableStyle(st))
    return t


def make(s):
    doc = SimpleDocTemplate(f"{OUT}/{s['file']}", pagesize=A4, leftMargin=16 * mm, rightMargin=16 * mm,
                            topMargin=14 * mm, bottomMargin=14 * mm,
                            title=f"Learning Agreement – {s['name']}", author=s['name'])
    E = []
    E.append(Paragraph('SAMPLE DOCUMENT – created for testing the Erasmus@UPT app. Not an official agreement.', SMALL))
    E.append(Spacer(1, 4))
    E.append(Paragraph('Erasmus+ Learning Agreement for Studies', H1))
    E.append(Paragraph('Higher Education – Student Mobility for Studies · Academic year 2026/2027 · Winter semester', P))
    E.append(Spacer(1, 6))

    E.append(Paragraph('Student', H2))
    E.append(grid([
        ['Name', s['name'], 'Nationality', s['nationality']],
        ['Field of education', '0613 Software and applications development', 'Study cycle', f"Bachelor, year {s['year']}"],
        ['EU / non-EU citizen', 'EU citizen' if s['eu'] else 'Non-EU citizen (residence permit needed)', 'Home language', s['lang']],
    ], [32 * mm, 62 * mm, 28 * mm, 56 * mm], header=False))

    E.append(Paragraph('Sending and receiving institutions', H2))
    E.append(grid([
        ['', 'Sending institution', 'Receiving institution'],
        ['Name', Paragraph(s['home'], CELL), Paragraph('Universitatea Politehnica Timișoara', CELL)],
        ['Faculty', 'Computer Science', Paragraph('Faculty of Automation and Computing', CELL)],
        ['City / country', s['city'], 'Timișoara, Romania'],
        ['Mobility period', 'Sep 2026 – Feb 2027', 'Sep 2026 – Feb 2027'],
    ], [32 * mm, 73 * mm, 73 * mm]))

    E.append(Paragraph('Table A – Study programme to be matched at the receiving institution', H2))
    E.append(Paragraph('Courses the student needs to cover during the mobility, as listed in the home course catalogue. '
                       'Matching UPT courses are to be agreed.', P))
    E.append(Spacer(1, 4))
    rows = [['Code', 'Course title (home catalogue)', 'Semester', 'ECTS']]
    rows += [[c, Paragraph(t, CELL), 'Winter', str(e)] for c, t, e in s['courses']]
    total = sum(e for _, _, e in s['courses'])
    t = grid(rows, [24 * mm, 110 * mm, 24 * mm, 20 * mm])
    t.setStyle(TableStyle([('ALIGN', (3, 0), (3, -1), 'CENTER')]))
    E.append(t)

    E.append(Paragraph('Table B – Recognition at the sending institution', H2))
    E.append(Paragraph(f'Table A total: {total} ECTS. To be completed after the receiving courses are confirmed. '
                       'The total number of ECTS credits in Table B should correspond to Table A.', P))
    E.append(Spacer(1, 4))
    E.append(grid([['UPT course code', 'UPT course title', 'ECTS']] + [['', '', ''] for _ in range(3)],
                  [34 * mm, 120 * mm, 24 * mm]))

    E.append(Paragraph('Commitment', H2))
    E.append(grid([
        ['Role', 'Name', 'Signature', 'Date'],
        ['Student', s['name'], '', ''],
        ['Sending coordinator', '', '', ''],
        ['Receiving coordinator', '', '', ''],
    ], [42 * mm, 56 * mm, 46 * mm, 34 * mm]))
    doc.build(E)


for s in STUDENTS:
    make(s)
    print('wrote', s['file'])
