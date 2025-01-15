# Variables for paths and config
$runnerDir = "C:\actions-runner"
$configCmd = "$runnerDir\config.cmd"
$runCmd = "$runnerDir\run.cmd"

# Check required environment variables
if (-not $env:RUNNER_TOKEN) {
    Write-Error "RUNNER_TOKEN is not set. Exiting."
    exit 1
}
if (-not $env:RUNNER_REPO_URL) {
    Write-Error "RUNNER_REPO_URL is not set. Exiting."
    exit 1
}
$env:RUNNER_NAME = "windows-amd64-cake"
$env:RUNNER_WORKDIR = "_work"

# Register the runner
Write-Host "Registering the runner..."
Write-Host "--url $env:RUNNER_REPO_URL"
Write-Host "--token $env:RUNNER_TOKEN"
Write-Host "--name $env:RUNNER_NAME"
Write-Host "--work $env:RUNNER_WORKDIR"

& $configCmd --url $env:RUNNER_REPO_URL `
             --token $env:RUNNER_TOKEN `
             --name $env:RUNNER_NAME `
             --work $env:RUNNER_WORKDIR `
             --unattended `
             --replace