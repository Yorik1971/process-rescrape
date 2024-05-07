<#
	.SYNOPSIS
		Build the Tenant-Based Input Parameters
	
	.DESCRIPTION
		This script will log in to the required Azure subscription and poll
		the Resource Explorer to gather the resources used during a lab. This
		will then be used to create a standardized JSON Resource Scrape file.
	
	.PARAMETER SubscriptionId
		Provide the Azure Subscription ID in the format "yyyy-yyyy-yyyy-yyyy"
	
	.PARAMETER Username
		A description of the Username parameter.
	
	.PARAMETER Password
		A description of the Password parameter.
	
	.PARAMETER LogToScreen
		A description of the LogToScreen parameter.
	
	.PARAMETER OutPath
		Path to output files
	
	.NOTES
		===========================================================================
		Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2023 v5.8.232
		Created on:   	2/22/2024 2:24 PM
		Created by:   	Wayne Klapwyk
		Organization: 	Skillable
		Filename:     	get-ResourceScrape
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
	[Parameter(HelpMessage = 'Path to output files')]
	[Alias('o')]
	[string]$OutPath,
	[Parameter(HelpMessage = 'Show the messages to the console')]
	[Alias('l')]
	[switch]$LogToScreen
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
	Write-Output "$($dte) (id:$($id)) $($msg)" | Out-file $log -append
	
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
	if ($err -eq "Auth") {
		if (Test-Path -Path "$($outDir)\FlagFile.chk" -PathType Leaf) {
			
			Write-log -toConsole $LogToScreen -id $id -msg "Your Azure credentials have not been set up or have expired, please run Connect-AzAccount to set up your Azure credentials. SharedTokenCacheCredential authentication unavailable. Token acquisition failed. Ensure that you have authenticated with a developer tool that supports Azure single sign on.`n`nThe Lab has likely ended or is otherwise unavailable. Please wait while processing is completed."
			Remove-Item -Path "$($outDir)\FlagFile.chk"
		}
	} else {
		$e = $err.Exception
		$msg = $e.Message
		while ($e.InnerException) {
			$e = $e.InnerException
			$msg += "`n" + $e.Message
		}
		Write-log -toConsole $LogToScreen -id $id -msg "Error $($err.Exception.HResult): $($err.Message)`n  Full Message: $($msg)"
	}
}

function Set-Environment {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$inDir
	)
	
	$retVal = $true
	try	{
		# Install the Azure PowerShell module (if you haven't already)
		Write-log -toConsole $LogToScreen -id 50 -msg "Verifying the local Powershell Azure environment."
#		Write-Host "Verifying the local Powershell Azure environment."
		If (Get-Module -ListAvailable -Name Az)	{
#			Write-Host "Checking availability of the Azure Az module"
			Import-Module Az -ErrorAction Stop
#			Write-Host "The Azure Az module is ready for use"
			Write-log -toConsole $LogToScreen -id 51 -msg "The Azure Az module is ready for use"
		} else {
#			Write-Host "This utility requires the use of the Azure Az Powershell module."
			Write-log -toConsole $LogToScreen -id 52 -msg "This utility requires the use of the Azure Az Powershell module."
#			Write-Host "Please install this module as an administrator before proceeding."
			Write-log -toConsole $LogToScreen -id 53 -msg "Please install this module as an administrator before proceeding."
##			Install-Module -Name Az -Scope CurrentUser -AllowClobber -Force
##			Import-Module -Name Az
			
		}
	} catch	{
		Show-Error -err $_ -id 1
		
		$retVal = $false
	}
	
	return $retVal
}

<#
	.SYNOPSIS
		Login to an Azure Account
	
	.DESCRIPTION
		Login to an Azure Account using credentials and a tenant ID
	
	.PARAMETER inUser
		A description of the inUser parameter.
	
	.PARAMETER inPswd
		A description of the inPswd parameter.
	
	.PARAMETER inSubs
		A description of the inSubs parameter.
	
	.EXAMPLE
		PS C:\> Access-AzAccount -inUser 'Value1' -inPswd 'Value2' -inTenant 'Value3'
	
	.NOTES
		
