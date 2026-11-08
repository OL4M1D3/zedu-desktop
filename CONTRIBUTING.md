# Contributing

Welcome! This guide covers how work gets from a ticket into Zedu Desktop: branches, pull requests, CI, review, and scheduled release promotion.

---

## The workflow at a glance

There is one repository. All contribution and release work happens in `zeduchat/zedu-desktop`:

| Branch | Purpose | Who merges |
|---|---|---|
| `staging` | Integration branch. All reviewed feature and fix PRs target this branch. | Repository reviewers |
| `main` | Release branch. It contains the latest approved staging promotion. | Manager agent, every six hours |

The full cycle for any piece of work:

1. Pick up an **approved** ticket in ClickUp or Linear. No ticket, no work.
2. Sync your local checkout from `zeduchat/zedu-desktop` and base the branch on `staging`.
3. Create a ticket branch, do the work, and test it against the live backend.
4. Open **one PR** from your ticket branch into `zeduchat/zedu-desktop:staging`.
5. CI runs on every push. Fix all required checks before requesting review.
6. Repository reviewers review and merge approved PRs into `staging`.
7. A manager agent checks the green `staging` branch every six hours and promotes it to `main` on `zeduchat/zedu-desktop`.
8. Verify the promoted release and close the ticket.

---

## One-time setup (per team)

