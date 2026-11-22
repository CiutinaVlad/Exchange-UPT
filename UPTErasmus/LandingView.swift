import SwiftUI

/// First screen when signed out: what the app does, then Create account / Log in.
struct LandingView: View {
    @State private var sheet: AuthSheet?

    enum AuthSheet: String, Identifiable { case register, login; var id: String { rawValue } }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    (Text("Exchange").foregroundColor(Theme.shellInk) + Text("@UPT").foregroundColor(Theme.brandMark))
                        .font(.app(.title2, .heavy))
                        .accessibilityLabel("Exchange at UPT")
                        .padding(.top, 8)

                    Text("For incoming Erasmus students · Faculty of Automation and Computing, UPT")
                        .font(.app(.footnote, .semibold))
                        .foregroundStyle(Theme.shellSub)

                    Text("Your UPT timetable, clash‑free before you land.")
                        .font(.app(.largeTitle, .heavy))
                        .foregroundStyle(Theme.shellInk)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Upload your Learning Agreement. We match it to UPT’s official Erasmus catalogue, check your ECTS and show every clash, then put you in the lab groups that fit your week.")
                        .font(.app(.body))
                        .foregroundStyle(Theme.shellSub)
                        .fixedSize(horizontal: false, vertical: true)

                    featureCard(number: "1", title: "Match your courses in seconds",
                                text: "Upload your Learning Agreement (PDF, Word or a photo). Each home course is matched to a UPT course, even across languages.") {
                        matchPreview
                    }
                    featureCard(number: "2", title: "A week without surprises",
                                text: "See every lecture clash before you sign, and get the lab group that fits around the rest of your week.") {
                        weekPreview
                    }

                    HStack(spacing: 0) {
                        stat("32", "autumn courses")
                        stat("Every", "lab group")
                        stat("0", "uploads: read on your iPhone")
                    }
                    .padding(.vertical, 12)
                    .background(Theme.shellHover, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }

            VStack(spacing: 10) {
                Button { sheet = .register } label: { Text("Create account") }
                    .buttonStyle(PrimaryButtonStyle())
                Button { sheet = .login } label: {
                    Text("Log in")
                        .font(.app(.headline))
                        .foregroundStyle(Theme.shellInk)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.shellSub, lineWidth: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .background(Theme.shell.ignoresSafeArea())
        .sheet(item: $sheet) { which in
            NavigationStack {
                Group {
                    if which == .register { RegisterView() } else { LoginView() }
                }
                .shellNavigationBar()
            }
        }
    }

    private func featureCard<P: View>(number: String, title: String, text: String, @ViewBuilder preview: () -> P) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(number)
                    .font(.app(.subheadline, .heavy))
                    .foregroundStyle(Theme.shell)
                    .frame(width: 26, height: 26)
                    .background(Theme.brandMark, in: Circle())
                    .accessibilityHidden(true)
                Text(title).font(.app(.title3, .bold)).foregroundStyle(Theme.shellInk)
            }
            Text(text).font(.app(.subheadline)).foregroundStyle(Theme.shellSub)
                .fixedSize(horizontal: false, vertical: true)
            preview()
                .accessibilityElement(children: .combine)
        }
        .padding(16)
        .background(Theme.shellStrip, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.shellHover, lineWidth: 1))
    }

    /// Two real matches from the German test agreement.
    private var matchPreview: some View {
        VStack(spacing: 8) {
            matchRow(home: "Datenbanken – 5 ECTS", upt: "Databases", code: "L002.25.03.F1", ects: 4)
            matchRow(home: "Rechnerarchitektur – 5 ECTS", upt: "Computer Architecture", code: "L002.25.03.F4", ects: 5)
        }
    }

    private func matchRow(home: String, upt: String, code: String, ects: Int) -> some View {
        HStack(spacing: 10) {
            Text(home).font(.app(.caption)).foregroundStyle(Theme.sub).lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "arrow.right").font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(upt).font(.app(.caption, .bold)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.8)
                Text("\(code) · \(ects) ECTS").font(.code(.caption2)).foregroundStyle(Theme.sub).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 10))
    }

    /// A small Monday–Friday strip: one lecture clash and a lab group that fits.
    private var weekPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 4) {
                ForEach(Array(["Mon", "Tue", "Wed", "Thu", "Fri"].enumerated()), id: \.offset) { i, d in
                    VStack(spacing: 3) {
                        Text(d).font(.app(size: 10, .bold)).foregroundStyle(Theme.sub)
                        if i == 0 {
                            HStack(spacing: 2) {
                                block("DB", clash: true); block("AIF", clash: true)
                            }
                            block("DB lab", fits: true)
                        } else if i == 1 {
                            block("SSD lab"); Spacer().frame(height: 24); block("AIF lab")
                        } else if i == 3 {
                            Spacer().frame(height: 12); block("SSD"); block("STA")
                        } else {
                            block(i == 2 ? "PDA" : "IPR"); Spacer().frame(height: 18)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .frame(height: 104, alignment: .top)
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.err)
                    Text("Lecture clash: Mon 8–10").foregroundStyle(Theme.ink)
                }.font(.app(.caption2, .semibold))
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.ok)
                    Text("Group 1.2 fits").foregroundStyle(Theme.ink)
                }.font(.app(.caption2, .semibold))
            }
        }
        .padding(10)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 10))
    }

    private func block(_ t: String, clash: Bool = false, fits: Bool = false) -> some View {
        Text(t)
            .font(.code(size: 9))
            .foregroundStyle(Theme.ink)
            .lineLimit(1).minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, minHeight: 26)
            .background(clash ? Theme.errBg : (fits ? Theme.okBg : Theme.chip), in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(clash ? Theme.err : (fits ? Theme.ok : Color.clear), lineWidth: 1))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.app(.headline, .heavy)).foregroundStyle(Theme.shellInk)
            Text(label).font(.app(size: 11)).foregroundStyle(Theme.shellSub).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Register

