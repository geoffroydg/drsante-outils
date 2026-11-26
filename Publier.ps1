# ===========================================================================
# PUBLICATION (cote administrateur) : cree le depot GitHub la 1re fois, puis
# envoie chaque modification. Les confreres la recoivent au demarrage suivant.
#
# Usage : double-clic sur Publier.bat (depuis le dossier du depot).
# Options : -Public (depot public, installation sans jeton) ; par defaut PRIVE.
# ===========================================================================
param(
    [string]$Nom = 'drsante-outils',
    [switch]$Public,
    [string]$Message = ''
)

# 'Continue' : les commandes natives (git, gh) ecrivent sur stderr sans que
# PowerShell 5.1 ne l'interprete comme une erreur ; on teste $LASTEXITCODE.
$ErrorActionPreference = 'Continue'
Set-Location -LiteralPath $PSScriptRoot

function Info($m) { Write-Host "[Publier] $m" -ForegroundColor Cyan }

function Update-PathSession {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}

# --- git et gh --------------------------------------------------------------
foreach ($outil in @(@{ cmd = 'git'; id = 'Git.Git' }, @{ cmd = 'gh'; id = 'GitHub.cli' })) {
    if (-not (Get-Command $outil.cmd -ErrorAction SilentlyContinue)) {
        Info "Installation de $($outil.cmd)..."
        & winget install --id $outil.id -e --silent --accept-package-agreements --accept-source-agreements
        Update-PathSession
        foreach ($p in @("$env:ProgramFiles\Git\cmd", "$env:ProgramFiles\GitHub CLI")) {
            if (Test-Path $p) { $env:Path += ";$p" }
        }
    }
    if (-not (Get-Command $outil.cmd -ErrorAction SilentlyContinue)) {
        throw "$($outil.cmd) introuvable apres installation. Fermez cette fenetre, rouvrez-la et relancez Publier.bat."
    }
}

# --- connexion GitHub (navigateur, une seule fois) --------------------------
& gh auth status 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Info 'Connexion a GitHub : suivez les instructions (navigateur).'
    & gh auth login --hostname github.com --git-protocol https --web
    if ($LASTEXITCODE -ne 0) { throw 'Connexion GitHub echouee.' }
}
& gh auth setup-git 2>$null | Out-Null

$login = (& gh api user -q .login).Trim()
$depot = "$login/$Nom"

# --- renseigne le depot dans l'installateur ---------------------------------
$inst = Join-Path $PSScriptRoot 'Installer.ps1'
$txt = [IO.File]::ReadAllText($inst)
if ($txt.Contains('__DEPOT__')) {
    [IO.File]::WriteAllText($inst, $txt.Replace('__DEPOT__', $depot), (New-Object Text.UTF8Encoding($true)))
}

# --- git : identite, commit -------------------------------------------------
if (-not (Test-Path (Join-Path $PSScriptRoot '.git'))) { & git init -b main | Out-Null }
if (-not (& git config user.name))  { & git config user.name $login }
if (-not (& git config user.email)) {
    $id = (& gh api user -q .id).Trim()
    & git config user.email "$id+$login@users.noreply.github.com"
}

# Garde-fou : aucun dossier patient ni config locale dans le depot
$interdits = & git ls-files | Where-Object { $_ -match '(^|/)Dossier patient/' -or $_ -match '(^|/)config\.ini$' }
if ($interdits) { throw "Fichiers interdits dans le depot : $($interdits -join ', ')" }

& git add -A
$statut = & git status --porcelain
if ($statut) {
    if (-not $Message) { $Message = 'Mise a jour ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') }
    & git commit -m $Message | Out-Null
    Info 'Modifications enregistrees.'
}

# --- creation du depot distant (1re fois) puis envoi ------------------------
& git remote get-url origin 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    $vis = if ($Public) { '--public' } else { '--private' }
    Info "Creation du depot $depot..."
    & gh repo create $depot $vis --source . --remote origin --push
    if ($LASTEXITCODE -ne 0) { throw 'Creation du depot echouee.' }
}
else {
    & git push -u origin main
    if ($LASTEXITCODE -ne 0) { throw 'Envoi echoue.' }
}

# --- consignes pour les confreres -------------------------------------------
$prive = ((& gh repo view $depot --json isPrivate -q .isPrivate) -eq 'true')
Write-Host ''
Write-Host "Depot : https://github.com/$depot" -ForegroundColor Green
if ($prive) {
    $cmd = '$t="COLLEZ_LE_JETON"; irm -Headers @{Authorization="Bearer $t"} "https://raw.githubusercontent.com/' + $depot + '/main/Installer.ps1" -OutFile "$env:TEMP\i.ps1"; powershell -ExecutionPolicy Bypass -File "$env:TEMP\i.ps1" -Token $t'
    Write-Host 'Depot PRIVE. Creez un jeton en lecture seule : https://github.com/settings/personal-access-tokens/new'
    Write-Host '  -> Repository access : Only select repositories > ' $Nom
    Write-Host '  -> Permissions : Contents = Read-only'
    Write-Host 'Puis donnez a chaque confrere cette ligne (a coller dans PowerShell) :'
}
else {
    $cmd = '& ([scriptblock]::Create((irm https://raw.githubusercontent.com/' + $depot + '/main/Installer.ps1)))'
    Write-Host 'Depot PUBLIC. Ligne a donner a chaque confrere (a coller dans PowerShell) :'
}
Write-Host $cmd -ForegroundColor Yellow
try { Set-Clipboard -Value $cmd; Write-Host '(ligne copiee dans le presse-papiers)' } catch { }
