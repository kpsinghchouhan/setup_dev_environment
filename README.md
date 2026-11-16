# Development Environment Setup

An Ansible playbook that configures Ubuntu and macOS machines for software development.
It installs and configures developer tools and desktop apps using roles from the
[`kpsinghchouhan.linux_developer_roles`](https://github.com/kpsinghchouhan/linux_developer_roles) collection.

## Table of contents

- [Supported platforms](#supported-platforms)
- [How it works](#how-it-works)
- [Prerequisites](#prerequisites)
- [Quick start](#quick-start)
- [Usage examples](#usage-examples)
- [What gets installed](#what-gets-installed)
- [Configuration](#configuration)
- [Project layout](#project-layout)
- [Development and CI](#development-and-ci)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Supported platforms

| Platform | Notes                                             |
| -------- | ------------------------------------------------- |
| Ubuntu   | Managed as `linux_hosts`                          |
| macOS    | Intel and Apple Silicon, managed as `macos_hosts` |

The playbook stops with an error on any other operating system.

## How it works

```text
macOS host (bootstrap_macos.sh: Homebrew, VirtualBox, Vagrant)
  └── Ubuntu Vagrant VM, the Ansible controller (bootstrap_linux.sh: uv, Python, ansible-dev-tools)
        └── ansible-playbook site.yml
              ├── linux_hosts: the VM itself   (ansible_connection: local)
              └── macos_hosts: the Mac host    (ansible_connection: ssh)
```

1. On the Mac, `bootstrap_macos.sh` installs Homebrew, VirtualBox and Vagrant so you can run a Linux VM.
2. Inside the Ubuntu VM, `bootstrap_linux.sh` installs Ansible (through `ansible-dev-tools`) into a virtual environment.
3. From the VM, `site.yml` configures the VM itself and the Mac over SSH.

## Prerequisites

- **Ansible controller (Ubuntu VM):** a regular (non-root) user with `sudo` access and internet access.
- **macOS target:**
  - Remote Login is turned on (System Settings → General → Sharing → Remote Login).
  - The controller's SSH public key is in `~/.ssh/authorized_keys` on the Mac.
  - The SSH user can run `sudo`.

## Quick start

1. Clone the repository on the controller:

   ```bash
   git clone https://github.com/kpsinghchouhan/setup_dev_environment.git
   cd setup_dev_environment
   ```

2. On the Mac only, install Homebrew, VirtualBox and Vagrant:

   ```bash
   ./bootstrap_macos.sh
   ```

3. On the controller, install Ansible into `~/.ansible-dev-tools/.venv` and activate it:

   ```bash
   source ./bootstrap_linux.sh
   ```

   In a new shell, re-activate the environment with `source ~/.ansible-dev-tools/.venv/bin/activate`.

4. Install the required collections:

   ```bash
   ansible-galaxy collection install -r collections/requirements.yml
   ```

5. Edit the inventory for your machines (see [Configuration](#configuration)):
   - Hostnames and IP addresses go in `inventory/hosts.yml`.
   - Connection users go in `inventory/group_vars/linux_hosts.yml` and `inventory/group_vars/macos_hosts.yml`.
   - Your Git identity (`git_user_name` and `git_user_email`) goes in `inventory/group_vars/all.yml`.

6. Run the playbook:

   ```bash
   ansible-playbook site.yml --ask-become-pass
   ```

## Usage examples

```bash
# Configure only one group of hosts
ansible-playbook site.yml -K --limit linux_hosts
ansible-playbook site.yml -K --limit macos_hosts

# Install only selected tools
ansible-playbook site.yml -K --tags git,starship

# Dry run that shows what would change
ansible-playbook site.yml -K --check --diff

# Run through ansible-navigator; logs and artifacts are written to .logs/
ansible-navigator run site.yml --mode stdout
```

The OS check and the apt/Homebrew update tasks are tagged `always`, so they also run when you use `--tags`.

## What gets installed

Each role runs only when its toggle variable is `true`. In `site.yml` every toggle defaults to `false`, so you
turn a tool on by setting its variable in the inventory.

| Tool                 | Tag                    | Toggle variable                | Platforms      | Enabled in        |
| -------------------- | ---------------------- | ------------------------------ | -------------- | ----------------- |
| Git                  | `git`                  | `install_git`                  | Ubuntu, macOS  | `all.yml`         |
| GitHub CLI           | `gh`                   | `install_gh`                   | Ubuntu, macOS  | `all.yml`         |
| Starship prompt      | `starship`             | `install_starship`             | Ubuntu, macOS  | `all.yml`         |
| Claude               | `claude`               | `install_claude`               | Ubuntu, macOS  | `all.yml`         |
| Nerd Fonts           | `nerd_font`            | `install_nerd_font`            | macOS          | `macos_hosts.yml` |
| Adobe Acrobat Reader | `adobe_acrobat_reader` | `install_adobe_acrobat_reader` | macOS          | `macos_hosts.yml` |
| Ghostty              | `ghostty`              | `install_ghostty`              | macOS          | `macos_hosts.yml` |
| Google Chrome        | `google_chrome`        | `install_google_chrome`        | macOS          | `macos_hosts.yml` |
| Google Drive         | `google_drive`         | `install_google_drive`         | macOS          | `macos_hosts.yml` |
| Visual Studio Code   | `visual_studio_code`   | `install_visual_studio_code`   | macOS          | `macos_hosts.yml` |
| Zed                  | `zed`                  | `install_zed`                  | macOS          | `macos_hosts.yml` |
| Notion               | `notion`               | `install_notion`               | macOS          | `macos_hosts.yml` |
| VirtualBox           | `virtualbox`           | `install_virtualbox`           | macOS          | `macos_hosts.yml` |
| HashiCorp Vagrant    | `hashicorp_vagrant`    | `install_hashicorp_vagrant`    | macOS          | `macos_hosts.yml` |

## Configuration

Variables are read in this order, with later files overriding earlier ones:

1. `inventory/group_vars/all.yml`: settings for every host, including the cross-platform tools and your Git identity.
2. `inventory/group_vars/linux_hosts.yml` and `inventory/group_vars/macos_hosts.yml`: connection settings and per-OS tools.
3. `inventory/host_vars/<hostname>.yml` (optional; create it as needed): overrides for one machine.

Set your Git identity in `inventory/group_vars/all.yml`:

```yaml
---
git_user_name: 'Your Name'
git_user_email: 'you@example.com'
```

To skip a tool on one machine, create a host_vars file for it. For example, `inventory/host_vars/kp-comp-mac-01.local.yml`:

```yaml
---
install_notion: false
install_virtualbox: false
```

## Project layout

```text
.
├── .devcontainer/           # Dev container definitions (Docker and Podman)
├── .github/
│   ├── workflows/tests.yml  # CI: ansible-lint on pull requests
│   └── ansible-code-bot.yml
├── .vscode/extensions.json  # Recommended VS Code extensions
├── collections/
│   └── requirements.yml     # Required collections
├── inventory/
│   ├── hosts.yml            # Hosts and groups
│   ├── group_vars/
│   │   ├── all.yml
│   │   ├── linux_hosts.yml
│   │   └── macos_hosts.yml
│   └── host_vars/           # Optional per-host overrides
├── ansible-navigator.yml    # ansible-navigator settings
├── ansible.cfg              # Ansible settings
├── bootstrap_linux.sh       # Installs ansible-dev-tools on the controller
├── bootstrap_macos.sh       # Installs Homebrew, VirtualBox and Vagrant on macOS
├── devfile.yaml             # Dev Spaces / devfile workspace definition
└── site.yml                 # Main playbook
```

## Development and CI

- Lint locally with `ansible-lint`. It is installed by `bootstrap_linux.sh` as part of `ansible-dev-tools`.
- GitHub Actions runs `ansible-lint` on every pull request to `main` (see `.github/workflows/tests.yml`).
- `.devcontainer/` and `devfile.yaml` give you a ready-made environment based on the `community-ansible-dev-tools` image.

The project is tested with ansible-lint 24.2.0 and later, and with the current development version of ansible-core.

## Troubleshooting

- **`ansible-playbook: command not found`:** activate the virtual environment with
  `source ~/.ansible-dev-tools/.venv/bin/activate`.
- **`brew: command not found` on macOS:** open a new terminal. `bootstrap_macos.sh` adds Homebrew to `~/.zprofile`.
- **VirtualBox kernel extension blocked (Intel Macs):** allow Oracle in System Settings → Privacy & Security, then reboot.
- **Output is very verbose:** `ansible.cfg` sets `verbosity = 2`. Lower it, or override it for a single run.

## License

MIT. See [LICENSE](LICENSE).
