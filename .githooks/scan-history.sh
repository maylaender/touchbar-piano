#!/bin/sh
# Scans every commit (content + author/committer) – run before each push.
cd "$(git rev-parse --show-toplevel)" && . .githooks/patterns.sh
BAD=0
HITS=$(git grep -nIiE "$PAT" $(git rev-list --all) -- . ':!.githooks' | filter)
[ -n "$HITS" ] && { echo "$HITS"; BAD=1; }
git log --all --format='%ae%n%ce' | sort -u | grep -v noreply && BAD=1
[ $BAD = 0 ] && echo "scan: clean ($(git rev-list --all --count) commits)" || { echo "scan: FAILED"; exit 1; }
