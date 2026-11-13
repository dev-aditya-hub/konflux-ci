#!/usr/bin/env bash
# Exercise the validation added to tasks/send-github-release-event, using the
# same validate_field implementation and the same patterns as the task script.
set -uo pipefail

pass=0
fail=0

# --- copied verbatim from the task script -----------------------------------
validate_field() {
  local name="$1" value="$2" pattern="$3"

  if [ "${#value}" -gt 256 ]; then
    echo "Error: ${name} is too long (${#value} characters, max 256)" >&2
    exit 1
  fi
  if [[ ! "${value}" =~ ${pattern} ]]; then
    echo "Error: ${name} contains disallowed characters: '${value}'" >&2
    echo "       Expected pattern: ${pattern}" >&2
    exit 1
  fi
}
PAT_VERSION='^[A-Za-z0-9][A-Za-z0-9._/+-]*$'
PAT_GIT_REF='^[0-9a-fA-F]{7,40}$'
PAT_IMAGE_TAG='^release-sha-[A-Za-z0-9._-]+$'
# ----------------------------------------------------------------------------

check() {
  local label="$1" want="$2" field="$3" value="$4" pattern="$5"
  local got
  if ( validate_field "$field" "$value" "$pattern" ) 2>/dev/null; then
    got="accepted"
  else
    got="rejected"
  fi
  if [[ "$got" == "$want" ]]; then
    printf '  PASS  %-44s -> %s\n' "$label" "$got"; pass=$((pass + 1))
  else
    printf '  FAIL  %-44s -> %s (wanted %s)\n' "$label" "$got" "$want"; fail=$((fail + 1))
  fi
}

# How the task derives the image tag, verbatim.
extract_tag() { echo "$1" | sed 's/.*:\(release-sha-[^@]*\).*/\1/'; }

echo "version (from the refs/tags/ annotation):"
check "v1.2.3"                        accepted version "v1.2.3"              "$PAT_VERSION"
check "v1.2.3-rc.1"                   accepted version "v1.2.3-rc.1"         "$PAT_VERSION"
check "command substitution"          rejected version 'v1.2.3$(id)'         "$PAT_VERSION"
check "leading dash"                  rejected version "-oProxyCommand=id"   "$PAT_VERSION"
check "semicolon chain"               rejected version "v1.2.3; id"          "$PAT_VERSION"
check "over 256 chars"                rejected version "v$(printf 'a%.0s' {1..300})" "$PAT_VERSION"

echo "git_ref (sha label, now required to be hex):"
check "short sha"                     accepted git_ref "80669c7"             "$PAT_GIT_REF"
check "full sha"                      accepted git_ref "80669c7a1b2c3d4e5f60718293a4b5c6d7e8f901" "$PAT_GIT_REF"
check "branch name, not a sha"        rejected git_ref "main"                "$PAT_GIT_REF"
check "sha with chained command"      rejected git_ref "80669c7; id"         "$PAT_GIT_REF"
check "too short to be a sha"         rejected git_ref "123"                 "$PAT_GIT_REF"

echo "image_tag (after the sed extraction the task does):"
t=$(extract_tag "quay.io/konflux-ci/konflux-operator:release-sha-80669c7@sha256:abc")
check "normal image url -> $t"        accepted image_tag "$t"                "$PAT_IMAGE_TAG"

# sed prints the line unchanged when the pattern does not match, so a url with
# no release-sha- segment leaves the whole url in the variable.
t=$(extract_tag "quay.io/konflux-ci/konflux-operator:latest")
check "no release-sha segment -> whole url" rejected image_tag "$t"          "$PAT_IMAGE_TAG"

# the capture group is [^@]*, which admits shell metacharacters.
t=$(extract_tag "quay.io/konflux-ci/konflux-operator:release-sha-7; id")
check "metachars inside the capture -> '$t'" rejected image_tag "$t"         "$PAT_IMAGE_TAG"

echo
echo "passed=$pass failed=$fail"
[[ $fail -eq 0 ]]
