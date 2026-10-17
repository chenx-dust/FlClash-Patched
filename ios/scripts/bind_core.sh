#!/bin/sh
# Binds core/mobile into ClashCore.framework, the iOS counterpart of the AAR
# that android/core builds. The app links the plain build; the Network
# Extension links the with_low_memory one, since jetsam ends it at its limit.
set -eu

variant="${1:?usage: bind_core.sh app|lowmem}"
case "$variant" in
  app) extra_tags="" ;;
  lowmem) extra_tags=",with_low_memory" ;;
  *) echo "error: unknown Core variant $variant" >&2; exit 1 ;;
esac

if [ "${PLATFORM_NAME:-iphoneos}" != "iphoneos" ]; then
  echo "error: the iOS Core is built for arm64 devices only, not ${PLATFORM_NAME}" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$script_dir/../.." && pwd)"
core="$root/core"
out="$root/build/ios/core"
framework="$out/$variant/ClashCore.framework"
stamp="$out/$variant.stamp"

# Xcode started from the Dock sees the PATH of the GUI session, which leaves out
# Homebrew and the Go installer.
PATH="$PATH:/opt/homebrew/bin:/usr/local/bin:/usr/local/go/bin:$HOME/go/bin"
go="$(command -v go || true)"
if [ -z "$go" ]; then
  echo "error: the iOS Core is built with gomobile, which needs Go on PATH" >&2
  exit 1
fi

config_value() {
  sed -n "s/^$1:[[:space:]]*//p" "$root/build_config.yaml" | tr -d "\"'"
}

if [ -d "$framework" ] && [ -f "$stamp" ] &&
  [ -z "$(find "$core" "$root/build_config.yaml" "$0" \
    \( -name '*.go' -o -name 'go.mod' -o -name 'go.sum' -o -name '*.yaml' -o -name '*.sh' \) \
    -not -path '*/.github/*' -newer "$stamp" -print -quit)" ]; then
  exit 0
fi

tools="$out/bin"
mkdir -p "$tools" "$out/$variant"
(cd "$core" && "$go" build -o "$tools/" golang.org/x/mobile/cmd/gomobile golang.org/x/mobile/cmd/gobind)

# gomobile links the library as the main package of a module it generates, whose
# go line is the toolchain's, so the GODEBUG defaults that core/go.mod sets for
# the desktop Core would not reach it on their own.
godebug="$(cd "$core" && "$go" list -f '{{.DefaultGODEBUG}}' ./cmd/core)"
ldflags="$(config_value go_ldflags)"
version="$(config_value core_version)"
if [ -n "$version" ]; then
  ldflags="$ldflags -X=github.com/metacubex/mihomo/constant.Version=$version"
fi

xcframework="$out/$variant/ClashCore.xcframework"
rm -rf "$xcframework"
# Xcode's own build settings in the environment would reach gomobile's clang,
# so it runs with the Go settings and little else.
set -- HOME="$HOME" PATH="$tools:$PATH" TMPDIR="${TMPDIR:-/tmp}"
[ -n "${DEVELOPER_DIR:-}" ] && set -- "$@" DEVELOPER_DIR="$DEVELOPER_DIR"
for name in $(env | sed -n 's/^\(GO[A-Z0-9_]*\)=.*/\1/p'); do
  eval "set -- \"\$@\" $name=\"\${$name}\""
done
(cd "$core" && env -i "$@" \
  "$tools/gomobile" bind \
  -target=ios/arm64 \
  -iosversion="${IPHONEOS_DEPLOYMENT_TARGET:-15.0}" \
  -tags="$(config_value tags)$extra_tags" \
  -ldflags="$ldflags -X=runtime.godebugDefault=$godebug" \
  -o "$xcframework" \
  ./mobile)

rm -rf "$framework"
mv "$xcframework/ios-arm64/ClashCore.framework" "$framework"
rm -rf "$xcframework"
touch "$stamp"
