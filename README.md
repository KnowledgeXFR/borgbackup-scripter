# BorgBackup Scripter

A shell script that eases the process of backing up your data via BorgBackup. A single installation can be used to support multiple repositories, both local and remote.

More information can be found at [KnowledgeXFR](https://www.knowledge-xfr.com/article/5mkhh9ok).

> **Note**
> This script supports the ```create``` and ```prune``` commands. All other BorgBackup commands (like ```init```) must be performed manually. Please see the official [Borg Documentation](https://borgbackup.readthedocs.io/en/stable/) for more information on these other BorgBackup commands.

## Benefits

BorgBackup Scripter supports configurations for multiple repositories. Each repository supports:

- Local and remote repositories
- Settings via a configuration file (no need to learn and type out arguments), including:
  - Caffeinate command (macOS)
  - Custom archive date format
  - Compression algorithm
  - Prune settings (optional)
- Bash scripts ran before and after the archive creation process (optional)
- An exclusion list (optional)
- Email (HTML and/or plaintext) with details of the run sent after completion (optional)

## Prerequisites

The ```sendmail``` command must be installed and operational on your system if you intend to use the email functionality. To determine if ```sendmail``` is available, run:

```
which sendmail
```

If the response is the path of ```sendmail```'s location (i.e., ```/usr/sbin/sendmail```) then ```sendmail``` has been found on your system. If no response is provided, then you will need to install ```sendmail``` on your respective system.

## Installation

Installation is as simple as cloning this repository:

```shell
git clone https://github.com/KnowledgeXFR/borgbackup-scripter
```

## Usage

> **Note**
> You will need to initialize the repository first manually via BorgBackup. Please see the official [Borg Documentation](https://borgbackup.readthedocs.io/en/stable/) for more information.

### Help

For a list of supported command line arguments, please run:

```shell
./borgbackup_scripter.sh --help
```

### Repository Setup

> **Note**
> The ```--setup``` argument does not overwrite existing files. If you wish to re-setup a repository configuration from scratch, please first delete the repository's directory under the "repo" directory.
> 
> Before you can backup a repository, you first must setup its configuration details. To do so, run the following command, replacing ```[REPO NAME]``` with your preferred repository's name:

```shell
./borgbackup_scripter.sh --repo=[REPO NAME] --setup
```

This will:

1. Create a directory named "repo" in the same directory where **borgbackup_scripter.sh** is located (if it doesn't already exist)
2. Create a directory with the repository name provided inside of the "repo" directory, and populate it with the following files:
    - excluded.txt
    - post.sh
    - pre.sh
    - repo.conf

Now, edit the files in the new directory to meet your needs.

#### File Notes

##### excluded.txt

- Supports one exclude pattern per line
- See [Miscellaneous Help > borg help patterns](https://borgbackup.readthedocs.io/en/stable/usage/help.html#borg-patterns) for more details

##### post.sh

- Shell script that runs before the ```borg create``` command

##### pre.sh

- Shell script that runs after the ```borg create``` command

##### repo.conf

- There are inline comments throughout the file to guide you as you populate it
- It is recommended to set this file's permissions to something restrictive as it does contain the repository's passphrase

### Testing a Repository Setup

To test a repository's setup, run the following command, replacing [REPO NAME] with your repository's name:

```shell
./borgbackup_scripter.sh --repo=[REPO NAME] --test
```

This will:
- Parse the ```repo.conf``` file, and validate it for errors
- If it passes, it will output the ```borg create``` command under the **Creating Archive** report section for review purposes
- If email has been setup in the configuration file, it will send the report to the provided email address. Otherwise, the report will be displayed in the terminal.

This won't:
- Run the ```borg create``` command
- Run the post.sh script
- Run the pre.sh script
- Run the ```borg prune``` command

### Production Run

Run the following command, replacing [REPO NAME] with your repository's name:

```shell
./borgbackup_scripter.sh --repo=[REPO NAME]
```

This will:

- Parse the ```repo.conf``` file, and validate it for errors
- Run the ```borg create``` command
- Run the post.sh script
- Run the pre.sh script
- Run the ```borg prune``` command
- If email has been setup in the configuration file, it will send the report to the provided email address. Otherwise, the report will be displayed in the terminal.