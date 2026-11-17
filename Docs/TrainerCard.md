# Trainer Card

Status: idea, not started (brainstormed November 2026).

A card like the trainer cards and save screens in the games: who you are as a trainer, shown in the
app, on Home and in Wallet, and shared as an image. Everything stays on the device unless a section
below says otherwise.

## On the card

- **Picture.** Choices:
  - A Pokémon's artwork, pixel sprite or animated sprite, shiny included.
  - A personal photo from the Photos picker, stored only on the device.
  - An Image Playground cartoon of you, made on the device.
  - A Showdown trainer sprite, from the same source as the Pokémon sprites.
- **Name, Trainer ID No.** (random digits made on the device, like the games) and a **Trainer since** date.
- **Team.** Any saved team, shown like the party screen. Each sprite opens its Pokémon.
- **Pokédex.**
  - *Seen* counts the unique Pokémon pages the user has opened. History keeps only the newest
    `History.maximumRecords` (300) views, so Seen needs its own lifetime list, seeded from the
    current history.
  - *Caught* is proposed as the Pokémon scanned with the camera. Alternatives are favorites or
    Pokémon on a team.
- **Location** (optional).
  - Either the current city, from "when in use" approximate location (`NSLocationDefaultAccuracyReduced`),
    or a hometown the user types in.
  - Apple's reverse geocoder sends the coordinates to Apple. A truly on-device version would bundle
    an offline city list instead, such as GeoNames (CC BY), through the data pipeline.
  - A fun twist: show the region the city inspired, such as "Paris (Kalos)" or "New York (Unova)".
  - Hidden on shared images by default.
- **Badges**, in original art: one per region once every Pokémon from it has been seen, plus
  milestones such as the first team, first scan and first Face-Off. The card's color upgrades as
  badges add up.
- **The back of the card** holds the badge case and a signature the user draws, as on the DS-era cards.
- **A holo shine** that follows the device's tilt, with sparkles when the picture is shiny.
- **Showdown username.** Optional; puts the user's ladder ratings on the back (needs the network).
- **Dexbot bio.** One line Dexbot writes from the user's stats.

## Where it shows up

- An avatar button in Home's toolbar, like the App Store's account button, that opens the full card.
- Optionally, a compact card at the top of Home: avatar, name, Seen count and the team as mini sprites.
- A Trainer Card widget (and StandBy), "Show my trainer card" for Siri and Shortcuts, and the card on
  Apple Watch.
- Wallet, below.

## Sharing

- Render the card to an image on the device (`ImageRenderer`) and hand it to the share sheet.
- Card trading: another Neodex user scans a QR code on the card to save the card and import the team.
  No accounts or server.

## Open decisions

1. What Caught means: scanned (proposed), favorites, or on a team.
2. City lookup: Apple's online geocoder (simpler; the privacy note has to name Apple) or a bundled
   city list (fully on-device, a couple of MB larger).
3. Home: the toolbar avatar, the compact card, or both.

## Wallet pass

### Constraints

- **Signing.** A pass must be signed with a Pass Type ID certificate. That key can't ship in the app
  or in this public repository, so signing needs a small service.
- **App Review.**
  - Guideline 3.2.1(iv) limits passes to payments, offers and identification. Other uses risk
    rejection and revoked Wallet access. Internal TestFlight builds are fine; an App Store release
    is a risk.
  - Guideline 1.5 asks for the issuer's contact information on the pass (a back field).
  - The pass carries Neodex's branding, not Pokémon's.
- **Devices.** Wallet passes live on iPhone, and the paired Apple Watch shows them too. iPad and Mac
  have neither.

### Design: the server signs without seeing the card

- **Only the manifest is signed.** Wallet's `signature` file is a PKCS #7 detached signature of
  `manifest.json`, and the manifest lists the SHA-1 hash of every file in the pass. So the server only
  ever needs the manifest.
- **The app does the rest.** It builds `pass.json` and the images on the device, photo and city
  included, and writes the manifest. It sends only the manifest to the signing function, gets the
  signature back, and zips the `.pkpass` itself.
- **The hashes don't give the card away.** `pass.json` carries a random serial number. Each image
  carries a random value in a PNG text chunk, so its hash can't be matched against known sprites.
- **The function** runs on Cloud Functions (2nd gen, Node). It:
  - verifies a limited-use Firebase App Check token (App Attest), consuming it to stop replays;
  - checks that the manifest lists only the expected file names;
  - signs with the key from Secret Manager, adding Apple's WWDR intermediate certificate;
  - returns the signature.

  It has no database or storage and doesn't log the request body. Google's request logs still record
  each call's time and IP address.
- **Updates.** There's no pass web service, because that would mean storing push tokens. When the
  card changes, the app signs a new pass and swaps it in with `PKPassLibrary.replacePass(with:)`.
  That needs the Wallet capability (`com.apple.developer.pass-type-identifiers`) on the App ID.
- **QR code.** The pass's QR code can be the card-trading code.

### Setup

- **Accounts:**
  - A Pass Type ID, such as `pass.Ethan.Neodex.trainer`, and its certificate in the developer portal.
  - A Firebase project on the Blaze plan with a budget alert. Usage this small should stay in the
    free tier.
  - The iOS app registered in that project, with App Check on App Attest.
  - The certificate and key stored as secrets with `firebase functions:secrets:set`.
- **Code:**
  - The function, in this repository with no secrets.
  - The on-device pass builder and a small zip writer.
  - App Check, using only `FirebaseCore` and `FirebaseAppCheck`.
  - The Add to Apple Wallet button and the App Attest entitlement.
  - Tests for the manifest, the zip and `pass.json`.

## Phases

1. The card screen with its flip, the editor (name, picture, team), ID and Seen, image sharing, and
   the Home placement.
2. Badges, card colors, the signature, the holo shine, the city and the widget.
3. The Wallet pass.
