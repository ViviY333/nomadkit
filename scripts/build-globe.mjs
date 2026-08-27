import { build } from "esbuild";
import { mkdir, copyFile, readFile, writeFile } from "node:fs/promises";

const outputDirectory = "NomadKit/Resources/Web";

await mkdir(outputDirectory, { recursive: true });

await build({
  stdin: {
    contents: "import Globe from 'globe.gl'; export default Globe;",
    resolveDir: process.cwd(),
    sourcefile: "globe-entry.js"
  },
  bundle: true,
  format: "iife",
  globalName: "GlobeGL",
  platform: "browser",
  minify: true,
  outfile: `${outputDirectory}/globe.bundle.js`
});

await copyFile("node_modules/three-globe/example/img/earth-blue-marble.jpg", `${outputDirectory}/earth-blue-marble.jpg`);
await copyFile("node_modules/three-globe/example/img/night-sky.png", `${outputDirectory}/night-sky.png`);
await copyFile("node_modules/three-globe/example/img/earth-night.jpg", `${outputDirectory}/earth-night.jpg`);
await copyFile("node_modules/three-globe/example/img/earth-water.png", `${outputDirectory}/earth-water.png`);

// WKWebView can reject sibling file URLs from a file:// document depending on
// the sandbox/read-access configuration. Inline the small set of globe textures
// so the demo is fully self-contained and also works offline.
const sourceHTML = await readFile(`${outputDirectory}/nomad-globe-gl-source.html`, "utf8");
const texture = async (path, mime) => `data:${mime};base64,${(await readFile(path)).toString("base64")}`;
const sourceCountries = JSON.parse(await readFile("node_modules/three-globe/example/hexed-polygons/ne_110m_admin_0_countries.geojson", "utf8"));
const countries = {
  type: sourceCountries.type,
  features: sourceCountries.features.map(({ geometry, properties }) => ({
    type: "Feature",
    geometry,
    properties: {
      ADMIN: properties.ADMIN,
      ADM0_A3: properties.ADM0_A3,
      ISO_A2: properties.ISO_A2,
      WB_A2: properties.WB_A2,
      LABELRANK: properties.LABELRANK,
      POP_RANK: properties.POP_RANK
    }
  }))
};
const html = sourceHTML
  .replaceAll("__EARTH_BLUE_MARBLE__", await texture("node_modules/three-globe/example/img/earth-blue-marble.jpg", "image/jpeg"))
  .replaceAll("__EARTH_WATER__", await texture("node_modules/three-globe/example/img/earth-water.png", "image/png"))
  .replaceAll("__NIGHT_SKY__", await texture("node_modules/three-globe/example/img/night-sky.png", "image/png"))
  .replace("__COUNTRIES_GEOJSON__", JSON.stringify(countries));
await writeFile(`${outputDirectory}/nomad-globe-gl.html`, html);
