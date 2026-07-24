#!/usr/bin/env bash
set -euo pipefail

if (( $# < 2 || $# > 3 )); then
  echo "Usage: $0 <previous-ref> <release-ref> [flclash-upstream-ref]" >&2
  exit 2
fi

previous_ref=$1
release_ref=$2
flclash_upstream_ref=${3:-upstream/dev}

repo_root=$(git rev-parse --show-toplevel)
core_dir="$repo_root/core/mihomo"

git -C "$repo_root" rev-parse --verify "${previous_ref}^{commit}" >/dev/null
release_sha=$(git -C "$repo_root" rev-parse --verify "${release_ref}^{commit}")
git -C "$repo_root" rev-parse --verify "${flclash_upstream_ref}^{commit}" >/dev/null

read_version() {
  git -C "$repo_root" show "$1:pubspec.yaml" |
    sed -n 's/^version: \([^+[:space:]]*\).*/\1/p' |
    head -n 1
}

previous_version=$(read_version "$previous_ref")
if [[ -z "$previous_version" ]]; then
  echo "Could not read the version from $previous_ref:pubspec.yaml" >&2
  exit 1
fi

if git -C "$repo_root" merge-base --is-ancestor "$previous_ref" "$release_ref"; then
  comparison_base=$(git -C "$repo_root" rev-parse "${previous_ref}^{commit}")
  comparison_reason="previous release tag is an ancestor"
else
  comparison_base=""
  while IFS= read -r commit; do
    version=$(read_version "$commit")
    [[ "$version" == "$previous_version" ]] || continue

    parent=$(git -C "$repo_root" rev-parse "${commit}^" 2>/dev/null || true)
    if [[ -z "$parent" || "$(read_version "$parent")" != "$previous_version" ]]; then
      comparison_base=$commit
      break
    fi
  done < <(git -C "$repo_root" rev-list --first-parent "$release_ref")

  if [[ -z "$comparison_base" ]]; then
    echo "Could not locate the $previous_version version boundary on $release_ref" >&2
    exit 1
  fi
  comparison_reason="parallel tags; using the previous version boundary on the release history"
fi

flclash_base=$(git -C "$repo_root" merge-base "$flclash_upstream_ref" "$release_ref")
flclash_branch=${flclash_upstream_ref#*/}

core_sha=$(
  git -C "$repo_root" ls-tree "$release_ref" core/mihomo |
    awk '$1 == "160000" { print $3 }'
)
if [[ -z "$core_sha" ]]; then
  echo "Could not resolve core/mihomo at $release_ref" >&2
  exit 1
fi
git -C "$core_dir" cat-file -e "${core_sha}^{commit}"

mihomo_tag=$(git -C "$core_dir" describe --tags --abbrev=0 "$core_sha" 2>/dev/null || true)
if [[ -n "$mihomo_tag" ]]; then
  mihomo_base=$(git -C "$core_dir" rev-parse "${mihomo_tag}^{commit}")
  mihomo_label="$mihomo_tag"
else
  mihomo_base=$core_sha
  mihomo_label=$(git -C "$core_dir" rev-parse --short=10 "$core_sha")
fi

printf 'Release: %s (%s)\n' "$release_ref" "$release_sha"
printf 'Comparison base: %s (%s)\n' "$comparison_base" "$comparison_reason"
printf 'FlClash upstream: %s at %s\n' "$flclash_branch" "$flclash_base"
printf 'mihomo upstream: %s at %s\n' "$mihomo_label" "$mihomo_base"
printf '\nRelease commits:\n'
git -C "$repo_root" log \
  --reverse \
  --format='- %h %s' \
  --invert-grep \
  --grep='^Bump version$' \
  "${comparison_base}..${release_sha}"
