# git-commit-push-script - Automating Staging, Committing and Pushing to GitHub 👨🏻‍💻➡️

Manually typing staging, commit messages, and push commands is repetative. Especially copying the ticket number into the commit message. Save time using this shell script.

## Table of Contents
* [What this script automates](#what-this-script-automates)
* [User input required](#user-input-required)
* [Requirements](#requirements)
* [Installation](#installation)
* [Usage](#usage)
* [License](#license)
  
## What this script automates:

| Name | Description |
| --- | --- | 
| Git Staging | Staging any modified files for commit using `git add -A`. |  
| Git Commit Message | Copying the ticket number of the Jira ticket as the commit message prefix. Example: `[CRS-12345]`. |
| Git Commit | Committing staged files with the commit message using `git commit -S -m "<commit message>"`. |
| Git Push | Pushing local commits to remote branch with `git push`. |

## User input required:

| Name | Description |
| --- | --- |
| Alias Command | The alias command to be used for the script: `cm`. |
| Commit Message | The commit message with description of the changes made. |

## Requirements

| Name | Description | Link, Location, or Command |
| --- | --- | --- |
| Terminal or Shell | A terminal or shell for configuring and running the script. | [Download Terminal](https://www.apple.com/macos/terminal/) |
| `Git Bash` ***Required for Windows** | Git Bash provides a UNIX command line emulator for windows which can be used to run Git, shell commands, and much more. | [Download Git Bash](https://gitforwindows.org/) |


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

5. Reload the terminal or shell configuration by running the following command:
```shell
source ~/.zshrc
# OR #
source ~/.bash_profile
```

## Usage

6. Test the script by running the following command from a Git repository directory with a Jira ticket branch.

```shell
cm
```

7. Enter your commit message when prompted.
```shell
Enter commit message: 
```

8. The script will stage, commit with the ticket prefix, and push the changes to the remote branch.
```shell
Enter commit message: Test message
Commit message: CRS-12345 - Test message
[CRS-12345-Git-Script-Test be6fe58] CRS-12345 - Test message
 1 file changed, 2 insertions(+), 1 deletion(-)
Enumerating objects: 5, done.
Counting objects: 100% (5/5), done.
Delta compression using up to 16 threads
Compressing objects: 100% (3/3), done.
Writing objects: 100% (3/3), 643 bytes | 643.00 KiB/s, done.
Total 3 (delta 0), reused 0 (delta 0), pack-reused 0
To https://github.com/wesleyscholl/git-commit-push-script.git
   c76b73c..be6fe58  CRS-12345-Git-Script-Test -> CRS-12345-Git-Script-Test
```

9. Enjoy the script!

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

