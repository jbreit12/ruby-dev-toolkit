# Ruby Dev Toolkit (RDT)

A CLI toolkit for speeding up common development tasks: Git management, log cleaning, README generation, CSV/JSON conversion, and project initialization.

For general help use command './bin/rdt help'

## Requirements
Ruby
Git (for cloning the repository and using Git Helper)

## Installation

```bash
git clone https://github.com/jbreit12/ruby-dev-toolkit.git
cd ruby-dev-toolkit
chmod +x bin/rdt
./bin/rdt git_helper status
```

## Git Helper

Convenient wrappers for `git` commands with safety checks.

* `status`, `fetch`, `list`, `init`
* `gitignore` (presets: Ruby, Node, Python, minimal)
* `firstcommit`, `remote --url=<git-url>`
* `branch --name=<branch>`, `checkout --name=<branch>`
* `newbranch --name=<branch>`
* `commitpush -m "<msg>"`, `pull`, `sync`
* `prune`, `upstream`

**Examples:**

```bash
./bin/rdt git_helper status
./bin/rdt git_helper newbranch --name=feature/test-feature
./bin/rdt git_helper help
```

## README Generator

Generates `README.md` with prompts or flags.

* `--name=`, `--desc=`, `--author=`, `--license=`, `--out=`

**Example:**

*WARNING: Using this command in the project root directory will replace this README file
```bash
./bin/rdt readme_gen --name=MyApp --desc="A CLI toolkit" --author="You"
```

## Project Initializer

Creates a new project skeleton with typical defaults and optional customization.

* **What it does:**

  * Creates a directory named `<ProjectName>` in the current working directory
  * Writes a starter `README.md` and `.gitignore`
  * Optionally writes a `LICENSE` file when `--license` is provided
  * Optionally creates additional folders passed via `--folders`
* **Notes:**

  * Quote the folders list if you include spaces after commas, e.g. `--folders="lib, bin, docs"`.
  * Run the command from the parent directory where you want the project folder created.

**Examples:**

```bash
./bin/rdt init_project MyApp
./bin/rdt init_project MyApp --folders="lib, bin, docs" --license=MIT
```

## CSV/JSON Converter

Converts CSV <-> JSON.

* `convert` for CSV -> JSON
* `reverse` for JSON -> CSV

**Example:**

*Sample csv and json files are in project root directory for testing*
```bash
./bin/rdt csv_json convert sample.csv converted.json
./bin/rdt csv_json reverse sample.json converted.csv
```

## Project Initializer

Creates a starter project structure with optional files.

* Prompts for project name, language, license, and extras
* Creates directories like `src/`, `tests/`, and starter files

**Example:**

```bash
./bin/rdt project_initializer
```

## Log Cleaner

Removes temp/log files.

* Default: `*.log`, `*.tmp`, `*.bak`, `tmp/**/*`, `log/**/*`
* `--patterns` to customize
* `--confirm` to skip prompt

**Example:**

```bash
./bin/rdt log_cleaner ./project --patterns=*.log,*.tmp --confirm
```

## Authors
John Breitbeil
Max Henson
Luke Barnett