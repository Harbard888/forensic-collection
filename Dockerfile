# Dockerfile for the Weather Dashboard proxy
# Uses a small Node image and runs server.js
FROM node:18-alpine

# Create app directory
WORKDIR /usr/src/app

# Install dependencies
COPY package.json package-lock.json* ./
RUN npm install --production --no-audit --no-fund

# Bundle app source
COPY . .

# Expose port and run
EXPOSE 3000
CMD ["node", "server.js"]