#>
function Access-AzAccount {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$inUser,
		[Parameter(Mandatory = $true)]
		[string]$inPswd,
		[Parameter(Mandatory = $true)]
		[string]$inSubs
	)
	
	$retVal = $true
	
	try {
		# Provide your Azure account credentials
		$pswd = ConvertTo-SecureString $inPswd -AsPlainText -Force
		$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $inUser, $pswd
		
		# Connect to your Azure account
		$context = Connect-AzAccount -Credential $cred -SubscriptionId $inSubs -Scope process -ErrorAction Stop
	} catch	{
		Show-Error -err $_ -id 2
	}
	
	return $retVal
}

function Create-TempFiles {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$inDir
	)
	
	# Create the Flag File
	# This script will query for resources as long as this file exists
	$file = New-Item -Path "$($inDir)\FlagFile.chk" -ItemType File -Force
	
	# Tell the user to delete the Flag File to stop the Resource Scrape utility
	$msg = @"
The get-ResourceScrape utility will now start gathering the resources from your subscription.

To stop this utility before the end of the lab, REMOVE the following File:
    $($inDir)\FlagFile.chk.
"@
	Write-log -toConsole $LogToScreen -id 54 -msg $msg
#	Write-Host ""
#	Write-Host "The get-ResourceScrape utility will now start gathering the resources from your subscription."
#	Write-Host ""
#	Write-Host "To stop this utility before the end of the lab, REMOVE the following File:"
#	Write-Host "    $($inDir)\FlagFile.chk."
	
	# Create/overwrite the temporary output file with a blank default file
	$hdr = @"
{
  `"Resources`": []
}
"@
	Remove-Item -Path "$($inDir)\output.tmp" -ErrorAction SilentlyContinue
	Set-Content -Path "$($inDir)\output.tmp" -Value $hdr
}

