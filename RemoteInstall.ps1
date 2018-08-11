Set-ExecutionPolicy RemoteSigned -Force
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

choco install 7zip -y
choco install curl -y
choco install Firefox -y
choco install git -y
choco install GoogleChrome -y
