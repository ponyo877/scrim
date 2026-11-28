#!/usr/bin/env bash
# Looks for a release of Agones newer than the one scrim is compatible
# with. When there is one, it tries the mechanical part of moving to it in
# the working tree, and opens an issue, or rewrites the open one, with how
# far that got and what is left. The rest is not done here: what changed
# in Agones has to be read, and ported where scrim does the same thing.
#
# Usage: build/ci/agones-follow.sh [VERSION]
#
# VERSION is the release to try, such as v1.63.0: the latest one when left
# out. With DRY_RUN=1 the issue is printed, not opened.
set -euo pipefail

have=$(go list -m -f '{{.Version}}' agones.dev/agones)
want=${1:-$(gh api repos/agones-dev/agones/releases/latest --jq .tag_name)}
if [ "$want" = "$have" ]; then
	echo "scrim is compatible with Agones $have, the latest release"
	exit 0
fi
log=$(mktemp)
tried=$(mktemp)
body=$(mktemp)

# step DESCRIPTION COMMAND...: one step of the move, checked off in the
# issue when it passes, and shown with the end of its output when not.
step() {
	local description=$1
	shift
	if "$@" >"$log" 2>&1; then
		echo "- [x] $description" >>"$tried"
		return
	fi
	{
		echo "- [ ] $description: failed"
		echo
		echo '  ```'
		tail -n 40 "$log" | sed 's/^/  /'
		echo '  ```'
	} >>"$tried"
	return 1
}
module() { go get "agones.dev/agones@$want" && go mod tidy; }
submodule() {
	git -C third_party/agones fetch --quiet --depth 1 origin tag "$want" &&
		git -C third_party/agones checkout --quiet "$want"
}
constant() {
	sed -i.old "s/^const Version = .*/const Version = \"${want#v}\"/" pkg/agones/agones.go &&
		rm pkg/agones/agones.go.old
}

# Each step needs the one before it, so the first to fail ends the move.
move() {
	step "go.mod requires agones.dev/agones $want" module &&
		step "third_party/agones is at $want" submodule &&
		step "pkg/agones says ${want#v}" constant &&
		step "it builds" go build ./cmd/... ./pkg/... &&
		step "the tests pass (go test -short)" go test -short ./pkg/... ./cmd/...
}
move || true

# Some of these lines say what scrim is compatible with, others how Agones
# behaved in that release.
named=$({ git grep -n -F "${have%.*}" -- . ':!third_party' || true; } | cut -d: -f1,2 | sed 's/.*/  - [ ] &/')

cat >"$body" <<EOF
[Agones $want](https://github.com/agones-dev/agones/releases/tag/$want) is out; scrim is compatible with $have. The workflow agones tried the first steps of moving to it:

$(cat "$tried")

What is left, as docs/design.md says under 本家の新しい版への追従:

- [ ] Read the release notes and [the changes since $have](https://github.com/agones-dev/agones/compare/$have...$want), and port those in the parts that scrim implements itself. A difference that stays is written down in docs/design.md and docs/agones.md.
- [ ] Read again each line that names ${have%.*}:
$named
- [ ] The kind node image in build/ci/agones-kind.sh is of the Kubernetes minor version that Agones tests with.
- [ ] CI passes, agones-sdks and agones-diff among the checks.
- [ ] A release of scrim is compatible with $want.
EOF

title="Follow Agones $want"
if [ "${DRY_RUN:-}" = 1 ]; then
	echo "# $title"
	cat "$body"
	exit 0
fi
open=$(gh issue list --state open --search "in:title \"$title\"" --json number,title \
	--jq "map(select(.title == \"$title\")) | first | .number // empty")
if [ -n "$open" ]; then
	gh issue edit "$open" --body-file "$body"
else
	gh issue create --title "$title" --body-file "$body"
fi
