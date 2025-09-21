# 🔍 Permission Drift Detector

A GitHub Action that detects **permission drift** in GitHub Actions workflow files. It compares workflow permissions between commits or pull requests and reports upgrades (for example: `read` → `write`) so reviewers and owners can catch unintended privilege escalations.

---

## ✨ Features

* 🚨 Detects permission upgrades in `.github/workflows/*.yml` (e.g., `read` → `write`).
* 🧾 Produces a Markdown report summarizing the permission drift.
* 💬 Posts a **PR comment** for pull requests (when drift is detected).
* 🐞 Creates a **GitHub issue** and assigns the repo owner for pushes/commits that introduce drift.
* 📌 Always adds a `GitHub Actions` job summary entry with the full report.

---

## ⚠️ Important notes

* To post comments or create issues the runner must have appropriate token permissions. Set the workflow `permissions` block (example below).
* For pull requests from forks the default `GITHUB_TOKEN` may be restricted and cannot post comments — a repo PAT may be required for those cases.

---

## 🚀 Quick start

Here’s an example workflow using the **Permission Drift Detector**:

```yaml
name: Permission Drift Detector

on:
  pull_request:
    paths:
      - ".github/workflows/*.yml"

jobs:
  detect-drift:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      issues: write
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run Permission Drift Detector
        uses: Meriem453/Permission-Drift-Detector@v1.0.0-beta
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}

```

Replace `Meriem453/Permission-Drift-Detector` with the path to your published action release (e.g., `Meriem453/Permission-Drift-Detector@v1`).

---

## ⚙️ Inputs

| Name           | Required | Description                                                                                                                                                             |
| -------------- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `github_token` | ✅ Yes    | GitHub token used to post PR comments or create issues. Pass `${{ github.token }}` in normal repo runs; for forked PRs you may need a PAT stored in repository secrets. |

---

## 📤 Outputs

This action writes a `permissions-report.md` to the job summary (visible in the Actions run summary) and posts the report as a PR comment or Issue when drift is detected. It does **not** create persistent files in the repository.

---

## 🔍 How it works

1. On a **push** event the action compares the `before` and `after` commit SHAs and diff the workflow files.
2. On a **pull\_request** event the action compares the PR branch against the target branch (`pull_request.base`).
3. It parses the `permissions` map inside the workflow YAML using `yq` and flags keys upgraded to `write` (or newly added as `write`).
4. If a drift is found it generates a small Markdown report, appends it to the job summary, and then:

   * Posts the report as a **comment** on the PR (when run in PR context).
   * Creates an **Issue** assigned to the repository owner (when run on pushes/commits).

---

## 🧩 Example report

```
### 🛡 Permission Drift Report

#### File: `.github/workflows/deploy.yml`
- **contents**: null → **write**

⚠️ Permission drift detected!
```

---

## 🛠️ Development

Build and run the Docker image locally:

```bash
git clone https://github.com/your-username/permission-drift-detector.git
cd permission-drift-detector
docker build -t permission-drift-detector .
# run inside container if needed
```

When publishing the action:

1. Tag a release (e.g. `v1.0.0`) and push a Git tag. Use that tag as the `uses:` reference.
2. In your `action.yml` keep inputs simple — users of the action will pass `${{ github.token }}` from their workflows.

---

## 🔐 Security & permissions

* The action requires `contents: read` to fetch file contents and `pull-requests: write` / `issues: write` to post comments or open issues.
* For PRs from forks, the default `GITHUB_TOKEN` may be restricted; document that your users may need to provide a PAT stored in repository secrets if they want comments for forked PRs.

---

## 🤝 Contributing

Contributions are welcome — open an issue or PR. If you add features, please include tests and update the README.

---

## 📜 License

This project is released under the **MIT License**. See [LICENSE](./LICENSE) for details.

---

*Maintainer: Meriem Zemane*
