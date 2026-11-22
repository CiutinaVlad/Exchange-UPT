# Exchange@UPT (iPhone)

SwiftUI app for incoming exchange (Erasmus) students at UPT, Faculty of Automation and Computing.
Built by team APSV (Abraham, Paul, Serban, Vlad) for the AI Bootcamp, November 2026. Demo prototype.

## What it does
- **Courses** – upload a Learning Agreement (PDF, Word, photo; read on the iPhone) or paste course names; they are matched to UPT's official Erasmus catalogue, with ECTS check and Romanian-taught courses flagged.
- **Schedule** – builds the week from the real AC timetable, shows lecture clashes, picks lab/seminar groups that fit (changeable), exports to Google/Apple Calendar (.ics).
- **Home** – what needs attention next, arrival countdown, to-do steps.
- **Resources** – EU / non-EU paperwork, what to bring, first days (from UPT's International Students' Guide 2026–2027).
- **First weeks** – offices with tap-to-call/email, buildings, map and room finder.

Accounts are local to the phone (demo only). Everything runs offline except the first map load.

## Run it on an iPhone
1. Open `UPTErasmus.xcodeproj` in Xcode 16 or newer.
2. Project → target **UPTErasmus** → **Signing & Capabilities** → pick your **Team**. If the bundle ID is taken, change `com.vladciutina.UPTErasmus`.
3. Connect the iPhone, choose it at the top of Xcode, press **Run** (⌘R).
4. First time: on the iPhone, **Settings → General → VPN & Device Management** → trust the developer certificate, and turn on **Settings → Privacy & Security → Developer Mode**.
   With a free account the install lasts 7 days; run it again from Xcode to renew.

## Folders
- `UPTErasmus/` – app source; `timetable.json` holds the AC timetable for Semester I 2026/27 (32 catalogue courses).
- `test-learning-agreements/` – 5 sample Learning Agreements used in user testing (fictional students).
- `tools/` – data import scripts.
- `PROJECT_LOG.md` – full build history. `COLOR-GUIDE.md`, `FONTS-LICENSE.md` – design notes and font licences (SIL OFL).
