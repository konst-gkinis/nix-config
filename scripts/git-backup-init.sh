# Make `git push` in the current repo go to GitHub and pvegit:<name>.git, then push everything.
# The repo on pve is created on first push by a forced-command wrapper; see git-backup.md in
# the homelab repo. Packaged in shared/packages.nix, so it runs as `git backup-init [name]`.
set -euo pipefail
url=$(git remote get-url origin)
name=${1:-$(basename "$url" .git)}
pushurls=$(git config --get-all remote.origin.pushurl || true)

case "$pushurls" in
  *pvegit:*) echo "origin already pushes to pvegit:"; git remote -v; exit 0 ;;
esac
# The first push URL replaces the fetch URL for pushes, so keep GitHub explicitly.
[ -n "$pushurls" ] || git remote set-url --add --push origin "$url"
git remote set-url --add --push origin "pvegit:$name.git"
git push --all "pvegit:$name.git"
git push --tags "pvegit:$name.git"
git remote -v
