# git-commit-push-script - Automating Staging, Committing and Pushing to GitHub with Gemini AI 👨🏻‍💻➡️

Staging, committing, and pushing code is a repetative manual process. Writing detailed commit messages and adding ticket numbers should be automated using AI. Save time using this shell script powered by Gemini AI.

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
| Writing Commit Messages Using AI | The script uses Gemini AI to generate commit messages using `git diff --cached`.                   |
| Git Commit                       | Committing staged files with the commit message using `git commit -S -m "<commit message>"`.       |
| Git Push                         | Pushing local commits to remote branch with `git push`.                                            |
| Git Push Retry (Pull & Push)     | If a push fails, the script will `git pull` from the remote branch and push again.                 |

## Requirements

| Name                                  | Description                                                                                                             | Link, Location, or Command                                 |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| Terminal or Shell                     | A terminal or shell for configuring and running the script.                                                             | [Download Terminal](https://www.apple.com/macos/terminal/) |
| `Git Bash` **\*Required for Windows** | Git Bash provides a Unix command line emulator for windows which can be used to run Git, shell commands, and much more. | [Download Git Bash](https://gitforwindows.org/)            |
| Google Gemini API Key                 | A Gemini API key is required to use Gemini AI to generate commit messages.                                              | [Get Gemini API Key](https://www.getgemini.ai/)            |
| Alias Command                         | The alias command to be used for the script: `cm`.                                                                      | Bash profile (`.zshrc` or `.bash_profile`)                 |

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

5. Add your Gemini API key to your bash or zsh configuration file (e.g., .zshrc or .bash_profile).

```shell
export GEMINI_API_KEY=<your-gemini-api-key>
```


6. Reload the terminal or shell configuration by running the following command:

```shell
source ~/.zshrc
# OR #
source ~/.bash_profile
```

## Usage

7. Test the script by running the following command from a Git repository directory with a Jira ticket branch (Example - `TEST-1234-Your-GitHub-Branch`).

```shell
cm
```

9. The script will stage, request the commit message from Gemini with the `git diff`, commit with the ticket prefix and message, and push the changes to the remote branch.

```shell
[TEST-1234 f94df31] TEST-1234 Fix: Remove unnecessary text from Gemini prompt
 1 file changed, 1 insertion(+), 1 deletion(-)
Branch 'TEST-1234' exists on remote. Pushing changes.
Enumerating objects: 5, done.
Counting objects: 100% (5/5), done.
Delta compression using up to 16 threads
Compressing objects: 100% (3/3), done.
Writing objects: 100% (3/3), 633 bytes | 633.00 KiB/s, done.
Total 3 (delta 2), reused 0 (delta 0), pack-reused 0 (from 0)
remote: Resolving deltas: 100% (2/2), completed with 2 local objects.
To https://github.com/wesleyscholl/git-commit-push-script.git
   ead30af..f94df31  TEST-1234 -> TEST-1234
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

If you want to use the -S flag, configure your Git configuration to use the GPG key for signing commits.
Use the guide here: <https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key>

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
