Get-Content requirements.txt | ForEach-Object { ($_ -split '[<>=]')[0].Trim() } | ForEach-Object { poetry add $_ }
