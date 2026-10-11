#Requires -Version 5.1
<#
Prepare an isolated TFTP root only. Does not serve files, alter networking,
download images, convert OEM firmware or establish hardware compatibility.
Read docs/ROUTER_RECOVERY.en.md before use. Stop the TFTP server first.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Image,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedSha256,
    [Parameter(Mandatory = $true)][string]$OutputDirectory
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$source = Get-Item -LiteralPath $Image
if ($source.PSIsContainer -or $source.Length -eq 0) {
    throw 'Image must be a non-empty file.'
}
# Filename/hash do not replace verification of provenance and board support.
if ($source.Name -notmatch '^openwrt-[0-9]+\.[0-9]+\.[0-9]+-ramips-mt76x8-tplink_tl-mr3020-v3-squashfs-tftp-recovery\.bin$') {
    throw 'Expected a versioned OpenWrt TL-MR3020 v3 recovery image. OEM and sysupgrade images are not accepted.'
}
$actual = (Get-FileHash -LiteralPath $source.FullName -Algorithm SHA256).Hash
if ($actual -ne $ExpectedSha256) { throw 'Source SHA256 mismatch.' }
$root = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
if (Test-Path -LiteralPath $root) { throw 'Output directory already exists; choose a new directory.' }
[void][System.IO.Directory]::CreateDirectory($root)
$target = Join-Path $root 'tp_recovery.bin'
[System.IO.File]::Copy($source.FullName, $target, $false)
if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $ExpectedSha256) {
    throw 'Staged SHA256 mismatch. Do not use this directory.'
}
Write-Output "Prepared: $target"
Write-Output "SHA256: $actual"
Write-Output 'No TFTP server started; no network or router changes made.'
Write-Output 'After board/image review, select this root and 192.168.0.225 in Tftpd64.'