struct RegisterView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isEU = true
    @State private var error: String?

    var body: some View {
        ScreenScroll {
            VStack(alignment: .leading, spacing: 4) {
                Text("Create your account").font(.app(.title, .bold)).foregroundStyle(Theme.ink)
                Text("Demo only: your account stays on this iPhone. Use any email.").font(.app(.subheadline)).foregroundStyle(Theme.sub)
            }
            Card(padding: 16) {
                LabeledInput(label: "Full name", placeholder: "e.g. Patrick O'Sullivan", text: $name)
                    .textContentType(.name)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Email").font(.app(.caption, .semibold)).foregroundStyle(Theme.sub)
                    TextField("you@example.com", text: $email)
                        .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .textContentType(.username)
                        .authField()
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("Password").font(.app(.caption, .semibold)).foregroundStyle(Theme.sub)
                    SecureField("At least 6 characters", text: $password)
                        .textContentType(.newPassword)
                        .authField()
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("Citizenship").font(.app(.caption, .semibold)).foregroundStyle(Theme.sub)
                    Picker("Citizenship", selection: $isEU) {
                        Text("EU citizen").tag(true)
                        Text("Non-EU citizen").tag(false)
                    }
                    .pickerStyle(.segmented)
                    Text("Decides which documents Resources shows you.").font(.app(.caption)).foregroundStyle(Theme.faint)
                }
            }
            if let error { Banner(kind: .bad, text: error) }
            Button("Create account") { submit() }
                .buttonStyle(PrimaryButtonStyle())
            #if DEBUG
            Button {
                name = name.isEmpty ? "Test Student" : name
                email = state.nextTestEmail()
                password = AppState.testPassword
                error = nil
            } label: {
                Label("Debug: fill test email and password", systemImage: "ladybug")
            }
            .buttonStyle(SecondaryButtonStyle())
            #endif
        }
        .navigationTitle("Register")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
    }

    private func submit() {
        do { try state.register(name: name, email: email, password: password, isEU: isEU) }
        catch { self.error = error.localizedDescription }
    }
}

// MARK: - Log in

struct LoginView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var error: String?

    var body: some View {
        ScreenScroll {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back").font(.app(.title, .bold)).foregroundStyle(Theme.ink)
                Text("Log in with the account you created on this iPhone.").font(.app(.subheadline)).foregroundStyle(Theme.sub)
            }
            Card(padding: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Email").font(.app(.caption, .semibold)).foregroundStyle(Theme.sub)
                    TextField("you@example.com", text: $email)
                        .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .textContentType(.username)
                        .authField()
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("Password").font(.app(.caption, .semibold)).foregroundStyle(Theme.sub)
                    SecureField("Your password", text: $password)
                        .textContentType(.password)
                        .authField()
                }
            }
            if let error { Banner(kind: .bad, text: error) }
            Button("Log in") { submit() }
                .buttonStyle(PrimaryButtonStyle())
            #if DEBUG
            if let last = state.lastTestEmail {
                Button {
                    email = last
                    password = AppState.testPassword
                    error = nil
                } label: {
                    Label("Debug: fill \(last)", systemImage: "ladybug")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            #endif
        }
        .navigationTitle("Log in")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
    }

    private func submit() {
        do { try state.login(email: email, password: password) }
        catch { self.error = error.localizedDescription }
    }
}

private extension View {
    func authField() -> some View {
        self.padding(.horizontal, 12).padding(.vertical, 10)
            .background(Theme.ground, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
            .foregroundStyle(Theme.ink)
    }
}
