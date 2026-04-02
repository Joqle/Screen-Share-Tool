$version = "2.0"
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

function Check-Modrinth([string]$jarName) {
    try {
        $slug = [System.IO.Path]::GetFileNameWithoutExtension($jarName)
        $slug = $slug -replace '[-_\s]?\d[\d\.\-\+\_]*$', ''
        $slug = $slug -replace '[-_](fabric|forge|quilt|neoforge|mc|minecraft).*$', ''
        $slug = $slug.ToLower().Trim()
        $url = "https://api.modrinth.com/v2/search?query=$([uri]::EscapeDataString($slug))&limit=5&facets=[[%22project_type:mod%22]]"
        $resp = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 6 -ErrorAction Stop
        foreach ($hit in $resp.hits) {
            $hitSlug  = $hit.slug.ToLower()
            $hitTitle = $hit.title.ToLower()
            if ($slug -like "*$hitSlug*" -or $hitSlug -like "*$slug*" -or $slug -like "*$hitTitle*") {
                return @{ Found = $true; Title = $hit.title }
            }
        }
        return @{ Found = $false }
    } catch {
        return @{ Found = $null }
    }
}

Write-Banner

Write-Host "  Enter the path to the .minecraft folder to scan:" -ForegroundColor White
Write-Host "  (Leave blank to use default: $env:APPDATA\.minecraft)" -ForegroundColor DarkGray
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
    Write-Host ""
    Write-Host "  Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

Write-Host "  Path set: $mcPath" -ForegroundColor Green
Write-Host ""

Write-Host "  Are you running this as Administrator? (y/n)" -ForegroundColor White
$adminInput = Read-Host "  Answer"
Write-Host ""

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($adminInput.Trim().ToLower() -eq "y" -and -not $isAdmin) {
    Write-Host "  [WARN] You said yes but this session is NOT running as Administrator." -ForegroundColor Yellow
    Write-Host "         Some checks (DLL injection, process modules) may be limited." -ForegroundColor DarkGray
    Add-Result "Admin Check" "WARN" "User claimed admin but session is not elevated" "MEDIUM"
} elseif ($isAdmin) {
    Write-Host "  [OK] Running as Administrator. Full scan enabled." -ForegroundColor Green
} else {
    Write-Host "  [INFO] Not running as Administrator. Some checks will be limited." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  Starting scan..." -ForegroundColor DarkGray
Start-Sleep -Milliseconds 600

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
    "extremedumper","bytecode","javaagent",
    "autoclicker","autoclick","opautoclicker",
    "ghostware","ghost client","payload","bypass"
)

$cheatProcessNames = @(
    "Vape","VapeV4","VapeLite","VapeNano",
    "Drip","DripLite",
    "Liquid","LiquidBounce",
    "Meteor","MeteorClient",
    "Wurst","WurstClient",
    "Impact","ImpactClient",
    "Future","FutureClient",
    "Reflex","Sigma","Ares","Rise","Entropy",
    "Inertia","Rusherhack","Novoline",
    "Xenos","ExtremeDumper",
    "CheatEngine","cheatengine-x86_64","cheatengine-i386",
    "ScyllaHide","x64dbg","x32dbg","ollydbg",
    "injector","dllinjector","syringe",
    "AutoClicker","AutoClick","OpAutoClicker"
)

Write-Section "Modrinth Mod Check"

$modsPath = Join-Path $mcPath "mods"
if (Test-Path $modsPath) {
    $jarFiles = Get-ChildItem -Path $modsPath -Filter "*.jar" -ErrorAction SilentlyContinue
    if ($jarFiles.Count -eq 0) {
        Write-Host "  No .jar files found in mods folder." -ForegroundColor DarkGray
    } else {
        Write-Host "  Checking $($jarFiles.Count) mod(s) against Modrinth..." -ForegroundColor DarkGray
        Write-Host ""
        foreach ($jar in $jarFiles) {
            $nameLower = $jar.Name.ToLower()
            $isSuspectName = $false
            foreach ($kw in $cheatKeywords) {
                if ($nameLower -like "*$kw*") { $isSuspectName = $true; break }
            }

            if ($isSuspectName) {
                Write-Host "  [HIGH] $($jar.Name) -- suspicious name" -ForegroundColor Red
                Add-Result "Mod Check" "SUSPECT NAME" $jar.FullName "HIGH"
                continue
            }

            $check = Check-Modrinth $jar.Name
            if ($check.Found -eq $true) {
                Write-Host "  [OK]   $($jar.Name)" -ForegroundColor Green
                Write-Host "         Modrinth: $($check.Title)" -ForegroundColor DarkGray
                Add-Result "Mod Check" "CLEAN" "$($jar.Name) -- $($check.Title)" "INFO"
            } elseif ($check.Found -eq $false) {
                Write-Host "  [WARN] $($jar.Name) -- not found on Modrinth" -ForegroundColor Yellow
                Add-Result "Mod Check" "NOT ON MODRINTH" $jar.FullName "MEDIUM"
            } else {
                Write-Host "  [INFO] $($jar.Name) -- could not reach Modrinth API" -ForegroundColor DarkGray
                Add-Result "Mod Check" "API UNREACHABLE" $jar.FullName "INFO"
            }
        }
    }
} else {
    Write-Host "  No mods folder found at: $modsPath" -ForegroundColor DarkGray
}

