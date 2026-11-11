#!/usr/bin/env bash
# Sends the announcement with Apprise and writes one summary row per tag.
# Inputs come from environment variables set by action.yml.
set -euo pipefail

summary() { echo "$1" >> "${GITHUB_STEP_SUMMARY:-/dev/null}"; }

summary "### Announcement"
if [ "${CONFIGURED}" != "true" ]; then
  summary "Skipped: no Apprise config."
  echo "failed=" >> "$GITHUB_OUTPUT"
  exit 0
fi

config_file="$(umask 077 && mktemp "${RUNNER_TEMP:-/tmp}/apprise.XXXXXX")"
trap 'rm -f "$config_file"' EXIT
printf '%s\n' "$CONFIG" > "$config_file"

link=""
[ -n "$URL" ] && link=$'\n\n'"$URL"
full_body="${BODY}${link}"
short_body="${URL:-$TITLE}"

summary ""
summary "| Tag | Result |"
summary "| --- | --- |"
failed=""
for tag in full short; do
  if [ "$tag" = full ]; then message="$full_body"; else message="$short_body"; fi
  status=0
  uvx --quiet --from "apprise==${APPRISE_VERSION}" apprise \
    --config "$config_file" --tag "$tag" --input-format markdown \
    --title "$TITLE" --body "$message" || status=$?
  case "$status" in
    0) summary "| \`$tag\` | sent |" ;;
    3) summary "| \`$tag\` | no channels |" ;; # Apprise: no service matched the tag
    *) summary "| \`$tag\` | failed (exit $status) |"; failed="$failed $tag" ;;
  esac
done

failed="${failed# }"
echo "failed=$failed" >> "$GITHUB_OUTPUT"
if [ -n "$failed" ]; then
  echo "::error::Announcement failed for: $failed"
  exit 1
fi
