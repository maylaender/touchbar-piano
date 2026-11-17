# Shared patterns for the privacy check (sourced by pre-commit and scan-history.sh).
# Personal data (names, emails) go into .git/info/private-patterns – one regex per line,
# local only, never committed.
PAT='api[_-]?key|token|secret|password|sk-[a-z0-9]|ghp_|github_pat_|BEGIN .*PRIVATE|@[a-z0-9-]+\.(ch|de|com|net|org|io)'
PRIV="$(git rev-parse --git-dir)/info/private-patterns"
if [ -f "$PRIV" ]; then
  EXTRA=$(grep -v '^#' "$PRIV" | grep -v '^$' | paste -sd'|' -)
  [ -n "$EXTRA" ] && PAT="$PAT|$EXTRA"
fi
# Known false positives: GitHub's per-run token placeholder, noreply addresses
filter() { grep -v 'noreply' | grep -vF 'GH_TOKEN: ${{ github.token }}'; }
