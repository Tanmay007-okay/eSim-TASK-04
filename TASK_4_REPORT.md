# eSim 2.5 Upgradation & Dependency Fix Report for Ubuntu 25.04

**Project:** FOSSEE Semester Long Internship Screening Task 4  
**Track:** eSim Upgradation (CSE and Related Fields)  
**Candidate Name:** Tanmay Joshi  
**Affiliation:** VIT University, Bhopal  
**Target Environment:** Ubuntu 25.04 (Plucky Puffin) x86_64  
**Date:** November 2026  

---

## 1. Executive Summary

As part of the screening task for the FOSSEE Semester Long Internship, this study investigates the dependency conflicts, package deprecations, and compiler toolchain incompatibilities encountered while installing **eSim Version 2.5** on **Ubuntu 25.04 (Plucky Puffin)**.

eSim 2.5's legacy installer was engineered for older Ubuntu LTS environments (Ubuntu 20.04 and 22.04 LTS). Running this legacy installer on Ubuntu 25.04 leads to catastrophic failures across multiple stages—from system package resolution to Python runtime configuration and C/C++ compilation.

This report documents:
1. **Five critical failure points** identified during the installation lifecycle.
2. Root-cause analysis for each failure.
3. The exact code-level resolutions applied to the unified `install-eSim.sh` script.
4. Validation methodologies ensuring a clean, reproducible installation.

---

## 2. Test Environment Specifications

| Component | Target Environment | Legacy Baseline (eSim 2.5) | Impact |
| :--- | :--- | :--- | :--- |
| **Operating System** | Ubuntu 25.04 (Plucky Puffin) | Ubuntu 20.04 / 22.04 LTS | Major ABI and package repository restructuring |
| **Linux Kernel** | 6.11+ | 5.4 / 5.15 | Hardware acceleration and pipe changes |
| **C/C++ Compiler** | GCC 14.x | GCC 9.x / 11.x | Modern C standards enforce `-Werror=implicit-function-declaration` |
| **Python Version** | Python 3.12.x | Python 3.8 / 3.10 | PEP 668 enforces externally managed environments |
| **LLVM Toolchain** | LLVM 18 / 19 | LLVM 10 / 12 | Older LLVM libraries completely removed from Ubuntu archives |

---

## 3. Comprehensive Analysis of Issues Encountered

### Issue 1: LLVM Version Deprecation & Package Inavailability (Critical)
* **Failure Phase:** Building NGHDL / GHDL co-simulation backend.
* **Error Output:**
  ```text
  E: Package 'llvm-10' has no installation candidate
  E: Unable to locate package llvm-10-dev
  configure: error: llvm-config not found or unsupported LLVM version
  ```
* **Root Cause Analysis:**  
  The legacy eSim installer script hardcoded installation targets for legacy LLVM versions (such as `llvm-10` or `llvm-12`) necessary for the GHDL LLVM synthesizer backend. Ubuntu 25.04 has purged all LLVM versions prior to LLVM 16 from its official repositories.
* **Resolution Implemented in `install-eSim.sh`:**
  - Implemented dynamic LLVM detection logic that checks for modern available LLVM packages (`llvm-18`, `llvm-16`, or `llvm-dev`).
  - Added fallback flags to query `llvm-config --version` and dynamically map the library paths.
  - Added GHDL GCC/LLVM prebuilt binary detection to prevent compilation hangs on machines with constrained resources.

---

### Issue 2: Python PEP 668 Environment Protection (`externally-managed-environment`)
* **Failure Phase:** Installing Python requirements (`pip3 install -r requirements.txt`).
* **Error Output:**
  ```text
  error: externally-managed-environment

  × This environment is externally managed
  ╰─> To install Python packages system-wide, try apt install
      python3-xyz, where xyz is the package you are trying to
      install.
  ```
* **Root Cause Analysis:**  
  Python 3.12 on Ubuntu 24.04 and 25.04 enforces **PEP 668**. This strictly forbids running `pip install` against the global system Python directory without a managed virtual environment to avoid corrupting OS-level packages (like `apt` or system utilities).
* **Resolution Implemented in `install-eSim.sh`:**
  - Refactored `installPythonDeps()` to automatically provision an isolated virtual environment at `$HOME/.esim/venv`.
  - Added automatic activation routines in the desktop launcher script (`eSim.desktop` and launcher shell script) to execute inside the virtual environment seamlessly.
  - Prefer system APT packages (`python3-numpy`, `python3-scipy`, `python3-matplotlib`, `python3-pyqt6`) where available, and only install pinned auxiliary packages (e.g., `sandpiper-saas`, `volare`) inside the isolated venv.

---

### Issue 3: KiCad PPA Failure (HTTP 404 on Plucky Puffin)
* **Failure Phase:** KiCad EDA Suite Installation.
* **Error Output:**
  ```text
  E: The repository 'https://ppa.launchpadcontent.net/kicad/kicad-8.0-releases/ubuntu plucky Release' does not have a Release file.
  W: Updating from such a repository can't be done securely, and is therefore disabled by default.
  ```
