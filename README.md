# memo

Let ChatGPT, Claude, or any AI agent hear your meetings as they happen, so every task you
hand off already has the full context.

![The Meeting.ai notetaker on a desk between ChatGPT and Claude](assets/banner.webp)

`memo` is the Meeting.ai command line. One binary that lets you, or the AI agent working for
you, list and search your meetings, read notes and transcripts, record a call, manage
contacts and Drive files, and export or share, all from a terminal. Every command prints
JSON, never prompts, and returns a meaningful exit code, so it is as comfortable in a script
or an agent loop as it is in your hands.

Meeting.ai is the AI that works before, during, and after your meeting. It prepares decks and
research before, records and writes the notes during, and turns what was actually said into
minutes, documents, spreadsheets, follow-up decks, audio briefs, and Visual Notes after.

## Install

| Platform | Architecture | Archive |
|---|---|---|
| macOS | Apple Silicon (arm64) | `memo_<version>_darwin_arm64.tar.gz` |
| macOS | Intel (amd64) | `memo_<version>_darwin_amd64.tar.gz` |
| Linux | arm64 | `memo_<version>_linux_arm64.tar.gz` |
| Linux | amd64 | `memo_<version>_linux_amd64.tar.gz` |

One line installs the right one:

```bash
curl -fsSL https://raw.githubusercontent.com/meeting-ai/memo-cli/main/install.sh | bash
```

The installer detects your platform, downloads the matching archive from the
[latest release](https://github.com/meeting-ai/memo-cli/releases/latest), verifies its
SHA-256 checksum, installs `memo` to `~/.local/bin`, adds that folder to your `PATH` if needed,
and installs the agent skill file. Set `MEMO_VERSION=v0.13.0` to pin a version or
`MEMO_INSTALL_DIR=/usr/local/bin` to change the location. Read [install.sh](install.sh) first
if you like to know what a script does before piping it to your shell.

Prefer to do it by hand? Download the archive for your platform and `checksums.txt` from the
release, check the sum, extract, and put `memo` on your `PATH`.

## Sign in

Meeting.ai commands need a signed-in session. Browser login is the default:

```bash
memo auth login        # opens Meeting.ai in your browser
memo auth status       # confirm who you are signed in as
```

The session is stored encrypted on your machine and can be revoked at any time from Connected
Apps in the Meeting.ai web app.

## Try it

memo covers far more than meeting notes. A few things to try once you are signed in.

| Area | Command | What it does |
|---|---|---|
| Meetings | `memo meetings list --compact` | Your recent meetings |
| | `memo meetings search --keyword "roadmap"` | Find a meeting by keyword |
| | `memo meetings get <id> --sections --key-points` | Read its notes |
| | `memo meetings create --url <meeting-url> --confirm` | Send the notetaker to a live call |
| | `memo meetings export <id> --format pdf` | Export to PDF |
| Contacts | `memo contacts list --search "Tirta"` | People you have met |
| | `memo contacts meetings <id>` | Every meeting with that person |
| Drive | `memo drive upload ./report.pdf --tag "Work"` | Upload and tag a file |
| | `memo drive list --tag "Work"` | Find it again |
| Calendar | `memo calendar events --date 2026-10-01` | What is coming up |
| | `memo calendar update-event <id> --invite-bot=true` | Make the notetaker join that meeting |
| Tools | `memo tools image "a teal fox logo, flat vector" --output fox.png` | Generate an image |
| | `memo tools tts "Hello from memo" --output hello.wav` | Text to speech |
| | `memo tools stt recording.mp3` | Audio to text |
| | `memo tools ocr scan.pdf` | Scanned PDF to text |
| | `memo tools search "latest Go release notes"` | Web search |
| | `memo recipe visual-note --content "$(cat notes.txt)"` | A one-page Visual Note |

Everything prints JSON to stdout, so `--jq` and `--compact` keep the output lean. Run
`memo --help` or `memo <group> --help` for the full command surface.

## Using memo with an AI agent

`memo` is built to be driven by agents. Install the bundled skill file into the agent
directories detected on your machine, and your agent learns how to use it:

```bash
memo install-skill-md
```

If you use Claude, the [Meeting.ai plugin for Claude](https://github.com/meeting-ai/memo-claude-plugin)
and the [Meeting.ai MCP server](https://github.com/meeting-ai/memo-mcp) connect Claude,
ChatGPT, and Codex to your meetings without installing anything locally.

## Links

- Website: https://meeting.ai
- Guide: https://meeting.ai/cli
- Privacy policy: https://meeting.ai/privacy
- Terms of service: https://meeting.ai/terms
- Support: support@meeting.ai

## License

Apache License 2.0. See [LICENSE](LICENSE). The Meeting.ai name, logo, and artwork are trademarks
of Meeting.ai and are not covered by the license; see [NOTICE](NOTICE).
