# Building Cake Wallet for Windows

## Requirements and Setup

The following are the system requirements to build Cake Wallet for your Windows PC.

```txt
Windows 10 or later (64-bit), x86-64 based
Flutter 3.24.4
```

### 1. Installing Flutter

Install Flutter, specifically version `3.24.4` by following the [official docs](https://docs.flutter.dev/get-started/install/windows).

In order for Flutter to function, you'll also need to enable Developer Mode:

Start Menu > search for "Run" > type `ms-settings:developers`, and turn on Developer Mode.

NOTE: as `3.24.4` is not the latest version, you'll need to download it from <https://docs.flutter.dev/release/archive> instead of the link in the docs above.

### 2. Install Development Tools

Install Git for Windows and Visual Studio 2022:

1. Follow the [Development Tools](https://docs.flutter.dev/get-started/install/windows/desktop#development-tools) installation instructions
   1. NOTE: Be sure to install the `Desktop Development with C++` workload in Visual Studio as outlined in the docs.
2. Add `git` to your path by going to Start Menu > search "environment" > Environment Variables > double-click Path > Add `C:\Program Files\Git\bin\` on a new line.

Lastly, you'll need to install Nuget separately:

1. Download the exe from <https://dist.nuget.org/win-x86-commandline/latest/nuget.exe>
2. Create a new directory, `C:\Program Files\Nuget\`
3. Move or copy the `nuget.exe` binary you just downloaded into the newly created directory above.

### 3. Installing WSL (Windows Subsystem for Linux)

For building Monero dependencies, it is required to install Windows [WSL](https://learn.microsoft.com/en-us/windows/wsl) and required packages for WSL (Ubuntu).

1. Open a Powershell window by going to the Start Menu and searching for "Powershell"
2. Install WSL with the command `wsl --install`
3. Install the necessary Ubuntu dependencies

```powershell
wsl --install
wsl sudo apt update
wsl sudo apt install -y autoconf build-essential ccache cmake curl gcc gcc-mingw-w64-x86-64 git g++ g++-mingw-w64-x86-64 gperf lbzip2 libtool make pkg-config pigz
```

### 4. Installing Rust

Install Rust and other Rust-related dependencies using [rustup.rs](https://rustup.rs/#) by running the following command:

```bash
wsl curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### 5. Acquiring the Cake Wallet source code

Download the latest release tag of Cake Wallet and enter the source code directory:

```powershell
git clone https://github.com/cake-tech/cake_wallet.git --branch main
cd cake_wallet
```

NOTE: Replace `main` with the latest release tag available at <https://github.com/cake-tech/cake_wallet/releases/latest>.

### 6. Build Monero, monero_c, and dependencies

To use Monero in Cake Wallet, you must build the Monero_C wrapper which will be used by monero.dart package.

Run the following in a WSL terminal window (set the Git username and email as desired, and be sure to replace `USERNAME` with your Windows username [case-sensitive!]):

```powershell
wsl
git config --global user.email "builds@cakewallet.com"
git config --global user.name "builds"
./build_all.sh
```

### 7. Configure and build Cake Wallet application

To configure the application, run the following:

```powershell
exit
.\cakewallet.bat
```

After running the script above, you should get `Cake Wallet.zip` in the project's root directory which will contain `CakeWallet.exe` and other needed files for running the application. Now you can extract files from `Cake Wallet.zip` archive and run the application.
