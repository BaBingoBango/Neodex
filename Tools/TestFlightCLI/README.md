# TestFlight CLI

`Tools/testflight` reads Neodex's TestFlight feedback, crash reports and build status from the
[App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi), so notes and
screenshots left in TestFlight can be worked on from the terminal. It has no dependencies: requests
are signed with CryptoKit and decoded with Codable.

## Setup (once)

1. In App Store Connect, open **Users and Access › Integrations › App Store Connect API**. The first
   time, the Account Holder requests access there.
2. Under **Team Keys**, add a key with the **Developer** role. That is the least access that can read
   TestFlight feedback and builds.
3. Download the key file, `AuthKey_<KEY ID>.p8`. Apple offers the download only once.
4. Run, with the Key ID from the table and the Issuer ID shown above it:

   ```bash
   Tools/testflight setup --issuer-id <ISSUER ID> --key-id <KEY ID>
   ```

   Setup moves the key file from Downloads into `~/.appstoreconnect/private_keys/` (where `altool` and
   `xcodebuild` also look), makes it readable only by you, saves the two IDs in
   `~/.appstoreconnect/config.json`, and checks the connection. `ASC_KEY_ID`, `ASC_ISSUER_ID` and
   `ASC_PRIVATE_KEY_PATH` override the saved values.

Nothing about the key ever goes in this repository; it is public. Revoke the key on the same App
Store Connect page if it is ever exposed.

## Commands

| Command | What it does |
| --- | --- |
| `check` | Tests the connection and counts the reports TestFlight holds. |
| `feedback` | Lists screenshot reports not yet marked handled, newest first, and saves each one with its screenshots. `--all` includes handled ones, `--build 6` narrows to a build, `--limit N` caps the fetch. |
| `crashes` | The same for crash reports, saving the crash log. |
| `handled <ID>… --note "…"` | Marks reports dealt with; the start of an ID is enough. `reopen <ID>…` undoes it. |
| `builds` | Recent uploads with their version, platform and whether App Store Connect finished processing them. |

Reports are saved in `~/.appstoreconnect/feedback/Ethan.Neodex/`, one folder per report with the
screenshots or crash log, a `feedback.md` summary and an `item.json`. They stay outside the repository
because they carry tester emails and personal screenshots. TestFlight has no "resolved" state and
deleting feedback is permanent, so handled reports are tracked locally in `state.json`.

## Tests

```bash
cd Tools/TestFlightCLI && swift test
```

The tests sign tokens with a throwaway key and verify them, decode a recorded response shape, and
exercise the configuration and the archive. Nothing in them touches the network.
