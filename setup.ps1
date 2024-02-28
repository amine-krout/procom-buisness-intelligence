Clear-Host # Clear console host screen
write-host "Starting script at $(Get-Date)" 
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted # Sets the PowerShell repository named "PSGallery" to have a trusted installation policy. No further confirmation will be demanded when installing modules from this repository.
Install-Module -Name Az.Synapse -Force 

# Handle cases where the user has multiple subscriptions
$subs = Get-AzSubscription | Select-Object # select all subscriptions and store them in variable subs 
if($subs.GetType().IsArray -and $subs.length -gt 1){ # check if subs have more than one subscription
    Write-Host "You have multiple Azure subscriptions - please select the one you want to use:"
    # Subscription selection 
    for($i = 0; $i -lt $subs.length; $i++)
    {
            Write-Host "[$($i)]: $($subs[$i].Name) (ID = $($subs[$i].Id))"
    }
    $selectedIndex = -1
    $selectedValidIndex = 0
    while ($selectedValidIndex -ne 1)
    {
            $enteredValue = Read-Host("Enter 0 to $($subs.Length - 1)")
            if (-not ([string]::IsNullOrEmpty($enteredValue)))
            {
                if ([int]$enteredValue -in (0..$($subs.Length - 1)))
                {
                    $selectedIndex = [int]$enteredValue
                    $selectedValidIndex = 1
                }
                else
                {
                    Write-Output "Please enter a valid subscription number."
                }
            }
            else
            {
                Write-Output "Please enter a valid subscription number."
            }
    }
    $selectedSub = $subs[$selectedIndex].Id
    Select-AzSubscription -SubscriptionId $selectedSub
    az account set --subscription $selectedSub
}

# Prompt user for a password for the SQL Database
$sqlUser = "SQLUser"
write-host ""
$sqlPassword = ""
$complexPassword = 0

