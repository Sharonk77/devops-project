FROM node:18-alpine

WORKDIR /dummy-server

COPY package*.json ./

RUN npm install --force


COPY . .

EXPOSE 80

CMD ["node", "server.js"]
