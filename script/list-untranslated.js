// List keys whose ja value still equals the en value (likely untranslated).
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const enPath = path.join(__dirname, 'en.json');
const jaPath = path.join(__dirname, '..', 'languages', 'ja.json');

let enRaw = fs.readFileSync(enPath, 'utf8');
let jaRaw = fs.readFileSync(jaPath, 'utf8');
let enData = JSON.parse(enRaw);
let jaData = JSON.parse(jaRaw);

function walk(enObj, jaObj, prefix) {
    let hits = [];
    for (let key in enObj) {
        const enVal = enObj[key];
        const jaVal = jaObj ? jaObj[key] : undefined;
        const fullKey = prefix ? prefix + '.' + key : key;
        if (typeof enVal == 'object' && enVal !== null) {
            hits = hits.concat(walk(enVal, jaVal, fullKey));
        } else {
            if (typeof jaVal == 'string' && enVal == jaVal) {
                hits = hits.concat([fullKey]);
            }
        }
    }
    return hits;
}

const untranslated = walk(enData, jaData, '');
console.log('untranslated count: ' + untranslated.length);
for (let i = 0; i < untranslated.length; i = i + 1) {
    console.log('- ' + untranslated[i]);
}
