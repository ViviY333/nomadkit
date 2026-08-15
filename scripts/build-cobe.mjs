import { build } from "esbuild";
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { PNG } from "pngjs";
import countries from "world-countries";

const outputDirectory = "NomadKit/Resources/Web";
const bundlePath = `${outputDirectory}/cobe.bundle.js`;

await mkdir(outputDirectory, { recursive: true });
await build({
  entryPoints: ["node_modules/cobe/dist/index.esm.js"],
  bundle: true,
  format: "iife",
  globalName: "Cobe",
  platform: "browser",
  minify: true,
  outfile: bundlePath
});

let bundle = await readFile(bundlePath, "utf8");
const match = bundle.match(/data:image\/png;base64,([A-Za-z0-9+/=]+)/);
if (!match) throw new Error("Could not find COBE's embedded world map");

const sourceMap = PNG.sync.read(Buffer.from(match[1], "base64"));
const rgbMap = new PNG({ width: sourceMap.width, height: sourceMap.height, colorType: 2 });
for (let index = 0; index < sourceMap.data.length; index += 4) {
  const value = sourceMap.data[index];
  const pixelIndex = index / 4;
  const pixelX = pixelIndex % sourceMap.width;
  const pixelY = Math.floor(pixelIndex / sourceMap.width);
  const longitude = pixelX / sourceMap.width * 360 - 180;
  const latitude = 90 - pixelY / sourceMap.height * 180;
  const isThailand = longitude >= 97 && longitude <= 106 && latitude >= 5.5 && latitude <= 20.7;
  const isTaiwan = longitude >= 120 && longitude <= 122.2 && latitude >= 21.5 && latitude <= 25.6;
  const isVisitedLand = value > 127 && (isThailand || isTaiwan);
  rgbMap.data[index] = value;
  rgbMap.data[index + 1] = isVisitedLand ? 0 : value;
  rgbMap.data[index + 2] = value;
  rgbMap.data[index + 3] = 255;
}
const encodedMap = PNG.sync.write(rgbMap, { colorType: 2 });
await writeFile(`${outputDirectory}/cobe-map.png`, encodedMap);

// Keep COBE's map embedded in the bundle. WKWebView can resolve a sibling file URL,
// but iOS WebGL may still leave the texture at its black placeholder.
const originalGlobeColor = "m+=vec4(F*(mix((1.-q)*pow(i,.4),q,n.z)+.1)+pow(1.-i,4.)*w,1)";
const lightGlobeColor = "vec4 S=texture2D(z,vec2(e*.5/3.141593,-(j/3.141593+.5)));float V=step(.5,S.r)*(1.-step(.5,S.g));float Q=clamp(q,0.,1.);float G=clamp((d.y+1.)*.5,0.,1.);vec3 L=mix(vec3(.18,.72,.67),vec3(.27,.62,.91),G);m+=vec4(mix(vec3(.955,.958,.96),mix(L,vec3(.42,.74,.94),V),Q)+pow(1.-i,4.)*w*.32,1)";
const originalDotRadius = "smoothstep(8e-3,0.,g)";
const enlargedDotRadius = "smoothstep(1.05e-2,0.,g)";
if (!bundle.includes(originalDotRadius)) {
  throw new Error("Could not find COBE's globe dot radius shader");
}
bundle = bundle.replace(originalDotRadius, enlargedDotRadius);
if (!bundle.includes(originalGlobeColor)) {
  throw new Error("Could not find COBE's globe color shader");
}
bundle = bundle.replace(originalGlobeColor, lightGlobeColor);
bundle = bundle.replace(match[0], `data:image/png;base64,${encodedMap.toString("base64")}`);
await writeFile(bundlePath, bundle);

const countryCenters = Object.fromEntries(
  countries.filter(country => country.cca2 && country.latlng?.length === 2)
    .map(country => [country.cca2, country.latlng])
);
const globeHTMLPath = `${outputDirectory}/nomad-globe.html`;
const globeHTML = await readFile(globeHTMLPath, "utf8");
await writeFile(globeHTMLPath, globeHTML.replace(
  /const countryCenters = .*;/,
  `const countryCenters = ${JSON.stringify(countryCenters)};`
));
