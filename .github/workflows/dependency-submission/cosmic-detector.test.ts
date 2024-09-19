import { describe, expect, test } from "vitest";

import { parseCosmicPackages, createPackageManifests } from "./cosmic-detector";
import { PackageURL } from "packageurl-js";

// Define a helper function to simulate a CosmicPackage
const createCosmicPackage = () => ({
  name: "example-package",
  url: "https://example.com",
  version: "1.0.0",
  hash: "abc123",
  executablePath: "path/to/executable",
  testArgs: ["arg1", "arg2"],
  type: "module",
  purl: "pkg:generic/example-package@1.0.0",
});

describe("parseCosmicPackages", () => {
  test("parses single package", () => {
    const stdout = JSON.stringify(createCosmicPackage());
    const result = parseCosmicPackages(stdout);
    if (result[0]) {
      expect(result).toHaveLength(1);
      expect(result[0].name).toBe("example-package");
    }
  });

  test("parses multiple packages", () => {
    const stdout = [
      JSON.stringify(createCosmicPackage()),
      JSON.stringify(createCosmicPackage()),
    ].join("---");
    const result = parseCosmicPackages(stdout);
    expect(result).toHaveLength(2);
  });

  test("handles invalid JSON gracefully", () => {
    const stdout = "invalid-json";
    const result = parseCosmicPackages(stdout);
    expect(result).toHaveLength(0);
  });
});

describe("createPackageManifests", () => {
  test("creates manifests from parsed packages", () => {
    const cosmicPackage = createCosmicPackage();
    const cosmicPackages = [cosmicPackage];
    const manifests = createPackageManifests(cosmicPackages);

    expect(manifests).toHaveLength(1);
    const manifest = manifests[0];

    if (manifest) {
      expect(manifest.name).toBe(cosmicPackage.name);

      const manifestDependencies = manifest.directDependencies();
      expect(manifestDependencies).toHaveLength(1);

      const purl = PackageURL.fromString(cosmicPackage.purl);
      expect(
        manifestDependencies
          .map((p) => {
            return p.packageURL;
          })
          .join(" "),
      ).toContain(purl);
    }
  });
});