Write-Section "Running Processes"

$runningProcs = Get-Process -ErrorAction SilentlyContinue
foreach ($cp in $cheatProcessNames) {
    $found = $runningProcs | Where-Object { $_.ProcessName -like "*$cp*" }
    foreach ($p in $found) {
        Write-Host "  [HIGH] $($p.ProcessName)  (PID $($p.Id))" -ForegroundColor Red
        Add-Result "Process" "FOUND" "$($p.ProcessName) (PID $($p.Id))" "HIGH"
    }
}

Write-Section "javaw.exe Injection Scan"

$javaw = Get-Process -Name "javaw" -ErrorAction SilentlyContinue
if ($javaw) {
    foreach ($proc in $javaw) {
        Write-Host "  Found javaw.exe  PID $($proc.Id)" -ForegroundColor DarkGray
        try {
            $modules = $proc.Modules | Select-Object -ExpandProperty FileName -ErrorAction SilentlyContinue
            $clean = $true
            foreach ($mod in $modules) {
                $modLower = [System.IO.Path]::GetFileName($mod).ToLower()
                foreach ($kw in $cheatKeywords) {
                    if ($modLower -like "*$kw*") {
                        Write-Host "  [HIGH] Suspicious DLL: $mod" -ForegroundColor Red
                        Add-Result "DLL Inject" "SUSPECT" $mod "HIGH"
                        $clean = $false
                    }
                }
            }
            if ($clean) {
                Write-Host "  [OK]  No suspicious DLLs found in javaw.exe" -ForegroundColor Green
            }
        } catch {
            Write-Host "  [WARN] Could not read modules for PID $($proc.Id) -- try running as Admin" -ForegroundColor Yellow
            Add-Result "DLL Inject" "SKIPPED" "Insufficient permissions for PID $($proc.Id)" "LOW"
        }
    }
} else {
    Write-Host "  javaw.exe is not running." -ForegroundColor DarkGray
    Add-Result "DLL Inject" "INFO" "javaw.exe not running" "INFO"
}

Write-Section "ProcessHacker / Echo Journal Check"

$phPath1 = "C:\Program Files\Process Hacker 2\ProcessHacker.exe"
$phPath2 = "C:\Program Files\System Informer\SystemInformer.exe"
$phRunning = Get-Process -Name "ProcessHacker","SystemInformer" -ErrorAction SilentlyContinue

if ($phRunning) {
    Write-Host "  [HIGH] ProcessHacker / System Informer is currently RUNNING" -ForegroundColor Red
    Add-Result "ProcessHacker" "RUNNING" $phRunning[0].ProcessName "HIGH"
} elseif ((Test-Path $phPath1) -or (Test-Path $phPath2)) {
    Write-Host "  [MEDIUM] ProcessHacker is installed but not running" -ForegroundColor Yellow
    Add-Result "ProcessHacker" "INSTALLED" "Found on disk but not active" "MEDIUM"
} else {
    Write-Host "  ProcessHacker not found. Skipping." -ForegroundColor DarkGray
    Write-Host "  Note: To use ProcessHacker checks, download it from processhacker.sourceforge.net" -ForegroundColor DarkGray
}

$echoJournalPath = "$env:APPDATA\EchoJournal"
if (Test-Path $echoJournalPath) {
    Write-Host ""
    Write-Host "  [INFO] Echo Journal folder found: $echoJournalPath" -ForegroundColor Yellow
    $logs = Get-ChildItem -Path $echoJournalPath -Recurse -ErrorAction SilentlyContinue | Select-Object -First 10
    foreach ($l in $logs) {
        Add-Result "Echo Journal" "FOUND" $l.FullName "LOW"
    }
} else {
    Write-Host ""
    Write-Host "  Echo Journal not found. Skipping." -ForegroundColor DarkGray
}

Write-Section "Recycle Bin Scan"

