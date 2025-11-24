# WiFi-Switcher-v1.0 - Stable
# --------------------------------
# Features
# - Quick toggle between given networks
# - Auto Retry on failed connection
# - Manual Retry Option after failed attempts
# --------------------------------
# Bug
# - Sometimes first try will cause network disable
# --------------------------------
# How To Use?
# Create a Shortcut with the following Command
#
# powershell.exe -ExecutionPolicy Bypass -File "C:\Path\To\WiFi-Switcher.ps1"
#
# - Start Minimized
# After Making shortcut
# Shortcut Link Properties >> RUN >> Minimized
# --------------------------------

# -------------------------------
# CONFIGURATION SECTION
# -------------------------------
#Wifi Names list
$wifiName1 = "Joey_AX56u_5G"
$wifiName2 = "Joey_5G"
$wifiList = @($wifiName1, $wifiName2)	#Add $wifiName3 etc. in the list after adding new WiFi variable

$retryLimit = 3						#Auto Retry Limit
$popupDurationMs = 1000				#Popup Duration Time

# -------------------------------
# Hide Console Window
# -------------------------------
if ($PSEdition -eq 'Desktop') {
    $null = Add-Type -Name Window -Namespace Console -MemberDefinition '
        [DllImport("Kernel32.dll")] public static extern IntPtr GetConsoleWindow();
        [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    '
    $consolePtr = [Console.Window]::GetConsoleWindow()
    [Console.Window]::ShowWindow($consolePtr, 0) | Out-Null
}

# -------------------------------
# Detect Current WiFi and Choose Next WiFi
# -------------------------------
function Get-ConnectedSSID {
    try {
        $wifiInfo = netsh wlan show interfaces
        return ($wifiInfo | Select-String "\bSSID\s*:\s*(.*)").Matches.Groups[1].Value.Trim()
    } catch {
        return $null
    }
}

$currentWifi = Get-ConnectedSSID

# Determine next WiFi
if (-not $currentWifi -or $currentWifi -eq "") {
    $nextWifi = $wifiList[0]
} else {
    $index = $wifiList.IndexOf($currentWifi)
    if ($index -lt 0 -or $index -eq $wifiList.Length - 1) {
        $nextWifi = $wifiList[0]
    } else {
        $nextWifi = $wifiList[$index + 1]
    }
}

# -------------------------------
# GUI - Create Popup Window
# -------------------------------
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object Windows.Forms.Form
$form.Text = "WiFi Switcher"
$form.Size = New-Object Drawing.Size(440, 200)
$form.StartPosition = "CenterScreen"
$form.TopMost = $true
$form.FormBorderStyle = "FixedToolWindow"

$labelCurrent = New-Object Windows.Forms.Label
$labelCurrent.Font = New-Object Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$labelCurrent.AutoSize = $true
$labelCurrent.Location = New-Object Drawing.Point(20, 20)
$labelCurrent.Text = "Current WiFi: $currentWifi"
$form.Controls.Add($labelCurrent)

$label = New-Object Windows.Forms.Label
$label.Font = New-Object Drawing.Font("Segoe UI", 11)
$label.AutoSize = $true
$label.Location = New-Object Drawing.Point(20, 55)
$form.Controls.Add($label)

$buttonRetry = New-Object Windows.Forms.Button
$buttonRetry.Text = "Retry"
$buttonRetry.Size = New-Object Drawing.Size(80, 30)
$buttonRetry.Location = New-Object Drawing.Point(30, 120)
$buttonRetry.Enabled = $false
$form.Controls.Add($buttonRetry)

$buttonClose = New-Object Windows.Forms.Button
$buttonClose.Text = "Close"
$buttonClose.Size = New-Object Drawing.Size(80, 30)
$buttonClose.Location = New-Object Drawing.Point(120, 120)
$form.Controls.Add($buttonClose)

$script:retryCount = 0

function Attempt-Connection {
    do {
        $script:retryCount++
        $label.Text = "Connecting to: $nextWifi`nAttempt #$retryCount"
        $form.Refresh()

        netsh wlan disconnect | Out-Null
        Start-Sleep -Milliseconds 500
        netsh wlan connect name="$nextWifi" | Out-Null
        Start-Sleep -Milliseconds 500

        $connectedWifi = Get-ConnectedSSID

        if ($connectedWifi -eq $nextWifi) {
            $label.Text = "✅ Connected to: $nextWifi"
            $labelCurrent.Text = "Current WiFi: $connectedWifi"
            $buttonRetry.Enabled = $false
            $form.Refresh()
            Start-Sleep -Milliseconds $popupDurationMs
            $form.Close()
            return
        } else {
            $label.Text = "❌ Failed to connect to: $nextWifi`nAttempt #$retryCount of $retryLimit"
            $labelCurrent.Text = "Current WiFi: $connectedWifi"
            $form.Refresh()
            if ($retryCount -ge $retryLimit) {
                $label.Text += "`nMaximum retries reached."
                $buttonRetry.Enabled = $true
                return
            }
            Start-Sleep -Milliseconds 500
        }
    } while ($retryCount -lt $retryLimit)
}

# Event Handlers
$buttonRetry.Add_Click({ 
    $buttonRetry.Enabled = $false
    $script:retryCount = 0
    Attempt-Connection 
})

$buttonClose.Add_Click({ $form.Close() })

$form.Add_Shown({ Attempt-Connection })
[Windows.Forms.Application]::EnableVisualStyles()
[Windows.Forms.Application]::Run($form)
