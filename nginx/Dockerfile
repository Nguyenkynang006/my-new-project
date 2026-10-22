FROM nginx:1.27-alpine

# Install openssl for self-signed certificate generation
RUN apk add --no-cache openssl

# Remove default configuration
RUN rm -f /etc/nginx/conf.d/default.conf

# Copy custom Nginx configuration and entrypoint
COPY nginx.conf /etc/nginx/nginx.conf
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 80 443 8080

ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
