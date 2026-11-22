# UPT Erasmus Companion – Project log

AI Bootcamp hackathon project (2 days, team of 4, pitch judged on problem + user insight).
App for incoming **Erasmus students** at **Universitatea Politehnica Timișoara (UPT)**, Faculty of Automation and Computing (AC).
This file is updated after every prompt. Newest entries at the bottom.

## Links
- Team doc (features & build plan): https://claude.ai/artifact/8spreMeYBYg3f5EnNTAXxX
- Web prototype: https://claude.ai/artifact/2C2upYhU4vBxfU15eydP3q
- Timetable source: https://ac.upt.ro/orare/ (Semester I 2026/27 Excel workbook)
- Official guide: UPT International Students' Guide 2026–2027 (PDF provided by the team)

## Key decisions so far
- Scope: **Erasmus students only**, AC faculty only, for the demo.
- Biggest problem found: **accommodation**; second: courses/timetable (mixing years, Romanian-only courses, clashes).
- Positioning: the **local UPT layer** that the Erasmus+ App / Erasmus Play / ESN buddy programme can't cover.
- Stack now: **SwiftUI app in Xcode** for iPhone 13 mini (only the user codes in Swift; Claude writes the code) + a read-only web prototype.
- No invented facts: unknown UPT rules are marked "check with your coordinator" / [verify].

---

## Log

### 1 · Kick-off (20 Nov 2026)
- Asked clarifying questions. Answers: 2-day hackathon, 4 people, UPT = Politehnica Timișoara, mock data + a few real items, judges reward problem + user insight.
- Delivered: personas (Lucía, Jonas, Aylin), feature split, stack feedback, where AI helps, data model, 2-day plan.

### 2 · Accommodation is the biggest problem; switch to Xcode (no Expo)
- Re-scoped around housing: listing search, AI listing checker (later dropped from the web), renting checklist.
- Stack changed to SwiftUI + Supabase; Vercel only for a static page.

### 3 · Only the user writes Swift; how to pitch well
- Pitch structure, interview script, demo rules, Q&A prep. Found ESN/ESU survey: 25% of exchange students hit scams, 41% lacked housing info, 49% faced deposits > 1 month.

### 4 · Maps for app and web
- MapKit in the app, Leaflet/OSM on the web, coordinates stored once and shared.

### 5 · Website = curated map + all categories + AI assistant
- Site structure: map, accommodation, courses, schedule, life planner, events, AI assistant grounded in curated data.

### 6 · Real timetable + checklists
- Read the real AC timetable (Computers English, years 2 and 3) from the UPT SharePoint Excel.
- Built the demo scenario: Jonas (German, year 3) with 4 year-3 courses and 2 year-2 courses that clash.
- Wrote 3 checklists: first days in town, checking in, before you sign or pay.
- File: `upt_mock_seed.json` (sent in chat).

### 7 · Review of the official International Students' Guide
- Finding: guide mentions "Erasmus" once and private housing not at all; written for non-EU degree students.
- Listed gaps (housing, EU path, EHIC, 112, calendar, costs, transport, departure) and how an app fixes them (personal path, deadlines, step chain, map pins, open-now hours, document wallet, AI with page references).

### 8 · Communication section
- Swift `Communication.swift`: groups/offices/lecturers matched to faculty + courses, open-now office hours, WhatsApp etiquette. Sample group data only.

### 9 · Brainstorm mode / concept check
- Competitors checked: Erasmus+ App (official, open source since March 2026), Erasmus Play (500+ destinations), ESN Timișoara buddy programme.
- Recommended concept: "Your UPT first month, sorted" – local layer + AI from official sources, housing as the emotional hook.

### 10 · Course entry at sign-up
- Options: pick from list, Learning Agreement upload (AI), timetable screenshot, Campus Virtual (no timetables there).
- Two-step account: email before arrival, UPT account after the Study Contract.

### 11 · Team doc
- Created the team doc "UPT ERASMUS App – Features & Build Plan" (link above), incl. architecture diagram.

### 12 · Web prototype v1
- Extracted the **whole** AC workbook in-browser: Computers (English) years 1–4, 32 courses, 152 sessions + room legend.
- Built and published the web prototype: profile → course matching (AI + offline) → schedule builder with clash detection → paperwork → map (building finder).
- Tested in headless Chrome; fixed one wrong match and layout issues.

