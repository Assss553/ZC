// ربط قناة يوتيوب (OAuth) والرفع عبر YouTube Data API v3
import fs from 'node:fs';
import { getDb, save } from './store.js';

const redirect = () => `${process.env.PUBLIC_URL || 'http://localhost:' + (process.env.PORT || 4000)}/auth/youtube/callback`;

export function authUrl() {
  const q = new URLSearchParams({
    client_id: process.env.GOOGLE_CLIENT_ID, redirect_uri: redirect(), response_type: 'code',
    access_type: 'offline', prompt: 'consent',
    scope: 'https://www.googleapis.com/auth/youtube.upload https://www.googleapis.com/auth/youtube.readonly',
  });
  return 'https://accounts.google.com/o/oauth2/v2/auth?' + q;
}

async function token(params) {
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ client_id: process.env.GOOGLE_CLIENT_ID, client_secret: process.env.GOOGLE_CLIENT_SECRET, ...params }),
  });
  if (!res.ok) throw new Error('Google token: ' + (await res.text()));
  return res.json();
}

export async function handleCallback(code) {
  const t = await token({ code, grant_type: 'authorization_code', redirect_uri: redirect() });
  const db = getDb();
  db.youtube = { refresh_token: t.refresh_token, access_token: t.access_token, expires: Date.now() + t.expires_in * 1000 };
  const ch = await (await fetch('https://www.googleapis.com/youtube/v3/channels?part=snippet&mine=true',
    { headers: { authorization: `Bearer ${t.access_token}` } })).json();
  db.youtube.channel = ch.items?.[0]?.snippet?.title || 'قناتي';
  save();
}

async function accessToken() {
  const yt = getDb().youtube;
  if (!yt) throw new Error('القناة غير مربوطة');
  if (Date.now() > yt.expires - 60000) {
    const t = await token({ refresh_token: yt.refresh_token, grant_type: 'refresh_token' });
    yt.access_token = t.access_token; yt.expires = Date.now() + t.expires_in * 1000; save();
  }
  return yt.access_token;
}

export async function upload({ file, title, description, tags, privacy = 'public' }) {
  const at = await accessToken();
  const size = fs.statSync(file).size;
  const init = await fetch('https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status', {
    method: 'POST',
    headers: { authorization: `Bearer ${at}`, 'content-type': 'application/json', 'x-upload-content-type': 'video/mp4', 'x-upload-content-length': String(size) },
    body: JSON.stringify({
      snippet: { title: title.slice(0, 100), description: `${description}\n\n#shorts`, tags, categoryId: '24' },
      status: { privacyStatus: privacy, selfDeclaredMadeForKids: false, containsSyntheticMedia: true },
    }),
  });
  if (!init.ok) throw new Error('YouTube init: ' + (await init.text()).slice(0, 300));
  const put = await fetch(init.headers.get('location'), {
    method: 'PUT', headers: { 'content-type': 'video/mp4', 'content-length': String(size) },
    body: fs.createReadStream(file), duplex: 'half',
  });
  if (!put.ok) throw new Error('YouTube upload: ' + (await put.text()).slice(0, 300));
  return (await put.json()).id;
}
