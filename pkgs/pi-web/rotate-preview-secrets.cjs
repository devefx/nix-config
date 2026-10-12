"use strict";

// Rewrite the preview-mode secrets in a pi-web `.next/prerender-manifest.json`.
//
// Why this runs at build time rather than at startup, as upstream intends:
// `bin/rotate-preview-secrets.js` rewrites these three values with fresh random
// ones before `next start`, which makes the published `previewModeId` useless.
// It needs a writable install directory, and the Nix store is read-only, so in
// this packaging the rotation always fails and the launcher warns:
//
//   Warning: could not rotate pi-web's preview-mode secrets because the install
//   directory is not writable.
//
// It then starts anyway, keeping the id that every published copy of the npm
// tarball shares. Since a match against the `x-prerender-revalidate` header
// makes Next skip middleware entirely, that value bypasses pi-web's password
// gate and its Host/Origin/Fetch-Metadata checks.
//
// Rotating here restores the property that actually matters: the on-disk id
// must not be the published one. A deterministic value is fine for that and
// keeps the build reproducible, which per-launch randomness would not. The
// values below are derived from a fixed string, not from entropy, and are not
// secret in any meaningful sense — they only need to differ from upstream's.

const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const SEED = "nix-config:pi-web:prerender-preview";

function derive(tag, length) {
  return crypto.createHash("sha256").update(`${SEED}:${tag}`).digest("hex").slice(0, length);
}

function main() {
  const nextDir = process.argv[2];
  if (!nextDir) {
    console.error("usage: rotate-preview-secrets.cjs <path-to-.next>");
    process.exit(2);
  }

  const manifestPath = path.join(nextDir, "prerender-manifest.json");
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));

  if (!manifest || typeof manifest.preview !== "object" || manifest.preview === null) {
    console.error(`no preview block in ${manifestPath}`);
    process.exit(1);
  }

  manifest.preview = {
    ...manifest.preview,
    // Lengths mirror what Next generates at build time.
    previewModeId: derive("id", 32),
    previewModeSigningKey: derive("signing", 64),
    previewModeEncryptionKey: derive("encryption", 64),
  };

  fs.writeFileSync(manifestPath, JSON.stringify(manifest));
  console.log(`rotated preview secrets in ${manifestPath}`);
}

main();
