# ESP32-S3-CAM_PDX DATV Beacon - IZ7PDX - GPL-3.0
# Scelta della porta per gli script .bat. Elenca le porte COM con il nome che dà Windows (CH340, CP210x, USB JTAG...),
# accetta "COM29", "com29" o "29"; con Invio prova ogni porta con "esptool chip-id" (solo lettura) e tiene solo quelle
# con un ESP32-S3: un'altra scheda ESP32 collegata (C3, ...) non blocca più il riconoscimento automatico, e con più
# ESP32-S3 si sceglie dall'elenco. Non dipende dal convertitore USB: vale anche per schede senza CH340.
# La porta scelta finisce in $Out (vuoto = nessuna), letto dal .bat con "set /p PORT=<file".
param([string]$Out = (Join-Path $env:TEMP 'datv_beacon_port.txt'))

$esptool = Join-Path $PSScriptRoot 'esptool.exe'
Set-Content -Path $Out -Value '' -NoNewline

function PortNum([string]$p) { [int]($p -replace '\D', '') }
function Ports {
    [System.IO.Ports.SerialPort]::GetPortNames() | ForEach-Object { $_.Trim().ToUpper() } | Sort-Object -Unique |
        Sort-Object { PortNum $_ }
}
function Label([string]$p) { if ($names.ContainsKey($p)) { $names[$p] } else { $p } }

# nomi di Gestione dispositivi, es. "USB-SERIAL CH340 (COM29)"
$names = @{}
try {
    Get-CimInstance Win32_PnPEntity -Filter "Name LIKE '%(COM%)'" -ErrorAction Stop | ForEach-Object {
        if ($_.Name -match '\((COM\d+)\)') { $names[$Matches[1].ToUpper()] = $_.Name }
    }
} catch {}

# ESP32-S3 sulla porta? "--after no-reset": una scheda messa a mano in download (BOOT + RST) ci resta per la scrittura
function ProbeS3([string]$p) {
    $o = & $esptool --port $p --connect-attempts 2 --after no-reset chip-id 2>&1 | Out-String
    if ($o -match 'ESP32-S3') { return $true }
    if ($o -match 'Connected to|Chip type') { & $esptool --port $p run 2>&1 | Out-Null }  # altro ESP32: riparte
    return $false
}

$ports = @(Ports)
Write-Host ''
if ($ports.Count -eq 0) {
    Write-Host ' No COM port found. Check the USB DATA cable and the driver (Device Manager -> Ports).'
    Write-Host ' Nessuna porta COM. Controllate il cavo USB DATI e il driver (Gestione dispositivi -> Porte).'
    exit 1
}
Write-Host ' Serial ports / porte seriali:'
foreach ($p in $ports) { Write-Host ('   ' + (Label $p)) }
Write-Host ''

while ($true) {
    $in = (Read-Host ' COM port (e.g. COM3 or 3, Enter = auto) / porta COM (es. COM3 o 3, Invio = automatico)').Trim().ToUpper()
    if ($in -eq '') { break }
    if ($in -match '^\d+$') { $in = 'COM' + $in }
    if ($ports -contains $in) { Set-Content -Path $Out -Value $in -NoNewline; exit 0 }
    Write-Host (" $in not found / non trovata: " + ($ports -join ', '))
}

Write-Host ' Looking for the ESP32-S3 / ricerca dell''ESP32-S3 ...'
$found = @()
foreach ($p in $ports) {
    Write-Host -NoNewline ('   ' + (Label $p) + ' ... ')
    if (ProbeS3 $p) { $found += $p; Write-Host 'ESP32-S3' } else { Write-Host '-' }
}

if ($found.Count -eq 0) {
    Write-Host ''
    Write-Host ' No ESP32-S3 found. Use the USB-serial port (marked COM or TTL, not OTG), or hold BOOT, press and release RST,'
    Write-Host ' release BOOT and run the script again.'
    Write-Host ' Nessun ESP32-S3. Usate la porta USB-seriale (marcata COM o TTL, non OTG), oppure tenete BOOT, premete e'
    Write-Host ' rilasciate RST, rilasciate BOOT e rilanciate lo script.'
    exit 1
}
# la scelta va nel file; gli altri ESP32-S3 provati escono dal bootloader
function Pick([string]$p) {
    foreach ($q in $found) { if ($q -ne $p) { & $esptool --port $q run 2>&1 | Out-Null } }
    Set-Content -Path $Out -Value $p -NoNewline
    exit 0
}
if ($found.Count -eq 1) {
    Write-Host (' Using / uso ' + (Label $found[0]))
    Pick $found[0]
}

# più ESP32-S3: mai scrivere a caso, si sceglie
Write-Host ''
Write-Host ' More than one ESP32-S3 / piu'' di un ESP32-S3:'
for ($i = 0; $i -lt $found.Count; $i++) { Write-Host ('   ' + ($i + 1) + ') ' + (Label $found[$i])) }
while ($true) {
    $in = (Read-Host ' Number or COM port / numero o porta COM').Trim().ToUpper()
    if ($in -match '^\d+$' -and [int]$in -ge 1 -and [int]$in -le $found.Count) { $in = $found[[int]$in - 1] }
    elseif ($in -match '^\d+$') { $in = 'COM' + $in }
    if ($found -contains $in) { Pick $in }
}
