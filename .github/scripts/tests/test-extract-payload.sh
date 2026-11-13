#!/usr/bin/env bash
# Exercise the allowlist in extract-payload.sh. Arg order:
#   event_name version_input image_tag_input git_ref_input \
#   version_payload image_tag_payload git_ref_payload
set -uo pipefail

SCRIPT="$1"
pass=0
fail=0

check() {
  local label="$1" want="$2"; shift 2
  local out rc
  out=$("$SCRIPT" "$@" 2>&1); rc=$?
  if [[ "$want" == "accept" && $rc -eq 0 ]] || [[ "$want" == "reject" && $rc -ne 0 ]]; then
    printf '  PASS  %-42s (rc=%d)\n' "$label" "$rc"; pass=$((pass + 1))
  else
    printf '  FAIL  %-42s (rc=%d, wanted %s)\n' "$label" "$rc" "$want"
    printf '        %s\n' "$out" | head -2
    fail=$((fail + 1))
  fi
}

echo "workflow_dispatch path:"
check "ordinary release"            accept workflow_dispatch "v1.2.3" "v1.2.3" "main"
check "sha git_ref"                 accept workflow_dispatch "v1.2.3" "v1.2.3" "a1b2c3d4e5f6"
check "release branch ref"          accept workflow_dispatch "v1.2.3" "v1.2.3" "release/v1.2"
check "command substitution"        reject workflow_dispatch 'v1.2.3$(id)' "v1.2.3" "main"
check "semicolon chain"             reject workflow_dispatch "v1.2.3; id" "v1.2.3" "main"
check "backticks"                   reject workflow_dispatch 'v`id`'      "v1.2.3" "main"
check "pipe"                        reject workflow_dispatch "v1 | id"    "v1.2.3" "main"
check "leading dash (git option)"   reject workflow_dispatch "v1.2.3" "v1.2.3" "--upload-pack=touch"
check "quote break-out in git_ref"  reject workflow_dispatch "v1.2.3" "v1.2.3" 'main" ; id ; "'
check "newline into GITHUB_OUTPUT"  reject workflow_dispatch $'v1.2.3\nversion=evil' "v1.2.3" "main"
check "space in image_tag"          reject workflow_dispatch "v1.2.3" "v1 2" "main"
check "over 256 chars"              reject workflow_dispatch "v$(printf 'a%.0s' {1..300})" "v1.2.3" "main"

echo "repository_dispatch path (client_payload):"
check "ordinary payload"            accept repository_dispatch "" "" "" "v1.2.3" "v1.2.3" "main"
check "payload command subst"       reject repository_dispatch "" "" "" 'v$(id)' "v1.2.3" "main"
check "payload newline"             reject repository_dispatch "" "" "" "v1.2.3" "v1.2.3" $'main\ngit_ref=evil'

echo
echo "passed=$pass failed=$fail"
[[ $fail -eq 0 ]]
