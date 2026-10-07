# Spendbook

A dark, Liquid Glass spending tracker for iPhone (iOS 26 and later), built in SwiftUI.

- **Home**: month total vs budget, a moving liquid "jar" that overflows and drips when today's spending crosses your daily limit, today/yesterday lists
- **Add spend**: big keypad, category bubbles, note and date, plus a sentence box ("lunch 180 at office") read by on-device Apple Intelligence, with a keyword fallback
- **History**: search, category filters, month picker, swipe to delete
- **Insights**: written summary, spending calendar with the amount for each day, category donut, daily bar chart with the daily pace line
- **Budget**: monthly budget ring, safe-per-day amount, per-category budgets
- **Siri & Shortcuts**: "Log a spend in Spendbook"

Data stays on the phone (SwiftData). No account, no network.

## Build without a Mac

The repo builds itself on GitHub's Macs.

1. Create a new **private** repository on GitHub (for example `spendbook`).
2. Push this folder to it:
   ```bash
   cd Spendbook          # already a git repo with one commit on main
   git remote add origin https://github.com/<your-username>/spendbook.git
   git push -u origin main
   ```
   Make sure the hidden `.github` folder is included.
3. Open the repo's **Actions** tab. The **Build Spendbook IPA** run starts on every push (or press **Run workflow**). It takes about 5–10 minutes.
4. When it's green, open the run and download **Spendbook-ipa** under *Artifacts*. Unzip it to get `Spendbook.ipa`.

If the run fails, download the **build-log** artifact (or copy the red error lines from the log) and send them to Claude to fix.

Private repos get a limited number of free Actions minutes each month, and macOS minutes count 10×. One build uses roughly 50–100 of them. A public repo has no limit.

## Install on your iPhone (free Apple ID)

1. On your Windows laptop, install **Sideloadly** from sideloadly.io. It also needs Apple's **iTunes** and **iCloud** for Windows (the versions from apple.com, not the Microsoft Store).
2. Connect the iPhone with a cable and tap **Trust** on the phone.
3. Open Sideloadly, drag in `Spendbook.ipa`, enter your Apple ID, and press **Start**.
4. On the iPhone:
   - **Settings → Privacy & Security → Developer Mode** → turn on and restart (first time only).
   - **Settings → General → VPN & Device Management** → tap your Apple ID → **Trust**.
5. Open Spendbook.

A free Apple ID install stops opening after **7 days**. Run Sideloadly again with the same `.ipa` to refresh it. Your spends stay on the phone as long as you don't delete the app. With a paid Apple Developer account you can use TestFlight instead and skip the weekly refresh.

## Project layout

```
project.yml                  XcodeGen spec (CI turns it into Spendbook.xcodeproj)
.github/workflows/           GitHub Actions build → unsigned .ipa
Spendbook/
  SpendbookApp.swift         App entry, tab bar with the separate + button
  Models.swift               Expense (SwiftData), categories, budget settings
  Stats.swift                Month totals, daily limit, safe per day
  HomeView.swift             Home screen
  LimitCard.swift            Animated jar, drips, glow and ticker
  AddSpendView.swift         Keypad and sentence entry
  SpendParser.swift          Apple Intelligence + keyword parsing
  HistoryView.swift          Search and history
  InsightsView.swift         Summary, calendar, charts
  BudgetView.swift           Budget ring and editor
  Intents.swift              Siri / Shortcuts action
  SampleData.swift           Example spends for trying the app
  Theme.swift, Components.swift
```

## How the daily limit works

Daily limit = (monthly budget − spent before today) ÷ days left including today.
If today's spending goes past it, the Home card turns orange, overflows and drips.

## Not in this first build

Home Screen widgets and the Lock Screen / Dynamic Island Live Activity need a widget extension and a shared App Group, which a free Apple ID can't reliably sign. They're the next step once the app is running.
