<#
	.SYNOPSIS
		A brief description of the  file.
	
	.DESCRIPTION
		A description of the file.
	
	.PARAMETER File
		Supply the input file containing the JSON object of the Resource Scrape to be processed.
	
	.PARAMETER showHtml
		If you want to view the HTML output automatically include the showHTML switch parameter
	
	.PARAMETER rulesfile
		Enter the path to the Rules file. The Rules file defines the characteristics of an ACP
	
	.PARAMETER OutPath
		Path to output files
	
	.PARAMETER Details
		Show the messages to the console
	
	.PARAMETER Stamp
		Attach the datetime stamp to the output folder and some files
	
	.NOTES
		===========================================================================
		Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2023 v5.8.232
		Created on:   	3/12/2024 1:55 PM
		Created by:   	WayneKlapwyk
		Organization: 	WKUtils
		Filename:     	process-ResourceScrape
		===========================================================================
#>
param
(
	[Parameter(Mandatory = $true,
			   HelpMessage = 'Supply the input file containing the JSON object of the Resource Scrape to be processed.')]
	[Alias('f')]
	[string]$file,
	[Parameter(HelpMessage = 'If you want to view the HTML output automatically include the show-HTML switch parameter')]
	[Alias('h')]
	[switch]$showHtml,
	[Parameter(HelpMessage = 'Enter the path to the Rules file. The Rules file defines the characteristics of an ACP')]
	[Alias('r')]
	[string]$rulesFile = 'rules.xml',
	[Parameter(HelpMessage = 'Path to output files')]
	[Alias('o')]
	[string]$OutPath,
	[Parameter(Mandatory = $false,
			   HelpMessage = 'Show the messages to the console')]
	[Alias('d')]
	[switch]$Details = $false,
	[Parameter(HelpMessage = 'Attach the datetime stamp to the output folder and some files')]
	[Alias('s')]
	[switch]$Stamp
)

$outRcd = ""
$typeElems = New-Object -TypeName System.Collections.ArrayList
$propElems = New-Object -TypeName System.Collections.ArrayList
$arrElems = New-Object -TypeName System.Collections.ArrayList
$chkElems = New-Object -TypeName System.Collections.ArrayList
$outElems = New-Object -TypeName System.Collections.ArrayList
$acpList = New-Object -TypeName System.Collections.ArrayList
$acpFile = ""

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
	
	# Appent the message to the log file
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
	
	# Get the current date/time
	$errTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
	
	# Retrieve the error message
	$e = $err.Exception
	$msg = $e.Message
	
	# parse the error message
	while ($e.InnerException) {
		$e = $e.InnerException
		$msg += "`n" + $e.Message
	}
	
	# write the update to the log file
	Write-log -toConsole $Details -id $id -msg "Error $($err.Exception.HResult): $($err.Message)`n  Full Message: $($msg)"
}

function ConvertTo-IndentedHtmlList {
	param (
		[Parameter(Mandatory = $true)]
		[Object]$Object,
		[int]$IndentLevel = 0
	)
	
	# Set the HTML indentation level
	$indentation = ' ' * ($IndentLevel * 4)
	$html = "$indentation<ul>"
	
	# Retrieve and convert the JSON properties
	$objProperties = $object | ConvertTo-Json | ConvertFrom-Json
	
	# Cycle over all the properties
	foreach ($property in $Object.PSObject.Properties) {
		# retrieve the current property name and value
		$propertyName = "$($property.Name)"
		$propertyValue = $property.Value
		
		# Build the HTML element with proper indentation
		$html += "$indentation    <li>$($propertyName): "
		
		if ($propertyValue -is [System.Management.Automation.PSCustomObject]) {
			$html += ConvertTo-IndentedHtmlList -Object $propertyValue -IndentLevel ($IndentLevel + 1)
		} elseif (($propertyValue -is [System.Collections.IEnumerable] -and $propertyValue -isnot [string]) -or ($propertyValue -is [Object])) {
			$html += "<ul>"
			foreach ($item in $propertyValue) {
				$html += "$indentation        <li>$item</li>"
			}
			$html += "$indentation    </ul>"
		} else {
			$html += "$propertyValue"
		}
		$html += "</li>"
	}
	
	$html += "$indentation</ul>"
	
	# Return the built HTML
	return $html
}

