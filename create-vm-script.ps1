# ============================================================
# AZURE VM LABORATORY
# Windows Server 2025 + NGINX
# ============================================================

$ErrorActionPreference = "Stop"

# ============================================================
# CONFIGURACIÓN GENERAL
# ============================================================

$location = "eastus"
$resourceGroup = "TmpGroup"

# Máquina virtual
$vmName = "MyVMWithPowershell"
$computerName = "MyVM"
$vmSize = "Standard_D2s_v5"

# Credenciales administrativas
$adminUser = "azuser"
$adminPassword = ConvertTo-SecureString `
    'YourPassword' `
    -AsPlainText `
    -Force

# Red
$vnetName = "MyVNet"
$subnetName = "MySubnet"
$nicName = "MyNIC"
$nsgName = "MyNSG"
$publicIpName = "MyPublicIP"

$vnetPrefix = "10.0.0.0/16"
$subnetPrefix = "10.0.0.0/24"

# Disco adicional
$dataDiskName = "MyDataDisk"
$dataDiskSizeGB = 250

# Tags
$tags = @{
    Owner       = "Elmer Marquez"
    Environment = "Laboratory"
}

# ============================================================
# AUTENTICACIÓN
# ============================================================

Write-Host ""
Write-Host "Verificando autenticación de Azure..." `
    -ForegroundColor Cyan

if (-not (Get-AzContext)) {
    Connect-AzAccount
}

$context = Get-AzContext

if (-not $context) {
    throw "No existe un contexto de Azure."
}

Write-Host "Suscripción: $($context.Subscription.Name)" `
    -ForegroundColor Green

# ============================================================
# RESOURCE GROUP
# ============================================================

Write-Host ""
Write-Host "Creando Resource Group..." `
    -ForegroundColor Cyan

New-AzResourceGroup `
    -Name $resourceGroup `
    -Location $location `
    -Tag $tags | Out-Null

# ============================================================
# NETWORK SECURITY GROUP
# ============================================================

Write-Host ""
Write-Host "Creando NSG..." `
    -ForegroundColor Cyan

$rdpRule = New-AzNetworkSecurityRuleConfig `
    -Name "Allow-RDP" `
    -Description "Permitir conexiones RDP" `
    -Access Allow `
    -Protocol Tcp `
    -Direction Inbound `
    -Priority 100 `
    -SourceAddressPrefix "*" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "*" `
    -DestinationPortRange 3389

$httpRule = New-AzNetworkSecurityRuleConfig `
    -Name "Allow-HTTP" `
    -Description "Permitir tráfico HTTP" `
    -Access Allow `
    -Protocol Tcp `
    -Direction Inbound `
    -Priority 110 `
    -SourceAddressPrefix "*" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "*" `
    -DestinationPortRange 80

$httpsRule = New-AzNetworkSecurityRuleConfig `
    -Name "Allow-HTTPS" `
    -Description "Permitir tráfico HTTPS" `
    -Access Allow `
    -Protocol Tcp `
    -Direction Inbound `
    -Priority 120 `
    -SourceAddressPrefix "*" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "*" `
    -DestinationPortRange 443

$nsg = New-AzNetworkSecurityGroup `
    -Name $nsgName `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -SecurityRules $rdpRule,$httpRule,$httpsRule `
    -Tag $tags

# ============================================================
# VNET Y SUBNET
# ============================================================

Write-Host ""
Write-Host "Creando VNet..." `
    -ForegroundColor Cyan

$subnet = New-AzVirtualNetworkSubnetConfig `
    -Name $subnetName `
    -AddressPrefix $subnetPrefix `
    -NetworkSecurityGroup $nsg

$vnet = New-AzVirtualNetwork `
    -Name $vnetName `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -AddressPrefix $vnetPrefix `
    -Subnet $subnet `
    -Tag $tags

# ============================================================
# PUBLIC IP
# ============================================================

Write-Host ""
Write-Host "Creando Public IP..." `
    -ForegroundColor Cyan

$publicIp = New-AzPublicIpAddress `
    -Name $publicIpName `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -AllocationMethod Static `
    -Sku Standard `
    -Tag $tags

# ============================================================
# NIC
# ============================================================

Write-Host ""
Write-Host "Creando NIC..." `
    -ForegroundColor Cyan

$nic = New-AzNetworkInterface `
    -Name $nicName `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -SubnetId $vnet.Subnets[0].Id `
    -PublicIpAddressId $publicIp.Id `
    -Tag $tags

# ============================================================
# CREDENCIALES
# ============================================================

$credential = New-Object `
    System.Management.Automation.PSCredential(
        $adminUser,
        $adminPassword
    )

