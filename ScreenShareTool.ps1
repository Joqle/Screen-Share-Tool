$version = "3.2"
$results = @()
$flagged = 0

function Write-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║       Joqle Screen Share Tool        ║" -ForegroundColor Cyan
    Write-Host "  ║              v$version                     ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Add-Result {
    param([string]$Category, [string]$Status, [string]$Detail, [string]$Severity)
    $global:results += [PSCustomObject]@{
        Category = $Category
        Status   = $Status
        Detail   = $Detail
        Severity = $Severity
    }
    if ($Severity -in @("HIGH","MEDIUM")) { $global:flagged++ }
}

function Write-Section([string]$title) {
    Write-Host ""
    Write-Host "  ── $title" -ForegroundColor DarkCyan
    Write-Host ""
}

function Get-FileSHA512([string]$filePath) {
    try {
        $sha = [System.Security.Cryptography.SHA512]::Create()
        $stream = [System.IO.File]::OpenRead($filePath)
        $hashBytes = $sha.ComputeHash($stream)
        $stream.Close()
        $sha.Dispose()
        return ([BitConverter]::ToString($hashBytes) -replace '-','').ToLower()
    } catch {
        return $null
    }
}

function Get-FileSHA1([string]$filePath) {
    try {
        $sha = [System.Security.Cryptography.SHA1]::Create()
        $stream = [System.IO.File]::OpenRead($filePath)
        $hashBytes = $sha.ComputeHash($stream)
        $stream.Close()
        $sha.Dispose()
        return ([BitConverter]::ToString($hashBytes) -replace '-','').ToLower()
    } catch {
        return $null
    }
}

function Check-ModrinthByHash([string]$filePath) {
    $sha512 = Get-FileSHA512 $filePath
    $sha1   = Get-FileSHA1   $filePath
    if (-not $sha512 -and -not $sha1) { return @{ Found = $null; Reason = "Hash failed" } }

    try {
        $body = @{ hashes = @($sha512, $sha1) | Where-Object { $_ }; algorithm = "sha512" } | ConvertTo-Json
        $resp = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/version_files" `
            -Method Post -Body $body -ContentType "application/json" -TimeoutSec 8 -ErrorAction Stop

        if ($resp -and $resp.PSObject.Properties.Count -gt 0) {
            $hit = $resp.PSObject.Properties | Select-Object -First 1
            $projectId = $hit.Value.project_id
            $versionName = $hit.Value.name
            return @{ Found = $true; ProjectId = $projectId; Version = $versionName }
        }
        return @{ Found = $false }
    } catch {
        return @{ Found = $null; Reason = $_.Exception.Message }
    }
}

function Check-ModrinthByName([string]$jarName) {
    try {
        $slug = [System.IO.Path]::GetFileNameWithoutExtension($jarName)
        $slug = $slug -replace '[-_\s]?\d[\d\.\-\+\_]*$', ''
        $slug = $slug -replace '[-_](fabric|forge|quilt|neoforge|mc|minecraft|+fabric|+forge).*$', ''
        $slug = $slug -replace '[_\-]$', ''
        $slug = $slug.ToLower().Trim()
        $url  = "https://api.modrinth.com/v2/search?query=$([uri]::EscapeDataString($slug))&limit=5&facets=[[%22project_type:mod%22]]"
        $resp = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 6 -ErrorAction Stop
        foreach ($hit in $resp.hits) {
            $hitSlug  = $hit.slug.ToLower()
            $hitTitle = $hit.title.ToLower() -replace '\s','-'
            if ($slug -eq $hitSlug -or $hitSlug -like "*$slug*" -or $slug -like "*$hitSlug*") {
                return @{ Found = $true; Title = $hit.title; Slug = $hit.slug }
            }
        }
        return @{ Found = $false }
    } catch {
        return @{ Found = $null }
    }
}

