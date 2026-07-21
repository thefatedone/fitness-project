FROM node:20-alpine

WORKDIR /app

# Build-time variable so Next.js bakes the API base URL into the bundle.
# Pass via `docker compose` build args (sourced from the root `.env`).
ARG NEXT_PUBLIC_API_URL=http://localhost:8000
ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}

COPY package*.json ./
RUN npm install --legacy-peer-deps

COPY . .

RUN npm run build

EXPOSE 3000

ENV NODE_ENV=production

CMD ["node", "node_modules/next/dist/bin/next", "start"]