function Add-headers {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $false)]
		$listHeaders
	)
	
	# Build the HTML headers based on the input list
	$retHead = "  <thead><tr>`n"
	$listHeaders | ForEach-Object {
		if ([string]::IsNullOrEmpty($_)) {
			$retHead += "    <th>$_</th>`n"
		} else {
			$retHead += "    <th>$_</th>`n"
		}
	}
	$retHead += "  </tr></thead>`n"
	
	return $retHead
}

#function Add-propElement {
#	[CmdletBinding()]
#	param
#	(
#		$name,
#		$type,
#		$field
#	)
#	
#	$retProp = ""
#	
#	if ($type -eq "contains" -or $type -eq "in") {
#		$retProp += ",`n            {`n                `"field`": `"$($field)`",`n                `"$($type)`": [`""
#		foreach ($item in $name) { $retProp += "`"$item`"" }
#		$retProp += "`"    ]`n            }"
#	} else {
#		$retProp += ",`n            {`n                `"field`": `"$($field)`",`n                `"$($type)`": `"$($name)`"`n            }"
#	}
#	
#	return $retProp
#}

function Set-acp {
	[CmdletBinding()]
	param
	(
		$name,
		$row,
		$props
	)
	
	Write-log -toConsole $Details -id 67 -msg "Looking up rules for property: $($name).`n"
	
	# verify that the rules file exists
	if (Test-Path -Path $rulesFile -PathType Leaf) {
		[xml]$rules = Get-Content -Path $rulesFile
		
		# NEW - Find the row.ResourceType in the rules file
		$rule = $rules.resources.resource | Where-Object {
			$_.type -eq $row.ResourceType -and $_.enabled -eq 'true'
		}
		
		# Find the row.ResourceType in the rules file
#		$cnt = 0
#		for ($x = 0; $x -lt $rules.resources.resource.count; $x++) {
#			$rule = $rules.resources.resource[$x]
			
#			if ($rule.type -eq $row.ResourceType) {
				Write-log -toConsole $Details -id 68 -msg "Rule has been found for $($rule.type).`n"
				# only process the rule if it has been enabled. Otherwise, ignore it
#				if ($rule.enabled -eq "true") {
					Write-log -toConsole $Details -id 69 -msg "Rule is enabled.`n"
					# Check to see if any properties exist for this rule
					if ($rule.properties -ne $null) {
						Write-log -toConsole $Details -id 70 -msg "This rule has properties.`n"
						
						$elem = "               {`n                    `"allOf`": [`n                        {`n                            `"field`": `"type`",`n                            `"equals`": "
						$elem += "`"$($rule.type)`"`n                        },`n"
						for ($x = 0; $x -lt $rule.properties.field.count; $x++) {
							if ((-not ($rule.properties.field.name -contains "provisioningstate")) -or ($rule.properties.field[0].value -match "Succeeded")) {
								if (($x -eq 0) -and (($rule.properties.field[0].name -match "provisioningState") -and ($rule.properties.field[0].value -match "Succeeded"))) {
									$x++
								}
								$elem += "                        {`n                            `"field`": `"$($rule.properties.field[$x].name)`",`n                            `"$($rule.properties.field[$x].func)`": "
								
								if ($rule.properties.field[$x].func -eq "in") {
									# Format the list of values on separate lines
									$elem += "[`n"
									$arrValues = $rule.properties.field[$x].value.split(",")
									for ($y = 0; $y -lt $arrValues.Count - 1; $y++) {
										$outElem = $arrValues[$y]
										if ($rule.properties.field[$x].valtype -eq "field") {
											$splitElem = $arrValues[$y].split(".")
											$outElem = $props."$($splitElem[0])"."$($splitElem[1])"
										}
										$elem += "                                `"$($arrValues[$y])`",`n"
									}
									# Remove the last comma
									$elem = $elem.Substring(0, $elem.Length - 1)
									# close the list of values
									$elem += "                            ]`n                        },`n"
								} else {
									$outElem = $rule.properties.field[$x].value
									if ($rule.properties.field[$x].valtype -eq "field") {
										$splitElem = $rule.properties.field[$x].value.split(".")
										$outElem = $props."$($splitElem[0])"."$($splitElem[1])"
									}
									$elem += "`"$($outElem)`"`n                        `},`n"
								}
								if (-not $arrElems.Contains($elem)) { [void]$arrElems.Add($elem) }
							}
						}
						$elem = $elem.Substring(0, $elem.LastIndexOf(","))
						$elem += "`n                    ]`n                },`n"
					} else {
						# Add the element without properties
						Write-log -toConsole $Details -id 70 -msg "This rule does not have properties.`n"
						if (-not $typeElems.Contains($rule.type)) { [void]$typeElems.Add($rule.type) }
					}
					
#					break
#				}
#			}
#		}
	} else {
		Write-log -toConsole $Details -id 9 -msg "ERROR: Could not find the rules file. File: $($rules)`n"
		$elem = ""
	}
	
	#	return $arrElems
	return $elem
}

function Build-Body {
	[CmdletBinding()]
	param
	(
		$rowData
	)
	
	$retVal = ""
	$cnt = 1
	$rowData | ForEach-Object {
		$object = $_
		if (-not ([string]::IsNullOrEmpty($object.ResourceName))) {
			
			# determine the odd/even nature of the row and use the appropriate CSS class
			$cssStyle = if ($cnt % 2 -eq 0) { "background-color: #ffffff;" } else { "background-color: #B3E5FC;" }
			# Add the main row
			$retVal += "  <tr class='main-row' style='$cssStyle'>`n"
			$retVal += "    <td><button type='button' id='prop' onclick='toggleRow(this)'>⮟</button></td>`n"
			$retVal += "    <td>$($object.ResourceName)</td>`n"
			$retVal += "    <td>$($object.ResourceLocation)</td>`n"
			$retVal += "    <td>$($object.ResourceGroupName)</td>`n"
			$retVal += "    <td>$($object.ResourceType)</td>`n"
			$retVal += "    <td align=right style='background-color: #ffffff;'>&nbsp</td>`n"
			$retVal += "  </tr>`n"
			
			# Add the extra properties dropdown row
			$retVal += "  <tr class='details-row' style='display:none'>`n"
			$retVal += "    <td>&nbsp;</td><td colspan=5>`n"
			$retVal += "      <table><tr style='background-color: #FFFDE7'><td>`n"
			$object | ForEach-Object {
				if (-not ([string]::IsNullOrEmpty($_.ResProperties))) {
					$retVal += "        <ul>`n"
					
					try {
						$jsnProps = $_.ResProperties | ConvertFrom-Json
					} catch {
						$jsnProps = $_.ResProperties | ConvertTo-Json | ConvertFrom-Json
					} finally {
						$retVal += "        <li><strong>Properties:</strong><br>`n          "
						$retVal += ConvertTo-IndentedHtmlList -Object $_.ResProperties
						$retVal += "`n        </li>`n"
						
						# Evaluate the row data for the ACP		
						$chkElems = Set-acp -row $object -props $_.Resproperties -name $_.ResourceName
						if (($chkElems -ne $null) -and ($chkElems -ne 0) -and (-not $outElems.Contains($chkElems))) {
							[void]$outElems.Add($chkElems)
						}
					}
					$retVal += "        </ul>`n"
				}
			}
			$retVal += "      </td></tr></table>`n    </td>`n  </tr>`n"
			
			$cnt++
		}
	}
	
	# Close the Table
	$retVal += "</tbody></table>`n`n"
	
	return $retVal
}

function Get-ScriptDirectory {
<#
    .SYNOPSIS
        Get-ScriptDirectory returns the proper location of the script.
 
    .OUTPUTS
        System.String
   
    .NOTES
        Returns the correct path within a packaged executable.
#>
	[OutputType([string])]
	param ()
	if ($null -ne $hostinvocation) {
		Split-Path $hostinvocation.MyCommand.path
	} else {
		Split-Path $script:MyInvocation.MyCommand.Path
	}
}

#####################################
# M A I N  L I N E
#####################################

# Script Version
$myVer = "1.1.2"

# Default the Verbosity of messages to NOT
if ([string]::IsNullOrEmpty($Details)) { $Details = $false }

# Set the Start Time
$startTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$timeId = Get-Date -Format "yyyyMMddHHmmss"

# Get the directory path and file name without extension
$inFile = Split-Path $file -leaf
$dir = Split-Path -Path $file -Parent
$noExt = [System.IO.Path]::GetFileNameWithoutExtension($File)

# Get the script directory
$scriptDir = Get-ScriptDirectory

# Set up the output directory
if ([string]::IsNullOrEmpty($OutPath)) {
	$outDir = "$($scriptDir)\output"
} else {
	$outDir = "$($OutPath)"
}

# Create the output directory if it doesn't exist
if (-not (Test-Path -Path $outDir -PathType Container)) {
	New-Item -ItemType Directory -Force -Path $outDir
}

# Define the log file name
$log = "$($outDir)\resourceProcessor"
if ($Stamp) { $log = "$($log)_$($timeId)" }
$log = "$($log).log"

# Write the program version to the log file/screen
Write-log -toConsole $Details -id 55 -msg "process-ResourceScrape.ps1 Version: $($myVer)"
Write-log -toConsole $Details -id 57 -msg "Input File: $($inFile)"

# Test for the existence of the Rules file
if (-not ([string]::IsNullOrEmpty($rulesFile))) {
	if (-not (Test-Path -Path $rulesFile -PathType Leaf)) {
		$rulesFile = "$($scriptDir)\rules.xml"
	}
} else {
	$rulesFile = "$($scriptDir)\rules.xml"
}
Write-log -toConsole $Details -id 58 -msg "Using Rules File: $($rulesFile)"

if (Test-Path $file -PathType Leaf) {
	Write-log -toConsole $Details -id 59 -msg "Input File Found. Continuing... `n"
	
	# Read the JSON file Resource Scrape
	$jsonScrape = Get-Content -Path $File -Raw | ConvertFrom-Json
	
	# Start building the HTML table markup
	$htmlTable = "`n<table id='resTable' style='width:800px'>`n"
	
	# Get the property names from the first object to use as table headers
	$headers = "", "Name", "Location", "Resource Group", "Resource Type", ""
	
	# Add table headers
	Write-log -toConsole $Details -id 61 -msg "Adding Table headers`n"
	$htmlTable += (Add-headers -listHeaders $headers)
	$htmlTable += "`n<tbody>`n"
	
	# Add table rows
	Write-log -toConsole $Details -id 62 -msg "Building the report body`n"
	$htmlTable += (Build-Body -rowData $jsonScrape)
	
	# Build the final initial ACP suggestion
	Write-log -toConsole $Details -id 63 -msg "Building the initial ACP suggestion`n"
	$group = ""
	$typeElems = $typeElems | Sort-Object
	if ($typeElems.Count -gt 0) {
		if ($outElems.Count -eq 0) {
			$group = "    {`n    {`n            `"field`": `"type`",`n            `"in`": [`n"
		} else {
			$group = "`n                {`n                    `"field`": `"type`",`n                    `"in`": [`n"
		}
		for ($x = 0; $x -lt $typeElems.Count; $x++) {
			$group += "                        `"$($typeElems[$x])`""
			if ($x -eq ($typeElems.Count - 1)) {
				$group += "`n"
			} else {
				$group += ",`n"
			}
		}
	}
	
	# Add the final Type Group to the ACP suggestion
	if ($group.Length -gt 0) { [void]$outElems.Add($group) }
	[void]$outElems.Add("                    ]`n                }`n            ]`n        }`n    },`n    `"then`": {`n        `"effect`": `"deny`"`n    }`n}")
	# Add the opening "If" statement to the outElems array
	[void]$outElems.Insert(0, "{`n    `"if`": {`n        `"not`": {`n            `"anyOf`": [`n")
	
	# Construct the output file path with the new extension
	Write-log -toConsole $Details -id 64 -msg "Defining the output files and paths`n"
	$outFile = Join-Path -Path $outDir -ChildPath "$($noExt).html"
	$outACP = (Join-Path -Path $outDir -ChildPath "$($noExt)").Replace("resourceScrape", "initialACP")
	$outACP += ".json"
	$inACPFile = Split-Path $outACP -leaf
	
	# Define the HTML document content
	Write-log -toConsole $Details -id 65 -msg "Assembling the HTML document`n"
	$htmlDocument = @"
<!DOCTYPE html>
<html lang='en'>
<head>
<meta charset='UTF-8'>
<meta name='viewport' content='width=device-width, initial-scale=1.0'>
<title>Resource Scrape Results</title>

<style>
    /* Basic table styling */
    table {
        border-collapse: collapse;
        width: 800px;
    }
    th, td {
        border: none;
		padding: 3;
		text-align: left;
		vertical-align:top;
    }

    /* Alternating row colors */
	th {
		background-color: #1E88E5; /* Header Row */
		color: white;
	}
</style>
</head>
<body>

<h2 style='text-align:center; background-color:#CFD8DC;'>Resource Scrape Results - $inFile</h2>
<table id='outTable' border=0><tr><td><strong>Download <a href="$inFile" download>$inFile</a></strong><br>
$htmlTable
</td>
<td>&nbsp;&nbsp;&nbsp;</td>
<td style='width:800px'>
    <strong>Download Initial ACP&nbsp;&nbsp;-&nbsp;&nbsp;<a href="$outACP" download>$inACPFile</a></strong><br>
    <strong>ACP Documentation</strong>&nbsp;&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;<a href="https://docs.skillable.com/docs/azure-access-control-policy-creation" target="_blank">ACP Documentation</a><br>
    <textarea id="initialACP" name="initialACP" rows="50" cols="100" onkeyup="textAreaAdjust(this)" style="overflow:hidden; overflow-y:scroll;">$outElems</textarea><br>
	<strong>Supported ACP Conditions</strong><br>
<ul>
<li>"equals": "stringValue"</li>
<li>"notEquals": "stringValue"</li>
<li>"like": "stringValue"</li>
<li>"notLike": "stringValue"</li>
<li>"match": "stringValue"</li>
<li>"matchInsensitively": "stringValue"</li>
<li>"notMatch": "stringValue"</li>
<li>"notMatchInsensitively": "stringValue"</li>
<li>"contains": "stringValue"</li>
<li>"notContains": "stringValue"</li>
<li>"in": ["stringValue1","stringValue2"]</li>
<li>"notIn": ["stringValue1","stringValue2"]</li>
<li>"containsKey": "keyName"</li>
<li>"notContainsKey": "keyName"</li>
<li>"less": "dateValue" | "less": "stringValue" | "less": intValue</li>
<li>"lessOrEquals": "dateValue" | "lessOrEquals": "stringValue" | "lessOrEquals": intValue</li>
<li>"greater": "dateValue" | "greater": "stringValue" | "greater": intValue</li>
<li>"greaterOrEquals": "dateValue" | "greaterOrEquals": "stringValue" | "greaterOrEquals": intValue</li>
<li>"exists": "bool"</li>
</ul>
</td></tr></table>

<script src='https://code.jquery.com/jquery-3.6.0.min.js'></script>
<script src='https://cdnjs.cloudflare.com/ajax/libs/jquery.tablesorter/2.31.3/js/jquery.tablesorter.min.js'></script>

<script>
function textAreaAdjust(element) {
  element.style.height = "1px";
  element.style.height = (25+element.scrollHeight)+"px";
}

function toggleRow(button) {
    var row = button.parentNode.parentNode;
    var nextRow = row.nextElementSibling;
    if (nextRow.style.display === 'none') {
        nextRow.style.display = 'table-row';
        button.innerText = '⮝';
    } else {
        nextRow.style.display = 'none';
        button.innerText = '⮟';
    }
}
var buttons = document.getElementsByTagName('button');
for (var i = 0; i < buttons.length; i++) {
    buttons[i].addEventListener('click', function() {
        toggleRow(this);
    });
}
var rows = document.getElementsByClassName('main-row');
for (var i = 0; i < rows.length; i++) {
    rows[i].addEventListener('click', function() {
        var nextRow = this.nextElementSibling;
        var button = this.querySelector('button');
        if (nextRow.style.display === 'none') {
            nextRow.style.display = 'table-row';
            button.innerText = '⮝';
        } else {
            nextRow.style.display = 'none';
            button.innerText = '⮟';
        }
    });
}
</script>

</body>
</html>
"@
	
	Write-log -toConsole $Details -id 66 -msg "Writing out the HTML file and initial ACP file`n"
	
	# Save the HTML document to a file
	$htmlDocument | Out-File -FilePath $outFile -Encoding UTF8
	
	# Save the initial ACP to a file
	$outElems | Out-File -FilePath $outACP -Encoding UTF8
	
	# Open the HTML document in the default web browser
	if ($showHtml) {
		Invoke-Item $outFile
	}
} else {
	Write-log -toConsole $Details -id 10 -msg "Input file path is required. Please try again.`nFile: $($file)"
	throw "Invalid file or path. Please try again."
	exit
}
