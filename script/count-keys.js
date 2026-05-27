// Count translation keys in languages/ja.json for quick sanity checks.
const fs = require('fs');
const path = require('path');

const jaPath = path.join(__dirname, '..', 'languages', 'ja.json');

const raw = fs.readFileSync(jaPath, 'utf8');
const data = JSON.parse(raw);

function countKeys(obj) {
    let count = 0;
    for (const key in obj) {
        if (typeof obj[key] === 'object' && obj[key] !== null) {
            count += countKeys(obj[key]);
        } else {
            count += 1;
        }
    }
    return count;
}

const total = countKeys(data);
console.log(`total keys: ${total}`);
