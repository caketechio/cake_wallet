# Building CakeWallet for Windows

## Requirements and Setup

The following are the system requirements to build CakeWallet for your Windows PC.

```
Windows 10 or later (64-bit), x86-64 based
Flutter 3 or above
```

## Building CakeWallet on Windows

These steps will help you configure and execute a build of CakeWallet from its source code.

### 1. Installing Package Dependencies

For build CakeWallet windows application from sources you will be needed to have:
> [Install Flutter]Follow installation guide (https://docs.flutter.dev/get-started/install/windows) and install do not miss to dev tools (install https://docs.flutter.dev/get-started/install/windows/desktop#development-tools) which are required for windows desktop development (need to install Git for Windows and Visual Studio 2022). Then install `Desktop development with C++` packages via GUI Visual Studio 2022, or Visual Studio Build Tools 2022 including: `C++ Build Tools core features`, `C++ 2022 Redistributable Update`, `C++ core desktop features`, `MVC v143 - VS 2022 C++ x64/x86 build tools`, `C++ CMake tools for Windows`, `Testing tools core features - Build Tools`, `C++ AddressSanitizer`.
> [Install WSL] for building monero dependencies need to install Windows WSL (https://learn.microsoft.com/en-us/windows/wsl/install) and required packages for WSL (Ubuntu):
`$ sudo apt update `
`$ sudo apt build-essential cmake gcc-mingw-w64 g++-mingw-w64 autoconf libtool pkg-config`

### 2. Pull CakeWallet source code

You can download CakeWallet source code from our [GitHub repository](github.com/cake-tech/cake_wallet) via git by following next command:
`$ git clone https://github.com/cake-tech/cake_wallet.git --branch MrCyjaneK-cyjan-monerodart`
OR you can download it as [Zip archive](https://github.com/cake-tech/cake_wallet/archive/refs/heads/MrCyjaneK-cyjan-monerodart.zip)

### 3. Build Monero, Monero_c and their dependencies

For use monero in the application need to build Monero wrapper - Monero_C which will be used by monero.dart package. For that need to run shell (bash - typically same named utility should be available after WSL is enabled in your system) with previously installed WSL, then change current directory to the application project directory with your used shell and then change current directory to `scripts/windows`: `$ cd scripts/windows`. Run build script: `$ ./build_all.sh`.

### 4. Configure and build CakeWallet application

To configure the application open directory where you have downloaded or unarchived CakeWallet sources and run `cakewallet.bat`.
Or if you used WSL and have active shell session you can run `$ ./cakewallet.sh` script in `scripts/windows` which will run `cakewallet.bat` in WSL.
After execution of `cakewallet.bat` you should to get `Cake Wallet.zip` in project root directory which will contains `CakeWallet.exe` file and another needed files for run the application. Now you can extract files from `Cake Wallet.zip` archive and run the application.
