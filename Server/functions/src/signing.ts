import forge from "node-forge";

/** The pass type ID certificate, its private key and the Apple WWDR intermediate that issued it, as PEM. */
export interface SigningIdentity {
  certificatePem: string;
  privateKeyPem: string;
  intermediatePem: string;
}

/**
 * Signs a pass's manifest the way Wallet checks it: a PKCS #7 detached signature over the manifest's exact
 * bytes, with a SHA-256 digest and the signing time, carrying the pass certificate and Apple's WWDR
 * intermediate. Wallet verifies every file in the pass through the hashes in the manifest, so this is all
 * the signer needs to see.
 */
export function signManifest(manifest: Buffer, identity: SigningIdentity, signingTime = new Date()): Buffer {
  const certificate = forge.pki.certificateFromPem(identity.certificatePem);
  const signedData = forge.pkcs7.createSignedData();
  signedData.content = forge.util.createBuffer(manifest.toString("binary"));
  signedData.addCertificate(certificate);
  signedData.addCertificate(forge.pki.certificateFromPem(identity.intermediatePem));
  signedData.addSigner({
    key: forge.pki.privateKeyFromPem(identity.privateKeyPem),
    certificate,
    digestAlgorithm: forge.pki.oids.sha256,
    authenticatedAttributes: [
      { type: forge.pki.oids.contentType, value: forge.pki.oids.data },
      { type: forge.pki.oids.messageDigest },
      { type: forge.pki.oids.signingTime, value: signingTime.toISOString() },
    ],
  });
  signedData.sign({ detached: true });
  return Buffer.from(forge.asn1.toDer(signedData.toAsn1()).getBytes(), "binary");
}
