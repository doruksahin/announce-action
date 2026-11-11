#!/usr/bin/env bash
# Sends the announcement with Apprise, one channel (config line) at a time, and
# writes one summary row per channel. A failed channel is retried on its own,
# so channels that already received the message never get it twice.
# Inputs come from environment variables set by action.yml.
set -euo pipefail

summary() { echo "$1" >> "${GITHUB_STEP_SUMMARY:-/dev/null}"; }

summary "### Announcement"
if [ "${CONFIGURED}" != "true" ]; then
  summary "Skipped: no Apprise config."
  echo "failed=" >> "$GITHUB_OUTPUT"
  exit 0
fi

workdir="$(umask 077 && mktemp -d "${RUNNER_TEMP:-/tmp}/apprise.XXXXXX")"
trap 'rm -rf "$workdir"' EXIT

link=""
[ -n "$URL" ] && link=$'\n\n'"$URL"
full_body="${BODY}${link}"
short_body="${URL:-$TITLE}"

# Sends one channel; returns Apprise's exit code (0 sent, other failed).
send_channel() {
  local file="$1" message="$2"
  uvx --quiet --from "apprise==${APPRISE_VERSION}" apprise \
    --config "$file" --input-format markdown \
    --title "$TITLE" --body "$message"
}

# Runs send_channel up to ATTEMPTS times, doubling the delay after each failure.
# Prints the attempt that succeeded; returns 1 when every attempt failed.
with_retry() {
  local attempt=1 delay="$RETRY_DELAY"
  while true; do
    if send_channel "$@" >&2; then echo "$attempt"; return 0; fi
    [ "$attempt" -ge "$ATTEMPTS" ] && return 1
    echo "::warning::Channel failed (attempt $attempt of $ATTEMPTS); retrying in ${delay}s" >&2
    sleep "$delay"
    attempt=$((attempt + 1))
    delay=$((delay * 2))
  done
}

summary ""
summary "| # | Tag | Service | Result |"
summary "| --- | --- | --- | --- |"
failed=""
n=0
while IFS= read -r line || [ -n "$line" ]; do
  line="${line#"${line%%[![:space:]]*}"}"
  case "$line" in ''|\#*) continue ;; esac
  n=$((n + 1))
  tag="${line%%=*}"
  service="$(printf '%s' "${line#*=}" | sed -E 's#^([a-z0-9+.-]+)://(([a-z0-9-]+\.)*([a-z0-9-]+\.[a-z]+))?.*#\1 \4#')"
  case "$tag" in
    full) message="$full_body" ;;
    short) message="$short_body" ;;
    *) summary "| $n | \`$tag\` | $service | skipped: unknown tag |"; continue ;;
  esac
  file="$workdir/$n"
  printf '%s\n' "${line#*=}" > "$file"
  if attempt="$(with_retry "$file" "$message")"; then
    summary "| $n | \`$tag\` | $service | sent (attempt $attempt) |"
  else
    summary "| $n | \`$tag\` | $service | failed after $ATTEMPTS attempts |"
    case " $failed " in *" $tag "*) ;; *) failed="$failed $tag" ;; esac
  fi
done <<< "$CONFIG"

[ "$n" -eq 0 ] && summary "No channels in the config."
failed="${failed# }"
echo "failed=$failed" >> "$GITHUB_OUTPUT"
if [ -n "$failed" ]; then
  echo "::error::Announcement failed for: $failed"
  exit 1
fi
