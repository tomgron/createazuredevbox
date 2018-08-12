Set-ExecutionPolicy RemoteSigned -Force
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

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
choco install webpi -y
choco install azcopy -y
choco install webpicmd -y
choco install winscp -y
choco install zoomit -y
choco install jq -y
choco install evernote -y
choco install awscli -y
choco install visualstudiocode -y
choco install spotify -y
choco install fiddler4 -y
choco install ccleaner -y
choco install rdcman -y
choco install googledrive -y
choco install microsoft-teams -y
choco install docker-for-windows -y
choco install docker-kitematic -y
choco install zeplin -y
choco install dotnetcore-sdk -y
choco install office365proplus -y
choco install resharper-ultimate-all -y
choco install jetbrainstoolbox -y
choco install steam -y
choco install zoomit -y
choco install rsat -y
choco install kubernetes-cli -y
choco install blender -y
choco install atom -y
choco install autohotkey -y
choco install microsoftazurestorageexplorer -y

choco install intellijidea-ultimate -y
choco install visualstudio2017community --package-parameters "--allWorkloads --includeRecommended --includeOptional --passive --locale en-US" -y
