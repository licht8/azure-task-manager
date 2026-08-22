FROM node:22-alpine

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci

# Copy application source
COPY . .

# Build TanStack Start / Nitro production bundle
RUN npm run build

# Production port
EXPOSE 3000

# Start Nitro production server
CMD ["node", ".output/server/index.mjs"]