$recyclePath = "C:\`$Recycle.Bin"
if (Test-Path $recyclePath) {
    $deleted = Get-ChildItem -Path $recyclePath -Recurse -ErrorAction SilentlyContinue |
        Where-Object {
            $n = $_.Name.ToLower()
            $cheatKeywords | Where-Object { $n -like "*$_*" }
        }
    if ($deleted) {
        foreach ($d in $deleted) {
            Write-Host "  [MEDIUM] Deleted file: $($d.Name)" -ForegroundColor Yellow
            Add-Result "Recycle Bin" "SUSPECT" $d.FullName "MEDIUM"
        }
    } else {
        Write-Host "  No suspicious files found in Recycle Bin." -ForegroundColor DarkGray
    }
} else {
    Write-Host "  Could not access Recycle Bin." -ForegroundColor DarkGray
}

Write-Section "Temp / AppData Traces"

foreach ($dir in @("$env:TEMP","$env:LOCALAPPDATA\Temp","$env:APPDATA")) {
    if (Test-Path $dir) {
        $items = Get-ChildItem -Path $dir -ErrorAction SilentlyContinue |
            Where-Object { $n = $_.Name.ToLower(); $cheatKeywords | Where-Object { $n -like "*$_*" } }
        foreach ($i in $items) {
            Write-Host "  [MEDIUM] $($i.FullName)" -ForegroundColor Yellow
            Add-Result "Temp/AppData" "SUSPECT" $i.FullName "MEDIUM"
        }
    }
}

Write-Section "Registry Traces"

$regPaths = @(
    "HKCU:\Software\Vape",
    "HKCU:\Software\LiquidBounce",
    "HKCU:\Software\MeteorClient",
    "HKCU:\Software\WurstClient",
    "HKCU:\Software\FutureClient",
    "HKCU:\Software\Sigma",
    "HKCU:\Software\Cheat Engine",
    "HKLM:\SOFTWARE\Cheat Engine",
    "HKCU:\Software\Rusherhack",
    "HKCU:\Software\Novoline"
)

$regFound = $false
foreach ($rp in $regPaths) {
    if (Test-Path $rp) {
        Write-Host "  [MEDIUM] Registry key found: $rp" -ForegroundColor Yellow
        Add-Result "Registry" "FOUND" $rp "MEDIUM"
        $regFound = $true
    }
}
if (-not $regFound) {
    Write-Host "  No suspicious registry keys found." -ForegroundColor DarkGray
}

Write-Host ""
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
    Write-Host "  [HIGH]  $($highs.Count) high-severity finding(s):" -ForegroundColor Red
    foreach ($r in $highs) { Write-Host "    [$($r.Category)]  $($r.Detail)" -ForegroundColor Red }
    Write-Host ""
}
if ($mediums.Count -gt 0) {
    Write-Host "  [MEDIUM]  $($mediums.Count) medium-severity finding(s):" -ForegroundColor Yellow
    foreach ($r in $mediums) { Write-Host "    [$($r.Category)]  $($r.Detail)" -ForegroundColor Yellow }
    Write-Host ""
}
if ($lows.Count -gt 0) {
    Write-Host "  [LOW]  $($lows.Count) low-severity finding(s):" -ForegroundColor DarkYellow
    foreach ($r in $lows) { Write-Host "    [$($r.Category)]  $($r.Detail)" -ForegroundColor DarkYellow }
    Write-Host ""
}
if ($infos.Count -gt 0) {
    Write-Host "  [INFO]  $($infos.Count) informational finding(s):" -ForegroundColor Gray
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
    if (-not (Test-Path $saveFolder)) {
        New-Item -ItemType Directory -Path $saveFolder -Force | Out-Null
    }
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $logFile = Join-Path $saveFolder "SSI-Results_$timestamp.txt"

    $lines = @()
    $lines += "Joqle Screen Share Tool v$version"
    $lines += "Scan Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $lines += "Minecraft Path: $mcPath"
    $lines += "Admin Session: $isAdmin"
    $lines += "Total Flagged: $flagged"
    $lines += ""
    $lines += "══════════════════════════════════════"
    $lines += "HIGH SEVERITY"
    $lines += "══════════════════════════════════════"
    foreach ($r in $highs)   { $lines += "[$($r.Category)]  $($r.Detail)" }
    $lines += ""
    $lines += "══════════════════════════════════════"
    $lines += "MEDIUM SEVERITY"
    $lines += "══════════════════════════════════════"
    foreach ($r in $mediums) { $lines += "[$($r.Category)]  $($r.Detail)" }
    $lines += ""
    $lines += "══════════════════════════════════════"
    $lines += "LOW / INFO"
    $lines += "══════════════════════════════════════"
    foreach ($r in ($lows + $infos)) { $lines += "[$($r.Category)]  $($r.Detail)" }

    $lines | Out-File -FilePath $logFile -Encoding UTF8
    Write-Host ""
    Write-Host "  Results saved to: $logFile" -ForegroundColor Green
}

Write-Host ""
Write-Host "  Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
