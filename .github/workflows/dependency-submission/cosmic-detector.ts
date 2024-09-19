import * as core from "@actions/core";
import * as exec from "@actions/exec";
import {
  Manifest,
  Package,
  Snapshot,
  submitSnapshot,
} from "@github/dependency-submission-toolkit";
import { PackageURL } from "packageurl-js";

// top-level structure from the output of 'npm list'
type CosmicPackage = {
  name: string;
  url: string;
  version: string;
  hash: string;
  executablePath: string;
  testArgs: Array<string>;
  type: string;
  purl: string;
};

export function parseCosmicPackages(stdout: string): CosmicPackage[] {
  const packages: CosmicPackage[] = [];

  // Split the stdout by the '---' separator
  const packageStrings = stdout
    .split("---")
    .map((pkgStr) => pkgStr.trim())
    .filter((pkgStr) => pkgStr.length > 0);

  // Parse each package string into an object
  for (const pkgStr of packageStrings) {
    try {
      const cosmicPackage = JSON.parse(pkgStr) as CosmicPackage;
      packages.push(cosmicPackage);
    } catch (error) {
      console.error("Error parsing package:", error);
    }
  }

  return packages;
}

export function createPackageManifests(
  cosmicPackages: CosmicPackage[],
): Manifest[] {
  return cosmicPackages.map((cosmicPackage) => {
    const purl = PackageURL.fromString(cosmicPackage.purl);
    let pkg = new Package(purl);
    let manifest = new Manifest(cosmicPackage.name);
    manifest.addDirectDependency(pkg);
    return manifest;
  });
}

// This program uses 'npm list' to provide a list of all production
// (non-development) dependencies and all transitive dependencies. This
// provides transitive relationships unlike package.json, and output can be
// configured to avoid issues present with parsing package-lock.json (such as
// inclusion of workspace packages). This is provided as example to help guide
// development.
export async function main() {
  const cosmicPackageDirectory = core.getInput("cosmic-package-directory");
  const prodPackages = await exec.getExecOutput(
    "pkl",
    ["eval", "-f", "json", "*.pkl"],
    { cwd: cosmicPackageDirectory },
  );
  if (prodPackages.exitCode !== 0) {
    core.error(prodPackages.stderr);
    core.setFailed("'pkl eval' failed!");
    return;
  }
  const cosmicPackages = parseCosmicPackages(prodPackages.stdout);
  const packageManifests = createPackageManifests(cosmicPackages);
  const snapshot = new Snapshot({
    name: "cosmic detector",
    url: "https://github.com/willswire/cosmic/tree/main/.github/workflows/dependency-submission",
    version: "0.0.1",
  });

  for (const pm of packageManifests) {
    snapshot.addManifest(pm);
  }

  submitSnapshot(snapshot);
}
