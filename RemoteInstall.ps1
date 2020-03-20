Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

choco install 7zip -y
choco install curl -y
choco install Firefox -y
choco install git -y
choco install GoogleChrome -y
choco install ngrok.portable -y
choco install nodejs.install -y
choco install notepadplusplus -y
choco install poshgit -y
choco install putty.install -y
choco install slack -y
choco install SourceTree -y
choco install sysinternals -y
choco install tortoisegit -y
choco install visualstudiocode -y
choco install ccleaner -y
choco install microsoft-teams -y
choco install dotnetcore-sdk -y
choco install office365proplus -y
choco install jetbrainstoolbox -y
choco install resharper-ultimate-all -y
choco install microsoftazurestorageexplorer -y
choco install choco install visualstudio2019professional --package-parameters "--allWorkloads --includeRecommended --includeOptional --passive --locale en-US" -y