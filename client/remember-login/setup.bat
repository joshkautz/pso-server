@echo off
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((Get-Content -LiteralPath '%~f0' | Select-Object -Skip 3) -join [Environment]::NewLine)"
exit /b
# ============================================================
#  Remember my PSO Blue Burst login (Windows) - single file, no installs.
#  Saves your BB UserID + password into the registry so the login screen
#  pre-fills both. The password is the 48-byte encrypted blob the game uses
#  (PSOBB's Blowfish, keyed by the UserID). Runs on built-in PowerShell.
# ============================================================
$ErrorActionPreference = 'Stop'
$M = [long]4294967295
$b64 = '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'
$raw = [Convert]::FromBase64String($b64)
$P = New-Object 'long[]' 18
for ($i=0; $i -lt 18; $i++) { $P[$i] = [long][BitConverter]::ToUInt32($raw, $i*4) }
$S = New-Object 'long[][]' 4
for ($b=0; $b -lt 4; $b++) {
  $S[$b] = New-Object 'long[]' 256
  for ($j=0; $j -lt 256; $j++) { $S[$b][$j] = [long][BitConverter]::ToUInt32($raw, 72 + $b*1024 + $j*4) }
}
for ($i=0; $i -lt 18; $i++) {
  $T = $P[$i]
  $plo = ((($T -band 0xFF) -shl 8) -bor (($T -shr 8) -band 0xFF))
  $phi = (((($T -shr 16) -band 0xFFFF) -bxor $plo) -band 0xFFFF)
  $P[$i] = ((($phi -shl 16) -bor $plo) -band $M)
}
function PadBuf([string]$s) {
  $bytes = [Text.Encoding]::ASCII.GetBytes($s)
  $buf = New-Object 'byte[]' 48
  $n = [Math]::Min($bytes.Length, 48)
  for ($k=0; $k -lt $n; $k++) { $buf[$k] = $bytes[$k] }
  return ,$buf
}
function Fn($x) {
  $x = $x -band $M
  $e = $S[0][($x -shr 24) -band 0xFF]
  $e = ($e + $S[1][($x -shr 16) -band 0xFF]) -band $M
  $e = $e -bxor $S[2][($x -shr 8) -band 0xFF]
  $e = ($e + $S[3][$x -band 0xFF]) -band $M
  return $e
}
function IB($l, $r) {
  for ($i=0; $i -lt 16; $i+=2) {
    $l = $l -bxor $P[$i];   $r = ($r -bxor (Fn $l)) -band $M
    $r = $r -bxor $P[$i+1]; $l = ($l -bxor (Fn $r)) -band $M
  }
  $l = $l -bxor $P[16]; $r = $r -bxor $P[17]
  return @(($r -band $M), ($l -band $M))
}
function EB($l, $r) {
  for ($i=0; $i -lt 4; $i++) { $l = $l -bxor $P[$i]; $r = ($r -bxor (Fn $l)) -band $M; $t = $l; $l = $r; $r = $t }
  $t = $l; $l = $r; $r = $t
  $r = $r -bxor $P[4]; $l = $l -bxor $P[5]
  return @(($l -band $M), ($r -band $M))
}

# --- get credentials (env vars are a non-interactive test hook) ---
if ($env:RL_TEST_UID) { $uid = $env:RL_TEST_UID; $pw = $env:RL_TEST_PW }
else {
  Write-Host ''
  Write-Host '  PSO Blue Burst - remember my login'
  Write-Host '  -----------------------------------'
  $uid = Read-Host '  UserID'
  $sec = Read-Host '  Password' -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  $pw = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}
if ([string]::IsNullOrEmpty($uid) -or [string]::IsNullOrEmpty($pw)) {
  Write-Host '  UserID and password are both required.'; exit 1
}

# --- key schedule (key = UserID) ---
$key = PadBuf $uid
$L = 48
for ($i=0; $i -lt 18; $i++) {
  $k = ([long]$key[($i*4+3)%$L]) -bor ([long]$key[($i*4+2)%$L] -shl 8) -bor ([long]$key[($i*4+1)%$L] -shl 16) -bor ([long]$key[($i*4+0)%$L] -shl 24)
  $P[$i] = ($P[$i] -bxor ($k -band $M)) -band $M
}
$v1 = [long]0; $v2 = [long]0
for ($i=0; $i -lt 18; $i+=2) { $res = IB $v1 $v2; $v1 = $res[0]; $v2 = $res[1]; $P[$i] = $v1; $P[$i+1] = $v2 }
for ($b=0; $b -lt 4; $b++) { for ($j=0; $j -lt 256; $j+=2) { $res = IB $v1 $v2; $v1 = $res[0]; $v2 = $res[1]; $S[$b][$j] = $v1; $S[$b][$j+1] = $v2 } }

# --- encrypt the 48-byte (NUL-padded) password ---
$ptbuf = PadBuf $pw
$pt = New-Object 'long[]' 12
for ($i=0; $i -lt 12; $i++) { $pt[$i] = [long][BitConverter]::ToUInt32($ptbuf, $i*4) }
$blob = New-Object 'byte[]' 48
for ($i=0; $i -lt 12; $i+=2) {
  $res = EB $pt[$i] $pt[$i+1]
  [Array]::Copy([BitConverter]::GetBytes([uint32]$res[0]), 0, $blob, $i*4, 4)
  [Array]::Copy([BitConverter]::GetBytes([uint32]$res[1]), 0, $blob, ($i+1)*4, 4)
}

if ($env:RL_TEST_PRINT) {
  ($blob | ForEach-Object { '{0:x2}' -f $_ }) -join ','
} else {
  $rk = 'HKCU:\Software\SonicTeam\PSOBB'
  if (-not (Test-Path $rk)) { New-Item -Path $rk -Force | Out-Null }
  New-ItemProperty -Path $rk -Name 'ACCOUNT'       -PropertyType String -Value $uid          -Force | Out-Null
  New-ItemProperty -Path $rk -Name 'ACCOUNT_CHECK' -PropertyType DWord  -Value 1             -Force | Out-Null
  New-ItemProperty -Path $rk -Name 'PASSWORD'      -PropertyType Binary -Value ([byte[]]$blob) -Force | Out-Null
  Write-Host ''
  Write-Host '  Done - launch Psobb.exe; your UserID and password are pre-filled.'
  Write-Host ''
  if (-not $env:RL_TEST_UID) { Read-Host '  Press Enter to close' | Out-Null }
}
