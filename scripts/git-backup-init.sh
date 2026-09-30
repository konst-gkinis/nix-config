# halp: [name] — add a "home" remote at pvegit:<name>.git and push everything there
# Add a remote named `home` pointing at pvegit:<name>.git, then push all branches and tags to it.
# `origin` is left untouched; back up later with `git push home`. The repo on pve is created on
# first push by a forced-command wrapper; see git-backup.md in the homelab repo. Packaged in
# shared/packages.nix, so it runs as `git backup-init [name]`.
set -euo pipefail
name=${1:-$(basename "$(git remote get-url origin)" .git)}

if git remote get-url home >/dev/null 2>&1; then
  echo "remote 'home' already exists:"; git remote -v; exit 0
fi
git remote add home "pvegit:$name.git"
git push --all home
git push --tags home
git remote -v
