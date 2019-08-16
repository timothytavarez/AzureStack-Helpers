
function New-AzSMarketplaceItem() {
    <#

    .SYNOPSIS
    Creates a new Azure Stack Marketplace item.

    .DESCRIPTION
    Generates a new Azure marketplace item package and uploads it to an Azure Stack marketplace.

    .PARAMETER StorageAccount
    The Storage Account that hosts the blob for marketplace packages.

    .PARAMETER StorageAccountKey
    A key to access the Storage account.

    .PARAMETER Context
    An Azure Storage Context object to optionally use. Use the New-AzureStorageContext cmdlet to generate a Context object.

    .PARAMETER Container
    The blob container to upload the .azpkg file into.

    .PARAMETER GalleryPackagerPath
    The full literal path to AzureGalleryPacker.exe. MUST be a fully qualified (not relative) path on the local system.

    .PARAMETER ManifestPath
    The path to the manifest.json file of the Azure Gallery package intended for creation.

    .PARAMETER PackageDestinationPath
    The full literal path to the destination directory that will have the newly created Azure Gallery Package (.azpkg) file. The directory MUST already exist.

    .EXAMPLE
    New-AzsMarketplaceItem -Context $Context -Container publicmarketplace -GalleryPackagerPath C:\AzPkg\AzureGalleryPacker.exe -ManifestPath C:\AzPkg\ContosoVM\manifest.json -PackageDestinationPath C:\AzPkg\Packages\

    .NOTES
    Timothy Tavarez
    Microsoft Consulting Services
    8/14/2019

    .LINK

    #>
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]$StorageAccountName,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [string]$StorageAccountKey,

        [Parameter(ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [object]$Context,

        [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true)]
        [string]$Container,

        [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true)]
        [string]$GalleryPackagerPath,

        [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true)]
        [string]$ManifestPath,

        [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true)]
        [string]$PackageDestinationPath
    )


    begin {

        try {
            Test-Path -Path $GalleryPackagerPath
        }
        catch {
            Write-Error "BEGIN: AzureGalleryPackager.exe not found. Validate that the full path to the file has been provided."
        }

        try {
            Test-Path -Path $PackageDestinationPath
        }
        catch {
            Write-Error "BEGIN: Package destination path invalid. Validate that the full path to the destination has been provided."
        }
        
        if ($Context) {
            Write-Verbose "BEGIN: Context object has been provided at runtime with. \nBEGIN: Storage account targeted: $Context.StorageAccountName"
        } else {
            Write-Verbose "BEGIN: Context object has not been provided. Constructing context from provided parameters."
            $Context = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
        }
        

    }

    process {

        foreach ($Manifest in $ManifestPath) {

            $Arguments = 'package', "-m $ManifestPath", "-o $PackageDestinationPath"
            Start-Process -FilePath $GalleryPackagerPath -ArgumentList $Arguments
            Write-Verbose "PROCESS: Executing AzureGalleryPacker.exe package -m $ManifestPath -o $PackageDestinationPath"

            $ManifestJson = Get-Content $Manifest | ConvertFrom-Json | Select-Object -Property Name, Publisher, Version
            $AzPkg = ($ManifestJson.publisher + "." + $ManifestJson.name + "." + $ManifestJson.version + ".azpkg")
            Write-Verbose "PROCESS: Extracting .azpkg file name values from JSON to create: $Azpkg"

            Set-AzureStorageBlobContent -Context $Context -Container $Container -File $AzPkg -BlobType Block
            
            $BlobUri = ($Context.BlobEndPoint + $Container + "/" + $AzPkg)
            Write-Verbose "PROCESS: .azpkg blob URI: $BlobUri"
            Add-AzsGalleryItem -GalleryItemUri $BlobUri -Verbose -Force

        }
    }

    end {} # Intentionally blank
}


function Get-AzSResourceProviderApiVersions {
    <#

    .SYNOPSIS
    Get API verions for an Azure Resource Type.

    .DESCRIPTION
    Returns an object containing the API verions of Resource Providers on the Azure Stack that the currently logged in user can consume.

    .PARAMETER ResourceProvider
    The Resource Provider to target. E.g.: Microsoft.Compute or Microsoft.Network

    .PARAMETER ResourceTypeName
    The specific Resource Type to return API versions for.

    .EXAMPLE 
    Get the API versions for the Microsoft.Storage/storageAccounts resource type
    Get-AzSResourceProviderApiVersions -ResourceProvider Microsoft.Storage -ResourceTypeName storageAccounts

    .NOTES
    Timothy Tavarez
    Microsoft Consulting Services
    8/1/2019

    .LINK

    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Microsoft.Compute', 'Microsoft.Insights', 'Microsoft.KeyVault', 'Microsoft.Network', 'Microsoft.Storage', 'Microsoft.Resources')]
        [string] $ResourceProvider,

        [Parameter(Mandatory=$true)]
        [string] $ResourceTypeName
    )

    begin {}

    process {
        (Get-AzureRmResourceProvider -ProviderNamespace $ResourceProvider).ResourceTypes | Where-Object -FilterScript {$_.ResourceTypeName -eq $ResourceTypeName}
    }

    end {} # Intentionally left blank

}