1. Clone **`zeduchat/zedu-desktop`** and check out `staging`.
2. In the repository, go to **Actions** and ensure workflows are enabled.
3. Create a short-lived ticket branch from `staging` and open its PR back into `staging`.
4. CI points builds at the live backend (see [How your PR gets built](#how-your-pr-gets-built)).
5. Each contributor clones the repository:

```bash
git clone https://github.com/<your-team>/zedu-desktop.git
cd zedu-desktop
cp .env.example .env
flutter pub get
flutter run
```

See the README for configuration and platform setup. Never commit `.env`.

Set `API_BASE_URL` in your `.env` (or pass `--dart-define=API_BASE_URL=...`) to the live backend, `https://api.zedu.chat/api/v1/`, or to a test backend while developing. The scheduled promotion uses the tested `staging` tree.

---

## Working on a ticket

```bash
# 1. Sync the repository, then base your branch on staging:
git checkout staging
git pull origin staging

# 2. Create your ticket branch
git checkout -b feat/123-dark-mode-toggle

# 3. Do work, commit
git add <files>
git commit -m "feat: add toggle component"

# 4. Push the branch, then open a PR into zeduchat:staging
git push -u origin feat/123-dark-mode-toggle
```

---

## Branch naming

Format: `type/<ticket-id>-short-description`

```
feat/123-dark-mode-toggle
fix/245-crash-on-empty-project
chore/190-bump-flutter
refactor/301-extract-file-loader
docs/110-setup-instructions
```

**Types:**

| Type       | When to use it                                              |
|------------|-------------------------------------------------------------|
| `feat`     | New functionality the user can see                          |
| `fix`      | Bug fix                                                     |
| `refactor` | Restructuring code without changing behaviour               |
| `chore`    | Dependency bumps, config changes, build tweaks              |
| `docs`     | Documentation only                                          |
| `test`     | Adding or fixing tests, no production code change           |
| `perf`     | Performance improvement                                     |
| `security` | Security hardening                                          |

**Rules:**

- Always include the ticket ID from ClickUp or Linear.
- Lowercase, hyphen-separated. No spaces, no underscores, no camelCase.
- 3–5 words after the ticket ID. The PR title carries the full description.
- No personal names (`remi/dark-mode` is an anti-pattern; git already knows who you are).
- One ticket per branch. If you find another problem, open another ticket.
- The **Branch name** check enforces the format on every PR. *(Switched off for now: a consolidated team PR may use any branch format, but should still include the main ticket ID.)*

**One person per PR. Team PRs are allowed for now.** A team can consolidate several members' work into one PR from its fork. The **Single author**, **Branch name** and **Size** checks are switched off for now: they still report, as passed, and can be switched back on. For a consolidated PR, put the main ticket in the branch and in the title and list the other tickets in the description. The earlier rule is kept for when it returns: *each member opens their own PR from their own ticket branch, with no team branches and no combined PRs, so nobody's work is held up by someone else's. The **Single author** check fails a PR with commits from more than one person.* If you commit from several emails, add all of them to your GitHub account (**Settings → Emails**), or they count as different authors. Credit a collaborator with a `Co-authored-by:` trailer instead.

**Dependent tickets:** if ticket B needs ticket A, open B's PR after A merges, then update B from `staging`.

**Testing combinations:** merge ticket branches into a private local branch to test them together if you like. Never open a PR from that branch.

---

## PR titles

Format: `type: short description in present tense, lowercase`

```
feat: add dark mode toggle to settings
fix: prevent crash when opening empty project
refactor: extract file loader into its own module
chore: bump flutter to 3.41.5
docs: explain how to run tests on windows
```

**Rules:**

- Same `type` prefix as your branch. If the branch is `feat/...`, the PR is `feat: ...`.
- **Present tense, imperative mood.** "add", not "added" or "adds". It reads as a command: *this PR will add dark mode*.
- Lowercase after the colon.
- No period at the end.
- Aim for 50 characters, hard cap at 72.

Your PR title becomes the commit message when it is merged into `staging`. This convention is called [Conventional Commits](https://www.conventionalcommits.org/).

---

## Testing

Run the same checks CI runs:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos --fatal-warnings
flutter test
```

Build and run on at least one desktop target (`flutter build macos|windows|linux`).

**What tests you need:**

- **Non-UI code** (business logic, state management, services/API layer, utilities): unit tests for what the ticket changed.
- **UI code:** a widget test for the changed widget. Integration tests only for new or changed *critical* flows (auth, payments, anything data-destructive).
- **Only what your ticket touched.** Not retroactive coverage of pre-existing untested code in the same file. If you notice a real gap, file a separate ticket.

For UI changes, also check the relevant window sizes, keyboard navigation, accessibility labels, and loading, empty and error states.

Then self-review:

```bash
git status
git diff
```

Check that:

- only intended files changed;
- debug code is gone;
- no secrets are committed;
- tests cover what this ticket changed.

---

## Protected files

These are owned by the reviewers. The **Protected files** check fails any PR that changes them, unless a reviewer has agreed it first and added the `config-change-approved` label:

- `.github/` (workflows and templates);
- `AGENTS.md` and `CONTRIBUTING.md`;
- `analysis_options.yaml`;
- `scripts/` (the CI scan scripts);
- secret-like files anywhere: `.env*` (except `.env.example`), keystores, certificates and keys (`.p12`, `.pfx`, `.pem`, `.p8`), provisioning profiles, credential or service-account JSON.

Dependency changes (`pubspec.yaml`, `pubspec.lock`) are fine when the ticket needs them. **Moving or restructuring files needs its own approved ticket**; never mix it into feature work.

---

## How your PR gets built

CI builds every PR targeting `staging`. Every build talks to the **live backend**, `https://api.zedu.chat`, unless the PR body has a `Backend URL:` line. Reviewers use test accounts.

- **Needs backend work that isn't on staging yet?** Add a line to the PR description, under **Backend**: `Backend URL: https://api.<team>.groups.zedu.chat`. Remove it once the backend change reaches staging.
- Nothing secret goes into a build: `.env` ships inside the app.

- **Builds run while your PR is open.** Pushes to a ticket branch without an open PR skip the build, and a PR that only changes Markdown needs no build.
- **First build:** opening the PR may not trigger one. Go to **Actions → PR build → Run workflow** on the branch, or push a commit. After that, every push builds automatically.
- Reviewers use the PR checks and artifacts for the latest commit.

Format, analyze, tests, security scans, protected-file checks, PR title and PR template checks run on the PR itself. Required checks must pass before merge.

---

## Opening the PR

Open the PR from your **ticket branch** into **`zeduchat/zedu-desktop:staging`**. Do not target `main`; the manager agent promotes staging on the six-hour schedule.

Fill out the PR template (`.github/PULL_REQUEST_TEMPLATE.md`). It loads automatically when you open a PR. The short version:

- **Ticket**: link to the ClickUp or Linear ticket.
- **What changed / Why**: the outcome, and the problem it solves.
- **How to test / What to expect**: steps a reviewer can follow, and the result they should see.
- **Reviewer**: request review from the repository maintainers.
- **Test evidence**: the backend you tested against, and the tests you added or updated. The build link is posted for you.
- **Screenshots / recording**: for any visible or interactive change.

Skip sections that don't apply, but write "N/A because…" so your reviewer can see you thought about it.

---

## Keeping your branch up to date

While you're working, `staging` will move forward as other PRs land. Pull those changes into your branch periodically, especially before opening your PR.

**We use `merge` for this, not `rebase`. Sync `staging` first, then:

```bash
git checkout feat/123-dark-mode-toggle
git fetch origin
git merge origin/staging

# Resolve any conflicts, commit them, push
git push
```

### Why merge and not rebase?

Both are valid ways to stay in sync. Here's the honest tradeoff:

- **Merge** is safer and conceptually simpler. You never rewrite history, so if you get something wrong, nothing is lost. The downside is that your branch ends up with merge commits in its history.
- **Rebase** produces a cleaner history but requires `git push --force-with-lease`, and getting it wrong on a shared branch can cause people to lose work.

Because reviewed PRs land in `staging`, keep the branch history merge-based and reviewable.

---

## How PRs land

- Reviewers approve PRs after the required checks pass.
- All required checks must pass, including the build when code changes are present.
- All review threads must be resolved. Don't resolve a thread without actually addressing it.
- Contributors don't merge their own PRs.
- Reviewers merge approved PRs into `staging`.

After merge, a manager agent checks the green `staging` branch every six hours and promotes `staging` → `main` on `zeduchat/zedu-desktop`. The ticket goes **MERGED → VERIFIED → CLOSED** once the promoted release is verified.

---

## Security and secrets

Never commit:

- API keys or tokens;
- passwords or private keys;
- signing certificates or provisioning profiles;
- cloud or database credentials;
- `.env` files with real values;
- user data.

`.env` is bundled into the app as an asset, so anything in it is readable by anyone who has the app. Real secrets belong on the backend.

If you expose a secret, deleting it in the next commit is not enough. Tell a reviewer immediately so it can be rotated.

---

## A few extra tips

- **Pull before you start work each day.** It saves you from a painful merge later.
- **Push often.** Pushed code is backed up, and once your PR is open every push builds.
- **Open PRs in draft mode** if you want early feedback before the work is done.
- **Keep PRs small.** A PR with 50 lines of change gets reviewed in 10 minutes. A PR with 500 lines gets a rubber-stamp review or sits for days.
- **If you're stuck, ask.** Use your team channel first, then the project channel. For a blocker, include:
  - the ticket number;
  - what you tried to do;
  - what happened, with the error or build output;
  - what you already tried;
  - what help you need.

### Working Notes & Handoffs

Per-ticket hand-offs, scratch status notes, decisions, and runbooks belong on the ticket and the pull request discussion, not committed into the product repository. Do not commit temporary directories or scratch notes (e.g. `handoff/`) into the codebase.

---

## Quick reference

```bash
# Start new work from staging
git checkout staging
git pull origin staging
git checkout -b feat/123-your-feature

# Save progress (once your PR is open, every push builds in CI)
git add <files>
git commit -m "feat: message"
git push

# Update from staging while working
git fetch origin
git merge origin/staging

# Ready for review
# → open a PR from your branch into zeduchat/zedu-desktop:staging and wait for review
```
