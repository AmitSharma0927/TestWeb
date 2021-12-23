[CmdletBinding()]
param(
  [parameter(Mandatory=$True)]
  [string]$enterpriseServerProtocol,
  [parameter(Mandatory=$True)]
  [string]$enterpriseServerHost,
  [parameter(Mandatory=$True)]
  [string]$enterpriseServerAgentPort,
  [parameter(Mandatory=$True)]
  [string]$projectKey,
  [parameter(Mandatory=$True)]
  [string]$agentTechnology,
  [parameter(Mandatory=$True)]
  [AllowEmptyString()]
  [string]$enterpriseServerPath,
  [string]$enterpriseServerPort,
  [string]$agentFlavor,
  [string]$agentName,
  [string]$accessToken,
  [string]$webServerKey="IIS",
  [parameter(ValueFromRemainingArguments=$True)]
  [string[]] $OtherArguments
)

# Check run as administrator
if(-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

  Write-Output "ERROR: [$(Get-Date -UFormat "%Y-%m-%d %H:%M:%S")] Must run as Administrator.`n`n`nInstallation process has been aborted.";
  exit 1;
}

if ($OtherArguments.count -gt 0) {
  
  Write-Output "==============================================================================";
  Write-Output "/!\\ The version of the Agent is earlier than the Seeker";
  Write-Output "/!\\ Enterprise Server version.";
  Write-Output "/!\\ Agent versions are backward-compatible with the server versions for up to";
  Write-Output "/!\\ 18 months, however, they might not support some of the recent features.";
  Write-Output "/!\\ Agent versions older than 18 months are not officially supported.";
  Write-Output "/!\\ For best results, we recommend that you use the latest versions of all";
  Write-Output "/!\\ Seeker components.";
  Write-Output "==============================================================================";
  
  Write-Warning "Running with unbound arguments:"
  foreach($Argument in $OtherArguments)
  {
    Write-Warning "-> $Argument";
  }
}

