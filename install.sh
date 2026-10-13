#!/usr/bin/env bash
# ==============================================================================
# install.sh — install & verify everything the Job_Applying_Cron engine needs.
#
#   ./install.sh                install anything missing, then verify everything
#   ./install.sh --check        verify only — install nothing, change nothing
#   ./install.sh --no-browser   do not install a web browser
#   ./install.sh -h | --help    show this help
#
# Linux only. Detects the distribution and drives its package manager:
#   Debian/Ubuntu (apt) · Fedora/RHEL/CentOS (dnf) · Arch (pacman)
#   openSUSE (zypper) · Alpine (apk)
#
# Idempotent: anything already present and new enough is left untouched.
# Exits non-zero if any required tool is still missing after the run.
# ==============================================================================
set -uo pipefail

CHECK_ONLY=0
INSTALL_BROWSER=1
for a in "$@"; do
  case "$a" in
    --check)      CHECK_ONLY=1 ;;
    --no-browser) INSTALL_BROWSER=0 ;;
    -h|--help)    sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "unknown option: $a (see --help)" >&2; exit 2 ;;
  esac
done

# --- pretty output -----------------------------------------------------------
if [ -t 1 ]; then B=$'\033[1m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; N=$'\033[0m'
else B=; G=; Y=; R=; N=; fi
step() { printf '\n%s==> %s%s\n' "$B" "$*" "$N"; }
ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*"; }
bad()  { printf '  %s✗%s %s\n' "$R" "$N" "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }
# true when the actual version ($2) is >= the required version ($1)
ver_ge() { [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]; }

# --- operating system --------------------------------------------------------
step "Detecting operating system"
if [ "$(uname -s)" != "Linux" ]; then
  bad "This installer supports Linux only (found '$(uname -s)')."; exit 1
fi
ok "Linux $(uname -r) ($(uname -m))"

FAMILY=""
[ -r /etc/os-release ] && . /etc/os-release
DISTRO_NAME="${PRETTY_NAME:-${NAME:-unknown}}"
DISTRO_ID="${ID:-}"; DISTRO_LIKE="${ID_LIKE:-}"

case " $DISTRO_ID $DISTRO_LIKE " in
  *debian*|*ubuntu*)              FAMILY=debian ;;
  *fedora*|*rhel*|*centos*)       FAMILY=fedora ;;
  *arch*)                         FAMILY=arch ;;
  *suse*|*opensuse*)              FAMILY=suse ;;
  *alpine*)                       FAMILY=alpine ;;
esac
# fall back to whatever package manager is actually present
if [ -z "$FAMILY" ]; then
  if   have apt-get; then FAMILY=debian
  elif have dnf;     then FAMILY=fedora
  elif have pacman;  then FAMILY=arch
  elif have zypper;  then FAMILY=suse
  elif have apk;     then FAMILY=alpine
  fi
fi
if [ -n "$FAMILY" ]; then ok "$DISTRO_NAME (package family: $FAMILY)"
else warn "$DISTRO_NAME — unknown package family; will verify only, no installs"; fi

# --- privileges --------------------------------------------------------------
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if have sudo; then SUDO="sudo"; else warn "not root and no sudo — installs may fail"; fi
fi

pkg_update() {
  [ "$CHECK_ONLY" = 1 ] && return 0
  case "$FAMILY" in
    debian) $SUDO apt-get update -qq ;;
    fedora) $SUDO dnf -q makecache ;;
    suse)   $SUDO zypper -q refresh ;;
    alpine) $SUDO apk update -q ;;
    arch)   : ;;                      # partial upgrades are discouraged; install fresh instead
  esac
}
pkg_install() {
  [ "$CHECK_ONLY" = 1 ] && return 0
  case "$FAMILY" in
    debian) $SUDO apt-get install -y "$@" ;;
    fedora) $SUDO dnf install -y "$@" ;;
    arch)   $SUDO pacman -S --noconfirm --needed "$@" ;;
    suse)   $SUDO zypper -n install "$@" ;;
    alpine) $SUDO apk add --no-cache "$@" ;;
    *) return 1 ;;
  esac
}

# --- base packages -----------------------------------------------------------
step "Base packages (git · curl · python3 · flock · timeout)"
case "$FAMILY" in
  debian) pkg_update; pkg_install git curl ca-certificates python3 util-linux coreutils ;;
  fedora) pkg_update; pkg_install git curl ca-certificates python3 util-linux coreutils ;;
  arch)   pkg_install git curl ca-certificates python util-linux coreutils ;;
  suse)   pkg_update; pkg_install git curl ca-certificates python3 util-linux coreutils ;;
  alpine) pkg_update; pkg_install git curl ca-certificates python3 util-linux coreutils bash ;;
  *) warn "no package manager — skipping base install" ;;
esac
for t in git curl python3 flock timeout; do
  have "$t" && ok "$t present" || bad "$t missing"
done

# --- Node.js (>= 22) + npm ---------------------------------------------------
step "Node.js >= 22 and npm"
node_ver=""; have node && node_ver="$(node -v 2>/dev/null | sed 's/^v//')"
if [ -n "$node_ver" ] && ver_ge "22.0.0" "$node_ver"; then
  ok "node $node_ver, npm $(npm -v 2>/dev/null)"