function Build-outputRecord {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[object]$inRcd,
		[Parameter(Mandatory = $true)]
		[string]$inTimeStamp,
		[Parameter(Mandatory = $true)]
		[object]$inProps
	)
	
	$retObj = ""
	
	try {
		try {
			$jobj = ""
			$jsnTags = ""
			
			# Set up any tags for the resource
			if ($inRcd.Tags.Keys.Count -gt 0) {
				$retObj = $retObj + "`"["
				$toAdd = ""
				$arrTags = New-Object -TypeName System.Collections.ArrayList
				for ($x = 0; $x -lt $inRcd.Tags.Keys.Count; $x++) {
					# Create the current Tag Key/Value Pair
					$toAdd = "{`"$($inRcd.Tags.Keys[$x])`":`"$($inRcd.Tags.Values[$x])`"}"
					# Add the current Tag into the JSON Object
					$arrTags.Add((ConvertFrom-Json -InputObject $toAdd))
				}
				$jsnTags = $arrTags | ConvertTo-Csv
			}
		} catch { }
		
			# Set up the resource with/without Tags and Properties
			if ($inProps.Count -gt 0) {
				
				# Set up the base resource with Tags
				$tmpJSON = @{
					"Timestamp"		    = $inTimeStamp
					"Name"			    = $inRcd.Name
					"ResourceGroupName" = $inRcd.ResourceGroupName
					"ResourceType"	    = $inRcd.ResourceType
					"Location"		    = $inRcd.Location
					"ResourceId"	    = $inRcd.ResourceId
					"Tags"			    = $arrTags
				}
				
				# Add in the Properties
				$targetJSON = $tmpJSON | ConvertTo-Json | ConvertFrom-Json
				$newProps = $inProps | ConvertFrom-Json
				#			$targetJSON | Add-Member -MemberType NoteProperty -Name "ResProperties" -Value $newProps -Force
				$targetJSON | Add-Member -MemberType NoteProperty -Name "ResProperties" -Value $inProps -Force
				
				$retObj = $targetJSON
				
			} else {
				
				# Set up the base resource with Tags and default the Properties to blank
				$retJSON = @{
					"Timestamp"		    = $inTimeStamp
					"Name"			    = $inRcd.Name
					"ResourceGroupName" = $inRcd.ResourceGroupName
					"ResourceType"	    = $inRcd.ResourceType
					"Location"		    = $inRcd.Location
					"ResourceId"	    = $inRcd.ResourceId
					"Tags"			    = $arrTags
					"ResProperties"	    = "[]"
				}
				$retObj = $targetJSON
			}
	} catch {
		Show-Error -err $_ -id 3
		
		# Set the return JSON to blank when an error is encountered
		$retObj = "`"[]`""
	}
	
	# Return the full record
	return $retObj
}


function Is-Unique {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[object]$inRow
	)
	
	$retVal = $true
	
	try {
		# Import the temporary output file
		$csv = Import-Csv "$($outDir)\output.tmp"
		$jsn = Get-Content -Path "$($outDir)\output.tmp" -Raw | ConvertFrom-Json
		$chk = $inRow 
		
		# Check if the record exists in the JSON object
		$recordExists = $jsn.resources | Where-Object {
			$_.Name -eq $chk.Name -and
			$_.ResourceGroupName -eq $chk.ResourceGroupName -and
			$_.ResourceType -eq $chk.ResourceType -and
			$_.Location -eq $chk.Location -and
			$_.ResourceId -eq $chk.ResourceId -and
			$_.ResProperties -eq $chk.ResProperties}
		
		# Output the result
		if ($recordExists) {
#			Write-Host "Record already exists."
			$retVal = $false
		}
	} catch {
		Show-Error -err $_ -id 4
	}
	
	return $retVal
}

function Run-Scrape {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$inDir
	)
	
	$retVal = $true
	$outJson = ""
	
	try {
		# Query the subscription for resources until the Flag File is removed
		# or for a maximum of 10 hours
		Do {
			# Retrieve the list of Resource Groups in the current Subscription
			try {
				$resourceGroups = Get-AzResourceGroup -ErrorAction Stop
			} catch {
				if (($_.Exception -Match "authentication unavailable") -or ($_.Exception -Match "does not have authorization")) {
					Show-Error -err "Auth" -id 10
				}
			}
			
			# Loop through the list of Resource Groups
			foreach ($resourceGroup in $resourceGroups) {
				# Increment the Pass counter
				$script:cntPass++
				
				# Retrieve the list of Resources within each Resource Group
				try {
					$resources = Get-AzResource -ResourceGroupName $resourceGroup.ResourceGroupName -ErrorAction Stop
				} catch {
					try {
						$resources = Get-AzResource -ResourceGroupName $resourceGroup.ResourceGroupName -ExpandProperties -ErrorAction Stop
					} catch {
						if (($_.Exception -Match "authentication unavailable") -or ($_.Exception -Match "does not have authorization")) {
							Show-Error -err "Auth" -id 11
						}
					}
				}
				
				if ($resources.Count -gt 0) {
					# Add the TimeStamp and Properties to each resource
					$rcd = $null
					
					$azResourcesTS = foreach ($rsc in $resources) {
						try {
							# Get the resource by its name, resource group, and type, and expand its properties
							try {
								$data = ""
								$data = Get-AzResource -Name $rsc.Name -ResourceGroupName $rsc.ResourceGroupName -ResourceType $rsc.ResourceType -ExpandProperties -ErrorAction Stop
							} catch {
								if (($_.Exception -Match "authentication unavailable") -or ($_.Exception -Match "does not have authorization")) {
									Show-Error -err "Auth" -id 12
								}
							}
							# Convert the properties object to a JSON string
							$props = $data.Properties
							if ([string]::IsNullOrEmpty($props)) {
								# Pause for 2 seconds and try again
								Start-Sleep -Seconds 2
								# Get the resource by its name, resource group, and type, and expand its properties
								try {
									$data = Get-AzResource -Name $rsc.Name -ResourceGroupName $rsc.ResourceGroupName -ResourceType $rsc.ResourceType -ExpandProperties -ErrorAction Stop
								} catch {
									if ((($_.Exception -Match "authentication unavailable") -or ($_.Exception -Match "does not have authorization")) -And (Test-Path -Path "$($outDir)\FlagFile.chk" -PathType Leaf)) {
										Show-Error -err "Auth" -id 13
									}
								}
								# Convert the properties object to a JSON string
								$props = $data.Properties
							}
							
							if (-not ([string]::IsNullOrEmpty($props))) {
								# Get current timestamp
								$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
								# Create a temporary version of the resource
								$tmp = Build-outputRecord -inRcd $data -inTimeStamp $timestamp -inProps ($data.Properties | ConvertTo-Json)
								
								# Check to see if the record is unique
								if (-not ([string]::IsNullOrEmpty($tmp))) {
									if (Is-Unique -inRow $tmp[$tmp.count - 1]) {
										# Add the number of records being added to the output file
										$script:cntRecords++
										
										# Read the current JSON file 
										$currFile = Get-Content -Path "$($inDir)\output.tmp" -Raw
										
										# Set up the output record by converting the output.tmp data from a JSON object
										$outData = $currFile | ConvertFrom-Json
										
										# Add the new "tmp" Resource record to the collection of Resources
										$newResources = $outData.Resources + $tmp[$tmp.Count - 1]
										$outData.Resources = $newResources
										
										# Convert the output data back to JSON
										$jsnData = $outData | ConvertTo-Json

										# Export the Resource result to the JSON file
										Set-Content -Path "$($inDir)\output.tmp" -Value $jsnData
										
										# Increment the resource counter
										$script:cntRecords++
									}
								}
							}
						} catch {
							Show-Error -err $_ -id 6
						}
					}
				}
			}
		} while ([System.IO.File]::Exists("$($inDir)\FlagFile.chk"))
	} catch {
		Show-Error -err $_ -id 7
		
		$retVal = $false
	}
	
	return $retVal
}

function Show-Results {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$inDir,
		[Parameter(Mandatory = $true)]
		[string]$inFilename
	)
	
	#####################################
	# Determine the record counts
	#####################################
	
	# Read the JSON file (replace 'path/to/your/file.json' with the actual file path)
	$jsonContent = Get-Content -Path "$($inDir)\output.tmp" | Out-String
	
	# Convert JSON to objects
	$resourceObjects = $jsonContent | ConvertFrom-Json
	
	# Initialize an empty hashtable to store unique resource group names and unique resources
	$uniqueResourceGroups = @{ }
	$uniqueResources = @{ }
	
	# Loop through the resource objects
	foreach ($resource in $resourceObjects.Resources) {
		# Extract resource group name
		$resourceGroupName = $resource.ResourceGroupName
		$resourceName = $resource.Name
		
		# Add the resource group name to the hashtable (if not already added)
		if (-not [string]::IsNullOrEmpty($resourceGroupName)) {
			if (-not $uniqueResourceGroups.ContainsKey($resourceGroupName)) {
				$uniqueResourceGroups[$resourceGroupName] = $true
			}
		}
		
		# Add the resource to the hashtable (if not already added)
		if (-not [string]::IsNullOrEmpty($resourceName)) {
			if (-not $uniqueResources.ContainsKey($resourceName)) {
				$uniqueResources[$resourceName] = $true
			}
		}
	}
	
	# Count unique resource groups and unique resources
	$uniqueResourceGroupCount = $uniqueResourceGroups.Count
	$uniqueResourcesCount = $uniqueResources.Count
	
	# Set the End Time
	$endTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
	
	# Convert start and end times to datetime objects
	$start = [datetime]::ParseExact($startTime, "yyyy-MM-dd HH:mm:ss", $null)
	$end = [datetime]::ParseExact($endTime, "yyyy-MM-dd HH:mm:ss", $null)
	
	# Calculate the duration
	$dur = $end - $start
	
	#####################################
	# Display the results and statistics
	#####################################
	
	# output the count records
	$msg = @"

#####################################
# Processed Records                 #
#-----------------------------------#
# Total Number of passes:     $($script:cntPass)
# Total records examined:     $($script:cntRecords)
# Count of Unique Groups:     $($uniqueResourceGroupCount)
# Count of Unique Resources:  $($uniqueResourcesCount)
#####################################

Start Time:     $($startTime)
End Time:       $($endTime)
Total Duration: $($dur.Hours):$($dur.Minutes):$($dur.Seconds)

Full Resource Scrape file:    $($inDir)\$($inFilename)

*NOTE: The Full Resource Scrape File may contain duplicate resources if the resource is modified during the lab.

#####################################
The get-ResourceScrape.ps1 utility has ended
"@
	
	Write-log -toConsole $LogToScreen -id 55 -msg $msg
#	Write-Host ""
#	Write-Host "#####################################"
#	Write-Host "# Processed Records                 "
#	Write-Host "#-----------------------------------"
#	Write-Host "# Total Number of passes:     $($script:cntPass)"
#	Write-Host "# Total records examined:     $($script:cntRecords)"
#	Write-Host "# Count of Unique Groups:     $($uniqueResourceGroupCount)"
#	Write-Host "# Count of Unique Resources:  $($uniqueResourcesCount)"
#	Write-Host "#####################################"
#	Write-Host ""
#	Write-Host "Start Time:     $($startTime)"
#	Write-Host "End Time:       $($endTime)"
#	Write-Host "Total Duration: $($dur.Hours):$($dur.Minutes):$($dur.Seconds)"
#	Write-Host ""
#	Write-Host "Full Resource Scrape file:    $($inDir)\$($inFilename)"
#	Write-Host ""
#	Write-Host "*NOTE: The Full Resource Scrape File may contain duplicate resources if the resource is modified during the lab."
#	Write-Host ""
#	Write-Host "#####################################"
#	Write-Host "The get-ResourceScrape.ps1 utility has ended"
#	Write-Host ""
}


#####################################
# M A I N  L I N E
#####################################
# This script requires -Module Az

# Script Version
$myVer = "1.0.2"

# Set the Start Time
$startTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$timeId = Get-Date -Format "yyyyMMddHHmmss"

# Get subscription ID numeric Digits
$numDigits = $Username -replace '\D', ''

# Get the script directory
$scriptDir = $PSScriptRoot

# Set up the output directory
if ([string]::IsNullOrEmpty($OutPath)) {
	$outDir = "$($scriptDir)\output_$($numDigits)_$($timeId)"
} else {
	$outDir = "$($OutPath)\output_$($numDigits)_$($timeId)"
}

# Create the output directory if it doesn't exist
if (-not (Test-Path -Path $outDir -PathType Container)) {
	New-Item -ItemType Directory -Force -Path $outDir
}

# Define the log file name
$log = "$($outDir)\resourceScrape_$($timeId).log"

# Write the program version to the log file/screen
Write-log -toConsole $LogToScreen -id 55 -msg "get-ResourceScrape.ps1 Version: $($myVer)"

if (Set-Environment -inDir $scriptDir) {
	if (Access-AzAccount -inUser $Username -inPswd $Password -inSubs $SubscriptionId) {
		# Initialize the Counters
		$script:cntPass = 0
		$script:cntRecords = 0
		$script:maxGroups = 0
		$script:maxResources = 0
		
		# Create the working files
		Create-TempFiles -inDir $outDir
		
		if (Run-Scrape -inDir $outDir) {
			# Create a copy of the temporary file with the current date & time
			$fileNameDate = "resourceScrape_" + (Get-Date).ToString("yyyyMMdd-HHmmss") + ".json"
			Copy-Item -Path "$($outDir)\output.tmp" -Destination "$($outDir)\$($fileNameDate)"
			
			Show-Results -inDir "$($outDir)" -inFilename "$($fileNameDate)"
		} else {
			$errTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
			Write-log -toConsole $LogToScreen -id 56 -msg "An error was encountered during the Resource Scrape process.`n$($_)"
#			Write-Host "$($errTime)  An error was encountered during the Resource Scrape process."
			
			Show-Error -err $_ -id 8
		}
	}
}