while ($complexPassword -ne 1)
{
    $SqlPassword = Read-Host "Enter a password to use for the $sqlUser login.
    `The password must meet complexity requirements:
    ` - Minimum 8 characters. 
    ` - At least one upper case English letter [A-Z]
    ` - At least one lower case English letter [a-z]
    ` - At least one digit [0-9]
    ` - At least one special character (!,@,#,%,^,&,$)
    ` "

    if(($SqlPassword -cmatch '[a-z]') -and ($SqlPassword -cmatch '[A-Z]') -and ($SqlPassword -match '\d') -and ($SqlPassword.length -ge 8) -and ($SqlPassword -match '!|@|#|%|\^|&|\$'))
    {
        $complexPassword = 1
	    Write-Output "Password $SqlPassword accepted. Make sure you remember this!"
    }
    else
    {
        Write-Output "$SqlPassword does not meet the complexity requirements."
    }
}

# Register resource providers
Write-Host "Registering resource providers...";
$provider_list = "Microsoft.Synapse", "Microsoft.Sql", "Microsoft.Storage", "Microsoft.Compute"
foreach ($provider in $provider_list){
    $result = Register-AzResourceProvider -ProviderNamespace $provider
    $status = $result.RegistrationState
    Write-Host "$provider : $status"
}

# Generate unique random suffix 
[string]$suffix =  -join ((48..57) + (97..122) | Get-Random -Count 7 | % {[char]$_})
Write-Host "Your randomly-generated suffix for Azure resources is $suffix"
$resourceGroupName = "procom-business-intelligence-$suffix"

# Choose a random region
Write-Host "Finding an available region. This may take several minutes...";
$delay = 0, 30, 60, 90, 120 | Get-Random
Start-Sleep -Seconds $delay # random delay to stagger requests from multi-student classes
$preferred_list = "australiaeast","centralus","southcentralus","eastus2","northeurope","southeastasia","uksouth","westeurope","westus","westus2" # we can keep it to one region if we want to - the only condition is that the location must be a provider for the list of providers we are using
$locations = Get-AzLocation | Where-Object {
    $_.Providers -contains "Microsoft.Synapse" -and
    $_.Providers -contains "Microsoft.Sql" -and
    $_.Providers -contains "Microsoft.Storage" -and
    $_.Providers -contains "Microsoft.Compute" -and
    $_.Location -in $preferred_list
}
$max_index = $locations.Count - 1
$rand = (0..$max_index) | Get-Random
$Region = $locations.Get($rand).Location

# Test for subscription Azure SQL capacity constraints in randomly selected regions
# (for some subsription types, quotas are adjusted dynamically based on capacity)
 $success = 0
 $tried_list = New-Object Collections.Generic.List[string]

 while ($success -ne 1){
    write-host "Trying $Region"
    $capability = Get-AzSqlCapability -LocationName $Region
    if($capability.Status -eq "Available")
    {
        $success = 1
        write-host "Using $Region"
    }
    else
    {
        $success = 0
        $tried_list.Add($Region)
        $locations = $locations | Where-Object {$_.Location -notin $tried_list}
        if ($locations.Count -ne 1)
        {
            $rand = (0..$($locations.Count - 1)) | Get-Random
            $Region = $locations.Get($rand).Location
        }
        else {
            Write-Host "Couldn't find an available region for deployment."
            Write-Host "Sorry! Try again later."
            Exit
        }
    }
}
Write-Host "Creating $resourceGroupName resource group in $Region ..."
New-AzResourceGroup -Name $resourceGroupName -Location $Region | Out-Null

# Create Synapse workspace
$synapseWorkspace = "synapse$suffix"
$dataLakeAccountName = "datalake$suffix"

# $sparkPool = "spark$suffix"
$sqlDatabaseName = "sql$suffix"

write-host "Creating $synapseWorkspace Synapse Analytics workspace in $resourceGroupName resource group..."
write-host "(This may take some time!)"

New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName `
  -TemplateFile "setup.json" `
  -Mode Complete `
  -workspaceName $synapseWorkspace `
  -dataLakeAccountName $dataLakeAccountName `
  -sqlUser $sqlUser `
  -sqlPassword $sqlPassword `
  -uniqueSuffix $suffix `
  -Force

# Create Azure SQL Server and Serverless SQL Database
$serverName = "sqlserver-$suffix"
$databaseName = "sqldatabase-$suffix"

Write-Host "Creating Azure SQL Server $serverName in $resourceGroupName resource group..."
New-AzSqlServer -ResourceGroupName $resourceGroupName `
                -ServerName $serverName `
                -Location $Region `
                -SqlAdministratorCredentials (New-Object -TypeName PSCredential -ArgumentList $sqlUser, ($SqlPassword | ConvertTo-SecureString -AsPlainText -Force))

# Write-Host "Creating Serverless SQL Database $databaseName in $serverName server..."
# New-AzSqlDatabase -ResourceGroupName $resourceGroupName `
#                   -ServerName $serverName `
#                   -DatabaseName $databaseName `
#                   -Edition "Hyperscale" `
#                   -ComputeModel "Serverless" `
#                   -AutoPauseDelay 60 `
#                   -Vcore 2 `
#                   -ComputeGeneration "Gen5"

# documentation : https://learn.microsoft.com/fr-fr/powershell/module/az.sql/new-azsqldatabase?view=azps-11.3.0
Write-Host "Creating Serverless SQL Database $databaseName in $serverName server..."
New-AzSqlDatabase -ResourceGroupName $resourceGroupName `
                  -ServerName $serverName `
                  -DatabaseName $databaseName `
                  -Edition "General Purpose " `
                  -ComputeModel "Serverless" `
                  -AutoPauseDelay 60 `
                  -Vcore 1 `
                  -ComputeGeneration "Gen5"



# Upload files
write-host "Loading data..."

# Define container name
$containerName = "container1"  # Replace with the desired container name

# Retrieve storage account and context
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $dataLakeAccountName
$storageContext = $storageAccount.Context

# Check if the container exists
if (!(Get-AzStorageContainer -Name $containerName -Context $storageContext)) {
    # Container doesn't exist, create it
    Write-Host "Container '$containerName' does not exist, creating..."
    New-AzStorageContainer -Name $containerName -Context $storageContext
    Write-Host "Container '$containerName' created successfully."
}

# Define the base blob path
$baseBlobPath = "données_pesticides/données_pesticides"

# Upload CSV files
Get-ChildItem "./data/*.csv" -File | ForEach-Object {
    $file = $_.Name
    Write-Host "Uploading $file to container $containerName..."
    $blobPath = "$baseBlobPath/$file"
    Set-AzStorageBlobContent -File $_.FullName -Container $containerName -Blob $blobPath -Context $storageContext -Force
    Write-Host "Uploaded $file successfully."
}

$linkedServiceName = "SqlServer"
New-AzSynapseLinkedService -Name $linkedServiceName -WorkspaceName $synapseWorkspace -DefinitionFile "linkedServiceDefinition.json"