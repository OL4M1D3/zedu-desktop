# Zedu Desktop release process

This repository uses a two-branch flow in `zeduchat/zedu-desktop`.

1. Contributors open pull requests from ticket branches into `staging`.
2. CI and repository review must pass before a pull request is merged into `staging`.
3. A manager agent checks the green `staging` branch every six hours.
4. The manager agent promotes the tested `staging` state to `main` on `zeduchat/zedu-desktop`.
5. The promoted build is smoke-tested against the release checklist.

Contributors and feature agents do not push directly to `main`. Release promotion is performed only by the manager agent after the required checks are green. The release repository is `zeduchat/zedu-desktop`; no separate review fork is part of this process.

## Promotion checklist

- Confirm the `staging` branch is green.
- Confirm required reviews and protected-file approvals are complete.
- Promote `staging` to `main` with the repository's approved merge method.
- Record the promotion commit and CI results in the release pull request.
- Smoke-test the resulting desktop build.
