import SwiftUI

/// Explains how to set up the Shortcuts automation, and lets you test a message.
struct SMSSetupView: View {
    @State private var testText = ""
    @State private var result: BankSMS?
    @State private var tested = false

    private let steps: [(String, String)] = [
        ("Open Shortcuts", "Open the Shortcuts app and tap Automation at the bottom."),
        ("New automation", "Tap + (New Automation), scroll down and choose Message."),
        ("Pick the trigger", "Set Message Contains to “debited”. Leave Sender empty so every bank works, or pick your bank’s sender (for example SBIUPI)."),
        ("Run without asking", "Choose Run Immediately, and turn off Notify When Run if you don’t want a banner. Tap Next."),
        ("Add Spendbook", "Tap New Blank Automation, then Add Action, search “Spendbook” and pick Log Spend from Bank SMS."),
        ("Pass the message in", "Tap the blue Message field in the action and choose Shortcut Input. Tap Done."),
        ("Repeat for other words", "Make the same automation for “spent” and “sent Rs” so card and other UPI messages are caught too.")
    ]

    var body: some View {
        Form {
            Section {
                Text("iPhone apps can’t read your messages directly, but the Shortcuts app can hand each bank SMS to Spendbook the moment it arrives. Set it up once and debit messages are logged for you, marked “SMS”.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.secondary)
            }

            Section("Set up once") {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Theme.onAccent)
                            .frame(width: 26, height: 26)
                            .background(Theme.accent, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.0).font(.system(size: 16, weight: .semibold))
                            Text(step.1).font(.system(size: 14)).foregroundStyle(Theme.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
                Link(destination: URL(string: "shortcuts://")!) {
                    Label("Open Shortcuts", systemImage: "arrow.up.forward.app")
                }
            }

            Section {
                TextField("Paste a bank SMS here", text: $testText, axis: .vertical)
                    .lineLimit(3...6)
                Button("Test this message") {
                    result = BankSMSParser.parse(testText)
                    tested = true
                }
                .disabled(testText.isEmpty)

                if tested {
                    if let r = result {
                        LabeledContent("Amount", value: r.amount.inr)
                        LabeledContent("Paid to", value: r.payee ?? "Not found")
                        LabeledContent("Date", value: r.date.map { $0.relativeDayLabel } ?? "Today")
                        LabeledContent("Category", value: r.category.name)
                    } else {
                        Label("Not a spend, so it would be skipped (credits, refunds and OTPs are ignored).",
                              systemImage: "xmark.circle")
                            .foregroundStyle(Theme.warnText)
                    }
                }
            } header: {
                Text("Try it")
            } footer: {
                Text("Nothing here is saved. If a real debit message isn’t read correctly, send it to Claude with the account number masked.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.sheet)
        .navigationTitle("Bank SMS")
        .navigationBarTitleDisplayMode(.inline)
    }
}
