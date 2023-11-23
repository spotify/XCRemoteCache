# ================================
# Build image
# ================================
FROM nginx:latest

COPY nginx.conf /etc/nginx/nginx.conf
RUN mkdir -p /tmp/cache
RUN chown -R nginx:nginx /tmp/cache
