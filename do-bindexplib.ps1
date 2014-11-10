#
# Run bindexplib using dumpbin.
#

#
# Some things we block (these are copied from bindexplib's logic):
#  Any deleting dtor
#
# Some things it blocks but we don't yet (b.c. we've not encountered them yet):
#  Any symbol with "real@" in it.

param(
    [parameter(Mandatory = $true)] [string] $filename,
    [parameter(Mandatory = $True)] [string] $libraryName
    )

if (-not $(test-path $filename)) {
  Write-Host "File $filename does not exist."
  return
}

#
# Next, run dump bin and get the output from it
#

$completeListing = & "C:\Program Files (x86)\Microsoft Visual Studio 11.0\VC\bin\dumpbin.exe" /headers /symbols $filename

#
# Now, process each line, and extract the symbols and the section information.
#

$functionSymbols = @()
$dataSymbols = @()
$dataOnDeck = ""

$sectionInfo = @{}
$sectionNumber = ""
$readingHeaderTable = $True

foreach ($line in $completeListing) {
  if ($readingHeaderTable) {
    if ($line.Contains("COFF SYMBOL TABLE")) {
	  $readingHeaderTable = $False
	} else {
	  if ($line.Contains("SECTION HEADER #")) {
	    $sectionNumber = $line.SubString(16)
	  }
	  if ($line.Contains("Read Only")) {
		$sectionInfo["$sectionNumber"] = @{"ReadOnly" = $True}
	  }
	  if ($line.Contains("Read Write")) {
		$sectionInfo["$sectionNumber"] = @{"ReadOnly" = $False}
	  }
	}
  } else {
	  # Is this a good line? We can tell if we look at the split by spaces, and the first
	  # guy is a 3 letter word.
	  $symbolInfo = -split $line
	  $symbolIndex = $symbolInfo[0]
	  if ($symbolIndex.Length -eq 3) {
		# Get the symbol name, make sure it is properly formatted with the mangled name
		$symbolNameInfo = $line -split "\|"
		if ($symbolNameInfo.Count -eq 2) {
		  if (-not $symbolNameInfo[1].Contains("deleting destructor")) {
			$symbolNameInfo = -split $symbolNameInfo[1]
			$symbolName = $symbolNameInfo[0]

			$section = $symbolInfo[2]
			$type = $symbolInfo[3]
			$other = $symbolInfo[4]

			#Accumulate the data and method guys
			if ($section -ne "UNDEF") {
			  if ($other -eq "()") {
				$linkage = $symbolInfo[5]
				if ($linkage -eq "External") {
				  $functionSymbols += $symbolName
				}
			  } else {
				# Make sure that this data is writable - otherwise no need to export it!
				if ($section.Length -ge 4) {
					$sectionNumber = $section.SubString(4)
					$sectionReadOnly = $True
					if ($sectionInfo.Contains("$sectionNumber")) {
					  $sectionReadOnly = $sectionInfo["$sectionNumber"]["ReadOnly"]
					}
					$linkage = $symbolInfo[4]
					if ($linkage -eq "External" -and (-not $sectionReadOnly)) {
					  $dataSymbols += $symbolName
					}
				}
			  }
			}
		  }
		}
	  }
	}
}

#
# Format it correctly for output
#

Write "LIBRARY    $libraryName"
Write "EXPORTS "

foreach ($f in $functionSymbols) {
  Write "`t$f"
}
foreach ($s in $dataSymbols) {
  Write "`t$s `t DATA"
}
