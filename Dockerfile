FROM haproxy:alpine
RUN  addgroup -S haproxy && adduser -S -g haproxy haproxy
VOLUME /var/lib/haproxy