FROM node:18-alpine

WORKDIR /dummy-server

COPY package*.json ./

RUN npm install --force


COPY . .

EXPOSE 3001

CMD ["node", "server.js"]
