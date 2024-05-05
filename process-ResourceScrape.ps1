<#
	.SYNOPSIS
		A brief description of the  file.
	
	.DESCRIPTION
		A description of the file.
	
	.PARAMETER File
		Supply the input file containing the JSON object of the Resource Scrape to be processed
	
	.PARAMETER showHtml
		If you want to view the HTML output automatically include the showHTML switch parameter
	
	.PARAMETER show-HTML
		If you want to view the HTML output automatically include the show-HTML switch parameter
	
	.NOTES
		===========================================================================
		Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2023 v5.8.232
		Created on:   	3/12/2024 1:55 PM
		Created by:   	WayneKlapwyk
		Organization: 	Skillable
		Filename:     	process-ResourceScrape
		===========================================================================
#>
param
(
	[Parameter(Mandatory = $true)]
	[Alias('f')]
	$file,
	[Parameter(HelpMessage = 'If you want to view the HTML output automatically include the show-HTML switch parameter')]
	[Alias('h')]
	[switch]$showHtml
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
		$msg,
		[bool]$toConsole = $false
	)
	
	# Define the log file name
	$log = "$($outDir)\resourceScrape_" + (Get-Date).ToString("yyyyMMdd-HHmmss") + ".log"
	
	# Get the Date/Time
	$dte = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
	
	# Write the message to the log file
	Write-Output "$($dte) $($msg)" | Out-file $log -append
	
	if ($toConsole) {
		Write-Host "$($dte) $($msg)" | Out-file $log -append
	}
}

function ConvertTo-IndentedHtmlList {
	param (
		[Parameter(Mandatory = $true)]
		[Object]$Object,
		[int]$IndentLevel = 0
	)
	
	$indentation = ' ' * ($IndentLevel * 4)
	$html = "$indentation<ul>"
	
	$objProperties = $object | ConvertTo-Json | ConvertFrom-Json
	
	foreach ($property in $Object.PSObject.Properties) {
#		$propertyName = "<button type='button' onclick='alert(`"Hello world!`")'><strong>&#10148;</strong></button>&nbsp;$($property.Name)"
		$propertyName = "$($property.Name)"
		$propertyValue = $property.Value
		
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
	
	return $html
}

function Add-headers {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $false)]
		$listHeaders
	)
	
	# Build the header based on the input list
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

