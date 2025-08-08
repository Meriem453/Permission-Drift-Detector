FROM alpine:3.20

# Install dependencies
RUN apk add --no-cache bash git curl

# Add yq
RUN curl -sSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
    -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
