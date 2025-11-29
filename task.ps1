# -------- НАЛАШТУВАННЯ --------
$location              = "northeurope"          # або "westeurope", якщо не хочеш чистити старі PIP
$resourceGroupName     = "mate-azure-task-12"
$vmName                = "mate12vm"
$vmSize                = "Standard_B1s"
$adminUsername         = "azureuser"
$sshPublicKeyPath      = "$HOME/.ssh/id_ed25519.pub"  # заміни, якщо інший ключ
$virtualNetworkName    = "mate12-vnet"
$subnetName            = "default"
$addressPrefixVnet     = "10.12.0.0/16"
$addressPrefixSubnet   = "10.12.0.0/24"
$networkSecurityGroup  = "mate12-nsg"
$publicIpName          = "mate12vm-pip"
$nicName               = "mate12vm-nic"
$dnsLabel              = "mate12task" + (Get-Random -Maximum 99999)

$installScriptUrl = "https://raw.githubusercontent.com/maximprysyazhnikov/azure_task_12_deploy_app_with_vm_extention/main/install-app.sh"

Write-Host "=== Task 12: Deploy VM and app with VM extension ===" -ForegroundColor Cyan

# 1. SSH key
if (-not (Test-Path -Path $sshPublicKeyPath)) {
    throw "SSH public key not found at $sshPublicKeyPath. Please generate it and try again."
}
$sshKey = Get-Content -Path $sshPublicKeyPath -Raw

# 2. Resource Group
$rg = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if (-not $rg) {
    Write-Host "Creating resource group $resourceGroupName in $location..."
    $rg = New-AzResourceGroup -Name $resourceGroupName -Location $location -Force
}

# 3. NSG (22, 8080)
Write-Host "Creating Network Security Group $networkSecurityGroup..."
$nsgRuleSsh = New-AzNetworkSecurityRuleConfig `
    -Name "Allow-SSH" `
    -Protocol Tcp `
    -Direction Inbound `
    -Priority 1000 `
    -SourceAddressPrefix "*" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "*" `
    -DestinationPortRange 22 `
    -Access Allow

$nsgRuleApp = New-AzNetworkSecurityRuleConfig `
    -Name "Allow-App-8080" `
    -Protocol Tcp `
    -Direction Inbound `
    -Priority 1010 `
    -SourceAddressPrefix "*" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "*" `
    -DestinationPortRange 8080 `
    -Access Allow

$nsg = New-AzNetworkSecurityGroup `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -Name $networkSecurityGroup `
    -SecurityRules $nsgRuleSsh, $nsgRuleApp

# 4. VNet + Subnet
Write-Host "Creating virtual network $virtualNetworkName..."
$subnetConfig = New-AzVirtualNetworkSubnetConfig `
    -Name $subnetName `
    -AddressPrefix $addressPrefixSubnet `
    -NetworkSecurityGroup $nsg

$vnet = New-AzVirtualNetwork `
    -Name $virtualNetworkName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -AddressPrefix $addressPrefixVnet `
    -Subnet $subnetConfig

# 5. Public IP
Write-Host "Creating public IP $publicIpName..."
$publicIp = New-AzPublicIpAddress `
    -Name $publicIpName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -AllocationMethod Dynamic `
    -Sku Basic `
    -DomainNameLabel $dnsLabel

# 6. NIC
Write-Host "Creating NIC $nicName..."
$subnetRef = Get-AzVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet
$nic = New-AzNetworkInterface `
    -Name $nicName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -Subnet $subnetRef `
    -PublicIpAddress $publicIp

# 7. OS + Image + SSH
Write-Host "Creating VM configuration $vmName..."

$credential = Get-Credential -Message "Enter password for local user $adminUsername" -UserName $adminUsername

$vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize |
    Set-AzVMOperatingSystem -Linux -ComputerName $vmName -Credential $credential -DisablePasswordAuthentication |
    Set-AzVMSourceImage -PublisherName "Canonical" -Offer "0001-com-ubuntu-server-jammy" -Skus "22_04-lts-gen2" -Version "latest" |
    Add-AzVMNetworkInterface -Id $nic.Id |
    Set-AzVMOSDisk -CreateOption FromImage

# додаємо SSH ключ
$vmConfig = Add-AzVMSshPublicKey -VM $vmConfig -KeyData $sshKey -Path "/home/$adminUsername/.ssh/authorized_keys"

# 8. Створюємо VM
Write-Host "Creating VM $vmName (this may take a few minutes)..."
New-AzVM `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -VM $vmConfig `
    -Verbose

Write-Host "VM created successfully." -ForegroundColor Green

# 9. Custom Script Extension
Write-Host "Adding Custom Script Extension to install the app..."

$publicSettings = @{
    "fileUris"        = @($installScriptUrl)
    "commandToExecute" = "bash install-app.sh"
} | ConvertTo-Json

Set-AzVMExtension `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -VMName $vmName `
    -Name "install-todo-app" `
    -Publisher "Microsoft.Azure.Extensions" `
    -ExtensionType "CustomScript" `
    -TypeHandlerVersion "2.1" `
    -SettingString $publicSettings `
    -Verbose

Write-Host "Custom Script Extension has been deployed." -ForegroundColor Green

# 10. Виводимо FQDN
$publicIpRef = Get-AzPublicIpAddress -Name $publicIpName -ResourceGroupName $resourceGroupName
$fqdn = $publicIpRef.DnsSettings.Fqdn

Write-Host "========================================================="
Write-Host " Deployment finished!"
Write-Host " App should be available (after a few minutes) at:"
Write-Host "   http://$fqdn:8080"
Write-Host "========================================================="
