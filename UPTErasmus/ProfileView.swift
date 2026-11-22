import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var confirm: Confirm?
    private enum Confirm { case clear, delete }

    var body: some View {
        ScreenScroll {
            HStack(spacing: 14) {
                Text(ProfileButton.initials(state.profile.name))
                    .font(.app(size: 20, .bold))
                    .foregroundStyle(Theme.accentInk)
                    .frame(width: 56, height: 56)
                    .background(Theme.accent, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.profile.name.isEmpty ? "Your profile" : state.profile.name)
                        .font(.app(.title2, .bold)).foregroundStyle(Theme.ink)
                    Text(state.currentEmail ?? "").font(.app(.subheadline)).foregroundStyle(Theme.sub)
                }
            }
            .padding(.top, 4)

            SectionTitle(title: "Your exchange")
            Card(padding: 16) {
                LabeledInput(label: "Name", placeholder: "e.g. Lukas Weber", text: $state.profile.name)
                LabeledInput(label: "Home country", placeholder: "e.g. Germany", text: $state.profile.country)
                LabeledInput(label: "Home university", placeholder: "Your university at home", text: $state.profile.homeUniversity)
                VStack(alignment: .leading, spacing: 5) {
                    FieldLabel(text: "Study level")
                    Picker("Study level", selection: $state.profile.level) {
                        Text("Bachelor").tag("Bachelor")
                        Text("Master").tag("Master")
                    }
                    .pickerStyle(.segmented)
                }
                VStack(alignment: .leading, spacing: 5) {
                    FieldLabel(text: "Citizenship")
                    Picker("Citizenship", selection: $state.profile.isEU) {
                        Text("EU citizen").tag(true)
                        Text("Non-EU").tag(false)
                    }
                    .pickerStyle(.segmented)
                }
            }

            SectionTitle(title: "At UPT")
            Card(padding: 16) {
                HStack(spacing: 10) {
                    FacultyDot(size: 12)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Automation and Computing (AC)").font(.app(.subheadline, .semibold)).foregroundStyle(Theme.ink)
                        Text("Your home faculty at UPT").font(.app(.caption)).foregroundStyle(Theme.sub)
                    }
                }
                Divider().overlay(Theme.line)
                Stepper(value: $state.minECTS, in: 3...60) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Minimum ECTS: **\(state.minECTS)**").font(.app(.subheadline)).foregroundStyle(Theme.ink)
                        Text("What your home university requires this semester. Usually 30.").font(.app(.caption)).foregroundStyle(Theme.sub)
                    }
                }
                Divider().overlay(Theme.line)
                DatePicker(selection: $state.profile.arrival, displayedComponents: .date) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Arrival in Timișoara").font(.app(.subheadline, .semibold)).foregroundStyle(Theme.ink)
                        Text("Paperwork deadlines count from this day").font(.app(.caption)).foregroundStyle(Theme.sub)
                    }
                }
            }

            SectionTitle(title: "Account")
            Card(padding: 16) {
                #if DEBUG
                Button("Debug: fill demo profile") { state.fillDemo() }
                    .buttonStyle(SecondaryButtonStyle())
                #endif
                Button { confirm = .clear } label: {
                    Label("Clear my courses and checklist", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(SecondaryButtonStyle())
                Button { state.logout() } label: {
                    Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .buttonStyle(SecondaryButtonStyle())
                Button(role: .destructive) { confirm = .delete } label: {
                    Label("Delete my account", systemImage: "trash")
                        .font(.app(.subheadline, .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .foregroundStyle(Theme.err)
                Text("Your account and data stay on this iPhone only.").font(.app(.caption)).foregroundStyle(Theme.faint)
            }
            .confirmationDialog(confirm == .delete ? "Delete your account?" : "Clear your courses?",
                                isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }),
                                titleVisibility: .visible) {
                if confirm == .delete {
                    Button("Delete account and data", role: .destructive) { state.deleteAccount() }
                } else {
                    Button("Clear courses, lab groups and checklist", role: .destructive) { state.reset(); dismiss() }
                }
                Button("Cancel", role: .cancel) { confirm = nil }
            } message: {
                Text(confirm == .delete ? "This removes your account and everything saved for it on this iPhone."
                                        : "Your account and name stay. Your courses, lab groups and checklist are removed.")
            }
        }
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .navigationTitle("Personal details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
