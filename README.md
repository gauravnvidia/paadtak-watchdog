# Paad Tak watchdog

A tiny checker that tells the owner by email when the Paad Tak YouTube live stream is not on air.

## What it checks
It asks YouTube, the way a normal desktop browser would, whether the Paad Tak channel has a stream marked LIVE right now (it reads the channel's "Live" tab data, and also tries https://www.youtube.com/@paadtak/live). YouTube shows GitHub's servers a "confirm you're not a bot" page on the watch and live pages, so the Live tab data is what works there.

## How often
Every 15 minutes, using a GitHub Actions schedule (GitHub may run it a few minutes late). If a check does not see the stream live, it looks again up to 3 times in total, about 4 minutes apart, so one short hiccup does not cause an alert.

## What happens
- **Live:** nothing happens. If an "off-air" issue was open, the check adds "Back on air at <time>." and closes it.
- **Off air (all 3 checks clearly saw a normal YouTube page with no live stream):** the check opens one GitHub issue called "Paad Tak stream is off air". GitHub emails the repository watcher. It will not open a second issue while one is open.
- **Could not tell (YouTube blocked the check, network error, consent page):** nothing happens either way.

The streamer on the Umbrel tries to repair itself first. If the issue stays open, check the Umbrel ("Paad Tak Stream" app).

## Keep-alive
GitHub switches off scheduled workflows in public repositories after 60 days without any repository activity. To prevent this, when the latest commit is older than 30 days the workflow commits a one-line update to `last-check.txt` as github-actions[bot]. Normally you will see one such commit about every 30 days.

## Test without alerts
Actions tab > "Check Paad Tak stream" > Run workflow > tick `dry_run`. It only logs and never opens or closes issues.

## How to stop it
Actions tab > "Check Paad Tak stream" > the "..." menu > Disable workflow. (Or run `gh workflow disable check.yml`.)

## Privacy
No secrets are used and nothing private belongs in this repository or its issues. It is public.