elif [ "$CHECK_ONLY" = 1 ]; then
  bad "node ${node_ver:-missing} is older than 22"
else
  warn "installing Node.js 22.x (found ${node_ver:-nothing})"
  case "$FAMILY" in
    debian) curl -fsSL https://deb.nodesource.com/setup_22.x | $SUDO -E bash - && pkg_install nodejs ;;
    fedora) curl -fsSL https://rpm.nodesource.com/setup_22.x | $SUDO bash - && pkg_install nodejs ;;
    suse)   curl -fsSL https://rpm.nodesource.com/setup_22.x | $SUDO bash - && pkg_install nodejs ;;
    arch)   pkg_install nodejs npm ;;
    alpine) pkg_install nodejs npm ;;
    *) bad "no supported package manager for Node.js — install Node 22 manually" ;;
  esac
  have node && ok "node $(node -v)" || bad "node still missing"
fi

# --- browser (Chromium family, for CDP) --------------------------------------
step "Chromium-family browser (the engine drives it over CDP)"
browser_found() { for b in brave-browser chromium chromium-browser google-chrome google-chrome-stable; do have "$b" && return 0; done; return 1; }
browser_name()  { for b in brave-browser chromium chromium-browser google-chrome google-chrome-stable; do have "$b" && { echo "$b"; return; }; done; }
if browser_found; then
  ok "found $(browser_name)"
elif [ "$CHECK_ONLY" = 1 ] || [ "$INSTALL_BROWSER" = 0 ]; then
  warn "no Chromium-family browser found (install Brave or Chromium for the engine to attach to)"
else
  warn "installing Chromium"
  case "$FAMILY" in
    debian) if have snap; then $SUDO snap install chromium || pkg_install chromium || pkg_install chromium-browser
            else pkg_install chromium || pkg_install chromium-browser; fi ;;
    *)      pkg_install chromium ;;
  esac
  browser_found && ok "installed $(browser_name)" || bad "browser install failed — install Brave/Chromium manually"
fi

# --- Command Code CLI + agent-browser (npm globals) --------------------------
step "Command Code CLI (cmd) and agent-browser"
if ! have npm; then
  bad "npm is missing — cannot install the CLIs"
elif [ "$CHECK_ONLY" = 1 ]; then
  have cmd && ok "cmd present" || bad "cmd missing"
  have agent-browser && ok "agent-browser present" || bad "agent-browser missing"
else
  to_add=()
  have cmd || to_add+=(command-code)
  have agent-browser || to_add+=(agent-browser)
  if [ "${#to_add[@]}" -gt 0 ]; then
    warn "npm i -g ${to_add[*]}"
    $SUDO npm i -g "${to_add[@]}" || npm i -g "${to_add[@]}"
  else
    ok "cmd and agent-browser already present"
  fi
fi

# --- verification ------------------------------------------------------------
step "Verifying required tools"
FAIL=0
check() { # <name> <version-command>
  local name="$1" vc="${2:-}" v=""
  if have "$name"; then
    [ -n "$vc" ] && v="$($vc 2>/dev/null | head -n1)"
    printf '  %s✓%s %-14s %s\n' "$G" "$N" "$name" "$v"
  else
    printf '  %s✗%s %-14s MISSING\n' "$R" "$N" "$name"; FAIL=1
  fi
}
check git           'git --version'
check curl          'curl --version'
check python3       'python3 --version'
check flock         'flock --version'
check timeout       'timeout --version'
check node          'node --version'
check npm           'npm --version'
check cmd           'cmd --version'
check agent-browser 'agent-browser --version'

if have node; then
  v="$(node -v | sed 's/^v//')"; ver_ge 22.0.0 "$v" && ok "node >= 22 ($v)" || { bad "node $v is older than 22"; FAIL=1; }
fi
if have python3; then
  v="$(python3 -c 'import sys;print("%d.%d"%sys.version_info[:2])')"; ver_ge 3.8 "$v" && ok "python3 >= 3.8 ($v)" || { bad "python3 $v is older than 3.8"; FAIL=1; }
fi
if browser_found; then ok "browser ($(browser_name))"; else bad "no Chromium-family browser"; FAIL=1; fi

echo
if [ "$FAIL" -ne 0 ]; then
  bad "One or more requirements are still missing (see the ✗ lines above)."
  exit 1
fi
ok "${B}All requirements satisfied.${N}"

cat <<'EOF'

Next steps:
  1. Sign in to Command Code:       cmd login
  2. Start your browser with CDP and sign in to the job boards:
       brave-browser --remote-debugging-port=9222 --restore-last-session &
  3. Create your private config from the shipped templates:
       cp .env.example .env
       cp bank/core.example.md bank/core.md
       cp bank/OPEN-QUESTIONS.example.md bank/OPEN-QUESTIONS.md
       cp applied-jobs-registry.example.md applied-jobs-registry.md
       cp cv/source/default.example.json cv/source/default.json
  4. Compose a run without sending anything:
       ./tools/cron-run.sh linkedin --dry-run
EOF
