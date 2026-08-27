import { mkdir, readFile, writeFile } from "node:fs/promises";

const inputPath = process.argv[2] || "/tmp/nomadkit-cities5000.txt";
const outputPath = process.argv[3] || "NomadKit/Resources/Data/city_directory.json";
const fields = ["id", "name", "asciiName", "alternateNames", "latitude", "longitude", "featureClass", "featureCode", "countryCode", "admin1", "population"];

const text = await readFile(inputPath, "utf8");
const cities = [];
for (const line of text.split(/\r?\n/)) {
  if (!line) continue;
  const values = line.split("\t");
  const record = Object.fromEntries(fields.map((field, index) => [field, values[index] || ""]));
  if (record.featureClass !== "P" || !/^[A-Z]{2}$/.test(record.countryCode)) continue;
  const alternateNames = record.alternateNames
    .split(",")
    .filter(Boolean)
    .filter((name, index, all) => all.indexOf(name) === index)
    .slice(0, 12);
  cities.push({
    id: Number(record.id),
    name: record.name,
    asciiName: record.asciiName,
    alternateNames,
    countryCode: record.countryCode,
    admin1: record.admin1,
    latitude: Number(record.latitude),
    longitude: Number(record.longitude),
    population: Number(record.population) || 0
  });
}

cities.sort((a, b) => a.countryCode.localeCompare(b.countryCode) || b.population - a.population || a.name.localeCompare(b.name));
await mkdir(outputPath.slice(0, outputPath.lastIndexOf("/")), { recursive: true });
await writeFile(outputPath, JSON.stringify({ source: "GeoNames cities5000", attribution: "GeoNames.org", cities }));
console.log(`Wrote ${cities.length} cities to ${outputPath}`);
