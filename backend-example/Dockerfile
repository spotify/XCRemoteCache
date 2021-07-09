# ================================
# Build image
# ================================
FROM nginx:1.21.1

COPY nginx.conf /etc/nginx/nginx.conf
RUN mkdir -p /tmp/cache
RUN chown -R nginx:nginx /tmp/cache
