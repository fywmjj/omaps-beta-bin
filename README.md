
# Organic Maps Beta - Android Beta APK
***Where's Organic Maps Beta Package?***

This is an automation project designed to streamline the process of downloading beta APKs directly from Organic Maps' GitHub Actions.

Many users—especially those unable to access Firebase App Distribution or who find it cumbersome—desire a stable, direct download link. This project fulfills that need using GitHub Actions.

## ✨ Features
- **Auto-Sync:** Automatically checks the [Organic Maps beta build workflow](https://github.com/organicmaps/organicmaps/actions/workflows/android-beta.yaml) every 5 minutes.
- **Fetch Latest Version:** Identifies and targets the most recent successful build.
- **Extract Download Links:** Parses build logs to retrieve temporary Firebase APK download URLs.
- **Permanent Archiving:** Downloads the APK and uploads it to this project's **[Releases](https://github.com/fywmjj/omaps-beta-bin/releases)** page for permanent storage.
- **Stay Up-to-Date:** New APKs are tagged as "Latest," ensuring you can always easily find the newest version.

## 📥 How to Use
No setup required! Simply visit the **[Releases page](https://github.com/fywmjj/omaps-beta-bin/releases)** to browse and download all archived beta APKs.

[![Sync Beta APK](https://github.com/fywmjj/omaps-beta-bin/actions/workflows/sync.yml/badge.svg)](https://github.com/fywmjj/omaps-beta-bin/actions/workflows/sync.yml)

## 🔧 Deployment Guide (For Developers)
If you wish to set up your own instance of this repository, follow these steps:

1.  **Fork this repository.**
2.  **Generate a Personal Access Token (PAT):**
    - Go to your GitHub [Developer Settings](https://github.com/settings/tokens?type=beta).
    - Generate a new **classic** PAT.
    - Grant `repo` and `workflow` scopes. The `repo` scope is needed to create Releases, while `workflow` is required to read Action details from the Organic Maps project.
    - **Make sure to copy and save this token immediately**, as you won't be able to see it again after refreshing the page.
3.  **Set up Secrets in your repository:**
    - Navigate to your forked repository and go to `Settings` > `Secrets and variables` > `Actions`.
    - Click `New repository secret`.
    - Create a secret named `GH_PAT` and paste your Personal Access Token as the value.
4.  **Enable Actions:**
    - Go to the `Actions` tab. If Actions are disabled, click the button to enable them.
    - The workflow will run automatically based on the schedule (every 5 minutes), or you can trigger it manually.

---

*This project is not officially affiliated with Organic Maps; it serves solely as a convenience tool for the community.*
