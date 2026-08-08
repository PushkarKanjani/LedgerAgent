# =============================================================================
# LedgerAgent Frontend — Multi-Stage Production Dockerfile
# Stage 1: Build static assets with Node.js & Vite
# Stage 2: Serve high-performance bundle with Nginx Alpine (envsubst template)
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

# Remove default packaged config so envsubst template cleanly applies
RUN rm -f /etc/nginx/conf.d/default.conf

COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf.template /etc/nginx/templates/default.conf.template

# Default DNS resolver for Docker bridge network (overridden in ECS task def to VPC resolver)
ENV BACKEND_HOST=backend
ENV DNS_RESOLVER=127.0.0.11

EXPOSE 80

# Healthcheck via IPv4 loopback
HEALTHCHECK --interval=5s --timeout=3s --start-period=3s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
