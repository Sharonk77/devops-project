FROM node:18-alpine

WORKDIR /health-check-backend

COPY package*.json ./

RUN npm install --force


COPY . .

EXPOSE 80

CMD ["node", "server.js"]
