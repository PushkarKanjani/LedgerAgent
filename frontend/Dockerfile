# =============================================================================
# LedgerAgent Frontend — Multi-Stage Production Dockerfile
# Stage 1: Build static assets with Node.js & Vite
# Stage 2: Serve high-performance bundle with Nginx Alpine
# =============================================================================

# --- Stage 1: Build ---
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

# --- Stage 2: Runtime ---
FROM nginx:alpine AS runtime

COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

# Explicitly test IPv4 loopback 127.0.0.1 to avoid Alpine/Busybox IPv6 loopback mismatch
HEALTHCHECK --interval=5s --timeout=3s --start-period=3s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
