<#
	.SYNOPSIS
		Tie the get-ResourceScrape.ps1 and process-ResourceScrape.ps1 utilities together
	
	.DESCRIPTION
		This script will accept the subscriptionId, username and password parameters
		and pass them to the get-ResourceScrape.ps1 utility. It will then monitor for
		creation of the Resource Scrape file. Once detected, this script will launch
		the process-ResourceScrape.ps1 utility. Once again, it will monitor for the
		creation of the HTML and ACP files. Once detected, this script will zip all
		the created files into a single compressed file for download by the Jenkins
		automation framework.
	
	.PARAMETER SubscriptionId
		Provide the Azure Subscription ID in the format "yyyy-yyyy-yyyy-yyyy"
	
	.PARAMETER Username
		A description of the Username parameter.
	
	.PARAMETER Password
		A description of the Password parameter.
	
	.PARAMETER Verbose
		Show the messages to the console
	
	.PARAMETER NoStamp
		Do not attach the datetime stamp to the output folder and some files
	
	.NOTES
		===========================================================================
		Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2023 v5.8.232
		Created on:   	5/7/2024 5:12 PM
		Created by:   	Wayne Klapwyk
		Organization: 	Skillable
		Filename:     	control-AzureScrape
		===========================================================================
#>
param
(
	[Parameter(Mandatory = $true,
			   ValueFromPipeline = $true,
			   HelpMessage = 'Provide the Azure Subscription ID in the format "yyyy-yyyy-yyyy-yyyy"')]
	[ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
	[Alias('s')]
	[string]$SubscriptionId,
	[Parameter(Mandatory = $true,
			   ValueFromPipeline = $true,
			   HelpMessage = 'Provide the Azure Account Username (as a valid email address)')]
	[ValidatePattern('^([\w-\.]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([\w-]+\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})(\]?)$')]
	[Alias('u')]
	[string]$Username,
	[Parameter(Mandatory = $true)]
	[Alias('p')]
	[string]$Password,
	[Parameter(HelpMessage = 'Show the messages to the console')]
	[Alias('v')]
	[switch]$Verbose,
	[Parameter(HelpMessage = 'Do not attach the datetime stamp to the output folder and some files')]
	[Alias('n')]
	[switch]$NoStamp
)

<#
	.DESCRIPTION
		Ensure that the Az (Azure) powershell module is installed and available in the environment
	
	.EXAMPLE
				PS C:\> Set-Environment
	
	.NOTES
#>

function Write-log {
	[CmdletBinding()]
	param
	(
		$id,
		$msg,
		[bool]$toConsole = $false
	)
	
	# Get the Date/Time
	$dte = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
	
	# Write the message to the log file
	Write-Output "$($dte) (id:$($id)) [ctrl] $($msg)" | Out-file $log -append
	
	if ($toConsole) {
		Write-Host "$($dte) (id:$($id)) $($msg)"
	}
}

function Show-Error {
	[CmdletBinding()]
	param
	(
		$id,
		[Parameter(Mandatory = $true)]
		$err
	)
	
	$errTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
	$e = $err.Exception
	$msg = $e.Message
	while ($e.InnerException) {
		$e = $e.InnerException
		$msg += "`n" + $e.Message
	}
	Write-log -toConsole $Verbose -id $id -msg "Error $($err.Exception.HResult): $($err.Message)`n  Full Message: $($msg)"
}

#####################################
# M A I N  L I N E
#####################################
# This script requires -Module Az

# Script Version
$myVer = "0.0.1"

# Set the Start Time
$startTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$timeId = Get-Date -Format "yyyyMMddHHmmss"

# Get subscription ID numeric Digits
$numDigits = $Username -replace '\D', ''

# Get the script directory
$scriptDir = $PSScriptRoot

# Set up the output directory
if ([string]::IsNullOrEmpty($OutPath)) {
	$outDir = "$($scriptDir)\output_$($numDigits)"
} else {
	$outDir = "$($OutPath)\output_$($numDigits)"
}

# Add the Time ID if requested
if (-not ($NoStamp)) { $outDir = "$($outDir)_$($timeId)" }

# Create the output directory if it doesn't exist
if (-not (Test-Path -Path $outDir -PathType Container)) {
	New-Item -ItemType Directory -Force -Path $outDir
}

# Define the log file name
$log = "$($outDir)\resourceScrape_$($timeId).log"
if (-not ($NoStamp)) { $log = "$($log)_$($timeId)" }
$log = "$($log).log"

# Write the program version to the log file/screen
Write-log -toConsole $Verbose -id 125 -msg "control-AzureScrape.ps1 Version: $($myVer)"

# Define the argument list to pass to the get-ResourceScrape.ps1 utility
$argList = "-s `"$($SubscriptionId)`" -u `"$($Username)`" -p `"$($Password)`" -n"

# Launch the get-ResourceScrape.ps1 utility
Write-log -toConsole $Verbose -id 126 -msg "Launching the get-ResourceScrape.ps1 utility"
Invoke-Expression "& `"get-ResourceScrape.ps1`" $argList"

# Wait for the get-ResourceScrape.ps1 utility to create all the appropriate files
$cntFiles = 0
do {
	$cntFiles = (Get-ChildItem -Path "$($outDir)" -File -Filter "resourcescrape_*.json" | Measure-Object).Count
	if ($cntFiles -gt 0) {
		$fileResourceScrape = Get-ChildItem -Path "$($outDir)" -File -Filter "resourcescrape_*.json"
	} else {
		Start-Sleep -Seconds 3 
	}
	
} while ($cntFiles -lt 1)

# The get-ResourceScrape.ps1 utility completed
Write-log -toConsole $Verbose -id 127 -msg "The get-ResourceScrape.ps1 utility has completed."

# Launch the get-ResourceScrape.ps1 utility
Write-log -toConsole $Verbose -id 127 -msg "The get-ResourceScrape.ps1 utility has completed."
Write-log -toConsole $Verbose -id 128 -msg "Launching the process-ResourceScrape.ps1 utility"
Invoke-Expression "& `"get-ResourceScrape.ps1`" $argList"

# Define the argument list to pass to the get-ResourceScrape.ps1 utility
$argList = "-f `"$($fileResourceScrape)`" -n"

# Wait for the get-ResourceScrape.ps1 utility to create all the appropriate files
$cntFiles = 0
do {
	$cntFiles = (Get-ChildItem -Path "$($outDir)" -File -Filter "resourcescrape_*.html" | Measure-Object).Count
	$cntFiles = $cntFiles + (Get-ChildItem -Path "$($outDir)" -File -Filter "initialACP*.json" | Measure-Object).Count
	if ($cntFiles -gt 1) {
		$fileResourceReport = Get-ChildItem -Path "$($outDir)" -File -Filter "resourcescrape_*.html"
		$fileResourceAcp = Get-ChildItem -Path "$($outDir)" -File -Filter "initialACP_*.json"
	} else {
		Start-Sleep -Seconds 3
	}
	
} while ($cntFiles -le 1)

# The get-ResourceScrape.ps1 utility completed
Write-log -toConsole $Verbose -id 127 -msg "The get-ResourceScrape.ps1 utility has completed."

# Create a compressed file with the ResourceScrape JSON and HTML files and the initial ACP file
$zipFile = "$($outDir)\resources"
if (-not ($NoStamp)) { $zipFile = "$($zipFile)_$($timeId)" }
$zipFile = "$($zipFile).zip"
Write-log -toConsole $Verbose -id 127 -msg "Creating the final ZIP file: $($zipFile)"
Compress-Archive -Path $fileResourceScrape -DestinationPath $zipFile -CompressionLevel Optimal
Compress-Archive -Path $fileResourceReport -Update -DestinationPath $zipFile -CompressionLevel Optimal
Compress-Archive -Path $fileResourceAcp -Update -DestinationPath $zipFile -CompressionLevel Optimal 
