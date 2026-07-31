# Pinned digest-free but version-locked: ubuntu:latest made builds
# non-reproducible and silently changed the base out from under CI.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# nano is installed because the TS/TSX syntax files are a shipped feature;
# the previous image installed the syntax but not the editor that reads it.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      git \
      jq \
      nano \
      shellcheck \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash user
WORKDIR /home/user
COPY --chown=user:user . .
USER user

RUN chmod +x install.sh uninstall.sh validate_color_roles.sh && \
    ./install.sh

# -l so .bashrc is sourced and the colour system is live.
CMD ["/bin/bash", "-l"]