# ============================================================
# CONFIGURACIÓN DE LA VM
# ============================================================

Write-Host ""
Write-Host "Configurando VM..." `
    -ForegroundColor Cyan

$vm = New-AzVMConfig `
    -VMName $vmName `
    -VMSize $vmSize `
    -Tags $tags

$vm = Set-AzVMOperatingSystem `
    -VM $vm `
    -Windows `
    -ComputerName $computerName `
    -Credential $credential `
    -ProvisionVMAgent `
    -EnableAutoUpdate

# ============================================================
# WINDOWS SERVER 2025
# ============================================================

Write-Host ""
Write-Host "Configurando Windows Server 2025..." `
    -ForegroundColor Cyan

$vm = Set-AzVMSourceImage `
    -VM $vm `
    -PublisherName "MicrosoftWindowsServer" `
    -Offer "WindowsServer" `
    -Skus "2025-datacenter-azure-edition" `
    -Version "latest"

# ============================================================
# NIC
# ============================================================

$vm = Add-AzVMNetworkInterface `
    -VM $vm `
    -Id $nic.Id

# ============================================================
# DISCO ADICIONAL DE 250 GB
# ============================================================

Write-Host ""
Write-Host "Agregando disco de 250 GB..." `
    -ForegroundColor Cyan

$vm = Add-AzVMDataDisk `
    -VM $vm `
    -Name $dataDiskName `
    -DiskSizeInGB $dataDiskSizeGB `
    -Lun 0 `
    -CreateOption Empty `
    -StorageAccountType "StandardSSD_LRS"

# ============================================================
# CREAR VM
# ============================================================

Write-Host ""
Write-Host "Desplegando Windows Server 2025..." `
    -ForegroundColor Green

New-AzVM `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -VM $vm `
    -Verbose

# ============================================================
# SCRIPT DE CONFIGURACIÓN DE NGINX
# ============================================================

Write-Host ""
Write-Host "Preparando instalación de NGINX..." `
    -ForegroundColor Cyan

$nginxScript = @'
$ErrorActionPreference = "Stop"

# ============================================================
# CHOCOLATEY
# ============================================================

Write-Host ""
Write-Host "Buscando Chocolatey..."

$chocoPath = "$env:ChocolateyInstall\bin\choco.exe"

if (-not (Test-Path $chocoPath)) {

    $chocoPath = "C:\ProgramData\chocolatey\bin\choco.exe"
}

if (-not (Test-Path $chocoPath)) {

    Write-Host "Chocolatey no está instalado. Instalándolo..."

    Set-ExecutionPolicy `
        Bypass `
        -Scope Process `
        -Force

    [System.Net.ServicePointManager]::SecurityProtocol = `
        [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

    [System.Net.WebClient]::new().DownloadString(
        "https://community.chocolatey.org/install.ps1"
    ) | Invoke-Expression

    $chocoPath = "$env:ChocolateyInstall\bin\choco.exe"
}

if (-not (Test-Path $chocoPath)) {

    throw "No se encontró choco.exe."
}

Write-Host "Chocolatey:"
Write-Host $chocoPath

# ============================================================
# INSTALAR NGINX
# ============================================================

Write-Host ""
Write-Host "Instalando NGINX..."

& $chocoPath install nginx -y

if ($LASTEXITCODE -ne 0) {

    throw "La instalación de NGINX falló."
}

# ============================================================
# UBICACIÓN DE NGINX
# ============================================================

$toolsLocation = $env:ChocolateyToolsLocation

if (-not $toolsLocation) {

    $toolsLocation = "$env:ChocolateyInstall\tools"
}

$nginxDirectory = Get-ChildItem `
    -Path $toolsLocation `
    -Directory `
    -Filter "Nginx*" |
    Select-Object -First 1

if (-not $nginxDirectory) {

    throw "No se encontró la instalación de NGINX."
}

$nginxRoot = $nginxDirectory.FullName

$nginxExe = Join-Path `
    $nginxRoot `
    "nginx.exe"

$webRoot = Join-Path `
    $nginxRoot `
    "html"

Write-Host ""
Write-Host "NGINX instalado en:"
Write-Host $nginxRoot

