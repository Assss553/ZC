// كل طلبات /api و /img و /healthz تمر من هنا على Netlify (دوال Netlify v2)
import serverless from 'serverless-http';
import app from '../../src/app.js';

const run = serverless(app, { binary: ['image/*'] });

export default async (req, context) => {
  const url = new URL(req.url);
  const body = Buffer.from(await req.arrayBuffer());
  const headers = Object.fromEntries(req.headers);
  if (context?.ip) headers['x-nf-client-connection-ip'] = context.ip;
  const multiQuery = {};
  for (const [k, v] of url.searchParams) (multiQuery[k] ??= []).push(v);
  const r = await run({
    httpMethod: req.method, path: url.pathname, rawUrl: req.url, headers,
    queryStringParameters: Object.fromEntries(url.searchParams), multiValueQueryStringParameters: multiQuery,
    body: body.length ? body.toString('base64') : null, isBase64Encoded: true,
  }, {});
  const out = new Headers();
  for (const [k, v] of Object.entries(r.headers || {})) if (v != null) out.set(k, String(v));
  for (const [k, vs] of Object.entries(r.multiValueHeaders || {})) { out.delete(k); for (const v of vs) out.append(k, String(v)); }
  const data = r.body ? (r.isBase64Encoded ? Buffer.from(r.body, 'base64') : r.body) : null;
  return new Response([204, 304].includes(r.statusCode) ? null : data, { status: r.statusCode, headers: out });
};

export const config = { path: ['/api/*', '/img/*', '/healthz'] };
