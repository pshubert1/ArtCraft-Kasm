# Private ArtCraft Kasm image repository

Source repository + GHCR build pipeline. This is NOT a one-click Kasm Workspace Registry catalog. Kasm does not build a Dockerfile when you add a catalog.

## Setup
1. Create a private GitHub repo named kasm-workspaces with default branch main.
2. Upload ALL archive contents, preserving paths, including .github/workflows/build-artcraft.yml and dotfiles. Do not upload only the ZIP.
3. Enable GitHub Actions if disabled. In Actions, run Build ArtCraft workspace.
4. After success, read the unique image tag in the run summary. Image owner is automatically your lowercase GitHub repository owner.
5. Confirm the GHCR package is private and associated with this repository. Repository and package visibility are separate settings.
6. Create a classic PAT with read:packages for an account authorized to read the package. Authorize SSO if required. Never commit the token.
7. In Kasm configure Docker Image as ghcr.io/OWNER/artcraft-workspace:UNIQUE_TAG, Docker Registry as https://ghcr.io, registry username as your GitHub username, registry password as your read:packages PAT. Keep the full ghcr.io-qualified image name.
8. Launch a NEW session. Keep the previous working image tag for rollback.

## Editing
- workspaces/artcraft/apps.txt: app repositories to include.
- workspaces/artcraft/artcraft.sh: latest-release download and installation logic.
- workspaces/artcraft/Dockerfile: base image and packages.
- workspaces/artcraft/custom_startup.sh: launcher and fullscreen behavior.
- .github/workflows/build-artcraft.yml: schedule, build and publishing.
Commits to main touching these files trigger a build. Schedules run on the default branch and can be delayed.

## Update behavior
Daily at 12:20 UTC; this shifts local Central time with daylight saving time.
Every run uses a new ARTCRAFT_REFRESH argument so the install layer rechecks releases.
The daily tag moves after a successful build. Unique tags use UTC date + run ID + attempt.
Use unique tags for production; test daily separately. Builds do NOT change your Kasm configuration or update active sessions automatically.
The installer deliberately fails the whole build if any listed app has no matching package or a download fails, rather than publishing an incomplete suite. Inspect the error and remove unsupported apps from apps.txt if necessary.
Latest means GitHub latest stable release, not unpublished commits or prereleases.

## Design
Retains the full Kasm Ubuntu Noble desktop startup stack and XFCE panel for black-screen recovery. Removes listed browser/office packages without broad autoremove. Deleting files in a derived image does not reclaim bytes in base layers; this is application cleanup, not a minimal image.
Launcher fullscreen defaults on. Workspace Docker Run Config may contain:
{
  "environment": {
    "ARTCRAFT_FULLSCREEN": "1",
    "ARTCRAFT_SOFTWARE_RENDERING": "1"
  }
}
Merge with existing configuration. Software rendering is experimental, not a guarantee.

## Local build
From repository root:
docker build --build-arg ARTCRAFT_REFRESH="$(date +%s)" -t local/artcraft-workspace:test workspaces/artcraft
API token is optional locally; if rate limited, use a BuildKit secret, never a build argument containing a token.

## Diagnose
Inside a running workspace:
cat ~/.local/state/artcraft/launcher.log
cat /usr/local/share/artcraft/releases.tsv
cat /etc/artcraft-launcher-path

## Security and operations
No PAT is embedded in the image or source. GitHub Actions uses its built-in GITHUB_TOKEN for publishing and an ephemeral BuildKit secret for release API calls. Action tags are convenience versions; for hardened deployment pin actions to reviewed commit SHAs.
Review upstream software licenses before redistributing. This starter has not been executed end-to-end; test it in a separate Kasm workspace before promotion.
Private GitHub Actions minutes/storage and GHCR usage may incur charges depending on your plan. Keep known-good production tags; clean up old versions deliberately.