* **Root Cause Analysis:**  
  The official KiCad Launchpad PPA only builds packages for Ubuntu Long Term Support (LTS) releases (e.g., `jammy` 22.04 and `noble` 24.04). Ubuntu 25.04 (`plucky`) is an interim non-LTS release, causing `apt-get update` to immediately fail with a fatal 404 repository error.
* **Resolution Implemented in `install-eSim.sh`:**
  - Updated `detect_profile()` to inspect `/etc/os-release`.
  - On Ubuntu 25.04, the installer explicitly sets `KICAD_SOURCE="universe"`.
  - It safely falls back to Ubuntu's native `universe` repository (which ships KiCad 8 natively for Plucky), eliminating the invalid PPA addition.

---

### Issue 4: Strict C23 / GCC 14 Compilation Errors in Ngspice & Code Models
* **Failure Phase:** Compiling Ngspice XSPICE subcircuits and NGHDL shared libraries.
* **Error Output:**
  ```text
  error: implicit declaration of function 'xxx' [-Werror=implicit-function-declaration]
  error: passing argument from incompatible pointer type [-Werror=incompatible-pointer-types]
  make[2]: *** [Makefile:452: cm_analog.o] Error 1
  ```
* **Root Cause Analysis:**  
  Ubuntu 25.04 ships with **GCC 14**. Starting in GCC 14, implicit function declarations and incompatible pointer type assignments (common in legacy 1990s/2000s SPICE3f5 and XSPICE code) are upgraded from warnings to **fatal errors by default**.
* **Resolution Implemented in `install-eSim.sh`:**
  - Injected modern compatibility flags into the compilation environment:
    ```bash
    export CFLAGS="-O2 -Wno-error=implicit-function-declaration -Wno-error=incompatible-pointer-types -Wno-error=int-conversion"
    export CXXFLAGS="-O2 -Wno-error=incompatible-pointer-types"
    ```
  - This preserves code model compilation on GCC 14 without breaking legacy C structures.

---

### Issue 5: Deprecated & Renamed System Packages
* **Failure Phase:** Base system package resolution.
* **Error Output:**
  ```text
  Package python3-wxgtk4.0 is not available, but is referred to by another package.
  E: Package 'python3-wxgtk4.0' has no installation candidate
  ```
* **Root Cause Analysis:**  
  Ubuntu 25.04 transitions to modern wxWidgets packaging (`python3-wxgtk-media4.0` / Qt6 equivalents) and refactors OpenGL development libraries.
* **Resolution Implemented in `install-eSim.sh`:**
  - Modernized dependency arrays to replace obsolete package names with modern alternatives:
    - Replaced `python3-wxgtk4.0` with `python3-pyqt6` and Qt6 SVG tools.
    - Updated `libfl-dev` and `bison` rules for Verilator.

---

## 4. Code Fixes Summary in `install-eSim.sh`

The following unified modifications were made to `Ubuntu/install-eSim.sh`:

```diff
--- install-eSim.sh.orig
+++ install-eSim.sh
@@ -115,6 +115,11 @@
         24.04)
             KICAD_SOURCE="ppa"; KICAD_PPA="kicad/kicad-9.0-releases"; KICAD_MIN_MAJOR=9
             ;;
+        25.04)
+            # KiCad PPA does not publish for interim plucky release; use universe
+            KICAD_SOURCE="universe"; KICAD_MIN_MAJOR=8
+            ;;
@@ -210,6 +215,14 @@
 installDependency() {
     echo "Installing base system packages..."
+    # Ubuntu 25.04 GCC 14 compatibility flags
+    export CFLAGS="-O2 -Wno-error=implicit-function-declaration -Wno-error=incompatible-pointer-types"
+    
+    # Manage Python Virtual Environment (PEP 668 compliance)
+    if [ ! -d "$HOME/.esim/venv" ]; then
+        python3 -m venv "$HOME/.esim/venv" --system-site-packages
+    fi
+    source "$HOME/.esim/venv/bin/activate"
```

---

## 5. Verification & Validation

The patched script was validated through the following criteria:
1. **Clean Profile Detection:** Executing `./install-eSim.sh --dry-run` accurately detects `Ubuntu 25.04` and selects `universe` for KiCad.
2. **PEP 668 Compliance:** Python wheels and eSim CLI dependencies install smoothly into `$HOME/.esim/venv` without triggering system package lockouts.
3. **GCC 14 Build Success:** Ngspice and NGHDL shared libraries compile without halting on implicit function declarations.
4. **Toolchain Verification:** `runToolchainDoctor` executes upon completion, verifying that KiCad, Ngspice, and GHDL are recognized.

---

## 6. Conclusion

With these five targeted fixes, eSim 2.5 can be installed and executed cleanly on **Ubuntu 25.04**. These patches resolve modern compiler strictness, adhere to modern Python PEP 668 packaging standards, and bypass Launchpad PPA limitations on non-LTS Ubuntu releases.

**Submitted By:**  
Tanmay Joshi (VIT University, Bhopal)  
FOSSEE Screening Task 4 Submission
