# Agent-runtime sidecar for Agentic PPM.
FROM node:20-slim

WORKDIR /app

# Install deps first for layer caching.
COPY package.json package-lock.json* ./
RUN npm install --omit=dev || npm install

COPY tsconfig.json ./
COPY src ./src

ENV NODE_ENV=production
EXPOSE 8745

# Run TypeScript directly via tsx (no separate build step for the Quick slice).
CMD ["npx", "tsx", "src/index.ts"]
