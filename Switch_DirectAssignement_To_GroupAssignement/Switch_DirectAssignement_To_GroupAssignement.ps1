Clear-Host

$myDir = Split-Path -Parent $MyInvocation.MyCommand.Path
[xml]$ConfigFile = Get-Content ($MyDir+"\Params.xml")

$ResultsFile = ($MyDir+"\Results.txt")
Set-Content $ResultsFile -Value $null
$idLicGroup = ($ConfigFile.Settings.IDGroup) -Split ","
if([string]::IsNullOrEmpty($ConfigFile.Settings.UPNFilter)){$UPNFilter = "*"}else{$UPNFilter = $ConfigFile.Settings.UPNFilter}
$SKULic = $ConfigFile.Settings.SKULic

if(!([string]::IsNullOrEmpty($idLicGroup)) -and !([string]::IsNullOrEmpty($SKULic))){

    $filtredUsers = 0
    $assignedByGroup = 0
    $wronglyAssignedByGroup = 0
    $directAssignement = 0
    $directAssignementModified = 0

    $licensesToRemove = Get-MgSubscribedSku -All | Where-Object{$_.SkuId -eq $SKULic}
    $licId = $licensesToRemove.SkuId
    $licName = $licensesToRemove.SkuPartNumber


    $users = Get-MgUser -All -Property AssignedLicenses, LicenseAssignmentStates, DisplayName, id, userPrincipalName, OnPremisesSyncEnabled, OnPremisesSamAccountName, AccountEnabled | Where-Object{$_.UserPrincipalName -like $UPNFilter} | Select-Object DisplayName, AssignedLicenses, id, userPrincipalName, OnPremisesSyncEnabled, OnPremisesSamAccountName, AccountEnabled -ExpandProperty LicenseAssignmentStates | Select-Object DisplayName, id, userPrincipalName, OnPremisesSyncEnabled, OnPremisesSamAccountName, AccountEnabled, AssignedByGroup, State, Error, SkuId | Where-Object{$_.SkuId -eq $licId}
    $filtredUsers = $users.count
    $users | ForEach-Object{
        $id = $_.Id
        $upn = $_.UserPrincipalName
        $assignedLicenseByGroup = $_.AssignedByGroup
        Write-Host ("[  OK   ] --- Processing user $upn with $licName")

        $params = @{
            groupIds = @(
                $idLicGroup
            )
        }

        if($assignedLicenseByGroup -eq $null){ # This property remains empty while license is directly affected even if the user is member of the right group
            try{
                if(Confirm-MgDirectoryObjectMemberGroup -DirectoryObjectId $id -BodyParameter $params){
                    Write-Host ("`t[  OK   ] --- User " + $upn + " already licensed through group, removing direct licensing")
                    try{
                        Write-Host ("`t`t[  OK   ] --- User " + $upn + " removing direct licensing ...")
                        Add-Content -Path $ResultsFile ("[  OK   ] --- User " + $upn + " removing direct licensing ...") 
                        #Set-MgUserLicense -UserId $_.Id -AddLicenses @() -RemoveLicenses $licId
                        $directAssignementModified++
                        Write-Host ("`t`t[  OK   ] --- User " + $upn + " direct licensing has been removed")
                        Add-Content -Path $ResultsFile ("[  OK   ] --- User " + $upn + " direct licensing has been removed")
                    }
                    catch{
                        Write-Host ("`t`t[ ERROR ] --- User " + $upn + " unable to remove direct licensing") -ForegroundColor Red
                        Add-Content -Path $ResultsFile ("[ERROR] --- User " + $upn + " unable to remove direct licensing")
                    }
                }
                else{
                    Write-Host ("`t[ERROR] --- User " + $upn + " is not member of licensing group, you need to add it to the proper group")  -ForegroundColor Red
                    Add-Content -Path $ResultsFile ("[ERROR] --- User " + $upn + " is not member of licensing group, you need to add the user to the proper group")
                    $directAssignement++
                }
            }
            catch{
                Write-Host ("`t`t[ERROR] --- User " + $upn + " cannot check group membership") -ForegroundColor Red
                Add-Content -Path $ResultsFile ("[ERROR] --- User " + $upn + " cannot check group membership")
            }
        }
        else{
            $testGroup = Confirm-MgDirectoryObjectMemberGroup -DirectoryObjectId $id -BodyParameter $params
            if($testGroup.count -eq 1){
                Write-Host ("`t[  OK   ] --- User " + $upn + " is group-based licensed") -ForegroundColor Green
                Add-Content -Path $ResultsFile ("[  OK   ] --- User " + $upn + " is group-based licensed")
                $assignedByGroup++
            }
            else{
                Write-Host ("`t[ERROR] --- User " + $upn + " is group-based licensed but not with a group set in the params.xml file") -ForegroundColor Red
                Add-Content -Path $ResultsFile ("[ERROR] --- User " + $upn + " is group-based licensed but not with a group set in the params.xml file")
                $wronglyAssignedByGroup++
            }
            
        }
    }

    Write-Host ("")
    Write-Host ("Filtred users                                        =   $filtredUsers")
    Write-Host ("Direct assignement with no group from params.xml     =   $directAssignement")
    Write-Host ("Direct assignement removed                           =   $directAssignementModified")
    Write-Host ("Group-based licesend with group from params.xml      =   $assignedByGroup")
    Write-Host ("Group-based licensed with no group from params.xml   =   $wronglyAssignedByGroup")
}
else{
    Write-Host ("[ERROR] --- Params.xml file not set properly, SKULic and/or IDGroup empty, see Readme.md for more informations") -ForegroundColor Red
    Add-Content -Path $ResultsFile ("[ERROR] --- Params.xml file not set properly, SKULic and/or IDGroup empty, see Readme.md for more informations")
}