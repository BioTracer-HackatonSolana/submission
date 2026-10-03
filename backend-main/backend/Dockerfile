# Stage 1: Build
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including devDependencies for building)
RUN npm install

# Copy source code
COPY tsconfig.json ./
COPY src/ ./src/
COPY sql/ ./sql/

# Build the TypeScript project
RUN npm run build

# Stage 2: Production
FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install only production dependencies
RUN npm install --omit=dev

# Copy built files from the builder stage
COPY --from=builder /app/dist ./dist
COPY sql/ ./sql/

# Set Node environment to production
ENV NODE_ENV=production
ENV PORT=3015

# Expose the API port
EXPOSE 3015

# Start the server
CMD ["node", "dist/server.js"]
