// تخزين بسيط بملف JSON (بدون قاعدة بيانات خارجية)
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

export const DATA_DIR = path.resolve('data');
export const VIDEOS_DIR = path.join(DATA_DIR, 'videos');
fs.mkdirSync(VIDEOS_DIR, { recursive: true });
const FILE = path.join(DATA_DIR, 'db.json');

const empty = { jobs: [], plans: [], youtube: null };
let db = fs.existsSync(FILE) ? { ...empty, ...JSON.parse(fs.readFileSync(FILE, 'utf8')) } : structuredClone(empty);

export function save() {
  fs.writeFileSync(FILE + '.tmp', JSON.stringify(db, null, 2));
  fs.renameSync(FILE + '.tmp', FILE);
}
export const getDb = () => db;
export const newId = () => crypto.randomUUID().slice(0, 8);
