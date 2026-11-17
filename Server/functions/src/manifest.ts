/**
 * The files a Neodex pass may contain. The signer only ever sees a pass's manifest, so this list is what
 * keeps it from vouching for anything other than a trainer card's pass.json and images.
 */
const imageNames = ["icon", "logo", "thumbnail", "strip"];
const scales = ["", "@2x", "@3x"];

export const allowedFiles: ReadonlySet<string> = new Set([
  "pass.json",
  ...imageNames.flatMap((name) => scales.map((scale) => `${name}${scale}.png`)),
]);

/** Wallet needs these in every pass. */
export const requiredFiles = ["pass.json", "icon.png"];

/** A manifest of every allowed file is well under 1 KB. */
export const maximumManifestBytes = 4096;

export class ManifestError extends Error {}

/**
 * Checks a pass's manifest before it is signed: a JSON object mapping known file names to lowercase SHA-1
 * hex digests, including pass.json and icon.png. Returns the parsed manifest.
 */
export function validateManifest(body: Buffer): Record<string, string> {
  if (body.length === 0 || body.length > maximumManifestBytes) {
    throw new ManifestError(`manifest is ${body.length} bytes`);
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(body.toString("utf8"));
  } catch {
    throw new ManifestError("manifest isn't JSON");
  }
  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
    throw new ManifestError("manifest isn't a JSON object");
  }
  const manifest = parsed as Record<string, unknown>;
  for (const [name, digest] of Object.entries(manifest)) {
    if (!allowedFiles.has(name)) throw new ManifestError(`unexpected file ${JSON.stringify(name)}`);
    if (typeof digest !== "string" || !/^[0-9a-f]{40}$/.test(digest)) {
      throw new ManifestError(`${name} doesn't have a SHA-1 digest`);
    }
  }
  for (const name of requiredFiles) {
    if (!Object.hasOwn(manifest, name)) throw new ManifestError(`manifest is missing ${name}`);
  }
  return manifest as Record<string, string>;
}
