﻿<#
.SYNOPSIS
Remove undesirable charaters from comma-separated value (CSV) files, especially the files generated by SQL Server Management Studio 2012 "Save Results As..." functionality.

.PARAMETER Files
Array of paths to be cleansed.  Pipeline values also supported.

.PARAMETER Encoding
The file's encoding.

.PARAMETER Nulls
Remove the word 'NULL' from the file.

.PARAMETER Milliseconds
Remove milliseconds from datetime values.  2015-12-13 23:32:59.000 --> 2015-12-13 23:32:59

.PARAMETER DoubleQuotes
Remove double quotes (") from the file.

.EXAMPLE
PS> Invoke-CsvCleanser 'path\to\file.csv' -Nulls -Milliseconds

.EXAMPLE
PS> Get-Items *.csv | Invoke-CsvCleanser '' -Nulls -Milliseconds

#>
function Invoke-CsvCleanser {

    [CmdletBinding()]
    Param
    (
        [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName = $true)]
        [Alias('FullName','f')]
        <#
        [ValidateScript({
            if(!(Test-Path -LiteralPath $_ -PathType Leaf))
            {
                throw "File doesn't exist: $_"
            }
            $true
        })]
        #>
        [ValidateNotNullOrEmpty()]
        [string[]]$Files,

        <#
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateScript({
            if(!(Test-Path -LiteralPath $_ -PathType Container))
            {
                try
                {
                    New-Item -ItemType Directory -Path $_ -Force
                }
                catch
                {
                    throw "Can't create output folder: $_"
                }
            }
            $true
        })]
        [ValidateNotNullOrEmpty()]
        [string]$OutPath,
        #>

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('e')]
        [string]$Encoding = 'Default',

        [switch][Alias('n')]$Nulls,

        [switch][Alias('m')]$Milliseconds,

        [switch][Alias('q')]$DoubleQuotes,

        [switch][Alias('a')]$Alert,

        [switch]$PassThru

    )

    BEGIN {
        Write-Debug "$($MyInvocation.MyCommand.Name)::Begin"

        # Set default encoding
        if($Encoding -eq 'Default') {
            $FileEncoding = [System.Text.Encoding]::Default
        }
        # Try to set user-specified encoding
        else {
            try {
                $FileEncoding = [System.Text.Encoding]::GetEncoding($Encoding)
            }
            catch {
                throw "Not valid encoding: $Encoding"
            }
        }

        Write-Debug "Encoding: $FileEncoding"
        Write-Debug "Nulls: $Nulls"
        Write-Debug "Milliseconds: $Milliseconds"
        Write-Debug "DoubleQuotes: $DoubleQuotes"
        Write-Debug "Alert: $Alert"
        Write-Debug "PassThru: $PassThru"

        $DQuotes = '"'
        $Separator = ','
        # http://stackoverflow.com/questions/15927291/how-to-split-a-string-by-comma-ignoring-comma-in-double-quotes
        $SplitRegex = "$Separator(?=(?:[^$DQuotes]|$DQuotes[^$DQuotes]*$DQuotes)*$)"
        # Regef to match NULL
        $NullRegex = '^NULL$'
        # Regex to match milliseconds: 23:00:00.000
        $MillisecondsRegex = '(\d{2}:\d{2}:\d{2})(\.\d{3})'

    } # BEGIN

  PROCESS {
        Write-Debug "$($MyInvocation.MyCommand.Name)::Process"

        Foreach ($File In $Files) {

            [DateTime] $started = Get-Date

            $Item = (Get-Item $File)

            $InFile = New-Object -TypeName System.IO.StreamReader -ArgumentList (
                #$_.FullName,
                $Item.FullName,
                $FileEncoding
            ) -ErrorAction Stop

            Write-Debug 'Created INPUT StreamReader'

            $tempFile = "$env:temp\TEMP-$(Get-Date -format 'yyyy-MM-dd hh-mm-ss').csv"
            # $tempFile = (Join-Path -Path $OutPath -ChildPath $_.Name)

            $OutFile = New-Object -TypeName System.IO.StreamWriter -ArgumentList (
                $tempFile,
                $false,
                $FileEncoding
            ) -ErrorAction Stop

            Write-Debug 'Created OUTPUT StreamWriter'

            # progress indicator
            $Activity = "Processing $Item..."
            $Length = $Item.Length
            $Done=0
            $rows=0

            While (($line = $InFile.ReadLine()) -ne $null) {

                $rows += 1
                $Done += $Line.Length
                Write-Progress -Activity $Activity -Status ("{0:p0} Complete:" -f ($Done/$Length)) -PercentComplete (($Done/$Length) * 100)

                Write-Debug "Raw: $line"

                $tmp = $line -split $SplitRegex | ForEach-Object {

                    # Strip surrounding quotes
                    if($DoubleQuotes) { $_ = $_.Trim($DQuotes) }

                    # Strip NULL strings
                    if($Nulls) { $_ = $_ -replace $NullRegex, '' }

                    # Strip milliseconds
                    if($Milliseconds) { $_ = $_ -replace $MillisecondsRegex, '$1' }

                    # Output current object to pipeline
                    $_

                } # Foreach

                Write-Debug "Clean: $($tmp -join $Separator)"

                # Write line to the new CSV file
                $OutFile.WriteLine($tmp -join $Separator)

            } # While

            # [DateTime] $ended = Get-Date
            [TimeSpan] $duration = (Get-Date) - $started

            Write-Verbose ("Processed {0} ({1:N0} bytes; {2:N0} rows) in {3}" -f $Item, $Item.Length, $rows, $duration)

            # Close open files and cleanup objects
            $OutFile.Flush()
            $OutFile.Close()
            $OutFile.Dispose()
            
            $InFile.Close()
            $InFile.Dispose()

            # move and replace
            Move-Item $tempFile $Item.FullName -Force

            If ($PassThru) { Write-Output (Get-Item $File) }
            If ($Alert) { [System.Media.SystemSounds]::Beep.Play() }

        } # Foreach

    } # PROCESS

    END { Write-Debug "$($MyInvocation.MyCommand.Name)::End"}

}

Set-Alias icc Invoke-CsvCleanser