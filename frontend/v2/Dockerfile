# ==========================================
# Stage 1: Build Stage
# ==========================================
FROM node:18-alpine AS builder

WORKDIR /app

# Enable legacy OpenSSL provider for react-scripts compatibility
ENV NODE_OPTIONS="--openssl-legacy-provider"

# Copy package specifications
COPY package*.json ./

# Install dependencies (frozen lockfile fallback to install)
RUN npm ci --silent || npm install --silent

# Copy application source code
COPY . .

# Build production static assets
RUN npm run build

# ==========================================
# Stage 2: Hardened Production Runtime
# ==========================================
FROM nginx:1.25-alpine

WORKDIR /usr/share/nginx/html

# Remove default nginx static assets
RUN rm -rf ./*

# Copy compiled assets from builder
COPY --from=builder /app/build .

# Copy optimized nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose HTTP port
EXPOSE 80

# Run nginx in foreground
CMD ["nginx", "-g", "daemon off;"]