# ============================================================
# PÁGINA WEB
# ============================================================
$html = @"
<!DOCTYPE html>
<html lang="es">

<head>

<meta charset="UTF-8">

<meta name="viewport"
      content="width=device-width, initial-scale=1.0">

<title>XNerd Azure Laboratory</title>

<style>

* {
    box-sizing: border-box;
}

body {
    margin: 0;
    min-height: 100vh;

    font-family:
        "Segoe UI",
        Arial,
        sans-serif;

    background:
        radial-gradient(
            circle at top,
            #1e3a5f 0%,
            #0f172a 45%,
            #020617 100%
        );

    color: #e2e8f0;
}

.container {
    width: 100%;
    max-width: 1000px;

    margin: 0 auto;

    padding: 50px 25px;
}

.header {
    text-align: center;
    margin-bottom: 35px;
}

.badge {
    display: inline-block;

    padding: 7px 14px;

    border-radius: 999px;

    background: rgba(56, 189, 248, 0.12);

    border: 1px solid
            rgba(56, 189, 248, 0.25);

    color: #38bdf8;

    font-size: 13px;

    font-weight: 600;

    letter-spacing: 1px;

    text-transform: uppercase;
}

h1 {
    margin: 18px 0 10px;

    font-size: 42px;

    color: #f8fafc;
}

.subtitle {
    margin: 0;

    color: #94a3b8;

    font-size: 17px;
}

.status {
    display: inline-flex;

    align-items: center;

    gap: 8px;

    margin-top: 22px;

    padding: 9px 16px;

    border-radius: 999px;

    background: rgba(34, 197, 94, 0.12);

    border: 1px solid
            rgba(34, 197, 94, 0.25);

    color: #4ade80;

    font-size: 14px;

    font-weight: 600;
}

.status-dot {
    width: 8px;
    height: 8px;

    border-radius: 50%;

    background: #22c55e;

    box-shadow:
        0 0 10px #22c55e;
}

.main-card {
    background:
        rgba(30, 41, 59, 0.85);

    border: 1px solid
            rgba(148, 163, 184, 0.12);

    border-radius: 22px;

    padding: 35px;

    box-shadow:
        0 25px 60px
        rgba(0, 0, 0, 0.35);

    backdrop-filter: blur(12px);
}

.section-title {
    margin: 0 0 20px;

    color: #f8fafc;

    font-size: 20px;
}

.grid {
    display: grid;

    grid-template-columns:
        repeat(2, 1fr);

    gap: 15px;
}

.info {
    padding: 18px;

    background:
        rgba(15, 23, 42, 0.75);

    border: 1px solid
            rgba(148, 163, 184, 0.10);

    border-radius: 14px;
}

.label {
    display: block;

    margin-bottom: 7px;

    color: #64748b;

    font-size: 12px;

    text-transform: uppercase;

    letter-spacing: 0.8px;
}

.value {
    color: #e2e8f0;

    font-size: 15px;

    font-weight: 600;
}

.services {
    display: grid;

    grid-template-columns:
        repeat(3, 1fr);

    gap: 15px;

    margin-top: 30px;
}

.service {
    padding: 20px;

    text-align: center;

    background:
        rgba(15, 23, 42, 0.75);

    border-radius: 14px;

    border: 1px solid
            rgba(56, 189, 248, 0.12);
}

.service-icon {
    font-size: 28px;

    margin-bottom: 10px;
}

.service-name {
    color: #f8fafc;

    font-weight: 600;
}

.service-port {
    margin-top: 5px;

    color: #64748b;

    font-size: 13px;
}

.footer {
    margin-top: 30px;

    text-align: center;

    color: #64748b;

    font-size: 13px;
}

@media (max-width: 700px) {

    h1 {
        font-size: 32px;
    }

    .grid {
        grid-template-columns: 1fr;
    }

    .services {
        grid-template-columns: 1fr;
    }

    .main-card {
        padding: 25px;
    }

}

</style>

</head>

<body>

