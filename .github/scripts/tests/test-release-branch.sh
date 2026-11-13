#!/usr/bin/env bash
# Exercise the git_ref check in create-release-branch-and-pr.sh.
# Args: <dev_version> <release_version> <git_ref> <remote>
#
# Every case here passes a deliberately invalid dev_version ("x"), so a git_ref
# that is ACCEPTED stops at the dev_version check instead. Both checks run
# before the script touches git or gh, so nothing here has side effects.
set -uo pipefail

SCRIPT="$1"
pass=0
fail=0

check() {
  local label="$1" want="$2" ref="$3"
  local out
  out=$("$SCRIPT" "x" "1.1" "$ref" "origin" 2>&1)

  local got
  if grep -qi "git_ref contains disallowed" <<<"$out"; then
    got="rejected"
  elif grep -qi "dev_version and release_version must be" <<<"$out"; then
    got="accepted"   # got past the git_ref check
  else
    got="other: $(head -1 <<<"$out")"
  fi

  if [[ "$got" == "$want" ]]; then
    printf '  PASS  %-38s -> %s\n' "$label" "$got"; pass=$((pass + 1))
  else
    printf '  FAIL  %-38s -> %s (wanted %s)\n' "$label" "$got" "$want"; fail=$((fail + 1))
  fi
}

check "main"                      accepted "main"
check "commit sha"                accepted "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
check "release/1.2"               accepted "release/1.2"
check "command substitution"      rejected 'main$(id)'
check "semicolon chain"           rejected "main; id"
check "backticks"                 rejected 'main`id`'
check "leading dash (git option)" rejected "--upload-pack=touch /tmp/pwn"
check "quote break-out"           rejected 'main" ; id ; "'
check "newline"                   rejected $'main\nid'

echo
echo "passed=$pass failed=$fail"
[[ $fail -eq 0 ]]
