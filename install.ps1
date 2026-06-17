param(
    [string]$Dest,
    [ValidateSet("all", "codex", "claude")]
    [string]$Target = "all",
    [string]$CodexDest,
    [string]$ClaudeDest,
    [string]$Version = "latest",
    [switch]$Latest,
    [string]$Repo = "https://github.com/bjornjac/ai-skills",
    [string]$Ref = "main",
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Usage:
  Install-AiSkills [-Dest <path>] [-Target all|codex|claude] [-CodexDest <path>] [-ClaudeDest <path>] [-Version <v> | -Latest] [-Repo <url>] [-Ref <ref>]

Defaults:
  Target: all
  CodexDest: `$env:CODEX_HOME\skills when CODEX_HOME is set, otherwise `$HOME\.codex\skills
  ClaudeDest: `$env:CLAUDE_HOME\skills when CLAUDE_HOME is set, otherwise `$HOME\.claude\skills
  Version: latest GitHub release
  Repo: https://github.com/bjornjac/ai-skills
  Ref: main fallback branch when a release is unavailable
"@
    exit 0
}

function Get-AiSkillsDefaultCodexDest {
    if ($env:CODEX_HOME) {
        return (Join-Path $env:CODEX_HOME "skills")
    }

    return (Join-Path (Join-Path $HOME ".codex") "skills")
}

function Get-AiSkillsDefaultClaudeDest {
    if ($env:CLAUDE_HOME) {
        return (Join-Path $env:CLAUDE_HOME "skills")
    }

    return (Join-Path (Join-Path $HOME ".claude") "skills")
}

function Install-AiSkills {
    param(
        [string]$Dest,
        [ValidateSet("all", "codex", "claude")]
        [string]$Target = "all",
        [string]$CodexDest,
        [string]$ClaudeDest,
        [string]$Version = "latest",
        [switch]$Latest,
        [string]$Repo = "https://github.com/bjornjac/ai-skills",
        [string]$Ref = "main"
    )

    $ErrorActionPreference = "Stop"

    if (-not $CodexDest) {
        $CodexDest = Get-AiSkillsDefaultCodexDest
    }

    if (-not $ClaudeDest) {
        $ClaudeDest = Get-AiSkillsDefaultClaudeDest
    }

    if ($Latest) {
        $Version = "latest"
    }

    if (-not $Repo -or -not $Ref -or -not $Version) {
        throw "Repo, Ref, and Version must not be empty."
    }

    $scriptPath = $MyInvocation.MyCommand.Path
    $scriptDir = if ($scriptPath) { Split-Path -Parent $scriptPath } else { $null }
    $localSkills = if ($scriptDir) { Join-Path $scriptDir "skills" } else { $null }
    $tmpDir = $null

    try {
        if ($localSkills -and (Test-Path (Join-Path $scriptDir "install.ps1")) -and (Test-Path $localSkills)) {
            $src = $localSkills
        } else {
            $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
            New-Item -ItemType Directory -Path $tmpDir | Out-Null

            $archivePath = Join-Path $tmpDir "ai-skills.tar.gz"
            if ($Version -eq "latest") {
                $archiveUrl = "$Repo/releases/latest/download/installer.tgz"
            } elseif ($Version.StartsWith("v")) {
                $archiveUrl = "$Repo/releases/download/$Version/installer.tgz"
            } else {
                $archiveUrl = "$Repo/releases/download/v$Version/installer.tgz"
            }

            try {
                Invoke-WebRequest -Uri $archiveUrl -OutFile $archivePath -UseBasicParsing
            } catch {
                Write-Warning "Release archive unavailable; falling back to $Ref branch archive..."
                $archiveUrl = "$Repo/archive/refs/heads/$Ref.tar.gz"
                Invoke-WebRequest -Uri $archiveUrl -OutFile $archivePath -UseBasicParsing
            }

            $tarCandidates = @("tar")
            if ($env:SystemRoot) {
                $tarCandidates = @(
                    (Join-Path $env:SystemRoot "System32\tar.exe"),
                    (Join-Path $env:SystemRoot "Sysnative\tar.exe")
                ) + $tarCandidates
            }
            $tarPath = $tarCandidates | Where-Object { Get-Command $_ -ErrorAction SilentlyContinue } | Select-Object -First 1
            if (-not $tarPath) {
                throw "tar was not found."
            }

            & $tarPath -xzf $archivePath -C $tmpDir
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to extract installer archive."
            }

            $src = Get-ChildItem -Path $tmpDir -Directory -Recurse -Filter "skills" | Select-Object -First 1 -ExpandProperty FullName
            if (-not $src -or -not (Test-Path $src)) {
                throw "Could not find skills directory in downloaded archive."
            }
        }

        function Install-AiSkillsTo {
            param(
                [string]$InstallDest,
                [string]$Label
            )

            if (-not $InstallDest) {
                throw "$Label destination must not be empty."
            }

            New-Item -ItemType Directory -Force -Path $InstallDest | Out-Null

            $installed = @()
            Get-ChildItem -Path $src -Directory | ForEach-Object {
                $skill = $_.FullName
                if (-not (Test-Path (Join-Path $skill "SKILL.md"))) {
                    return
                }

                $name = $_.Name
                $targetPath = Join-Path $InstallDest $name
                $staging = Join-Path $InstallDest ".$name.installing"

                Remove-Item -Force -Recurse $staging -ErrorAction SilentlyContinue
                Copy-Item -Recurse -Path $skill -Destination $staging
                Remove-Item -Force -Recurse $targetPath -ErrorAction SilentlyContinue
                Move-Item -Path $staging -Destination $targetPath

                $installed += $name
            }

            if ($installed.Count -eq 0) {
                throw "No skills found to install."
            }

            Write-Host "Installed $Label skills to ${InstallDest}:"
            foreach ($name in $installed) {
                Write-Host "  - $name"
            }
        }

        if ($Dest) {
            Install-AiSkillsTo -InstallDest $Dest -Label "custom"
        } else {
            switch ($Target) {
                "all" {
                    Install-AiSkillsTo -InstallDest $CodexDest -Label "Codex"
                    Install-AiSkillsTo -InstallDest $ClaudeDest -Label "Claude"
                }
                "codex" {
                    Install-AiSkillsTo -InstallDest $CodexDest -Label "Codex"
                }
                "claude" {
                    Install-AiSkillsTo -InstallDest $ClaudeDest -Label "Claude"
                }
            }
        }
    } finally {
        if ($tmpDir -and (Test-Path $tmpDir)) {
            Remove-Item -Force -Recurse $tmpDir
        }
    }
}

if ($MyInvocation.MyCommand.Path -and $MyInvocation.InvocationName -ne ".") {
    Install-AiSkills -Dest $Dest -Target $Target -CodexDest $CodexDest -ClaudeDest $ClaudeDest -Version $Version -Latest:$Latest -Repo $Repo -Ref $Ref
}
