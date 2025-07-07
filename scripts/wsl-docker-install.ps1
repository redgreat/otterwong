# WSL Docker Installation PowerShell Script
# This script provides an interactive menu to install and manage Docker in WSL Ubuntu

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Color definitions
$Colors = @{
    Red = "Red"
    Green = "Green"
    Yellow = "Yellow"
    Blue = "Blue"
    Magenta = "Magenta"
    Cyan = "Cyan"
    White = "White"
    Gray = "Gray"
}

function Write-ColorText {
    param([string]$Text, [string]$Color = "White")
    Write-Host $Text -ForegroundColor $Color
}

function Test-WSLAvailable {
    try {
        $null = wsl --version 2>$null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

function Find-UbuntuDistro {
    try {
        Write-ColorText "Detecting WSL distributions..." $Colors.Cyan
        
        $wslOutput = wsl --list --quiet 2>$null
        
        if ($LASTEXITCODE -ne 0) {
            Write-ColorText "[ERROR] Cannot get WSL distribution list" $Colors.Red
            return $null
        }
        
        $wslList = @()
        foreach ($line in $wslOutput) {
            if ($line -and $line.Trim() -ne "") {
                $wslList += $line.Trim()
            }
        }
        
        Write-ColorText "Detected WSL distributions: $($wslList -join ', ')" $Colors.Yellow
        
        $ubuntuDistros = @()
        foreach ($distro in $wslList) {
            # Remove all non-printable characters
            $cleanDistro = $distro -replace '[\x00-\x1F\x7F-\x9F]', ''
            $cleanDistro = $cleanDistro.Trim()
            
            # Simple string comparison
            if ($cleanDistro -ieq "ubuntu" -or $cleanDistro -ilike "*ubuntu*") {
                if ($cleanDistro -inotlike "*docker*") {
                    $ubuntuDistros += $cleanDistro
                }
            }
        }
        
        if ($ubuntuDistros.Count -eq 0) {
            Write-ColorText "[ERROR] No Ubuntu distribution found" $Colors.Red
            Write-ColorText "Available distributions: $($wslList -join ', ')" $Colors.Yellow
            Write-ColorText "Please install Ubuntu from Microsoft Store first" $Colors.Yellow
            return $null
        }
        
        if ($ubuntuDistros.Count -eq 1) {
            Write-ColorText "[SUCCESS] Found Ubuntu distribution: $($ubuntuDistros[0])" $Colors.Green
            return $ubuntuDistros[0]
        }
        
        Write-ColorText "Found multiple Ubuntu distributions:" $Colors.Cyan
        for ($i = 0; $i -lt $ubuntuDistros.Count; $i++) {
            Write-ColorText "$($i + 1). $($ubuntuDistros[$i])" $Colors.White
        }
        
        do {
            $choice = Read-Host "Please select (1-$($ubuntuDistros.Count))"
            $choiceNum = [int]$choice - 1
        } while ($choiceNum -lt 0 -or $choiceNum -ge $ubuntuDistros.Count)
        
        Write-ColorText "[SUCCESS] Selected: $($ubuntuDistros[$choiceNum])" $Colors.Green
        return $ubuntuDistros[$choiceNum]
    }
    catch {
        Write-ColorText "[ERROR] Detection failed: $($_.Exception.Message)" $Colors.Red
        return $null
    }
}

function Invoke-WSLCommand {
    param(
        [string]$DistroName,
        [string]$Command
    )
    
    try {
        Write-ColorText "Executing in $DistroName : $Command" $Colors.Cyan
        wsl -d $DistroName -e bash -c $Command
        return $LASTEXITCODE -eq 0
    }
    catch {
        Write-ColorText "[ERROR] Command execution failed: $($_.Exception.Message)" $Colors.Red
        return $false
    }
}

function Show-Menu {
    Write-Host ""
    Write-ColorText "=== WSL Docker Installation Menu ===" $Colors.Magenta
    Write-ColorText "1. Full installation (Install Docker + Build Otter image)" $Colors.White
    Write-ColorText "2. Build Otter image only" $Colors.White
    Write-ColorText "3. Run Otter container only" $Colors.White
    Write-ColorText "4. View container status" $Colors.White
    Write-ColorText "5. View container logs" $Colors.White
    Write-ColorText "6. Enter container for debugging" $Colors.White
    Write-ColorText "7. Clean up resources" $Colors.White
    Write-ColorText "8. Show help" $Colors.White
    Write-ColorText "0. Exit" $Colors.White
    Write-Host ""
}

function Main {
    Write-ColorText "WSL Docker Installation Tool" $Colors.Magenta
    Write-ColorText "============================" $Colors.Magenta
    
    # Check WSL availability
    if (-not (Test-WSLAvailable)) {
        Write-ColorText "[ERROR] WSL is not available or not installed" $Colors.Red
        Write-ColorText "Please install WSL first: https://docs.microsoft.com/en-us/windows/wsl/install" $Colors.Yellow
        Read-Host "Press any key to exit"
        return
    }
    
    # Find Ubuntu distribution
    $ubuntuDistro = Find-UbuntuDistro
    if (-not $ubuntuDistro) {
        Write-ColorText "[ERROR] Cannot find Ubuntu distribution" $Colors.Red
        Read-Host "Press any key to exit"
        return
    }
    
    do {
        Show-Menu
        $choice = Read-Host "Please select an option (0-8)"
        
        switch ($choice) {
            "1" {
                Write-ColorText "Starting full installation..." $Colors.Green
                Invoke-WSLCommand $ubuntuDistro "cd /mnt/d/github/otterwong && chmod +x scripts/wsl-docker-setup.sh && ./scripts/wsl-docker-setup.sh install"
            }
            "2" {
                Write-ColorText "Building Otter image..." $Colors.Green
                Invoke-WSLCommand $ubuntuDistro "cd /mnt/d/github/otterwong && chmod +x scripts/wsl-docker-setup.sh && ./scripts/wsl-docker-setup.sh build"
            }
            "3" {
                Write-ColorText "Running Otter container..." $Colors.Green
                Invoke-WSLCommand $ubuntuDistro "cd /mnt/d/github/otterwong && chmod +x scripts/wsl-docker-setup.sh && ./scripts/wsl-docker-setup.sh run"
            }
            "4" {
                Write-ColorText "Checking container status..." $Colors.Green
                Invoke-WSLCommand $ubuntuDistro "cd /mnt/d/github/otterwong && chmod +x scripts/wsl-docker-setup.sh && ./scripts/wsl-docker-setup.sh status"
            }
            "5" {
                Write-ColorText "Viewing container logs..." $Colors.Green
                Invoke-WSLCommand $ubuntuDistro "cd /mnt/d/github/otterwong && chmod +x scripts/wsl-docker-setup.sh && ./scripts/wsl-docker-setup.sh logs"
            }
            "6" {
                Write-ColorText "Entering container for debugging..." $Colors.Green
                Invoke-WSLCommand $ubuntuDistro "cd /mnt/d/github/otterwong && chmod +x scripts/wsl-docker-setup.sh && ./scripts/wsl-docker-setup.sh enter"
            }
            "7" {
                Write-ColorText "Cleaning up resources..." $Colors.Green
                Invoke-WSLCommand $ubuntuDistro "cd /mnt/d/github/otterwong && chmod +x scripts/wsl-docker-setup.sh && ./scripts/wsl-docker-setup.sh cleanup"
            }
            "8" {
                Write-ColorText "Showing help..." $Colors.Green
                Invoke-WSLCommand $ubuntuDistro "cd /mnt/d/github/otterwong && chmod +x scripts/wsl-docker-setup.sh && ./scripts/wsl-docker-setup.sh help"
            }
            "0" {
                Write-ColorText "Exiting..." $Colors.Yellow
                break
            }
            default {
                Write-ColorText "Invalid option. Please try again." $Colors.Red
            }
        }
        
        if ($choice -ne "0") {
            Write-Host ""
            Read-Host "Press any key to continue"
        }
    } while ($choice -ne "0")
}

# Run the main function
Main