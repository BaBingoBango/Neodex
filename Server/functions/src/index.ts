import { readFileSync } from "node:fs";
import { initializeApp } from "firebase-admin/app";
import { getAppCheck } from "firebase-admin/app-check";
import { logger } from "firebase-functions";
import { defineSecret } from "firebase-functions/params";
import { onRequest } from "firebase-functions/v2/https";
import { ManifestError, validateManifest } from "./manifest.js";
import { signManifest } from "./signing.js";

initializeApp();

const passCertificate = defineSecret("PASS_CERTIFICATE");
const passPrivateKey = defineSecret("PASS_PRIVATE_KEY");

/** Apple's WWDR intermediate that issued the pass certificate. It's public, so it ships with the source. */
let intermediatePem: string | undefined;
function intermediate(): string {
  intermediatePem ??= readFileSync(new URL("../../certs/AppleWWDRCA.pem", import.meta.url), "utf8");
  return intermediatePem;
}

/**
 * Signs a Wallet pass's manifest for the Neodex app.
 *
 * The app builds the whole pass on the device and sends only `manifest.json`, the SHA-1 hashes of the pass's
 * files, so this function never sees a trainer card: no name, picture, team or city. It keeps nothing and
 * logs nothing about the request. A limited-use App Check token, consumed here, keeps anything but the
 * genuine app from getting a signature, and keeps a token from being used twice.
 */
export const signPass = onRequest(
  {
    secrets: [passCertificate, passPrivateKey],
    invoker: "public",
    maxInstances: 2,
    memory: "256MiB",
    timeoutSeconds: 15,
  },
  async (request, response) => {
    response.set("Cache-Control", "no-store");
    if (request.method !== "POST") {
      response.set("Allow", "POST").status(405).end();
      return;
    }
    if (!(await hasFreshAppCheckToken(request.get("X-Firebase-AppCheck")))) {
      response.status(401).end();
      return;
    }
    const manifest = request.rawBody;
    try {
      validateManifest(manifest);
    } catch (error) {
      if (!(error instanceof ManifestError)) throw error;
      logger.warn(`Rejected a manifest: ${error.message}`);
      response.status(400).send(error.message);
      return;
    }
    const signature = signManifest(manifest, {
      certificatePem: passCertificate.value(),
      privateKeyPem: passPrivateKey.value(),
      intermediatePem: intermediate(),
    });
    response.type("application/pkcs7-signature").send(signature);
  },
);

async function hasFreshAppCheckToken(token: string | undefined): Promise<boolean> {
  if (!token) return false;
  try {
    const verified = await getAppCheck().verifyToken(token, { consume: true });
    return !verified.alreadyConsumed;
  } catch {
    return false;
  }
}
