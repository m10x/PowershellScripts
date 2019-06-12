# PowershellScripts

## Delete Fast Big Amount of Files with Progress
[IO.Directory]::EnumerateFiles("C:\FOLDER_WITH_FILES_TO_DELETE") | select -first 100000 | where { [IO.File]::GetLastWriteTime($_) -lt (Get-Date).AddDays(-90) } | foreach { $c = 0 } { Write-Progress -Activity "Delete Files" -CurrentOperation $_ -PercentComplete ((++$c/100000)*100); rm $_ }