function IsInstalled( $program ) {

  $x86 = ((Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall") |
    Where-Object { $_.GetValue( "DisplayName" ) -match "$program" } ).Length -gt 0;

  $x64 = ((Get-ChildItem "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall") |
    Where-Object { $_.GetValue( "DisplayName" ) -match "$program" } ).Length -gt 0;

  return $x86 -or $x64;
}

function GetInstallFilePath( $program ) {

  $x86 = ((Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall") |
    Where-Object { $_.GetValue( "DisplayName" ) -match "$program" } ).Length -gt 0;
    
  if ($x86) {
  
    return ((Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall") |
      Where-Object { $_.GetValue( "DisplayName" ) -match "$program" } ).GetValue("BundleCachePath")
  }

  $x64 = ((Get-ChildItem "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall") |
    Where-Object { $_.GetValue( "DisplayName" ) -match "$program" } ).Length -gt 0;

  if ($x64) {
  
    return ((Get-ChildItem "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall") |
      Where-Object { $_.GetValue( "DisplayName" ) -match "$program" } ).GetValue("BundleCachePath")
  }

  return "";
}

function CreateVisualStudioBatchFile() {
  if (Test-Path .\VS.bat) {
    return;
  }
  
  $vsBatchPath = (Get-Item .).FullName + "\VS.bat"
  Write-Output "INFO: [$(Get-Date -UFormat "%Y-%m-%d %H:%M:%S")] Creating a batch file for starting Visual Studio with the Seeker .NET Framework Agent in `"$vsBatchPath`"."
  Add-Content -Path .\VS.bat -value "@ECHO OFF `r`n"
  Add-Content -Path .\VS.bat -value "ECHO Starting Visual Studio with the Seeker .NET Framework Agent...`r`n"
  Add-Content -Path .\VS.bat -value "SET Cor_Enable_Profiling=1`r`n"
  Add-Content -Path .\VS.bat -value "SET Cor_Profiler={17691574-689D-4366-BEAF-ED00B8618013}`r`n"
  Add-Content -Path .\VS.bat -value "SET SEEKER_DN_PROCESS_INCLUDES=`".*iisexpress\.exe.*`"`r`n"
  
  # Test for Visual Studio path
  $vsWherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe";
  $isDevEnvPathSet = $False;
  
  if (Test-Path $vsWherePath) {
    $devenvPath =  &$vsWherePath -latest -property productPath
    $devenvName =  &$vsWherePath -latest -property displayName
    if ([string]::IsNullOrEmpty($devenvPath) -eq $False) {
      $isDevEnvPathSet = $True;
    }
  }
  
  if ($isDevEnvPathSet)
  {
    Add-Content -Path .\VS.bat -value "START `"`" `"${devenvPath}`"`r`n"
    Write-Output "INFO: [$(Get-Date -UFormat "%Y-%m-%d %H:%M:%S")] Visual Studio batch file will start `"$devenvName`" located in `"$devenvPath`"."
  } else {
    Add-Content -Path .\VS.bat -value "REM START `"`" `"<Full path to devenv.exe>`"`r`n"
    Write-Output "INFO: [$(Get-Date -UFormat "%Y-%m-%d %H:%M:%S")] Could not locate the path to devenv.exe, please check and update it in `"$vsBatchPath`"."
  }
}

# Set working dir to the location of the script
Set-Location $PSScriptRoot

# Uninstall .Net agent
if( IsInstalled("^Seeker (Inline\s|)(\.Net Agent|\.NET Framework and \.NET Core Agents)$") ) {

  Write-Output "INFO: [$(Get-Date -UFormat "%Y-%m-%d %H:%M:%S")] Uninstall current version..."

  # Remove previous logs
  Get-ChildItem (Get-Location) | Where{$_.Name -Match "^Seeker-Agent\.uninstall.*\.log$" -and !$_.PSIsContainer} | Remove-Item;

  Write-Output "WARNING: [$(Get-Date -UFormat "%Y-%m-%d %H:%M:%S")] IIS will be restarted."
  
  $installFile = GetInstallFilePath("^Seeker (Inline\s|)(\.Net Agent|\.NET Framework and \.NET Core Agents)$")
  $process = Start-Process -filePath $installFile -ArgumentList '/uninstall', '/quiet', '/norestart', '/log Seeker-Agent.uninstall.log' -PassThru -Wait;
  
  # List logs files with fullname
  $logs = Get-ChildItem (Get-Location) | Where{$_.Name -Match "^Seeker-Agent\.uninstall.*\.log$" -and !$_.PSIsContainer} | Select-Object FullName;

  if (($process.ExitCode -eq 3010) -or ($process.ExitCode -eq 1641)) {
    Write-Error "ERROR: [$(Get-Date -UFormat "%Y-%m-%d %H:%M:%S")] Uninstall failed: Installation process returned error code: $($process.ExitCode). A restart is required to initiate or complete uninstallation.`nFor details, see the logs:`n $($logs | foreach {"- " + $_.FullName + "`n" })`n";
    exit -1;
  }
  elseif ($process.ExitCode -eq 1603) {
    Write-Error "ERROR: [$(Get-Date -UFormat "%Y-%m-%d %H:%M:%S")] Uninstall failed: Installation process returned error code: $($process.ExitCode). Uninstall agent service failed. This error may be related to a timeout, stop the 'Seeker .NET Agent' service and retry.`nFor details, see the logs:`n $($logs | foreach {"- " + $_.FullName + "`n" })`n";
    exit -1;
  }
  elseif ($process.ExitCode -ne 0) {
    Write-Error "ERROR: [$(Get-Date -UFormat "%Y-%m-%d %H:%M:%S")] Uninstall failed: Installation process returned error code: $($process.ExitCode).`nFor details, see the logs:`n $($logs | foreach {"- " + $_.FullName + "`n" })`n";
    exit -1;
  }
}

# Set environment variable SEEKER_SERVER_URL if not set
if ([string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable('SEEKER_SERVER_URL', [EnvironmentVariableTarget]::Machine))) {    
  
  # Remove ending colon if exists
  if ($enterpriseServerProtocol.Indexof(':') -ne -1) {
    $enterpriseServerProtocol = $enterpriseServerProtocol -replace ".$"
  }
  
  $seekerServerUrl = "${enterpriseServerProtocol}://${enterpriseServerHost}:${enterpriseServerAgentPort}${enterpriseServerPath}"
  Write-Output "INFO: [$(Get-Date -UFormat "%Y-%m-%d %H:%M:%S")] Set environment variable SEEKER_SERVER_URL to ${seekerServerUrl}"
  [Environment]::SetEnvironmentVariable('SEEKER_SERVER_URL', $seekerServerUrl, [EnvironmentVariableTarget]::Machine);
  $env:SEEKER_SERVER_URL=$seekerServerUrl;
}

# Set environment variable SEEKER_ACCESS_TOKEN
if (![string]::IsNullOrEmpty($accessToken)) {
  Write-Output "INFO: [$(Get-Date -UFormat "%Y-%m-%d %H:%M:%S")] Set environment variable SEEKER_ACCESS_TOKEN to ${accessToken}"
  $env:SEEKER_ACCESS_TOKEN=$accessToken;
}
[Environment]::SetEnvironmentVariable('SEEKER_ACCESS_TOKEN', $accessToken, [EnvironmentVariableTarget]::Machine);

# Install .Net agent
Write-Output "INFO: [$(Get-Date -UFormat "%Y-%m-%d %H:%M:%S")] Install new version...";

# Remove previous logs
Get-ChildItem (Get-Location) | Where{$_.Name -Match "^Seeker-Agent\.install.*\.log$" -and !$_.PSIsContainer} | Remove-Item;

Write-Output "WARNING: [$(Get-Date -UFormat "%Y-%m-%d %H:%M:%S")] IIS will be restarted."

$agentSetup = Join-Path -Path (Get-Location) -ChildPath "Seeker-Agent.exe";
$process = Start-Process -filepath $agentSetup -ArgumentList '/install', '/quiet', '/norestart', '/log Seeker-Agent.install.log', "PROJECTKEY=${projectKey}" -PassThru -Wait;

if ($webServerKey -eq "IIS_VS") {
  # Create VS batch file wrapper
  CreateVisualStudioBatchFile;
}

# List logs files with fullname
$logs = Get-ChildItem (Get-Location) | Where{$_.Name -Match "^Seeker-Agent\.install.*\.log$" -and !$_.PSIsContainer} | Select-Object FullName;

if (($process.ExitCode -eq 3010) -or ($process.ExitCode -eq 1641)) {
  Write-Error "ERROR: [$(Get-Date -UFormat "%Y-%m-%d %H:%M:%S")] Install failed: Installation process returned error code: $($process.ExitCode). A restart is required to initiate, continue or complete installation.`nFor details, see the logs:`n $($logs | foreach {"- " + $_.FullName + "`n" })`n";
  exit -1;
}
elseif ($process.ExitCode -eq 1603) {
  Write-Error "ERROR: [$(Get-Date -UFormat "%Y-%m-%d %H:%M:%S")] Uninstall failed: Installation process returned error code: $($process.ExitCode). Install/uninstall agent service failed. This error may be related to:`n- a timeout, stop the 'Seeker .NET Agent' service and retry`n- previous installation wasn't uninstalled properly, uninstall previous installation and retry. If uninstalling wasn't successful, you can use a tool provided by Microsoft: https://support.microsoft.com/en-us/help/17588/windows-fix-problems-that-block-programs-being-installed-or-removed.`nFor details, see the logs:`n $($logs | foreach {"- " + $_.FullName + "`n" })`n";
  exit -1;
}
elseif ($process.ExitCode -ne 0) {
  Write-Error "ERROR: [$(Get-Date -UFormat "%Y-%m-%d %H:%M:%S")] Install failed: Installation process returned error code: $($process.ExitCode).`nFor details, see the logs:`n $($logs | foreach {"- " + $_.FullName + "`n" })`n";
}
else {
  # Refresh current session env to allow run of VisualStudio in this session
  $env:SEEKER_HOME_DIR=[System.Environment]::GetEnvironmentVariable("SEEKER_HOME_DIR", "Machine");
  Write-Output "INFO: [$(Get-Date -UFormat "%Y-%m-%d %H:%M:%S")] Installation complete.";
  exit 0;
}
