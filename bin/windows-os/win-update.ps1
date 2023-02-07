param( [switch]$Force )


# Your main script logic here
Write-Host "Performing the operation..."

# Auto-elevate to Administrator
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).
           IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $IsAdmin) {
    Write-Host "Elevating to Administrator..."
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "Running winget updates..."
&winget update
if ($Force) {
    &winget upgrade --all --force
} else {
    &winget upgrade --all
}

# Enable Microsoft Update
try {
    Write-Host "Enabling Microsoft Update (includes Office/Edge/SQL/etc.)..."
    Add-WUServiceManager -MicrosoftUpdate -Confirm:$false
} catch {
    Write-Warning "Could not enable Microsoft Update: $($_.Exception.Message)"
}

# Scan & Install Updates
Write-Host "Scanning for updates..."
Get-WindowsUpdate -Verbose -ErrorAction SilentlyContinue

Write-Host "Installing updates (auto-reboot)..."
Install-WindowsUpdate -AcceptAll -AutoReboot -Verbose -ErrorAction Stop

Write-Host "Updates installation initiated/completed. System may reboot automatically if required."
# winget pin add Microsoft.Office --blocking

Write-Host "Pinned packages (not updated):"
winget pin list

# Inspect if something went wrong
# Get-WindowsUpdateLog
