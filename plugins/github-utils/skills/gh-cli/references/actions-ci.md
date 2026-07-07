# GitHub Actions / CI — Full Reference

## Contents
1. [Monitoring runs](#monitoring-runs)
2. [Triggering workflows](#triggering-workflows)
3. [Artifact downloads](#artifact-downloads)
4. [Secrets and variables](#secrets-and-variables)
5. [Scheduled and manual dispatch](#scheduled-and-manual-dispatch)

---

## Monitoring Runs

```bash
# List recent runs
gh run list --limit 20
gh run list --workflow build.yml --branch main --limit 5
gh run list --status failure --limit 10

# Detailed view of a run (jobs + steps with status)
gh run view <run-id>

# Stream live logs
gh run watch <run-id>

# Download complete logs
gh run view <run-id> --log
gh run view <run-id> --log-failed          # only failed steps

# Get the latest run ID for the current branch
gh run list --branch "$(git branch --show-current)" --json databaseId \
  --jq '.[0].databaseId'
```

---

## Triggering Workflows

```bash
# Manually dispatch a workflow (workflow_dispatch trigger required)
gh workflow run deploy.yml
gh workflow run deploy.yml --ref feature/my-branch
gh workflow run deploy.yml -f environment=staging -f version=1.2.3

# List available workflows
gh workflow list

# Enable / disable
gh workflow enable deploy.yml
gh workflow disable scheduled-cleanup.yml
```

---

## Re-running and Cancelling

```bash
# Rerun an entire run
gh run rerun <run-id>

# Rerun only failed jobs (avoids re-running passed jobs)
gh run rerun --failed <run-id>

# Cancel an in-progress run
gh run cancel <run-id>

# Delete a run (removes logs from GitHub)
gh run delete <run-id>
```

---

## Artifact Downloads

```bash
# List artifacts for a run
gh run view <run-id> --json jobs --jq '.jobs[].name'
# (Artifacts are separate from job outputs — use api or download command)

# Download all artifacts from a run
gh run download <run-id>

# Download a specific artifact by name
gh run download <run-id> --name coverage-report --dir ./coverage

# Download from a specific repo
gh run download <run-id> -R owner/repo --name build-output
```

---

## Secrets and Variables

```bash
# Repository secrets
gh secret list
gh secret set MY_SECRET                          # prompts for value
gh secret set MY_SECRET --body "value"
gh secret set MY_SECRET < secret.txt             # read from file
gh secret delete MY_SECRET

# Environment secrets (for deployment environments)
gh secret set MY_SECRET --env production

# Organization secrets
gh secret set ORG_SECRET --org myorg --visibility all

# Variables (not encrypted — for non-sensitive config)
gh variable list
gh variable set APP_VERSION --body "1.2.3"
gh variable delete APP_VERSION
```

---

## Scheduled and Manual Dispatch

To trigger a `workflow_dispatch` workflow with inputs from the API:

```bash
gh api -X POST repos/{owner}/{repo}/actions/workflows/deploy.yml/dispatches \
  -F ref=main \
  -f inputs[environment]=production \
  -f inputs[version]=1.2.3
```

To list scheduled workflows that would run next:

```bash
gh api repos/{owner}/{repo}/actions/workflows \
  --jq '.workflows[] | select(.state=="active") | .name'
```
