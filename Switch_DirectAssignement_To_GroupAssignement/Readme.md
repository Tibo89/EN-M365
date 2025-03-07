## Description

Extract users from Entra ID and check if the selected license is set with direct assignement or group-based assigment

## Prerequisites

- The MgGraph module must be installed
- API authorizations must be configured for the execution account. You can update the script to call App Registration instead of "Connect-MgGraph", you will need to reuse or deploy an App Registration with API Authorizations

## Params.xml

    UPNFilter : Allows you to retrieve only small amount of your tenant users. If empty, it will get all the users with the license ID specified (optionnal)
    SKULic    : Add the license SkuID spotted, to retrieve all the SkuID try this cmdlet : Get-MgSubscribedSku -All (mandatory)
    IDGroup   : Add comma-separated ID(s) of the groups holding the licenses (mandatory)