# https://github.com/astral-sh/uv/pull/3522/files
# https://learn.microsoft.com/en-us/windows/dev-drive/
param(
	[string]$Path = "C:/dev_drive.vhdx",
	[int64]$SizeBytes = 10GB
)

$Volume = New-VHD -Path $Path -SizeBytes $SizeBytes |
	Mount-VHD -Passthru |
	Initialize-Disk -Passthru |
	New-Partition -AssignDriveLetter -UseMaximumSize |
	Format-Volume -FileSystem ReFS -Confirm:$false -Force

Write-Output $Volume
# Write-Output "DEV_DRIVE=$($Volume.DriveLetter):" >> $env:GITHUB_ENV
