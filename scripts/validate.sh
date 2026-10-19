#!/usr/bin/env bash
# Validate every app request: apps/<name>/<env>.yaml
#   - <name>: 2-30 chars, lowercase letters, digits, "-", starts with a letter, ends with a letter/digit
#   - <env>:  dev | staging | prod
#   - the file must not set "name" or "env" (they come from the path)
#   - the chart renders (same validation as in the cluster)
# Run locally before opening a pull request:  ./scripts/validate.sh
# Needs: bash, helm. Runs in CI on every pull request (.github/workflows/validate.yml).
set -uo pipefail
cd "$(dirname "$0")/.."

errors=0
fail() { echo "ERROR: $*"; errors=$((errors + 1)); }

shopt -s nullglob
for dir in apps/*/; do
  name=$(basename "$dir")
  [[ "$name" =~ ^[a-z][a-z0-9-]{0,28}[a-z0-9]$ ]] || fail "apps/$name/: invalid app name (2-30 chars, lowercase letters, digits, '-', start with a letter)"
  files=("$dir"*)
  [ ${#files[@]} -gt 0 ] || fail "apps/$name/: empty folder"
  for f in "${files[@]}"; do
    file=$(basename "$f")
    env="${file%.yaml}"
    if [[ "$file" != *.yaml ]]; then fail "$f: only <env>.yaml files are allowed (dev.yaml, staging.yaml, prod.yaml)"; continue; fi
    [[ "$env" =~ ^(dev|staging|prod)$ ]] || { fail "$f: invalid environment '$env' (dev, staging or prod)"; continue; }
    if grep -Eq '^(name|env):' "$f"; then fail "$f: do not set 'name' or 'env' in the file, they come from the folder and the file name"; fi
    # render the chart with this request, exactly like Argo CD does
    vals=$(mktemp)
    { echo "app:"; sed 's/^/  /' "$f"; echo "  name: $name"; echo "  env: $env"; } > "$vals"
    if out=$(helm template "$name" app-template -f "$vals" --set platform.domain=example.com --set platform.ingress.lbHostname=lb.example.com 2>&1); then
      echo "OK   $f -> $(echo "$out" | grep -c '^kind:') objects"
    else
      fail "$f: $(echo "$out" | grep -m1 -E 'Error|error')"
    fi
    rm -f "$vals"
  done
done

echo
if [ $errors -gt 0 ]; then echo "$errors error(s)"; exit 1; fi
echo "All app requests are valid."