$cheatKeywords = @(
    "vape","vapev4","vapelite","vapenano",
    "drip","driplite",
    "liquid","liquidbounce",
    "meteor","meteorclient",
    "wurst","wurstclient",
    "impact","impactclient",
    "future","futureclient",
    "reflex","sigma","ares","rise","entropy",
    "inertia","rusherhack","novoline","azura",
    "xenos","syringe","injector","dllinjector",
    "cheatengine","cheat engine",
    "scyllahide","x64dbg","x32dbg","ollydbg",
    "extremedumper","bytecode",
    "autoclicker","autoclick","opautoclicker",
    "ghostware","ghost","payload","bypass","remap",
    "hook","hack","cheats","hacked","exploit",
    "aimbot","killaura","kill aura","blink","scaffold",
    "esp","wallhack","fullbright","nofall",
    "bhop","bunny","criticals","fastplace",
    "reach","timer","nuker","xray","cavefinder",
    "antiknockback","antikb","velocity","noslowdown"
)

$legitimateCmdLineContexts = @(
    "theseus.jar","modrinthapp","modrinth",
    "multimc","prismlauncher","prism",
    "tlauncher","curseforge","gdlauncher",
    "atlauncher","feather","badlion",
    "minecraft.launcher","mojang"
)

$cheatProcessNames = @(
    "Vape","VapeV4","VapeLite","VapeNano",
    "Drip","DripLite","Liquid","LiquidBounce",
    "Meteor","MeteorClient","Wurst","WurstClient",
    "Impact","ImpactClient","Future","FutureClient",
    "Reflex","Sigma","Ares","Rise","Entropy",
    "Inertia","Rusherhack","Novoline",
    "Xenos","ExtremeDumper",
    "CheatEngine","cheatengine-x86_64","cheatengine-i386",
    "ScyllaHide","x64dbg","x32dbg","ollydbg",
    "injector","dllinjector","syringe",
    "AutoClicker","AutoClick","OpAutoClicker"
)

Write-Banner

Write-Host "  Enter the path to the .minecraft folder to scan:" -ForegroundColor White
Write-Host "  (Leave blank for default: $env:APPDATA\.minecraft)" -ForegroundColor DarkGray
Write-Host ""
$inputPath = Read-Host "  Path"
if ([string]::IsNullOrWhiteSpace($inputPath)) {
    $mcPath = "$env:APPDATA\.minecraft"
} else {
    $mcPath = $inputPath.Trim().Trim('"')
}

