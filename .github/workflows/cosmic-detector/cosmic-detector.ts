import * as core from "@actions/core";
import * as exec from "@actions/exec";
import * as glob from "@actions/glob";
import {
  Manifest,
  Package,
  Snapshot,
  submitSnapshot,
} from "@github/dependency-submission-toolkit";
import { PackageURL } from "packageurl-js";

// Type definition for the top-level structure from the output of 'pkl eval'
type CosmicPackage = {
  name: string; // Name of the package
  url: string; // URL of the package repository
  version: string; // Version of the package
  hash: string; // Hash of the package
  executablePath: string; // Path to the executable
  testArgs: string[]; // Arguments for testing the package
  type: string; // Type of the package
  purl: string; // Package URL in purl format
};

/**
 * Parses the stdout from the 'pkl eval' command to extract package information.
 * @param stdout - The stdout from the 'pkl eval' command.
 * @returns An array of CosmicPackage objects.
 */
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
      core.error(`Error parsing package: ${error}`);
    }
  }

  return packages;
}

/**
 * Creates package manifests from an array of CosmicPackage objects.
 * @param cosmicPackages - An array of CosmicPackage objects.
 * @returns An array of Manifest objects.
 */
export function createPackageManifests(
  cosmicPackages: CosmicPackage[],
): Manifest[] {
  return cosmicPackages.map((cosmicPackage) => {
    const purl = PackageURL.fromString(cosmicPackage.purl);
    const pkg = new Package(purl);
    const manifest = new Manifest(
      cosmicPackage.name,
      `Packages/${cosmicPackage.name}.pkl`,
    );
    manifest.addDirectDependency(pkg);
    return manifest;
  });
}

/**
 * Main function that orchestrates the process of retrieving, parsing, and submitting package information.
 */
export async function main() {
  try {
    const cosmicPackageDirectory = core.getInput("cosmic-package-directory");

    const globber = await glob.create(`${cosmicPackageDirectory}/*.pkl`);
    const files = await globber.glob();

    // Ensure there are some .pkl files to process.
    if (files.length === 0) {
      core.setFailed(
        `No .pkl files found in directory: ${cosmicPackageDirectory}`,
      );
      return;
    }

    const prodPackages = await exec.getExecOutput(
      "pkl",
      ["eval", "-f", "json", ...files],
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
      name: "cosmic-detector",
      url: "https://github.com/willswire/cosmic/tree/main/.github/workflows/cosmic-detector",
      version: "0.0.1",
    });

    for (const pm of packageManifests) {
      snapshot.addManifest(pm);
    }

    submitSnapshot(snapshot);
  } catch (error) {
    core.setFailed(`Action failed with error: ${error}`);
  }
}
