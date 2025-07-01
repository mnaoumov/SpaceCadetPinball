$ErrorActionPreference = 'Stop'

function Main {
    #Run this script from Developer Command Prompt for VS *
    $artefacts = ".\bin\Release\SpaceCadetPinball.exe", ".\bin\Release\SDL2.dll", ".\bin\Release\SDL2_mixer.dll"

    #X86 build
    Remove-Item -Path .\build\CMakeCache.txt -ErrorAction SilentlyContinue
    exec { cmake -S . -B build -A Win32 -DCMAKE_WIN32_EXECUTABLE:BOOL=1 }
    exec { cmake --build build --config Release }
    Compress-Archive -Path $artefacts -DestinationPath ".\bin\SpaceCadetPinballx86Win.zip" -Force

    #X64 build
    Remove-Item -Path .\build\CMakeCache.txt
    exec { cmake -S . -B build -A x64 -DCMAKE_WIN32_EXECUTABLE:BOOL=1 }
    exec { cmake --build build --config Release }
    Compress-Archive -Path $artefacts -DestinationPath ".\bin\SpaceCadetPinballx64Win.zip" -Force

    #86 XP build, requires special XP MSVC toolset
    Remove-Item -Path .\build\CMakeCache.txt
    exec { cmake -S . -B build -G "Visual Studio 16 2019" -A Win32 -DCMAKE_WIN32_EXECUTABLE:BOOL=1 -T v141_xp }
    exec { cmake --build build --config Release }
    Compress-Archive -Path $artefacts -DestinationPath ".\bin\SpaceCadetPinballx86WinXP.zip" -Force
}

# https://github.com/mnaoumov/Invoke-NativeApplication/blob/master/exec.ps1
function Invoke-NativeApplication {
    param
    (
        [Parameter(Position = 0)][ScriptBlock] $ScriptBlock,
        [Parameter(Position = 1)][HashTable] $ArgumentList,
        [Parameter()][int[]] $AllowedExitCodes = @(0),
        [Parameter()][switch] $IgnoreExitCode
    )

    $backupErrorActionPreference = $ErrorActionPreference

    $ErrorActionPreference = "Continue"
    try {
        Write-Verbose ('Executing native application {0} with parameters: {1}' -f $ScriptBlock, ([PSCustomObject] $ArgumentList))
        if (Test-CalledFromPrompt) {
            $wrapperScriptBlock = { & $ScriptBlock @ArgumentList }
        }
        else {
            $wrapperScriptBlock = { & $ScriptBlock @ArgumentList 2>&1 }
        }

        & $wrapperScriptBlock | ForEach-Object -Process `
        {
            $isError = $_ -is [System.Management.Automation.ErrorRecord]

            if ($isError) {
                $message = $_.Exception.Message
            }
            else {
                $message = $_
            }

            $message | Add-Member -Name IsError -MemberType NoteProperty -Value $isError -PassThru
        }
        if ((-not $IgnoreExitCode) -and (Test-Path -Path Variable:LASTEXITCODE) -and ($AllowedExitCodes -notcontains $LASTEXITCODE)) {
            throw ('Native application {0} with parameters {1} failed at {2} with exit code {3}' -f
                $ScriptBlock, ([PSCustomObject] $ArgumentList), (Get-PSCallStack -ErrorAction:SilentlyContinue)[1].Location, $LASTEXITCODE)
        }
    }
    finally {
        $ErrorActionPreference = $backupErrorActionPreference
    }
}

function Invoke-NativeApplicationSafe {
    param
    (
        [Parameter(Position = 0)][ScriptBlock] $ScriptBlock,
        [Parameter(Position = 1)][HashTable] $ArgumentList
    )

    Invoke-NativeApplication -ScriptBlock:$ScriptBlock -IgnoreExitCode -ArgumentList:$ArgumentList | `
        Where-Object -FilterScript { -not $_.IsError }
}

function Test-CalledFromPrompt {
    (Get-PSCallStack)[-2].Command -eq "prompt"
}

Set-Alias -Name exec -Value Invoke-NativeApplication
Set-Alias -Name safeexec -Value Invoke-NativeApplicationSafe

Main