Write-Host ""
if (-not (Test-Path $mcPath)) {
    Write-Host "  [ERROR] Path not found: $mcPath" -ForegroundColor Red
    Write-Host "  Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}
Write-Host "  Path set: $mcPath" -ForegroundColor Green
Write-Host ""

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Host "  Are you running this as Administrator? (y/n)" -ForegroundColor White
$adminInput = (Read-Host "  Answer").Trim().ToLower()
Write-Host ""

if ($adminInput -eq "y" -and -not $isAdmin) {
    Write-Host "  [WARN] You said yes but this session is NOT elevated." -ForegroundColor Yellow
    Add-Result "Admin Check" "WARN" "User claimed admin but session is not elevated" "MEDIUM"
} elseif ($isAdmin) {
    Write-Host "  [OK] Running as Administrator. Full scan enabled." -ForegroundColor Green
} else {
    Write-Host "  [INFO] Not running as Administrator. Some checks will be limited." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  Starting scan..." -ForegroundColor DarkGray
Start-Sleep -Milliseconds 400

Write-Section "Modrinth Mod Verification"

$modsPath = Join-Path $mcPath "mods"
if (Test-Path $modsPath) {
    $jarFiles = Get-ChildItem -Path $modsPath -Filter "*.jar" -Recurse -ErrorAction SilentlyContinue
    Write-Host "  Found $($jarFiles.Count) mod(s) in: $modsPath" -ForegroundColor DarkGray
    Write-Host "  Checking each mod via hash lookup + name search..." -ForegroundColor DarkGray
    Write-Host ""

    foreach ($jar in $jarFiles) {
        $nameLower = $jar.Name.ToLower()
        Write-Host "  Checking: $($jar.Name)" -ForegroundColor White

        $isSuspectName = $false
        $matchedKw = ""
        foreach ($kw in $cheatKeywords) {
            if ($nameLower -like "*$kw*") { $isSuspectName = $true; $matchedKw = $kw; break }
        }

        if ($isSuspectName) {
            Write-Host "  [HIGH]   Suspicious filename -- keyword: $matchedKw" -ForegroundColor Red
            Write-Host "           Path: $($jar.FullName)" -ForegroundColor DarkGray
            Write-Host ""
            Add-Result "Mod Check" "SUSPECT NAME" "$($jar.FullName) [keyword: $matchedKw]" "HIGH"
            continue
        }

        $hashCheck = Check-ModrinthByHash $jar.FullName
        if ($hashCheck.Found -eq $true) {
            Write-Host "  [OK]     Verified on Modrinth via file hash" -ForegroundColor Green
            Write-Host "           Project ID: $($hashCheck.ProjectId)  |  Version: $($hashCheck.Version)" -ForegroundColor DarkGray
            Write-Host ""
            Add-Result "Mod Check" "HASH VERIFIED" "$($jar.Name) -- Project: $($hashCheck.ProjectId) v$($hashCheck.Version)" "INFO"
            continue
        }

        $nameCheck = Check-ModrinthByName $jar.Name
        if ($nameCheck.Found -eq $true) {
            Write-Host "  [OK]     Found on Modrinth by name" -ForegroundColor Green
            Write-Host "           Title: $($nameCheck.Title)  |  Slug: $($nameCheck.Slug)" -ForegroundColor DarkGray
            Write-Host ""
            Add-Result "Mod Check" "NAME VERIFIED" "$($jar.Name) -- $($nameCheck.Title) (modrinth.com/mod/$($nameCheck.Slug))" "INFO"
        } elseif ($nameCheck.Found -eq $false) {
            Write-Host "  [WARN]   NOT found on Modrinth (hash or name)" -ForegroundColor Yellow
            Write-Host "           This mod is unknown -- could be a private/cheat mod" -ForegroundColor DarkYellow
            Write-Host "           Path: $($jar.FullName)" -ForegroundColor DarkGray
            Write-Host ""
            Add-Result "Mod Check" "NOT ON MODRINTH" $jar.FullName "MEDIUM"
        } else {
            Write-Host "  [INFO]   Could not reach Modrinth API" -ForegroundColor DarkGray
            Write-Host ""
            Add-Result "Mod Check" "API UNREACHABLE" $jar.FullName "INFO"
        }
    }
} else {
    Write-Host "  No mods folder found at: $modsPath" -ForegroundColor DarkGray
}

Write-Section "Running Processes (Full List + Cheat Check)"

$runningProcs = Get-Process -ErrorAction SilentlyContinue | Sort-Object ProcessName
Write-Host "  Total running processes: $($runningProcs.Count)" -ForegroundColor DarkGray
Write-Host ""

foreach ($proc in $runningProcs) {
    $isSuspect = $false
    $matchedKw = ""
    $procLower = $proc.ProcessName.ToLower()
    foreach ($kw in $cheatKeywords) {
        if ($procLower -like "*$kw*") { $isSuspect = $true; $matchedKw = $kw; break }
    }
    foreach ($cp in $cheatProcessNames) {
        if ($procLower -like "*$($cp.ToLower())*") { $isSuspect = $true; $matchedKw = $cp; break }
    }
    try { $path = $proc.MainModule.FileName } catch { $path = "N/A" }

    if ($isSuspect) {
        Write-Host "  [HIGH]  $($proc.ProcessName)  PID: $($proc.Id)" -ForegroundColor Red
        Write-Host "          Path: $path" -ForegroundColor DarkGray
        Write-Host "          Matched: $matchedKw" -ForegroundColor DarkRed
        Add-Result "Process" "SUSPECT" "$($proc.ProcessName) (PID $($proc.Id)) | Path: $path | Keyword: $matchedKw" "HIGH"
    } else {
        Write-Host "  [OK]    $($proc.ProcessName)  PID: $($proc.Id)  |  $path" -ForegroundColor DarkGray
        Add-Result "Process" "CLEAN" "$($proc.ProcessName) (PID $($proc.Id)) | $path" "INFO"
    }
}

Write-Section "javaw.exe Injection + String Scan"

$javaw = Get-Process -Name "javaw" -ErrorAction SilentlyContinue
if ($javaw) {
    foreach ($proc in $javaw) {
        Write-Host "  Found javaw.exe  PID: $($proc.Id)" -ForegroundColor DarkGray
        Write-Host ""

        try {
            $modules = $proc.Modules | Sort-Object FileName
            Write-Host "  Loaded modules ($($modules.Count) total):" -ForegroundColor DarkGray
            Write-Host ""
            foreach ($mod in $modules) {
                $modName = [System.IO.Path]::GetFileName($mod.FileName).ToLower()
                $isSuspect = $false
                $matchedKw = ""
                foreach ($kw in $cheatKeywords) {
                    if ($modName -like "*$kw*") { $isSuspect = $true; $matchedKw = $kw; break }
                }
                if ($isSuspect) {
                    Write-Host "  [HIGH]  $($mod.FileName)" -ForegroundColor Red
                    Write-Host "          Matched: $matchedKw" -ForegroundColor DarkRed
                    Add-Result "DLL Inject" "SUSPECT" "$($mod.FileName) [keyword: $matchedKw]" "HIGH"
                } else {
                    Write-Host "  [OK]    $($mod.FileName)" -ForegroundColor DarkGray
                    Add-Result "DLL Inject" "CLEAN" $mod.FileName "INFO"
                }
            }
        } catch {
            Write-Host "  [WARN] Cannot read modules -- run as Administrator for full scan" -ForegroundColor Yellow
            Add-Result "DLL Inject" "SKIPPED" "Insufficient permissions for PID $($proc.Id)" "MEDIUM"
        }

        Write-Host ""
        Write-Host "  Scanning javaw command line..." -ForegroundColor DarkGray
        try {
            $wmi = Get-WmiObject Win32_Process -Filter "ProcessId=$($proc.Id)" -ErrorAction Stop
            $cmdLine = $wmi.CommandLine
            $cmdLower = $cmdLine.ToLower()
            Write-Host "  Command line captured. Scanning keywords..." -ForegroundColor DarkGray
            Add-Result "javaw Strings" "CMDLINE" $cmdLine "INFO"

            foreach ($kw in $cheatKeywords) {
                if ($cmdLine -and $cmdLower -like "*$kw*") {
                    $kwIndex = $cmdLower.IndexOf($kw)
                    $start   = [Math]::Max(0, $kwIndex - 80)
                    $len     = [Math]::Min(160, $cmdLine.Length - $start)
                    $context = $cmdLower.Substring($start, $len)

                    $isWhitelisted = $false
                    foreach ($legit in $legitimateCmdLineContexts) {
                        if ($context -like "*$legit*") { $isWhitelisted = $true; break }
                    }

                    if (-not $isWhitelisted) {
                        Write-Host "  [HIGH] Keyword '$kw' in command line" -ForegroundColor Red
                        Write-Host "         Context: ...$(($cmdLine.Substring($start,$len)).Trim())..." -ForegroundColor DarkRed
                        Add-Result "javaw Strings" "SUSPECT CMDLINE" "Keyword '$kw' | context: $($cmdLine.Substring($start,$len).Trim())" "HIGH"
                    } else {
                        Write-Host "  [OK]   '$kw' linked to known launcher -- whitelisted" -ForegroundColor DarkGray
                        Add-Result "javaw Strings" "WHITELISTED" "Keyword '$kw' near known launcher" "INFO"
                    }
                }
            }
        } catch {
            Write-Host "  [INFO] Could not read command line." -ForegroundColor DarkGray
        }
    }
} else {
    Write-Host "  javaw.exe is not currently running." -ForegroundColor DarkGray
    Add-Result "DLL Inject" "INFO" "javaw.exe not running" "INFO"
}

Write-Section "ProcessHacker Check"

$phPaths = @(
    "C:\Program Files\Process Hacker 2\ProcessHacker.exe",
    "C:\Program Files\System Informer\SystemInformer.exe",
    "C:\Program Files (x86)\Process Hacker 2\ProcessHacker.exe"
)
$phCLI = @(
    "C:\Program Files\Process Hacker 2\phcmd.exe",
    "C:\Program Files\System Informer\phcmd.exe"
)

$phRunning   = Get-Process -Name "ProcessHacker","SystemInformer" -ErrorAction SilentlyContinue
$phInstalled = $phPaths | Where-Object { Test-Path $_ }
$phCLIPath   = $phCLI   | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($phRunning) {
    Write-Host "  [HIGH] ProcessHacker is currently RUNNING" -ForegroundColor Red
    foreach ($p in $phRunning) {
        Write-Host "         $($p.ProcessName)  PID: $($p.Id)" -ForegroundColor DarkRed
        Add-Result "ProcessHacker" "RUNNING" "$($p.ProcessName) PID $($p.Id)" "HIGH"
    }
} elseif ($phInstalled) {
    Write-Host "  [MEDIUM] ProcessHacker installed but not running:" -ForegroundColor Yellow
    foreach ($ph in $phInstalled) { Write-Host "           $ph" -ForegroundColor DarkYellow }
    Add-Result "ProcessHacker" "INSTALLED" ($phInstalled -join ", ") "MEDIUM"
} else {
    Write-Host "  ProcessHacker not found. Skipping." -ForegroundColor DarkGray
    Write-Host "  Download from: https://processhacker.sourceforge.net" -ForegroundColor DarkGray
}

if ($phCLIPath -and $javaw) {
    Write-Host ""
    Write-Host "  Running ProcessHacker CLI dump on javaw..." -ForegroundColor DarkGray
    foreach ($proc in $javaw) {
        try {
            $phOut = & $phCLIPath -c -ctype process -filter "Pid=$($proc.Id)" 2>&1
            Write-Host "  PH Output for PID $($proc.Id):" -ForegroundColor DarkGray
            $phOut | ForEach-Object {
                $line = $_.ToString()
                $isSuspect = $false
                $matchedKw = ""
                foreach ($kw in $cheatKeywords) {
                    if ($line.ToLower() -like "*$kw*") { $isSuspect = $true; $matchedKw = $kw; break }
                }
                if ($isSuspect) {
                    Write-Host "  [HIGH] $line" -ForegroundColor Red
                    Add-Result "PH Dump" "SUSPECT" "$line [keyword: $matchedKw]" "HIGH"
                } else {
                    Write-Host "         $line" -ForegroundColor DarkGray
                    Add-Result "PH Dump" "CLEAN" $line "INFO"
                }
            }
        } catch {
            Write-Host "  [WARN] ProcessHacker CLI failed for PID $($proc.Id)" -ForegroundColor Yellow
        }
    }
}

Write-Section "Echo Journal Check"

$echoPath = "$env:APPDATA\EchoJournal"
if (Test-Path $echoPath) {
    $echoFiles = Get-ChildItem -Path $echoPath -Recurse -ErrorAction SilentlyContinue
    Write-Host "  Echo Journal found: $echoPath" -ForegroundColor Yellow
    Write-Host "  Files ($($echoFiles.Count) total):" -ForegroundColor DarkGray
    Write-Host ""
    foreach ($f in $echoFiles) {
        Write-Host "  $($f.FullName)" -ForegroundColor DarkGray
        Add-Result "Echo Journal" "FOUND" $f.FullName "LOW"
        if ($f.Extension -in @(".txt",".log",".json")) {
            try {
                $content = Get-Content $f.FullName -ErrorAction SilentlyContinue -Raw
                foreach ($kw in $cheatKeywords) {
                    if ($content -and $content.ToLower() -like "*$kw*") {
                        Write-Host "  [HIGH] Keyword '$kw' found inside: $($f.Name)" -ForegroundColor Red
                        Add-Result "Echo Journal" "SUSPECT CONTENT" "$($f.FullName) contains: $kw" "HIGH"
                    }
                }
            } catch {}
        }
    }
} else {
    Write-Host "  Echo Journal not found. Skipping." -ForegroundColor DarkGray
}

Write-Section "Recycle Bin Scan"

$recyclePath = "C:\`$Recycle.Bin"
if (Test-Path $recyclePath) {
    $allDeleted = Get-ChildItem -Path $recyclePath -Recurse -ErrorAction SilentlyContinue
    Write-Host "  Total items in Recycle Bin: $($allDeleted.Count)" -ForegroundColor DarkGray
    Write-Host ""
    foreach ($d in $allDeleted) {
        $nameLower = $d.Name.ToLower()
        $isSuspect = $false
        $matchedKw = ""
        foreach ($kw in $cheatKeywords) {
            if ($nameLower -like "*$kw*") { $isSuspect = $true; $matchedKw = $kw; break }
        }
        if ($isSuspect) {
            Write-Host "  [MEDIUM] $($d.FullName)" -ForegroundColor Yellow
            Write-Host "           Matched: $matchedKw" -ForegroundColor DarkYellow
            Add-Result "Recycle Bin" "SUSPECT" "$($d.FullName) [keyword: $matchedKw]" "MEDIUM"
        } else {
            Write-Host "  [OK]     $($d.Name)" -ForegroundColor DarkGray
            Add-Result "Recycle Bin" "CLEAN" $d.Name "INFO"
        }
    }
} else {
    Write-Host "  Could not access Recycle Bin." -ForegroundColor DarkGray
}

Write-Section "Temp / AppData Traces"

foreach ($dir in @("$env:TEMP","$env:LOCALAPPDATA\Temp","$env:APPDATA")) {
    if (Test-Path $dir) {
        $items = Get-ChildItem -Path $dir -ErrorAction SilentlyContinue
        Write-Host "  Scanning: $dir ($($items.Count) items)" -ForegroundColor DarkGray
        foreach ($i in $items) {
            $nameLower = $i.Name.ToLower()
            $isSuspect = $false
            $matchedKw = ""
            foreach ($kw in $cheatKeywords) {
                if ($nameLower -like "*$kw*") { $isSuspect = $true; $matchedKw = $kw; break }
            }
            if ($isSuspect) {
                Write-Host "  [MEDIUM] $($i.FullName)" -ForegroundColor Yellow
                Write-Host "           Matched: $matchedKw" -ForegroundColor DarkYellow
                Add-Result "Temp/AppData" "SUSPECT" "$($i.FullName) [keyword: $matchedKw]" "MEDIUM"
            }
        }
    }
}

Write-Section "Registry Traces"

$regPaths = @(
    "HKCU:\Software\Vape","HKCU:\Software\LiquidBounce",
    "HKCU:\Software\MeteorClient","HKCU:\Software\WurstClient",
    "HKCU:\Software\FutureClient","HKCU:\Software\Sigma",
    "HKCU:\Software\Cheat Engine","HKLM:\SOFTWARE\Cheat Engine",
    "HKCU:\Software\Rusherhack","HKCU:\Software\Novoline",
    "HKCU:\Software\Inertia","HKCU:\Software\Rise","HKCU:\Software\Ares"
)

$regFound = $false
foreach ($rp in $regPaths) {
    if (Test-Path $rp) {
        Write-Host "  [MEDIUM] $rp" -ForegroundColor Yellow
        try {
            $vals = Get-ItemProperty -Path $rp -ErrorAction SilentlyContinue
            $vals.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } | ForEach-Object {
                Write-Host "           $($_.Name) = $($_.Value)" -ForegroundColor DarkYellow
            }
        } catch {}
        Add-Result "Registry" "FOUND" $rp "MEDIUM"
        $regFound = $true
    }
}
if (-not $regFound) { Write-Host "  No suspicious registry keys found." -ForegroundColor DarkGray }

Write-Host ""
Write-Host "  ╔══════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║            SCAN RESULTS              ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$highs   = $results | Where-Object { $_.Severity -eq "HIGH" }
$mediums = $results | Where-Object { $_.Severity -eq "MEDIUM" }
$lows    = $results | Where-Object { $_.Severity -eq "LOW" }
$infos   = $results | Where-Object { $_.Severity -eq "INFO" }

if ($highs.Count -gt 0) {
    Write-Host "  [HIGH]  $($highs.Count) finding(s):" -ForegroundColor Red
    foreach ($r in $highs) {
        Write-Host "    [$($r.Category)]  $($r.Status)" -ForegroundColor Red
        Write-Host "    $($r.Detail)" -ForegroundColor DarkRed
        Write-Host ""
    }
}
if ($mediums.Count -gt 0) {
    Write-Host "  [MEDIUM]  $($mediums.Count) finding(s):" -ForegroundColor Yellow
    foreach ($r in $mediums) {
        Write-Host "    [$($r.Category)]  $($r.Status)" -ForegroundColor Yellow
        Write-Host "    $($r.Detail)" -ForegroundColor DarkYellow
        Write-Host ""
    }
}
if ($lows.Count -gt 0) {
    Write-Host "  [LOW]  $($lows.Count) finding(s):" -ForegroundColor DarkYellow
    foreach ($r in $lows) { Write-Host "    [$($r.Category)]  $($r.Detail)" -ForegroundColor DarkYellow }
    Write-Host ""
}
if ($infos.Count -gt 0) {
    Write-Host "  [INFO]  $($infos.Count) finding(s):" -ForegroundColor Gray
    foreach ($r in $infos) { Write-Host "    [$($r.Category)]  $($r.Detail)" -ForegroundColor Gray }
    Write-Host ""
}

if ($flagged -eq 0) {
    Write-Host "  Player appears clean. No significant findings." -ForegroundColor Green
} else {
    Write-Host "  Total flagged findings: $flagged" -ForegroundColor Red
}

Write-Host ""
Write-Host "  ──────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Enter a folder path to save the results log:" -ForegroundColor White
Write-Host "  (Leave blank to skip)" -ForegroundColor DarkGray
Write-Host ""
$saveFolder = Read-Host "  Results folder"

if (-not [string]::IsNullOrWhiteSpace($saveFolder)) {
    $saveFolder = $saveFolder.Trim().Trim('"')
    if (-not (Test-Path $saveFolder)) { New-Item -ItemType Directory -Path $saveFolder -Force | Out-Null }
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logFile = Join-Path $saveFolder "SSI-Results_$timestamp.txt"

    $lines = @()
    $lines += "Joqle Screen Share Tool v$version"
    $lines += "Scan Date  : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $lines += "MC Path    : $mcPath"
    $lines += "Admin      : $isAdmin"
    $lines += "Flagged    : $flagged"
    $lines += ""
    $lines += "══════════════════════════════════════"
    $lines += "HIGH SEVERITY ($($highs.Count))"
    $lines += "══════════════════════════════════════"
    foreach ($r in $highs)   { $lines += "[$($r.Category)]  $($r.Status)"; $lines += "  $($r.Detail)"; $lines += "" }
    $lines += "══════════════════════════════════════"
    $lines += "MEDIUM SEVERITY ($($mediums.Count))"
    $lines += "══════════════════════════════════════"
    foreach ($r in $mediums) { $lines += "[$($r.Category)]  $($r.Status)"; $lines += "  $($r.Detail)"; $lines += "" }
    $lines += "══════════════════════════════════════"
    $lines += "LOW ($($lows.Count))"
    $lines += "══════════════════════════════════════"
    foreach ($r in $lows)    { $lines += "[$($r.Category)]  $($r.Detail)" }
    $lines += ""
    $lines += "══════════════════════════════════════"
    $lines += "INFO ($($infos.Count))"
    $lines += "══════════════════════════════════════"
    foreach ($r in $infos)   { $lines += "[$($r.Category)]  $($r.Detail)" }

    $lines | Out-File -FilePath $logFile -Encoding UTF8
    Write-Host ""
    Write-Host "  Results saved to: $logFile" -ForegroundColor Green
}

Write-Host ""
Write-Host "  Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
