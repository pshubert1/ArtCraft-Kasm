#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID == 0 ]] || { echo 'Run this installer as root.' >&2; exit 1; }
APP_LIST="${1:-/tmp/apps.txt}"
TMP_DIR="$(mktemp -d /tmp/artcraft-install-XXXXXXXX)"
trap 'rm -rf -- "$TMP_DIR"' EXIT
chmod 0755 "$TMP_DIR"
ARCH="$(dpkg --print-architecture)"
case "$ARCH" in
  amd64) ASSET_ARCH=x86_64 ;;
  arm64) ASSET_ARCH=aarch64 ;;
  *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac
API_HEADERS=(-H 'Accept: application/vnd.github+json')
if [[ -s /run/secrets/github_token ]]; then
  API_HEADERS+=(-H "Authorization: Bearer $(cat /run/secrets/github_token)")
fi
PACKAGES=()
mkdir -p /usr/local/share/artcraft
MANIFEST=/usr/local/share/artcraft/releases.tsv
printf 'repository\ttag\tasset\n' > "$MANIFEST"
while IFS= read -r repo || [[ -n "$repo" ]]; do
  [[ -z "$repo" || "$repo" == \#* ]] && continue
  [[ "$repo" =~ ^[a-z0-9-]+$ ]] || { echo "Invalid repo: $repo" >&2; exit 1; }
  echo "Resolving latest release: $repo"
  json="$TMP_DIR/$repo.json"
  curl -fsSL --retry 3 --connect-timeout 30 "${API_HEADERS[@]}" \
    "https://api.github.com/repos/storytold/$repo/releases/latest" -o "$json"
  tag="$(jq -er .tag_name "$json")"
  matches="$(jq -c --arg suffix "-linux-$ASSET_ARCH.deb" --arg arch "$ARCH" --arg alt "$ASSET_ARCH" '
    [.assets[] | select(.name | endswith($suffix))] as $exact
    | if ($exact|length)>0 then $exact else
      [.assets[] | select(.name | endswith(".deb"))
        | select(.name | test("(^|[-_.])("+$arch+"|"+$alt+")([-_.]|$)";"i"))]
      end' "$json")"
  count="$(jq length <<< "$matches")"
  if [[ "$count" != 1 ]]; then
    jq -r '.assets[].name' "$json" >&2
    echo "$repo: expected exactly one compatible .deb, found $count. Refusing partial build." >&2
    exit 1
  fi
  file="$(jq -er '.[0].name' <<< "$matches")"
  url="$(jq -er '.[0].browser_download_url' <<< "$matches")"
  [[ "$file" != */* ]] || exit 1
  mkdir -p "$TMP_DIR/$repo"
  chmod 0755 "$TMP_DIR/$repo"
  dest="$TMP_DIR/$repo/$file"
  curl -fL --retry 3 --connect-timeout 30 "$url" -o "$dest"
  chmod 0644 "$dest"
  dpkg-deb --info "$dest" >/dev/null
  pkgarch="$(dpkg-deb --field "$dest" Architecture)"
  [[ "$pkgarch" == "$ARCH" || "$pkgarch" == all ]] || exit 1
  PACKAGES+=("$dest")
  printf '%s\t%s\t%s\n' "$repo" "$tag" "$file" >> "$MANIFEST"
done < "$APP_LIST"
(( ${#PACKAGES[@]} > 0 ))
apt-get update
apt-get install -y "${PACKAGES[@]}"
cat "$MANIFEST"
