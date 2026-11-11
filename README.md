# announce-action

Send one announcement to Discord, Bluesky, Telegram, Slack, Mastodon, X and
[100+ other services](https://github.com/caronc/apprise/wiki) from a GitHub
Actions step. It is a thin wrapper around the [Apprise](https://github.com/caronc/apprise) CLI.

The action knows nothing about your project. You give it a title, a Markdown
body and a link; your workflow decides when to call it and what to say.

## Usage

```yaml
- uses: doruksahin/announce-action@<commit-sha> # v1
  with:
    title: My App 1.2.0: Faster search
    body: |
      ## New
      - Search by card title.
    url: https://example.com/changelog#v1.2.0
    config: ${{ secrets.ANNOUNCE_CONFIG }}
```

Pin the action by commit SHA.

## Channels: the `config` secret

`config` is an [Apprise TEXT config](https://github.com/caronc/apprise/wiki/config_text):
one `tag=url` line per channel. Store it as a secret.

```
full=discord://<webhook_id>/<webhook_token>
full=tgram://<bot_token>/<chat_id>
short=bluesky://<handle>@<app_password>
short=x://<consumer_key>/<consumer_secret>/<access_key>/<access_secret>
```

| Tag | Receives | Use for |
| --- | --- | --- |
| `full` | title, body, link | Discord, Telegram, Slack, email |
| `short` | title, link | Bluesky, X, Mastodon (character limits, paid posts) |

Each service's URL format is on its
[Apprise wiki page](https://github.com/caronc/apprise/wiki#notification-services).
Adding a channel is a config change, not a code change.

## Inputs and outputs

| Input | Required | Default | Meaning |
| --- | --- | --- | --- |
| `title` | yes | | Announcement title |
| `body` | no | `''` | Markdown body, `full` channels only |
| `url` | no | `''` | Link added for every channel |
| `config` | yes | | Apprise config; empty skips the run |
| `attempts` | no | `3` | Tries per channel before it counts as failed |
| `retry-delay` | no | `10` | Seconds before the first retry; doubles after each try (10, 20, …) |
| `apprise-version` | no | pinned | Apprise version from PyPI |

Output `failed`: the tags with at least one channel that failed every attempt (empty on success).

## Behaviour

- Empty `config`: the step succeeds and the run summary says "Skipped".
- Each channel (config line) is sent on its own and retried on its own, with
  exponential backoff, so a flaky network or a blocked host gets more tries
  and a channel that already received the message never gets it twice.
- The run summary has one row per channel: tag, service, result and the
  attempt that worked. URLs and tokens are never printed.
- Any failed channel fails the step after all channels were tried. Run the
  step in its own job, or with `continue-on-error`, if it must not fail your pipeline.
- A rerun of the step sends to every channel again.
- Each channel's URL is written to a `0600` file in `$RUNNER_TEMP` and removed at the end;
  URLs never appear on a command line.
- Uses `uvx` when the runner has it; otherwise installs `uv` with `astral-sh/setup-uv`.

## License

MIT
