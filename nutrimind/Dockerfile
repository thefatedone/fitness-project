FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

ENV NEXT_PUBLIC_API_URL=https://backend-fitness-production-3829.up.railway.app/

RUN npm run build

EXPOSE 3000

ENV NODE_ENV=production

CMD ["npm", "start"]