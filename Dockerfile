# صورة تشغيل المتجر — تشتغل على Koyeb و Railway و Fly.io وأي استضافة تدعم Docker
FROM node:22-slim
ENV NODE_ENV=production PORT=8000
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY server.js ./
COPY src ./src
COPY scripts ./scripts
COPY public ./public
RUN mkdir -p data && chown -R node:node /app
USER node
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s CMD node -e "fetch('http://localhost:'+process.env.PORT+'/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "--disable-warning=ExperimentalWarning", "server.js"]