function Add-propElement {
	[CmdletBinding()]
	param
	(
		$name,
		$type,
		$field
	)
	
	$retProp = ""
	
	if ($type -eq "contains" -or $type -eq "in") {
		$retProp += ",`n            {`n                `"field`": `"$($field)`",`n                `"$($type)`": [`""
		foreach ($item in $name) { $retProp += "`"$item`"" }
		$retProp += "`"    ]`n            }"
	} else {
		$retProp += ",`n            {`n                `"field`": `"$($field)`",`n                `"$($type)`": `"$($name)`"`n            }"
	}
	
	return $retProp
}


function Set-acp {
	[CmdletBinding()]
	param
	(
		$name,
		$row,
		$props
	)
	
	# Read the Resources file into a variable
	[xml]$rules = Get-Content -Path "rules.xml"
	
	# Find the row.ResourceType in the rules file
	#	$rule = $rules | Select-Xml -XPath "//*[@type=$row.ResourceType]" | Select -ExpandProperty Node
	$cnt=0
	#	$rules.resources.resource | ForEach-Object {
	for ($x = 0; $x -lt $rules.resources.resource.count; $x++) {
		$rule = $rules.resources.resource[$x]
		
#		if ($_.type -eq $row.ResourceType) {
		if ($rule.type -eq $row.ResourceType) {
			# Check to see if any properties exist for this rule
#			if ($_.properties -ne $null) {
			if ($rule.properties -ne $null) {
				foreach ($node in $rule.properties) {
					$doug = "me"
					if ($node.provisioningState -eq $props.provisioningState) {
						$acpName = ""
						$acpNotName = ""
						$acpNameType = $node.Name.type
						$acpSkuName = ""
						$acpNotSkuName = ""
						$acpSkuNameType = $node.sku_Name.type
						$acpSkuTier = ""
						$acpNotSkuTier = ""
						$acpSkuTierType = $node.sku_Tier.type
						$acpSkuCap = ""
						$acpNotSkuCap = ""
						$acpSkuCapType = $node.sku_Capacity.type
						$acpLocation = ""
						$acpNotLocation = ""
						$acpLocationType = $node.location.type
						
						# Name
						$acpName = $node.Name.equal
						$acpNotName = $node.Name.notequal
						if ($acpName -eq "value") {
							$arr = $node.Name.value.split(".")
							$acpName = $props.($arr[0]).($arr[1])
							if ($acpNotName -eq "value") {
								$arr = $node.Name.notvalue.split(".")
								$acpNotName = $node.Name.notvalue
							}
						}
						
						# SKU Name
						$acpSkuName = $node.sku_Name.equal
						$acpNotSkuName = $node.Sku_Name.notequal
						if ($acpSkuName -eq "value") {
							$arr = $node.Sku_Name.value.split(".")
							$acpSkuName = $props.($arr[0]).($arr[1])
							if ($acpNotSkuName -eq "value") {
								$arr = $node.Sku_Name.notvalue.split(".")
								$acpNotSkuName = $props.($arr[0]).($arr[1])
							}
						}
						
						# SKU Tier
						$acpSkuTier = $node.sku_Tier.equal
						$acpNotSkuTier = $node.sku_Tier.notequal
						if ($acpSkuTier -eq "value") {
							$arr = $node.sku_Tier.value.split(".")
							$acpSkuTier = $props.($arr[0]).($arr[1])
							if ($acpNotSkuTier -eq "value") {
								$arr = $node.sku_Tier.notvalue.split(".")
								$acpNotSkuTier = $props.($arr[0]).($arr[1])
							}
						}
						
						# SKU Capacity
						$acpSkuCap = $node.sku_Capacity.equal
						$acpNotSkuCap = $node.sku_Capacity.notequal
						if ($acpSkuCap -eq "value") {
							$arr = $node.sku_Capacity.value.split(".")
							$acpSkuCap = $props.($arr[0]).($arr[1])
							if ($acpNotSkuCap -eq "value") {
								$arr = $node.sku_Capacity.notvalue.split(".")
								$acpNotSkuCap = $props.($arr[0]).($arr[1])
							}
						}
						
						# Location
						$acpLocation = $node.Location.equal
						$acpNotLocation = $node.Location.notequal
						if ($acpLocation -eq "value") {
							$arr = $node.Location.value.split(".")
							$acpLocation = $props.($arr[0]).($arr[1])
							if ($acpNotLocation -eq "value") {
								$arr = $node.Location.notvalue.split(".")
								$acpNotLocation = $props.($arr[0]).($arr[1])
							}
						}
						# Add the element with Properties
						$elem = "{`n    {`n        `"allOf`": [`n            {`n                `"field`": `"type`",`n                `"equals`": `""
						$elem += "$($rule.type)`"`n            }"
						
						if (-not [string]::IsNullOrEmpty($acpName)) {
							$elem += Add-propElement -name $acpName -type $acpNameType -field "name"
						}
						if (-not [string]::IsNullOrEmpty($acpNotName)) {
							$elem += Add-propElement -name $acpNotName -type "notEquals" -field "name"
						}
						if (-not [string]::IsNullOrEmpty($acpSkuName)) {
							$elem += Add-propElement -name $acpSkuName -type $acpSkuNameType -field "Microsoft.Compute/virtualMachines/sku.name"
						}
						if (-not [string]::IsNullOrEmpty($acpNotSkuName)) {
							$elem += Add-propElement -name $acpNotSkuName -type "notEquals" -field "Microsoft.Compute/virtualMachines/sku.name"
						}
						if (-not [string]::IsNullOrEmpty($acpSkuTier)) {
							$elem += Add-propElement -name $acpSkuTier -type $acpSkuTierType -field "Microsoft.Compute/virtualMachines/sku.tier"
						}
						if (-not [string]::IsNullOrEmpty($acpNotSkuTier)) {
							$elem += Add-propElement -name $acpNotSkuTier -type "notEquals" -field "Microsoft.Compute/virtualMachines/sku.tier"
						}
						if (-not [string]::IsNullOrEmpty($acpSkuCap)) {
							$elem += Add-propElement -name $acpSkuCap -type $acpSkuCapType -field "Microsoft.Compute/virtualMachines/sku.Capacity"
						}
						if (-not [string]::IsNullOrEmpty($acpNotSkuCap)) {
							$elem += Add-propElement -name $acpNotSkuCap -type "notEquals" -field "Microsoft.Compute/virtualMachines/sku.Capacity"
						}
						if (-not [string]::IsNullOrEmpty($acpLocation)) {
							$elem += Add-propElement -name $acpLocation -type $acpLocationType -field "location"
						}
						if (-not [string]::IsNullOrEmpty($acpNotLocation)) {
							$elem += Add-propElement -name $acpNotLocation -type "notEquals" -field "location"
						}
						$elem += "`n        ]`n    }"
#						if (-not $propElems.Contains($elem)) { $propElems.Add($elem) }
						if (-not $arrElems.Contains($elem)) { [void]$arrElems.Add($elem) }
					}
				}
			} else {
#				$elem = "`n    {`n        `"field`": `"type`",`n        `"equals`": `"$($rule.type)`"`n    }"
				#				if (-not $actElems.Contains($elem)) { $actElems.Add($elem) }
				
				# Add the element without properties
				if (-not $typeElems.Contains($rule.type)) { [void]$typeElems.Add($rule.type) }
#				if (-not $arrElems.Contains($rule.type)) { $arrElems.Add($rule.type) }
#				if (-not $arrElems.Contains($elem)) { [void]$arrElems.Add($elem) }
			}
			break
		}
	}
	
	return $arrElems
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
		if (-not ([string]::IsNullOrEmpty($object.Name))) {
			
			# determine the odd/even nature of the row and use the appropriate CSS class
			$cssStyle = if ($cnt % 2 -eq 0) { "background-color: #ffffff;" } else { "background-color: #B3E5FC;" }
			# Add the main row
			$retVal += "  <tr class='main-row' style='$cssStyle'>`n"
			$retVal += "    <td><button type='button' id='prop' onclick='toggleRow(this)'>⮟</button></td>`n"
			$retVal += "    <td>$($object.Name)</td>`n"
			$retVal += "    <td>$($object.Location)</td>`n"
			$retVal += "    <td>$($object.ResourceGroupName)</td>`n"
			$retVal += "    <td>$($object.ResourceType)</td>`n"
			#			$htmlTable += "    <td align=right style='background-color: #ffffff;'><button type='button' id='elem' onclick='alert(`"Hello Resource!`")'>&#10148;</button></td>`n"
			$retVal += "    <td align=right style='background-color: #ffffff;'>&nbsp</td>`n"
			$retVal += "  </tr>`n"
			
			# Add the extra properties dropdown row
			$retVal += "  <tr class='details-row' style='display:none'>`n"
			$retVal += "    <td>&nbsp;</td><td colspan=5>`n"
			$retVal += "      <table><tr style='background-color: #FFFDE7'><td>`n"
			$object.PSObject.Properties | ForEach-Object {
				if (-not ([string]::IsNullOrEmpty($_.Name)) -and -not ([string]::IsNullOrEmpty($_.Value))) {
					if ($_.Name -eq 'Tags' -or $_.Name -eq 'ResProperties') {
						$retVal += "        <ul>`n"
					}
					if ($_.Name -eq 'Tags') {
						$retVal += "          <li><strong>Tags:</strong> $($_.Value)</li>`n"
					} elseif ($_.Name -eq 'ResProperties') {
						$jsnProps = $_.Value | ConvertFrom-Json
						$retVal += "        <li><strong>Properties:</strong><br>`n          "
						$retVal += ConvertTo-IndentedHtmlList -Object $jsnProps
						$retVal += "`n        </li>`n"
						
						# Evaluate the row data for the ACP		
						$chkElems = Set-acp -row $object -props $jsnProps -name $_.Name
						if (($chkElems -ne $null) -and ($chkElems -ne 0) -and (-not $outElems.Contains($chkElems))) {
							[void]$outElems.Add($chkElems)
						}
						
						#						if (-not $acpList.Contains($arrElems)) { $acpList.Add($arrElems) }
						
					} else {
						# The $_.Name value will be ResourceId or Timestamp and we don't care about those in this situation 
					}
					if (($_.Name -eq 'Tags') -or ($_.Name -eq 'ResProperties')) {
						$retVal += "        </ul>`n"
					}
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


#####################################
# M A I N  L I N E
#####################################

# Script Version
$myVer = "1.0.3"

# Get the directory path and file name without extension
$inFile = Split-Path $file -leaf
$dir = Split-Path -Path $file -Parent
$noExt = [System.IO.Path]::GetFileNameWithoutExtension($File)

Write-Host "`nprocess-ResourceScrape.ps1 Version: $($myVer)"
Write-Host "File: $($infile)"

if (Test-Path $file -PathType Leaf) {
	Write-Host "`nFile Found. Processing... `n"
	
	# Read the JSON file Resource Scrape
	$jsonScrape = Get-Content -Path $File -Raw
	
	# Convert the JSON Resource Scrape into a list
	$jsonObjects = $jsonScrape | ConvertFrom-Json
	
	$sortObjects = $jsonObjects.Resources | Sort-Object -Property "Name"
	
	# Start building the HTML table markup
#	$htmlTable = "`n<table id='resTable' style='width:800px'><thead><tr>`n"
	$htmlTable = "`n<table id='resTable' style='width:800px'>`n"
	
#	# Get the property names from the first object to use as table headers
	$headers = "","Name","Location","Resource Group","Resource Type",""
	
	# Add table headers
	$htmlTable += (Add-headers -listHeaders $headers)
	$htmlTable += "`n<tbody>`n"
	
	# Add table rows
	$htmlTable += (Build-Body -rowData $sortObjects)
	
	# Build the final initial ACP suggestion
	$typeElems = $typeElems | Sort-Object
	if ($typeElems.Count -gt 0) {
		if ($outElems.Count -eq 0) {
			$group = "{`n    {`n        `"field`": `"type`",`n        `"in`": [`n"
		} else {
			$group = ",`n    {`n        `"field`": `"type`",`n        `"in`": [`n"
		}
		for ($x = 0; $x -lt $typeElems.Count; $x++) {
			$group += "            `"$($typeElems[$x])`""
			if ($x -eq ($typeElems.Count - 1)) {
				$group += "`n"
			} else {
				$group += ",`n"
			}
		}
		
	}
	
	
	# Add the final Type Group to the ACP suggestion
	if ($group.count -eq 0) {
		
	}
	[void]$outElems.Add($group)
	[void]$outElems.Add("        ]`n    },`n    `"then`": {`n        `"effect`": `"Deny`"`n    }`n}")
	
	# Construct the output file path with the new extension
	if ([string]::IsNullOrEmpty($dir)) { $dir = "." }
	$outFile = Join-Path -Path $dir -ChildPath "$($noExt).html"
	$outACP = (Join-Path -Path $dir -ChildPath "$($noExt)").Replace("resourceScrape", "initialACP")
	$outACP += ".json"
	$inACPFile = Split-Path $outACP -leaf
	
	# Define the HTML document content
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
<!--
    tr:nth-child(even) {
        background-color: #FFFFFF; /* Even rows */
    }
    tr:nth-child(odd) {
        background-color: #B3E5FC; /* Odd rows */
    }
-->
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
    <strong>ACP Documentation</strong>&nbsp;&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;<a href="https://docs.learnondemandsystems.com/lod/acp-creation-process.md" target="_blank">ACP Documentation</a><br>
    <textarea id="initialACP" name="initialACP" rows="50" cols="100" onkeyup="textAreaAdjust(this)" style="overflow:hidden">$outElems</textarea><br>
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
	

	# Save the HTML document to a file
	$htmlDocument | Out-File -FilePath $outFile -Encoding UTF8
	
	
	# Save the initial ACP to a file
	$outElems| Out-File -FilePath $outACP -Encoding UTF8
	
	# Open the HTML document in the default web browser
	if ($showHtml) {
		Invoke-Item $outFile
	}
} else {
	Write-Host "Input file path is required. Please try again."
	throw "Invalid file or path. Please try again."
	exit
}
