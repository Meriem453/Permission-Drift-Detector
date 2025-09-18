FROM alpine:3.20

# Install dependencies
RUN apk add --no-cache bash git curl

# Install yq safely (detect HTML instead of binary)
RUN curl -sSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
    -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq \
    && if head -n 1 /usr/local/bin/yq | grep -q DOCTYPE; then \
         echo "❌ Failed to download yq binary (got HTML instead). Exiting."; \
         exit 1; \
       fi

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
