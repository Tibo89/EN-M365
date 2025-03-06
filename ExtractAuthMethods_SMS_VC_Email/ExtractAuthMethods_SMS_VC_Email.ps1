Clear-Host

$countSMS = 0
$countPhone = 0
$countMail = 0
$countTotal = 0
$countOnly = 0

$myDir = Split-Path -Parent $MyInvocation.MyCommand.Path
[xml]$ConfigFile = Get-Content ($MyDir+"\Params.xml")


$pathSMSFile = ($myDir+"\"+$ConfigFile.Settings.Paths.SMSFile)
$pathPhoneFile = ($myDir+"\"+$ConfigFile.Settings.Paths.PhoneFile)
$pathEmailFile = ($myDir+"\"+$ConfigFile.Settings.Paths.EmailFile)
$pathDeprecatedMethodsFile = ($myDir+"\"+$ConfigFile.Settings.Paths.DeprecatedMethodsFile)

Set-Content -Path $pathSMSFile -Value "UPN;PhoneNumber"
Set-Content -Path $pathPhoneFile -Value "UPN;PhoneNumber"
Set-Content -Path $pathEmailFile -Value "UPN;mail"
Set-Content -Path $pathDeprecatedMethodsFile -Value "UPN"

Get-MgUser -All | ForEach-Object{
    $upn = $_.UserPrincipalName
    $id = $_.Id
    $countTotal++
    $userCount = 1
    try{
        $authMethods = Get-MgUserAuthenticationMethod -UserId $id -ErrorAction Stop
        $authMethods | ForEach-Object{
            
            if($_.AdditionalProperties['@odata.type'] -like "*phone*" -and $_.AdditionalProperties['smsSignInState'] -eq "ready"){
                Write-Host ("$upn with SMS method, phone number : " + $_.AdditionalProperties['phoneNumber'])
                $countSMS++
                $userCount++
                Add-Content -Path $pathSMSFile -Value ($upn+";"+$_.AdditionalProperties['phoneNumber'])
            }
            elseif($_.AdditionalProperties['@odata.type'] -like "*phone*" -and $_.AdditionalProperties['smsSignInState'] -eq "notSupported"){
                Write-Host ("$upn with Voice Call method, phone number : " + $_.AdditionalProperties['phoneNumber'])
                $countPhone++
                $userCount++
                Add-Content -Path $pathPhoneFile -Value ($upn+";"+$_.AdditionalProperties['phoneNumber'])
            }
            elseif($_.AdditionalProperties['@odata.type'] -like "*email*"){
                Write-Host ("$upn with OTP Mail, address : " + $_.AdditionalProperties['emailAddress'])
                $countMail++
                $userCount++
                Add-Content -Path $pathEmailFile -Value ($upn+";"+$_.AdditionalProperties['emailAddress']) 
            }
        }
        if($userCount -eq ($authMethods.count) -and ($authMethods.count) -gt 1){
            Write-Host ("$upn has registred only deprecated method(s)") -ForegroundColor Red
            $countOnly++
            Add-Content -Path $pathDeprecatedMethodsFile -Value ($upn)
        }
    }
    catch{
        Write-Host ("[ERROR] UPN $upn") -ForegroundColor Red
        Write-Host ("[ERROR]  "+ $_.Exception.Message) -ForegroundColor Red
    }
}

Write-Host ("")
Write-Host ("$countSMS users out of $countTotal with SMS Signin method")
Write-Host ("$countPhone users out of $countTotal with Voice Call method")
Write-Host ("$countMail users out of $countTotal with Mail method")
Write-Host ("$countOnly users out of $countTotal with only SMS and/or Voice Call and/or Mail OTP method") -ForegroundColor Red