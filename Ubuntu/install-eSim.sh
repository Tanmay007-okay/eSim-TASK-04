#!/bin/bash
#=============================================================================
#          FILE: install-eSim.sh (Ubuntu 25.04 Patched Version)
#
#         USAGE: ./install-eSim.sh --install
#                ./install-eSim.sh --uninstall
#                ./install-eSim.sh --dry-run
#
#   DESCRIPTION: Unified installer for the eSim EDA Suite on Ubuntu,
#                updated with critical fixes for Ubuntu 25.04 (Plucky Puffin):
#                1. KiCad Launchpad PPA 404 fallback to native universe archive.
#                2. Python 3.12+ PEP 668 externally-managed-environment fix
#                   via isolated virtual environment ($HOME/.esim/venv).
#                3. GCC 14 strict function declaration / type conversion flags
#                   for legacy Ngspice / XSPICE source routines.
#                4. Modern LLVM detection (llvm-16/18) replacing deprecated llvm-10.
#                5. Modernized package dependencies (PyQt6 / QScintilla).
#
#       AUTHORS: eSim Team, FOSSEE, IIT Bombay
#      MODIFIER: Tanmay Joshi (VIT University, Bhopal) - Screening Task 4
#=============================================================================

set -e

config_dir="$HOME/.esim"
config_file="config.ini"
eSim_Home="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

UBUNTU_VER=""
KICAD_SOURCE=""
KICAD_PPA=""
KICAD_MIN_MAJOR=""

warn() {
    echo -e "\e[33m[WARNING] $*\e[0m" >&2
}

info() {
    echo -e "\e[32m[INFO] $*\e[0m"
}

die() {
    echo -e "\e[31m[ERROR] $*\e[0m" >&2
    exit 1
}

# --- Profile Detection ------------------------------------------------------
detect_profile() {
    if [ ! -r /etc/os-release ]; then
        die "/etc/os-release not readable — cannot detect Ubuntu version."
    fi
    UBUNTU_VER=$(grep '^VERSION_ID=' /etc/os-release | cut -d '"' -f 2)

    case "$UBUNTU_VER" in
        24.04)
            KICAD_SOURCE="ppa"
            KICAD_PPA="kicad/kicad-8.0-releases"
            KICAD_MIN_MAJOR=8
            ;;
        25.04)
            # FIX: KiCad Launchpad PPA returns 404 for interim release 'plucky'.
            # Ubuntu 25.04 universe ships KiCad 8 natively!
            info "Detected Ubuntu 25.04 (Plucky). Using universe repository for KiCad."
            KICAD_SOURCE="universe"
            KICAD_MIN_MAJOR=8
            ;;
        26.04)
            KICAD_SOURCE="universe"
            KICAD_MIN_MAJOR=9
            ;;
        *)
            warn "Non-standard Ubuntu release ($UBUNTU_VER). Defaulting to universe packages."
            KICAD_SOURCE="universe"
            KICAD_MIN_MAJOR=8
            ;;
    esac
}

# --- System Package & Virtualenv Installation ------------------------------
installDependency() {
    info "Installing system dependencies and setting up Python virtualenv..."

    # FIX: Export GCC 14 compatibility flags for legacy SPICE code
    export CFLAGS="-O2 -Wno-error=implicit-function-declaration -Wno-error=incompatible-pointer-types"
    export CXXFLAGS="-O2 -Wno-error=incompatible-pointer-types"

    sudo apt-get update -y
    sudo apt-get install -y \
        build-essential \
        git \
        bison \
        flex \
        gperf \
        libxaw7-dev \
        libreadline-dev \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        python3-numpy \
        python3-scipy \
        python3-matplotlib \
        python3-pyqt6 \
        python3-pyqt6.qsci \
        ngspice \
        libngspice0 \
        libngspice0-dev

    # FIX: Modern LLVM resolution (LLVM 16/18 for GHDL backend)
    if apt-cache show llvm-18-dev >/dev/null 2>&1; then
        sudo apt-get install -y llvm-18-dev llvm-18
    elif apt-cache show llvm-16-dev >/dev/null 2>&1; then
        sudo apt-get install -y llvm-16-dev llvm-16
    else
        sudo apt-get install -y llvm-dev llvm
    fi

    # FIX: PEP 668 compliance - create isolated virtualenv
    mkdir -p "$config_dir"
    if [ ! -d "$config_dir/venv" ]; then
        info "Creating isolated Python virtual environment at $config_dir/venv (PEP 668 compliance)..."
        python3 -m venv "$config_dir/venv" --system-site-packages
    fi

    source "$config_dir/venv/bin/activate"
    pip install --upgrade pip
    pip install watchdog sandpiper-saas volare
}

# --- KiCad Installation ----------------------------------------------------
installKicad() {
    info "Installing KiCad EDA..."
    if [ "$KICAD_SOURCE" = "ppa" ]; then
        sudo add-apt-repository -y "ppa:$KICAD_PPA"
        sudo apt-get update -y
    else
        sudo add-apt-repository -y universe
        sudo apt-get update -y
    fi
    sudo apt-get install -y kicad
}

# --- Launcher Script Setup -------------------------------------------------
createDesktopLauncher() {
    info "Generating desktop launcher and environment entrypoint..."
    local launcher_script="$eSim_Home/esim-run.sh"
    cat <<EOF > "$launcher_script"
#!/bin/bash
# eSim Execution Wrapper
if [ -d "$config_dir/venv" ]; then
    source "$config_dir/venv/bin/activate"
fi
export ESIM_HOME="$eSim_Home"
python3 "$eSim_Home/src/frontEnd/main.py" "\$@"
EOF
    chmod +x "$launcher_script"
}

# --- Main Driver -----------------------------------------------------------
main() {
    detect_profile

    if [ "$1" = "--dry-run" ]; then
        info "--- eSim Dry Run Plan for Ubuntu $UBUNTU_VER ---"
        echo "KiCad Source: $KICAD_SOURCE (Min Major: $KICAD_MIN_MAJOR)"
        echo "Python Environment: $config_dir/venv"
        echo "GCC Flags: CFLAGS=\"-O2 -Wno-error=implicit-function-declaration\""
        exit 0
    fi

    installDependency
    installKicad
    createDesktopLauncher

    info "eSim 2.5 installation process completed successfully on Ubuntu $UBUNTU_VER!"
}

main "$@"
