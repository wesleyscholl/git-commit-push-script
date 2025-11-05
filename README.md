# git-commit-push-script - Automating Staging, Committing and Pushing to GitHub with Ollama and Mistral AI 👨🏻‍💻➡️

Staging, committing, and pushing code is a repetative manual process. Writing detailed commit messages and adding ticket numbers should be automated using AI. Save time using this shell script powered by Ollama and Mistral AI.

<img height="550" alt="cm" src="https://github.com/user-attachments/assets/7600a83d-1a96-4afe-9cf2-82e6604675a8" />

## Table of Contents

- [What this script automates](#what-this-script-automates)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [License](#license)

## What this Script Automates

| Name                             | Description                                                                                        |
| -------------------------------- | -------------------------------------------------------------------------------------------------- |
| Git Staging                      | Staging any modified files for commit using `git add -A`.                                          |
| Git Commit Message Ticket Title  | Copying the ticket number of the Jira ticket as the commit message prefix. Example: `[CRS-12345]`. |
| Writing Commit Messages Using AI | The script uses Ollama and Mistral AI to generate commit messages using `git diff --cached`.                   |
| Git Commit                       | Committing staged files with the commit message using `git commit -S -m "<commit message>"`.       |
| Entering SSH Passphrase          | If the SSH key is passphrase protected, the script will enter the passphrase automatically using an env variable (Ex. `GIT_SSH_PASSPHRASE`).                |
| Git Fetch & Pull                        | Pulling the latest changes from the remote branch with `git fetch origin <branch>` & `git pull`.                         |
| Git Push                         | Pushing local commits to remote branch with `git push`.                                            |
| Git Push Retry (Pull & Push)     | If a push fails, the script will `git pull` from the remote branch and push again.                 |

## Requirements

| Name                                  | Description                                                                                                             | Link, Location, or Command                                 |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| Terminal or Shell                     | A terminal or shell for configuring and running the script.                                                             | [Download Terminal](https://www.apple.com/macos/terminal/) |
| `Git Bash` **\*Required for Windows** | Git Bash provides a Unix command line emulator for windows which can be used to run Git, shell commands, and much more. | [Download Git Bash](https://gitforwindows.org/)            |
| Ollama                | Ollama must be installed and configured.                                              | [Get Ollama](https://ollama.com/)            |
| Mistral AI Model                     | The Mistral AI model must be downloaded and running locally. Example: `ollama pull mistral`                             | [Get Mistral](https://ollama.com/models/mistral)           |
| Alias Command **(optional)**                         | The alias command to be used for the script: `cm`.                                                                      | Bash profile (`.zshrc` or `.bash_profile`)                 |
| SSH Key **(optional)**               | If you want to use SSH for Git operations, you will need to configure your SSH key.                                      | [Git SSH Key Guide](https://docs.github.com/en/authentication/connecting-to-github-with-ssh) |
| GPG Key **(optional)**               | If you want to sign your commits, you will need to configure your GPG key in Git.                                        | [Git GPG Key Guide](https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key) |

## Installation

1. Clone the git-commit-push-script repository to your local computer.

```shell
git clone https://github.com/wesleyscholl/git-commit-push-script.git
```

2. Navigate to the git-commit-push-script directory with your terminal, shell, command line, or bash.

```shell
cd git-commit-push-script
```

3. Make the script executable by running the following command:

```shell
chmod +x git-commit-push-script.sh
```

4. Configure the alias command for the script in zshrc or bash_profile.

```shell
alias cm='bash /path/to/git-commit-push-script/git-commit-push-script.sh'
```

5. Install and start the Ollama server by running the following command:

```shell
homebrew install ollama
# AND/OR #
ollama serve
```
6. Download the Mistral AI model by running the following command:

```shell
ollama pull mistral
```

7. Reload the terminal or shell configuration by running the following command:

```shell
source ~/.zshrc
# OR #
source ~/.bash_profile
```

## Usage

1. Test the script by running the following command from a Git repository directory with a Jira ticket branch (Example - `TEST-1234-Your-GitHub-Branch`).

```shell
cm
# OR #
./git-commit-push-script.sh
```

2. The script will stage, request the commit message from Ollama and Mistral with the `git diff`, commit with the ticket prefix and message, and push the changes to the remote branch.

```shell
argo-gr-cr-test git:(WXYZ-1234) cm
Removed sync options, enabled cron workflow
spawn git commit -S -m WXYZ-1234 Removed sync options, enabled cron workflow
Enter passphrase for "/Users/wscholl/.ssh/id_ed25519": 
[WXYZ-1234 94f179e] WXYZ-1234 Removed sync options, enabled cron workflow
 1 file changed, 7 deletions(-)
Branch 'WXYZ-1234' exists on remote.
Pulling latest changes from remote branch...
From https://github.com/myOrg/argo-gr-cr-test
 * branch            WXYZ-1234  -> FETCH_HEAD
Already up to date.
Pushing changes to remote WXYZ-1234 branch...
Enumerating objects: 9, done.
Counting objects: 100% (9/9), done.
Delta compression using up to 8 threads
Compressing objects: 100% (5/5), done.
Writing objects: 100% (5/5), 671 bytes | 671.00 KiB/s, done.
Total 5 (delta 4), reused 0 (delta 0), pack-reused 0 (from 0)
remote: Resolving deltas: 100% (4/4), completed with 4 local objects.
To https://github.com/myOrg/argo-gr-cr-test.git
   f546666..94f179e  WXYZ-1234 -> WXYZ-1234
```

## Troubleshooting

You may encounter an error from the following command because of the `-S` flag:

```shell
git commit -S -m "<commit message>"
```

To resolve this error, remove the `-S` from the command in the `git-commit-push-script.sh` file:

```shell
git commit -m "<commit message>"
```

Or if you want to use the -S flag, configure your Git configuration to use the GPG key for signing commits.
Use the guide here: <https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key>

## Contributing

Contributions are welcome! If you have suggestions for improvements or new features, please open an issue or submit a pull request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
