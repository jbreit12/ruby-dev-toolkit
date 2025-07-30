# RDT (Ruby Dev Toolkit)

**RDT** is a command-line utility designed to automate common development tasks for Ruby programmers and small teams. The toolkit helps you quickly scaffold a new project directory with default files and folders using customizable options.

## 🔧 Features

- `init_project` command to generate a new project structure
- Creates a project folder with:
  - `README.md`
  - `.gitignore` (with Ruby-specific ignores)
  - Optional `LICENSE` file
  - Customizable subfolder layout
- Supports CLI flags:
  - `--no-license`: omit the license file
  - `--folders=`: customize folder names (comma-separated)

---

## 🚀 Getting Started

### Prerequisites

- Ruby (version 2.7+ recommended)
- Git (for cloning the repository)

### Authors
John Breitbeil
Luke Barnett
Max Henson

### Clone the Repository

```bash
git clone git@github.com:jbreit12/rdt.git
cd rdt