### 13 · Romanian courses + class detail pages
- Added 57 Romanian-taught courses (Calculatoare + Tehnologia Informației), total 89 courses / 416 sessions.
- 🇷🇴 "Taught in Romanian" flag everywhere; English translations (ours) for matching; language preference in profile.
- Class detail pages: lecturer, language, programme, sessions, buildings, clashes, equivalent in the other language. Map lists classes per building, each opens its page.

### 14 · Upload button
- Upload PDF / Word .docx / text / photo next to "Your courses". PDF.js + mammoth.js on the web; AI for photos.
- PDF and Word readers tested in the browser pane with sample files.

### 15 · Native iPhone app (this prompt, 20 Nov 2026, ~23:00)
- Created the Xcode project at `~/Documents/UPTErasmus` (SwiftUI, iOS 17+, iPhone only, Xcode 16 synchronized folder).
- Ported every web feature to Swift:
  - `Models.swift` – courses, sessions, buildings (room legend), offices (guide), timetable loader.
  - `timetable.json` – the real timetable data (89 courses, 416 sessions), bundled.
  - `Scheduler.swift` – fixed lectures + best lab/seminar/project slots, clash detection.
  - `Matcher.swift` – offline TF-IDF course matching with German synonyms, Romanian alternatives.
  - `DocumentReader.swift` – on-device reading: PDFKit (PDF), built-in zip reader (.docx), Vision OCR (photos).
  - Views: `ProfileView`, `MatchView` (+ course browser), `ScheduleView` (week grid, tap a class), `PaperworkView`, `PlacesView` (MapKit, buildings geocoded from their real addresses), `CourseDetailView`.
- No AI service needed on the phone (iPhone 13 mini has no Apple Intelligence); matching and OCR run offline.
- Opened in Xcode 27.2 on the Mac mini: **Build Succeeded** (0 errors). Xcode picked the Personal Team automatically and installed the app on the iPhone ("Viphone").
- Launch blocked until the developer certificate is trusted on the iPhone (Settings → General → VPN & Device Management) – expected for a personal team.
- Fixed the one code warning (`AppState.defaultArrival` now `nonisolated`). The other warning is Xcode's "Update to recommended settings" (harmless).

