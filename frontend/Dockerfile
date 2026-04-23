FROM node:20-alpine AS deps

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

FROM node:20-alpine

WORKDIR /app

RUN addgroup -S frontendgrp \
    && adduser -S frontendusr -G frontendgrp

COPY --from=deps /app/node_modules ./node_modules
COPY package.json package-lock.json ./
COPY . .

RUN chown -R frontendusr:frontendgrp /app

USER frontendusr

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health >/dev/null || exit 1

CMD ["npm", "start"]
