const fs = require('fs');
const data = JSON.parse(fs.readFileSync('merchant_translation_mapping.json','utf8'));
const target = process.argv[2];
const entries = [];
for (const entry of data) {
  for (const occ of entry.occurrences) {
    const [occFile, line] = occ.split(':');
    if (occFile === target) {
      entries.push({ line: Number(line), key: entry.key, ar: entry.ar, en: entry.en });
    }
  }
}
entries.sort((a,b)=>a.line-b.line);
for (const item of entries) {
  console.log(`${item.line}: ${item.key} => ${item.ar} | ${item.en}`);
}