### 16 · What's left to build? (20 Nov 2026, 23:41)
- Reviewed what the app has vs the original plan. Biggest gap: **accommodation** (the #1 problem from research) is not in the app yet.
- Proposed next features, by pitch value: Housing tab, Communication tab (code from step 8 exists), schedule overlap with friends via QR code, plus quick wins (calendar export, deadline reminders, app icon, onboarding).
- Waiting for the team to pick what to build next.

### 17 · App icon + Erasmus@UPT colour guide (21 Nov 2026, 10:40)
- **App icon:** the team's icon (UPT + Erasmus+ logo, navy) from `Documents/AI BOOTCAMP`. Its white rounded corners were filled with the icon's navy (#0E1C5F) so iOS's own rounding looks clean. Added as `Assets.xcassets/AppIcon.appiconset`.
- **Colours:** applied `COLOR-GUIDE.md` (copied into this folder). All 35 tokens are colour sets in `Assets.xcassets` with light and dark values; `Theme.swift` exposes them with the guide's names. No raw hex in components.
  - Charcoal top bar with the "Erasmus@UPT" wordmark (brand-mark teal only on "@UPT").
  - Teal accent is the only action colour (global accent = `AccentColor`).
  - Status: "Taught in English" = ok, "Taught in Romanian" = warn, clashes/errors = err.
  - Faculty colour AC orange for dots and timetable block borders; years are neutral chips (no extra hues).
  - Dark values not given in the guide were derived by us: shellSub, shellHover, shellStrip, faint, accentHover, accentSoft*, selection, status colours, lighter faculty colours.
- App display name changed to **Erasmus@UPT** to match the guide.
- Built and ran on the iPhone (Viphone) from Xcode: runs with the new icon and colours. Fixed two warnings: moved the default arrival date to a file-level constant, and turned off Xcode's generated asset symbols (the "accent" token clashed with "AccentColor").

### 18 · Learning Agreement PDF fix + new card-based UI (21 Nov 2026, 10:47)
- **PDF problem:** the offline reader kept every "course-looking" line, including the student's name, addresses and course descriptions. The web app avoids this with AI.
- **Fix:** new `learningAgreementCourses()` in `DocumentReader.swift` reads **Table A / Tabelle A** rows that start with a reference code (e.g. `MOD-01 Datenbanken … 5`) and attaches each row's ECTS. Tested on the team's `Erasmus+ Learning Agreement (DE).pdf`: all 8 courses found, no noise. Generic fallback now skips sentences and long lines.
- **Matching:** added German words to the matcher (Grundlagen, Künstlichen, Mustererkennung, Softwareverifikation, Validierung, Bioinformatik, Funktionelle, Genomik …). Bioinformatik maps to the Romanian-only course, as that LA asks.
- After reading a file the app now matches straight away.
- **UI redesign** (it looked like the Settings app): replaced grouped lists/forms with scrolling **cards** on the light ground. New `Components.swift`: ScreenScroll, SectionTitle, Card, Primary/Secondary button styles, LabeledInput, StatTile, LinkRow, InfoRow, CheckCircle, MapsLink.
  - You: welcome header, stat tiles (courses, clashes, steps done), input cards, segmented choices.
  - Courses: upload card (file/photo), editor card, match cards (your course → UPT course with faculty stripe, confidence pill, language/year tags), card-style course browser.
  - Schedule: header + stat tiles, week grid card, course legend card.
  - Paperwork: progress card with next deadline, phase cards with tick rows and due-date pills.
  - Map: map in a rounded card, room finder card, building cards with class rows, office cards.
  - Class page: header card with faculty stripe, about card, session cards, clashes, buildings.
- Global accent now uses the `accent` token directly (removed duplicate `AccentColor` set → no asset-symbol warning; old set moved to `_to_delete/`).
- **Bug found on the phone:** reading the PDF froze on "Reading…". Cause: "rechnernetze" was in the German word list twice, and Swift crashes on duplicate dictionary keys the first time matching runs (Xcode paused the app in the debugger). Fixed, rebuilt, running on the iPhone. Also re-sent one file whose first copy to the Mac was stale.

## Open items
- Interview 5–8 real Erasmus students at UPT (weakest evidence).
- Verify [verify] items (registration certificate for EU students, dorm documents, transport payment).
- Pitch length and Q&A format still unknown.
- Master's programmes not in the timetable data yet.

## 19 · Sat 21 Nov 2026 · ETC faculty, cross-faculty matching, minimum ECTS
**Asked:** add Electronics & Telecommunications (ETC); can a CS student be matched to another faculty's course; a minimum ECTS is important. Mid-turn: a Gemini prompt for pitch brainstorming (sent in chat).
**Data (real, nothing invented):**
- ETC timetables are published Google Sheets (etc.upt.ro/avizier/orar → Orar semestrul 1, posted 23 Sep 2026). Read via `pubhtml/sheet` (keeps merged cells, so durations are correct). Only years 1–2 have an English line ("ETcTI ENG"); years 3–4 are Romanian only (EA, TST, PI), so they're not included.
- Imported the ENG line, subgroups 1.1–1.3 (the public sheet hides ENG group 2): 16 ETC courses, 45 sessions. Lab rooms come from the sheet's legend. Top/bottom split cells = odd/even weeks.
- Course names + ECTS: ETC syllabus pages (TST English 2026–2030 for year 1, 2025–2029 for year 2). Both total 30 ✓.
- AC ECTS: plan 2025–2029 C-EN (year 1, year 2 partly), 2024–2028 C-EN sem 5 (year 3) and 2023–2027 C-EN sem 7 (year 4), read with pdf.js. Electives are 5 ECTS each.
- **Not confirmed (shown as "ECTS ?", not counted):** AC year-2 OOP and DSA (not in the 2025–2029 sem-3 plan as read) and all Romanian-taught courses.
- timetable.json: course rows now have [7] faculty and [8] ects (null = unknown). 105 courses, 461 sessions.
**App:**
- Course has faculty + ects. Matcher searches all faculties; near-ties (within 0.05) go to AC. Added 11 German electronics synonyms (no duplicate keys, checked).
- New ECTSMeter (total vs minimum, "N short", bar, unknown-credit note, Table A vs Table B check, minimum stepper) on Courses results and Your week. Minimum also on the You tab; stored separately (key "minECTS", default 30).
- FacultyTag + ECTSTag on match cards, course list (new faculty filter), course detail (Faculty, Credits rows, cross-faculty banner), schedule legend and blocks.
- Demo profile name is now Lukas Weber (matches the Learning Agreement PDF).
- Build succeeded; launch waited for the iPhone to be unlocked.
**Open items:** ETC has no colour in COLOR-GUIDE.md, so it uses the neutral `faint` grey for now; the user must choose one. ETC N-rooms (N303, N305, N207) and "PN Hidro" aren't mapped to buildings (no address source yet). The web prototype doesn't have ETC/ECTS yet.

## 20 · Sat 21 Nov 2026 · All ETC files + masters (paused), N rooms, one faculty colour
**Asked:** N rooms = new Mechanical building (Mecanica Nouă), M = Mechanical; ETC has a separate file per year; add master's; all faculties use the same colour. Then: pause ETC to save usage, and test the app live with impeccable/GSD.
**Done:**
- One faculty colour: `Theme.faculty()` returns the AC colour for every faculty; the faculty is shown by its label (FacultyTag).
- New building "New Mechanical building (Mecanica Nouă)" for rooms N###; M### rooms → old Mechanical building. Its address isn't confirmed, so it has no map pin yet.
- ETC import, **paused before merging into the app** (the app still has the ETC English years 1–2 from entry 19). Work saved in `tools/etc_import/`:
  - `parse.py` reads all 4 bachelor files + master years 1–2 (Google Sheets CSV for every column + published HTML for cell lengths) and all ETC syllabus pages.
  - `build.py` maps abbreviations to syllabus names. Draft result `etc_draft.json`: 128 courses, 767 sessions.
  - Findings: year 3–4 "PI" line is taught in English (course names match the TST English syllabus). No syllabus pages exist for the 2023–2027 and 2024–2028 cohorts, so year 3–4 names come from the 2025–2029 plan and their ECTS stay unconfirmed. 153 sessions have a guessed length (columns hidden in the public sheet). ~25 abbreviations unresolved (e.g. TICEA, SAD, BMEV, VHDL, IT, SD, WC, TAM, PMM, MCSW, NBFHE).
  - To finish: clean "Opțional împachetat …" names, translate Romanian names to English for matching, fix the master research-practice language, merge into timetable.json.
- AC master's sheets: not started.
- Transfer trick: the browser pane can only save a download after a real click, so the data is saved via an on-page button.

## 21 · Sat 21 Nov 2026 · User-flow bug audit (taps, double taps, state)
**Asked:** test like a real user; no AI slop; catch buttons that act differently on a second press; Apple-quality. GSD checked: not available in this chat (Claude Code planning workflow, not a UI tester); Design plugin is enabled.
**Fixed:**
1. Adding/removing any course wiped all hand-picked lab/seminar slots → now only the removed course's slots are dropped.
2. One tap rebuilt the week twice (course + locks) on the main thread → rebuilds are coalesced into one.
3. "Add N courses to my week" pressed twice → second press now changes nothing.
4. Course list: coming back from a course page reset the language filter to English → default applies only on first open.
5. Picking a UPT course by hand on a "No match" card left it unchecked (not added) → picking includes it, "No match" excludes it.
6. Upload buttons and Match stayed active while a file was being read → disabled until reading finishes (no overlapping reads).
7. Leftover "Jonas" labels and the hard-coded "89 courses" → "Try an example", "Lukas", live course count.
8. Slot picker showed raw codes (e.g. "SS-ETC") → shows the course name.
Build compiled; launch waited for the iPhone to be unlocked.

## 22 · Sat 21 Nov 2026 · ETC removed, official ECTS
**Asked:** remove ETC for now; get ECTS from the web (user found international.upt.ro course catalogue).
**Done:**
- ETC courses and sessions removed from timetable.json (89 courses, 416 sessions again); ETC faculty filter, ETC profile row and empty picker section removed. Import work stays in tools/etc_import/ for later.
- ECTS source is now the official **UPT Erasmus course catalogue 2026–2027** (SharePoint folder linked from international.upt.ro → "Course_catalogue_Automatics and Computing_2026-2027_ERASMUS.xlsx"). All 32 English-taught AC courses matched; it confirms the study-plan values and adds OOP 5 and DSA 5. Copy of the file: Documents/AI BOOTCAMP/AC_catalogue_2026-2027.xlsx.
- Still unconfirmed: the 57 Romanian-taught courses (the catalogue lists only English-taught units). Next source if needed: the C-RO / TI study plans on upt.ro.
- The catalogue also has a Master 2026–2027 sheet (AC master's programmes with ECTS), useful when master's are added.

## 23 · Sat 21 Nov 2026 · 5 test Learning Agreements + slot picker that shows what fits
**Asked:** 5 different LA PDFs for user testing (Patrick, Sergiu, Denis, Alex, Anon; 3 EU, 2 non-EU), each with clashing timetables and one Romanian-taught course; let students choose a lab group that doesn't clash.
**Test LAs** (test-learning-agreements/, generator make_las.py; all marked "SAMPLE", fictional home universities). Verified with a Python copy of the app's LA parser + matcher + clash check:
| Student | EU | Year | Lecture clashes (real UPT timetable) | Romanian-taught match |
|---|---|---|---|---|
| Patrick O'Sullivan, Ireland | EU | 3 | DB × AIF Mon 8–10; SSD × Network Admin Thu 10–12; AIF × Network Admin Thu 13–14 | Network Administration (AR-TI) |
| Sergiu Ceban, Moldova | non-EU | 3 | OOP × CET Fri 9–10; CET × DD Tue 8–10; DSA × MS Wed 10–11 | High-Performance Computing (CIP-TI) |
| Denis Moreau, France | EU | 4 | WAD × Bioinformatics Tue 12–14; MSA × PDA Wed 12–14 | Bioinformatics & Functional Genomics (BGF-TI) |
| Alex Becker, Germany (German titles) | EU | 2 | CA × AG Thu 12–14; EE × LSIC Thu 16–18 | Mensch-Computer-Interaktion → Interfețe om-calculator (IOC-TI) |
| Anon Srisuk, Thailand | non-EU | 3 | FCPL × STA Thu 9–10; STA × SSD Thu 10–11 | CMS Application Administration (AAC-TI) |
All also have labs where only some groups fit (e.g. CAD 1 of 3, MS 1 of 3, LSIC 1 of 2). UPT ECTS totals land at 23–25 because the Romanian course has no confirmed ECTS → the ECTS meter warns (useful test).
**App:** new SlotPicker on Your week: each lab/seminar/project shows "N of M groups fit your week"; the menu lists fitting groups first, clashing ones say what they clash with; if the current group clashes and a free one exists, a one-tap "Switch to a group that fits". Picks keep the slot's real index, so a choice never shifts. Built and running on the iPhone.

## 24 · Sat 21 Nov 2026 · Reset between testers
**Asked:** did you modify Xcode? Add a reset to remove the current person and their courses so testers can switch.
- Xcode itself isn't changed: only the project's Swift files on the Mac are edited, then built with the Run button (project settings untouched since the icon/accent change in entry 14).
- You tab → "Start over with a new student" (red, with a confirmation): clears profile, courses, lab groups, checklist and ECTS minimum, returns to the You tab, and rebuilds every tab (`.id(state.session)`) so typed course lists, match results and open pages are gone too.
- Lesson: never commit in the same parallel step as an edit (the Mac got stale copies once more); always verify sizes before building. Built and running on the iPhone.

## 25 · Sat 21 Nov 2026 · Fonts, "E…" icon, one group per year
**Asked:** Public Sans (400–800) for all interface text, Red Hat Mono (500–600) for course codes like L002.25.03.F1, system font as fallback; what is the tiny "E…" in the top-left; labs where each group has its own time aren't implemented.
- **Fonts:** variable TTFs from google/fonts in UPTErasmus/Fonts (OFL 1.1, FONTS-LICENSE.md). New AppFont.swift registers them at launch (CTFontManager, no Info.plist change) and sets weights through the 'wght' axis; Font.app(style, weight) scales with Dynamic Type; Font.code(…) = Red Hat Mono. All `.font(.style…)` calls replaced (9 files); nav bar and tab bar use Public Sans too. Falls back to the system font if registration fails.
- **Official codes:** catalogue codes (e.g. L002.25.03.F1) added to the 32 English courses (timetable.json row[9]) and shown in Red Hat Mono on match cards, course detail and timetable blocks.
- **"E…" icon:** it was the "Erasmus@UPT" wordmark squeezed into the top bar on the 13 mini. Removed from the bar; the wordmark now sits at the top of the You screen.
- **Groups:** a student now sits in one group per year/programme. Scheduler searches group combinations (fewest clash-hours) unless the student picks one; labs/seminars follow the group, hand-picked slots still win. New "Your groups" cards on Your week with a menu: Automatic, or each group with "+N clash hours". Picking a group drops that year's hand-picked slots. Lab cards now start with the group ("Group 1.2 · Mon 10–12 · B623").

## 26 · Sat 21 Nov 2026 · Erasmus catalogue courses only; PDFs remade
**Asked:** focus only on the Erasmus subjects; remake the test PDFs without the niche Romanian-only subjects.
- timetable.json now holds only the 32 courses in UPT's Erasmus course catalogue 2026–2027 for AC (taught in English, every one with official code + ECTS); 152 sessions. Romanian-taught courses removed.
- UI: "Languages you can study in" removed from You; language filter removed from the course list (search now also finds official codes); match picker is one list; copy updated ("courses UPT offers Erasmus students").
- Test LAs regenerated (Romanian course swapped for a catalogue course), verified:
  Patrick: DB×AIF Mon 8–10, SSD×STA Thu 10–11 · UPT 29 ECTS
  Sergiu: OOP×CET, OOP×MER, CET×MER (Fri), CET×DD Tue, DSA×MS Wed · 30 ECTS
  Denis: MSA×PDA Wed 12–14 · 28 ECTS (under 30 → meter warns)
  Alex (German titles): CA×AG Thu 12–14, EE×LSIC Thu 16–18 · 28 ECTS
  Anon: FCPL×STA, STA×SSD Thu, MS×CAD Wed 8–10 · 30 ECTS

## 27 · Sat 21 Nov 2026 · Pitch prompt + landing-page hero
- Gemini prompt for selling the idea + hero section (sent in chat).
- Hero section built as a Design canvas: https://claude.ai/artifact/7ZsD4ATUvaksft6sFdpZRK — charcoal top bar with the Erasmus@UPT wordmark, headline "Your UPT timetable, clash-free before you land.", upload CTA + "See how it works", 3 facts (32 catalogue courses, every lab group, on-device reading), and an iPhone mock of Your week (Patrick: Databases × AI Fundamentals clash, 29/30 ECTS, lab group 1.2 fits, code L002.25.03.F1 in Red Hat Mono). Colours from COLOR-GUIDE.md, Public Sans + Red Hat Mono via Google Fonts. Only true claims; nav links are placeholders.
- Hero v2: phone redrawn as an iPhone (Dynamic Island, side buttons, home indicator); "32 courses" now says "this autumn at UPT's Faculty of Automation and Computing, from its official Erasmus catalogue". Catalogue totals for context: AC bachelor 84 courses (41 autumn, 43 spring), AC master's 120 (76 autumn, 44 spring); the app holds the 32 autumn bachelor courses that have a published timetable.

## 28 · Sat 21 Nov 2026 · New app structure: landing, accounts, 5-tab layout
**Asked:** landing page (mobile) with Log in / Register; fake-email registration with a debug fill; Home dashboard after login; custom 5-icon bar: Courses · Schedule · Home (centre, bigger) · Resources · First weeks; Courses = my courses + match + all courses (matching can be partial; Home pushes you to match first); Schedule only once you have courses; Resources split EU / non-EU; First weeks = secretariats, buildings, phone numbers; AC students only; profile icon top-right on every tab.
**Built (all compiled, running on the iPhone):**
- Accounts (AppState): local only, password SHA-256 hashed with the email as salt, each account's data saved separately (u.<email>.*). Register (name, email, password ≥6, EU/non-EU), Log in, Log out, Delete account, Clear courses. Debug builds: "fill test email and password" (tester1@example.com, tester2@…, password erasmus123); login fills the latest tester.
- LandingView: charcoal hero (headline, sub, 3 facts) + Create account / Log in.
- ErasmusTabBar: 4 tabs on a capsule rail with an underline on the selected one; Home is a raised 64 pt circle (teal when selected). Custom container keeps all 5 tabs alive.
- HomeView: greeting + arrival countdown, stats (courses, ECTS/minimum, steps), "Needs your attention" (match courses first → ECTS short → lecture clashes → next deadline → finish profile), To do (next 5 steps, tick off, "All steps"), week summary.
- CoursesView: segmented My courses / Match / All courses; My courses lists added courses (code in Red Hat Mono, ECTS, remove), ECTS meter, See my week.
- ResourcesView: EU / non-EU segmented (defaults to the user's citizenship): legal stay & health, bring with you, first days at UPT, each with its guide page.
- First weeks (PlacesView): Who to ask (offices with tap-to-call / tap-to-email), map + room finder, all faculty buildings with addresses, your classes by building.
- ProfileButton (initials) on every tab → Personal details sheet (exchange details, minimum ECTS, arrival day, account actions).

## 29 · Sat 21 Nov 2026 · UI/UX pass: buttons moved up, neutral text colours, Resources filters, calendar export
**Asked:** move every call to action up in each tab; no green/yellow/red text unless it is a call to action; Resources in tabs/filters instead of a wall of text; a nice "Add to Google Calendar" button on Schedule.
**Built (compiled, running on the iPhone):**
- Buttons moved up: My courses (See my week / Match more / Browse now come before the ECTS meter), Match results ("Add N courses" right under the title), course browser ("N selected" bar now at the top), Course detail (add/remove under the header), Home (stats moved below "Needs your attention"), First weeks (button to add your courses when you have none).
- Colour rule: status text is now ink/grey everywhere; colour only shows in icons, dots, bars and buttons (Banner gets a status icon, StatTile gets a coloured dot, ECTS meter keeps a coloured bar, clash cards and slot captions are neutral, language and "Yours" tags are neutral).
- Resources: EU / non-EU picker + topic chips (Stay & health · What to bring · First days). One list at a time, each row shows only its title; tap to expand the details and the source.
- Schedule: "Add to Google Calendar" card at the top (CalendarExport.swift). It writes an .ics file (Europe/Bucharest time zone, each class repeating weekly with odd/even/range weeks, room + building address, code, lecturer, ECTS) and opens the share sheet → Calendar → pick the Google calendar. Weeks count from Mon 28 Sep 2026 (UPT Semester I start). The winter break is NOT excluded yet: official IF dates not found; add them to `CalendarExport.breakWeeks` once confirmed.

## 30 · Sat 21 Nov 2026 · Content above the tab bar, messages first, simpler calendar button
**Asked:** content ran behind the bottom tab bar; all coloured messages (red/yellow/green) must sit at the top of each screen; Google Calendar button simpler, with a Google image.
**Built (compiled, running on the iPhone):**
- Tab bar now floats over the screens (overlay), and every scroll screen leaves 96 pt at the bottom (`ErasmusTabBar.clearance`), so the last items scroll clear of it.
- Order on every screen is now: title → coloured messages → main button → the rest. Schedule: week status + clash cards right under the title, then the calendar button. Course detail: faculty/Romanian notes and clashes under the header, then Add/Remove (clash text no longer red). Match: reading status under the title; Romanian/other-faculty/years notes above "Add N courses". Paperwork: guide warning under the title. Home already led with "Needs your attention".
- Calendar button: one slim white pill "Add to Google Calendar" + one faint line about the 28 Sep start / winter break. It shows the image set **GoogleCalendar** from Assets if present (drop in Google's official icon); until then a calendar symbol.

## 31 · Sun 22 Nov 2026 · Demo prep: rename to Exchange@UPT, repo ready
- Visible name changed to **Exchange@UPT**: landing wordmark, home-screen label (CFBundleDisplayName), calendar file name. Needs a rebuild (⌘R).
- Added `.gitignore` (macOS, Xcode user data, _to_delete/) and rewrote `README.md` (current features, run steps, folders) so the project can go on GitHub.
