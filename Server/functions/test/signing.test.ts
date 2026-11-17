import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, before, describe, test } from "node:test";
import { ManifestError, validateManifest } from "../src/manifest.js";
import { type SigningIdentity, signManifest } from "../src/signing.js";

const digest = "0123456789abcdef0123456789abcdef01234567";
const manifest = Buffer.from(JSON.stringify({ "pass.json": digest, "icon.png": digest, "thumbnail@2x.png": digest }));

describe("validateManifest", () => {
  test("accepts SHA-1 digests for a pass's files", () => {
    assert.deepEqual(Object.keys(validateManifest(manifest)), ["pass.json", "icon.png", "thumbnail@2x.png"]);
  });

  for (const [why, body] of [
    ["an unexpected file", { "pass.json": digest, "icon.png": digest, "evil.html": digest }],
    ["a path into a folder", { "pass.json": digest, "icon.png": digest, "en.lproj/pass.strings": digest }],
    ["__proto__", JSON.parse(`{"pass.json": "${digest}", "icon.png": "${digest}", "__proto__": "${digest}"}`)],
    ["an uppercase digest", { "pass.json": digest.toUpperCase(), "icon.png": digest }],
    ["a SHA-256 digest", { "pass.json": digest + digest.slice(0, 24), "icon.png": digest }],
    ["a number for a digest", { "pass.json": 7, "icon.png": digest }],
    ["no pass.json", { "icon.png": digest }],
    ["no icon.png", { "pass.json": digest }],
    ["an array", [digest]],
  ] as const) {
    test(`rejects ${why}`, () => {
      assert.throws(() => validateManifest(Buffer.from(JSON.stringify(body))), ManifestError);
    });
  }

  test("rejects anything that isn't JSON, and empty or oversized bodies", () => {
    for (const body of ["{", "", " ".repeat(5000)]) {
      assert.throws(() => validateManifest(Buffer.from(body)), ManifestError);
    }
  });
});

describe("signManifest", () => {
  let folder: string;
  let identity: SigningIdentity;

  // A throwaway chain shaped like Apple's: a root, a WWDR-style intermediate and a pass type ID certificate.
  before(() => {
    folder = mkdtempSync(join(tmpdir(), "neodex-signing-"));
    const run = (...args: string[]) => execFileSync("openssl", args, { cwd: folder, stdio: "pipe" });
    writeFileSync(join(folder, "ca.ext"), "basicConstraints=critical,CA:TRUE\nkeyUsage=critical,keyCertSign,cRLSign\n");
    writeFileSync(join(folder, "pass.ext"), "basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\n");
    run("req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", "root.key", "-out", "root.pem", "-days", "2",
      "-subj", "/CN=Test Root", "-addext", "basicConstraints=critical,CA:TRUE", "-addext", "keyUsage=critical,keyCertSign,cRLSign");
    run("req", "-newkey", "rsa:2048", "-nodes", "-keyout", "wwdr.key", "-out", "wwdr.csr", "-subj", "/OU=G0/CN=Test WWDR");
    run("x509", "-req", "-in", "wwdr.csr", "-CA", "root.pem", "-CAkey", "root.key", "-CAcreateserial",
      "-out", "wwdr.pem", "-days", "2", "-extfile", "ca.ext");
    run("req", "-newkey", "rsa:2048", "-nodes", "-keyout", "pass.key", "-out", "pass.csr",
      "-subj", "/UID=pass.test.neodex/CN=Pass Type ID: pass.test.neodex");
    run("x509", "-req", "-in", "pass.csr", "-CA", "wwdr.pem", "-CAkey", "wwdr.key", "-CAcreateserial",
      "-out", "pass.pem", "-days", "2", "-extfile", "pass.ext");
    const read = (name: string) => readFileSync(join(folder, name), "utf8");
    identity = { certificatePem: read("pass.pem"), privateKeyPem: read("pass.key"), intermediatePem: read("wwdr.pem") };
  });

  after(() => rmSync(folder, { recursive: true, force: true }));

  /** Checks a signature with OpenSSL, independently of node-forge. */
  function verify(signature: Buffer, content: Buffer) {
    writeFileSync(join(folder, "signature"), signature);
    writeFileSync(join(folder, "manifest.json"), content);
    return spawnSync("openssl", ["cms", "-verify", "-binary", "-inform", "DER", "-in", "signature",
      "-content", "manifest.json", "-CAfile", "root.pem", "-purpose", "any", "-out", "/dev/null"], { cwd: folder });
  }

  test("produces a detached PKCS #7 signature that verifies against the chain", () => {
    const signature = signManifest(manifest, identity);
    const result = verify(signature, manifest);
    assert.equal(result.status, 0, result.stderr.toString());
    const printed = execFileSync("openssl", ["cms", "-cmsout", "-print", "-inform", "DER", "-in", "signature"],
      { cwd: folder }).toString();
    assert.match(printed, /eContent: <ABSENT>/, "the manifest itself must not be embedded");
    assert.match(printed, /signingTime/);
    assert.match(printed, /sha256/);
  });

  test("carries the pass certificate and the intermediate, and no root", () => {
    writeFileSync(join(folder, "signature"), signManifest(manifest, identity));
    const subjects = execFileSync("openssl", ["pkcs7", "-inform", "DER", "-in", "signature", "-print_certs", "-noout"],
      { cwd: folder }).toString();
    assert.match(subjects, /subject=.*Pass Type ID: pass\.test\.neodex/);
    assert.match(subjects, /subject=.*Test WWDR/);
    assert.doesNotMatch(subjects, /subject=.*Test Root/);
  });

  test("doesn't verify for a manifest that was changed after signing", () => {
    const signature = signManifest(manifest, identity);
    const tampered = Buffer.from(manifest.toString().replace(digest, "f".repeat(40)));
    assert.notEqual(verify(signature, tampered).status, 0);
  });
});
