FROM alpine:3.20

# Install curl, bash, git, jq, yq, and GitHub CLI
RUN apk add --no-cache curl bash git jq yq \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
       tee /etc/apk/keys/githubcli-archive-keyring.gpg > /dev/null \
    && echo "https://cli.github.com/packages" >> /etc/apk/repositories \
    && apk add --no-cache gh


# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
