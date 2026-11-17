# Neodex server

Firebase functions for the Trainer Card's Wallet pass (see `Docs/TrainerCard.md`). The project is
`neodex26`.

## `signPass`: signs a pass without seeing it

The app builds the whole pass on the device: pass.json and the images, including the name, picture, team
and city. It sends `signPass` only `manifest.json`, the SHA-1 hashes of those files, and gets back the
detached PKCS #7 signature Wallet checks. The function:

- accepts only a limited-use App Check token, and consumes it, so only the genuine app gets a signature
  and each token works once;
- signs only manifests that list a pass's own files (`src/manifest.ts`);
- stores nothing and doesn't log the request. Google's request logs still record each call's time and
  IP address.

## Setup

1. Put `neodex26` on the Blaze plan, which Cloud Functions and Secret Manager need, and add a budget
   alert. This usage should stay inside the free tier.
2. In the developer portal, create the Pass Type ID `pass.Ethan.Neodex.trainer` and its certificate.
   The app's pass.json uses that identifier.
3. Install the certificate in Keychain, export it with its private key as a .p12, and convert both
   halves to PEM. Add `-legacy` if OpenSSL 3 can't read the Keychain export.

   ```bash
   openssl pkcs12 -in Neodex-Pass.p12 -clcerts -nokeys -out pass.pem
   openssl pkcs12 -in Neodex-Pass.p12 -nocerts -nodes -out pass.key
   ```

4. From `Server/`, store them as secrets, then delete the PEM files.

   ```bash
   firebase functions:secrets:set PASS_CERTIFICATE --data-file pass.pem
   firebase functions:secrets:set PASS_PRIVATE_KEY --data-file pass.key
   ```

5. Save Apple's WWDR intermediate that issued the certificate as `functions/certs/AppleWWDRCA.pem`.
   The certificate's issuer names it (`OU = G4` and so on). It's public, so it's committed.
6. Register the iOS app (`Ethan.Neodex`) in the project and turn on App Check with App Attest.

## Developing

- `npm test` in `functions/` builds the TypeScript and runs the tests. They sign with a throwaway
  certificate chain and check each signature with OpenSSL.
- `firebase deploy --only functions` from `Server/` deploys.
