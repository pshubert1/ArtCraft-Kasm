# syntax=docker/dockerfile:1
FROM kasmweb/ubuntu-noble-desktop:1.19.0
USER root
ENV HOME=/home/kasm-default-profile \
    STARTUPDIR=/dockerstartup \
    DEBIAN_FRONTEND=noninteractive
WORKDIR /home/kasm-default-profile
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl jq python3 wmctrl libgl1-mesa-dri mesa-vulkan-drivers \
    && rm -rf /var/lib/apt/lists/*
# Retain XFCE and its panel for recovery. No broad autoremove.
RUN set -eux; REMOVE_PKGS=""; \
    for pkg in firefox firefox-esr chromium chromium-browser google-chrome-stable \
        libreoffice-common libreoffice-core thunderbird; do \
      if dpkg-query -W -f='${db:Status-Status}' "$pkg" 2>/dev/null | grep -qx installed; then \
        REMOVE_PKGS="$REMOVE_PKGS $pkg"; \
      fi; \
    done; \
    if [ -n "$REMOVE_PKGS" ]; then apt-get update; apt-get purge -y $REMOVE_PKGS; fi; \
    rm -rf /var/lib/apt/lists/*
COPY artcraft.sh apps.txt /tmp/
ARG ARTCRAFT_REFRESH=manual
RUN --mount=type=secret,id=github_token \
    echo "Release refresh: $ARTCRAFT_REFRESH" \
    && bash -n /tmp/artcraft.sh \
    && bash /tmp/artcraft.sh /tmp/apps.txt \
    && rm -f /tmp/artcraft.sh /tmp/apps.txt \
    && rm -rf /var/lib/apt/lists/*
RUN python3 - <<'PY'
import os, pathlib, subprocess
packages = subprocess.check_output(['dpkg-query', '-W', '-f=${binary:Package}\n'], text=True).splitlines()
matches = [p for p in packages if 'craft' in p.lower() and 'launcher' in p.lower()]
if len(matches) != 1:
    raise SystemExit(f'Cannot identify launcher package: {matches}')
files = subprocess.check_output(['dpkg-query', '-L', matches[0]], text=True).splitlines()
executables = [p for p in files if p.startswith(('/usr/bin/', '/opt/')) and pathlib.Path(p).is_file() and os.access(p, os.X_OK) and 'craft' in pathlib.Path(p).name.lower() and 'launcher' in pathlib.Path(p).name.lower()]
if len(executables) != 1:
    raise SystemExit(f'Cannot identify launcher executable: {executables}')
pathlib.Path('/etc/artcraft-launcher-path').write_text(executables[0] + '\n')
print('Launcher:', executables[0])
PY
COPY custom_startup.sh /dockerstartup/custom_startup.sh
RUN bash -n /dockerstartup/custom_startup.sh \
    && chmod 0755 /dockerstartup/custom_startup.sh \
    && chown -R 1000:0 /home/kasm-default-profile \
    && /dockerstartup/set_user_permission.sh /home/kasm-default-profile
ENV HOME=/home/kasm-user
WORKDIR /home/kasm-user
RUN mkdir -p /home/kasm-user && chown 1000:0 /home/kasm-user
USER 1000
