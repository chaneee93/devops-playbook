# Node.js Dockerfile 템플릿
# TODO: 멀티스테이지 빌드로 구성
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
CMD ["node", "index.js"]
