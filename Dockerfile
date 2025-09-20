FROM alpine:3.20

# Install dependencies
RUN apk add --no-cache bash git curl jq

# Install yq safely
RUN curl -sSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
    -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq \
    && if head -n 1 /usr/local/bin/yq | grep -q DOCTYPE; then \
         echo "❌ Failed to download yq binary (got HTML instead). Exiting."; \
         exit 1; \
       fi

# Install GitHub CLI (gh)
RUN curl -sSL -o gh.tar.gz https://github.com/cli/cli/releases/download/v2.63.2/gh_2.63.2_linux_amd64.tar.gz \
    && tar -xzf gh.tar.gz \
    && mv gh_*/bin/gh /usr/local/bin/ \
    && rm -rf gh_* gh.tar.gz

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

