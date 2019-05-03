#Requires -version 3.0
#Requires -RunAsAdministrator

<#
    .SYNOPSIS
    Create a D Partition
    .DESCRIPTION
    Resizes C and Creates D Partition
    .PARAMETER splitUnit
    gb / abs for absolute value in GB, percent / rel for relative value
    .PARAMETER amount
    the amount in GB or %
    .EXAMPLE
    Resize-EmpirumCPartition.ps1 -splitUnit percent -amount 50
#>

[CmdletBinding()]

param(
  [parameter(Mandatory)]
  [ValidateSet('gb','percent','abs','rel',ignorecase=$false)]
  [String] $splitUnit,
  [parameter(Mandatory)]
  [Int] $amount
)

function Resize-C-Abs {
  $diskC = (Get-Partition -DriveLetter 'C')
  $total = $diskC.Size															#Größe von C
  $minimum = (Get-PartitionSupportedSize -DriveLetter C).SizeMin												#Minimale mögliche Größe von C
  $free = ($total - $minimum)/1GB																			#Freier Speicher in GB
  if ($free -gt $amount)																					#Ist genug Speicherplatz vorhanden? Wenn nicht 50/50%
  {
    $cSize = $total - ($amount*1GB)																		#Neue Größe für C festlegen
    Resize-Partition -DriveLetter C -Size $cSize													#C verkleinern
    New-Partition -DiskNumber $diskC.DiskNumber -DriveLetter D -UseMaximumSize							#Partition D mit maximaler möglicher Größe erstellen
    Format-Volume -DriveLetter D -FileSystem NTFS -NewFileSystemLabel Daten 							#D formatieren
  }
  else
  {
    Write-Verbose -Message ("Error! Only {0} GB available, can't shrink by {1} GB! Going with 50%/50%" -f $free, $amount)
    $script:amount = 50
    Resize-C-Percent
  }
}

function Resize-C-Percent {

  $diskC = (Get-Partition -DriveLetter 'C')
  $total = $diskC.Size															#Größe von C
  $minimum = (Get-PartitionSupportedSize -DriveLetter C).SizeMin												#Minimale mögliche Größe von C
  $free = ($total - $minimum)																				#Freier Speicher
  $shortenBy = $total * ($amount/100)
  if ($free -gt $shortenBy)																				#Ist genug Speicherplatz vorhanden?
  {
    $cSize = $total - $shortenBy																		#Neue Größe für C festlegen
    Resize-Partition -DriveLetter C -Size $cSize														#C verkleinern
    New-Partition -DiskNumber $diskC.DiskNumber -DriveLetter D -UseMaximumSize											#Partition D mit maximaler möglicher Größe erstellen
    Format-Volume -DriveLetter D -FileSystem NTFS -NewFileSystemLabel Daten 							#D formatieren
  }
  else
  {
    Write-Verbose -Message ("Error! Can't shrink by {0} % ({1} B). Only {2} B available" -f $amount, $shortenBy, $free)
  }
}

function New-D-2ndDisk {
  $diskC = Get-Partition -DriveLetter C | Get-Disk													#Gesamtgröße der Festplatte
  $drives = Get-PhysicalDisk | Where-Object {$_.MediaType -eq 'HDD' -or $_.MediaType -eq 'SSD'}
  Write-Verbose -Message 'Creating D on second Hard Drive...'
  $diskD = Get-Disk | Where-Object {($_.Number -ne $diskC.Number) -and ($_.UniqueId -eq $drives.UniqueId)}	#Nimm das Drive, welches eine HDD oder SSD ist und nicht C ist
  $diskDNumber = $diskD.Number
  Clear-Disk -Number $diskDNumber -RemoveData -RemoveOEM														#Entferne Daten auf 2ter Festplatte.
  Initialize-Disk  -Number $diskDNumber																		#Initialisiere Disk. GPT ist default. Für MBR: -PartitionStyle MBR
  New-Partition -DiskNumber $diskDNumber -DriveLetter D -UseMaximumSize								#2. Festplatte als D nehmen
  Format-Volume -DriveLetter D -FileSystem NTFS -NewFileSystemLabel Daten 							#D formatieren
}

$isDaDrive = $(Get-WmiObject -class Win32_Volume |Where-Object {$_.DriveLetter -eq 'D:'})

if ( ( $isDaDrive | Measure-Object).Count -ne 0)	#D Partition exists
{
  Write-Verbose -Message 'Error! D: does already exist...'
  if($isDaDrive.DriveType -eq 5) { # CD/DVD/BD-ROM
    $isDaDrive.DriveLetter = $(for($j=67;gdr($d=[char]++$j)2>0){}$d)+':'
    $isDaDrive.Put() | Out-Null
  }
  elseif($isDaDrive.DriveType -eq 2) { # Card-Reader
    $isDaDrive.DriveLetter = $(for($j=67;gdr($d=[char]++$j)2>0){}$d)+':'
    $isDaDrive.Put() | Out-Null
  }
  elseif( $(Get-PhysicalDisk |Where-Object {$_.MediaType -ne 'SSD' -and $_.MediaType -ne 'HDD'}).DeviceId -contains $(try { (Get-Partition -DriveLetter 'D').DiskNumber } catch {}) ) { # USB Drive
    Set-Partition -DriveLetter 'D' -NewDriveLetter $(for($j=67;gdr($d=[char]++$j)2>0){}$d)
  }
}

$countDrives = (Get-WmiObject -Class Win32_Volume |Where-Object {$_.DriveType -eq 3 -and $_.DriveLetter -ne $null} |Measure-Object).Count	#Zähle HDDs und SSDs
if ($countDrives -eq 1)																									#Nur 1ne HDD/SSD?
{
  Write-Verbose -Message 'Shrinking C and Creating D...'
  if ($splitUnit -eq 'gb' -or $splitUnit -eq 'abs')		#Soll um GB verkleinert werden?
  {
    Resize-C-Abs
  }
  else #es wird um Prozente verkleinert
  {
    Resize-C-Percent
  }
}
elseif ($countDrives -eq 2)
{
  New-D-2ndDisk
}
else
{
  Write-Verbose -Message ('Error! {0} HDD/SSD Drives found!' -f $countDrives)
}