<div class="container">

    <header class="header">

        <span class="badge">
            Microsoft Azure Laboratory
        </span>

        <h1>
            XNerd Azure Laboratory
        </h1>

        <p class="subtitle">
            Windows Server 2025 · NGINX
        </p>

        <div class="status">

            <span class="status-dot"></span>

            NGINX ONLINE

        </div>

    </header>


    <main class="main-card">

        <h2 class="section-title">
            Infrastructure
        </h2>


        <div class="grid">

            <div class="info">

                <span class="label">
                    Operating System
                </span>

                <span class="value">
                    Windows Server 2025
                </span>

            </div>


            <div class="info">

                <span class="label">
                    Web Server
                </span>

                <span class="value">
                    NGINX
                </span>

            </div>


            <div class="info">

                <span class="label">
                    Resource Group
                </span>

                <span class="value">
                    TmpGroup
                </span>

            </div>


            <div class="info">

                <span class="label">
                    Region
                </span>

                <span class="value">
                    East US
                </span>

            </div>


            <div class="info">

                <span class="label">
                    Environment
                </span>

                <span class="value">
                    Laboratory
                </span>

            </div>


            <div class="info">

                <span class="label">
                    Owner
                </span>

                <span class="value">
                    Elmer Marquez
                </span>

            </div>

        </div>


        <h2 class="section-title"
            style="margin-top: 35px;">

            Services

        </h2>


        <div class="services">


            <div class="service">

                <div class="service-name">
                    HTTP
                </div>

                <div class="service-port">
                    TCP / 80
                </div>

            </div>


            <div class="service">

                <div class="service-name">
                    HTTPS
                </div>

                <div class="service-port">
                    TCP / 443
                </div>

            </div>


            <div class="service">

                <div class="service-name">
                    RDP
                </div>

                <div class="service-port">
                    TCP / 3389
                </div>

            </div>


        </div>


        <div class="footer">

            Deployed with Azure PowerShell

        </div>

    </main>

</div>

</body>

</html>
"@

Set-Content `
    -Path "$webRoot\index.html" `
    -Value $html `
    -Encoding UTF8

# ============================================================
# WINDOWS FIREWALL
# ============================================================

Write-Host ""
Write-Host "Configurando Windows Firewall..."

New-NetFirewallRule `
    -DisplayName "NGINX HTTP" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 80 `
    -Action Allow `
    -Profile Any `
    -ErrorAction SilentlyContinue

New-NetFirewallRule `
    -DisplayName "NGINX HTTPS" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 443 `
    -Action Allow `
    -Profile Any `
    -ErrorAction SilentlyContinue

# ============================================================
# INICIAR NGINX
# ============================================================

Write-Host ""
Write-Host "Iniciando servicio NGINX..."

Start-Service `
    -Name "nginx"

Write-Host ""
Write-Host "NGINX iniciado correctamente." `
    -ForegroundColor Green

Write-Host ""
Write-Host "Ejecutable : $nginxExe"
Write-Host "Web Root   : $webRoot"
'@

# ============================================================
# EJECUTAR NGINX EN LA VM
# ============================================================

Write-Host ""
Write-Host "Instalando NGINX dentro de Windows Server..." `
    -ForegroundColor Cyan

$result = Invoke-AzVMRunCommand `
    -ResourceGroupName $resourceGroup `
    -VMName $vmName `
    -CommandId "RunPowerShellScript" `
    -ScriptString $nginxScript

# ============================================================
# MOSTRAR RESULTADO
# ============================================================

Write-Host ""
Write-Host "============================================"
Write-Host " RESULTADO DE CONFIGURACIÓN "
Write-Host "============================================"

$result.Value | ForEach-Object {

    if ($_.Message) {

        Write-Host $_.Message
    }
}

# ============================================================
# OBTENER IP PÚBLICA
# ============================================================

$publicIp = Get-AzPublicIpAddress `
    -ResourceGroupName $resourceGroup `
    -Name $publicIpName

# ============================================================
# RESULTADO FINAL
# ============================================================

Write-Host ""
Write-Host "============================================" `
    -ForegroundColor Green

Write-Host " DESPLIEGUE COMPLETADO " `
    -ForegroundColor Green

Write-Host "============================================" `
    -ForegroundColor Green

Write-Host ""
Write-Host "Resource Group : $resourceGroup"
Write-Host "VM             : $vmName"
Write-Host "OS             : Windows Server 2025"
Write-Host "Region         : $location"
Write-Host "Public IP      : $($publicIp.IpAddress)"
Write-Host "HTTP           : http://$($publicIp.IpAddress)"
Write-Host "RDP            : $($publicIp.IpAddress):3389"
Write-Host "HTTPS          : https://$($publicIp.IpAddress)"
Write-Host "Data Disk      : $dataDiskSizeGB GB"
Write-Host "Owner          : Elmer Marquez"
Write-Host "Environment    : Laboratory"

Write-Host ""
Write-Host "============================================"
