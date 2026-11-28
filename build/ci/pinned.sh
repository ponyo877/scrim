#!/bin/sh
# Checks that the Agones in third_party is the version the build uses, and
# that the documents say it is the one scrim is compatible with.
#
# third_party/agones is a reference copy: the comments name files in it,
# and some tests read its samples. The code that is built comes from the
# Go module. The two must be the same commit, which is the one upstream
# has under the tag of the module's version. And the copy must be as
# upstream has it: nobody edits it.
set -eu
version=$(go list -m -f '{{.Version}}' agones.dev/agones)
url=$(git config -f .gitmodules submodule.third_party/agones.url)
have=$(git rev-parse HEAD:third_party/agones)
# An annotated tag is listed twice, the commit it stands for last.
want=$(git ls-remote "$url" "refs/tags/$version" "refs/tags/$version^{}" | tail -1 | cut -f1)

echo "go.mod has agones.dev/agones $version, which is commit $want"
echo "third_party/agones is at commit $have"
[ "$have" = "$want" ]
if [ -e third_party/agones/.git ]; then
	changed=$(git -C third_party/agones status --porcelain)
	[ -z "$changed" ] || { echo "third_party/agones has been changed:"; echo "$changed"; exit 1; }
fi

# Where the documents say which release scrim is compatible with. Other
# lines name it too; a move to a new release reads them all again.
stale=0
while IFS='|' read -r file claim; do
	grep -qF "$claim" "$file" || { echo "$file does not say: $claim"; stale=1; }
done <<EOF
README.md|compatible%20with-Agones%20$version
README.md|pinned to **Agones $version**
CONTRIBUTING.md|pinned to Agones $version.
docs/agones.md|compatible with **Agones $version**
docs/design.md|互換の基準は Agones $version である。
docs/planning.md|Agones のバージョンは $version に固定する。
EOF
[ "$stale" = 0 ]
