# DSH_NET - разбор NET_EXPLOSION и доказательство «дубль не нанёс урона».
#
# Раньше проверка сравнивала только ЧИСЛО строк NET_EXPLOSION у двух сторон.
# Равные агрегаты ничего не доказывают: лишний взрыв от кинематического дубля
# на приёмной стороне уравновешивался любым другим расхождением, а повтор
# одного и того же события считался двумя событиями.
#
# Здесь взрывы сопоставляются ПО СОБЫТИЮ: у каждой строки берутся path, killed,
# dead и точка at=. Условия PASS:
#   * обе стороны прислали разбираемые строки, взрывы есть у обеих;
#   * на приёмной стороне нет ни одного path=local - локальный урон от дубля;
#   * число событий совпадает у обеих сторон;
#   * события совпадают попарно в порядке применения: точка (<= 0.05 м),
#     dead= и killed=.
# Нет данных (нет лога, нет строк, строка обрезана) - NOT_PROVEN, не PASS.
# Явное противоречие (локальный урон у гостя, лишнее/другое событие) - FAIL.
#
# Ограничение: в лог печатается только path/killed/dead/at, без event_id,
# поэтому «ровно один раз на событие» доказывается попарным сопоставлением,
# а не идентификатором. Для полного доказательства нужно печатать event_id
# (см. отчёт OPT-20261020-001) - это отдельное изменение runtime.
#
# Проверка самого разбора: `powershell -File net_catapult_damage_check.ps1 -SelfTest`.

param(
    [switch]$SelfTest
)

$script:NetExplosionPattern =
    '^NET_EXPLOSION\s+path=(local|dead)\s+killed=(-?\d+)\s+dead=(-?\d+)\s+at=\((-?[\d.]+), (-?[\d.]+), (-?[\d.]+)\)$'

function ConvertFrom-NetExplosionLines {
    param([string[]]$Lines)

    $records = @()
    if ($null -eq $Lines) { return ,$records }
    foreach ($line in $Lines) {
        if ($null -eq $line) { continue }
        $text = $line.Trim()
        if ($text -notmatch 'NET_EXPLOSION') { continue }
        $m = [regex]::Match($text, $script:NetExplosionPattern)
        if (-not $m.Success) {
            $records += [pscustomobject]@{
                Path = ''; Killed = 0; Dead = 0; At = $null; Raw = $text; Malformed = $true
            }
            continue
        }
        $records += [pscustomobject]@{
            Path    = $m.Groups[1].Value
            Killed  = [int]$m.Groups[2].Value
            Dead    = [int]$m.Groups[3].Value
            At      = @([double]$m.Groups[4].Value, [double]$m.Groups[5].Value, [double]$m.Groups[6].Value)
            Raw     = $text
            Malformed = $false
        }
    }
    return ,$records
}

function Get-NetEventDistance($a, $b) {
    if ($null -eq $a -or $null -eq $b) { return [double]::PositiveInfinity }
    $dx = $a[0] - $b[0]; $dy = $a[1] - $b[1]; $dz = $a[2] - $b[2]
    return [math]::Sqrt($dx * $dx + $dy * $dy + $dz * $dz)
}

# Возвращает [pscustomobject] с Verdict = PASS | FAIL | NOT_PROVEN и Reasons.
function Test-ProxyNoDamage {
    param(
        [string]$HostLog,
        [string]$GuestLog,
        [double]$PositionTolerance = 0.05
    )

    $reasons = @()
    $hostLines = @()
    $guestLines = @()
    if (-not (Test-Path $HostLog)) { $reasons += 'host: лог отсутствует' }
    else { $hostLines = @(Get-Content $HostLog) }
    if (-not (Test-Path $GuestLog)) { $reasons += 'guest: лог отсутствует' }
    else { $guestLines = @(Get-Content $GuestLog) }

    $hostEvents = ConvertFrom-NetExplosionLines -Lines $hostLines
    $guestEvents = ConvertFrom-NetExplosionLines -Lines $guestLines
    # @(...) вокруг всего выражения: Where-Object на одном объекте может вернуть
    # PSCustomObject, у которого .Count в Windows PowerShell 5.1 пуст.
    $malformed = @(@($hostEvents) + @($guestEvents) | Where-Object { $_.Malformed })

    $result = [pscustomobject]@{
        Verdict     = 'NOT_PROVEN'
        Reasons     = $reasons
        HostEvents  = $hostEvents
        GuestEvents = $guestEvents
        Pairs       = @()
    }

    if ($malformed.Count -gt 0) {
        $result.Reasons += ("не разобрано строк NET_EXPLOSION: " + $malformed.Count +
            " (первая: " + $malformed[0].Raw + ")")
        return $result
    }
    if ($hostEvents.Count -eq 0) {
        $result.Reasons += 'host: ни одного применённого взрыва - сверять не с чем'
        return $result
    }
    if ($guestEvents.Count -eq 0) {
        $result.Reasons += 'guest: ни одного применённого взрыва - отсутствие данных не PASS'
        return $result
    }

    $guestLocal = @($guestEvents | Where-Object { $_.Path -eq 'local' })
    if ($guestLocal.Count -gt 0) {
        $result.Verdict = 'FAIL'
        $result.Reasons += ("guest применил урон локально (path=local): " + $guestLocal.Count + " соб." +
            " - это урон кинематического дубля")
        return $result
    }
    if ($hostEvents.Count -ne $guestEvents.Count) {
        $result.Verdict = 'FAIL'
        $result.Reasons += ("число взрывов не совпало: host=" + $hostEvents.Count + " guest=" + $guestEvents.Count)
        return $result
    }

    $mismatch = @()
    $pairs = @()
    for ($i = 0; $i -lt $hostEvents.Count; $i++) {
        $h = $hostEvents[$i]
        $g = $guestEvents[$i]
        $distance = Get-NetEventDistance $h.At $g.At
        $same = ($distance -le $PositionTolerance) -and ($h.Dead -eq $g.Dead) -and ($h.Killed -eq $g.Killed)
        $pairs += [pscustomobject]@{ Index = $i; Host = $h; Guest = $g; Distance = $distance; Same = $same }
        if (-not $same) {
            $mismatch += ("#[" + $i + "] host(" + $h.Path + " dead=" + $h.Dead + " killed=" + $h.Killed +
                ") guest(" + $g.Path + " dead=" + $g.Dead + " killed=" + $g.Killed +
                ") d=" + [math]::Round($distance, 3))
        }
    }
    $result.Pairs = $pairs
    if ($mismatch.Count -gt 0) {
        $result.Verdict = 'FAIL'
        $result.Reasons += ('события не совпали по событию: ' + ($mismatch -join '; '))
        return $result
    }

    $result.Verdict = 'PASS'
    $result.Reasons += ("события совпали попарно: " + $hostEvents.Count)
    return $result
}

if ($SelfTest) {
    $fixtures = @(
        @{ Name = 'valid_one_event'; Host = @('NET_EXPLOSION path=local killed=1 dead=1 at=(0.0, 0.03, 911.9525)');
           Guest = @('NET_EXPLOSION path=dead killed=1 dead=1 at=(0.0, 0.03, 911.9525)'); Want = 'PASS' },
        @{ Name = 'valid_two_events'; Host = @(
                'NET_EXPLOSION path=local killed=1 dead=1 at=(0.0, 0.03, 911.9525)',
                'NET_EXPLOSION path=local killed=0 dead=0 at=(0.0, 0.03, 911.9525)');
           Guest = @(
                'NET_EXPLOSION path=dead killed=1 dead=1 at=(0.0, 0.03, 911.9525)',
                'NET_EXPLOSION path=dead killed=0 dead=0 at=(0.0, 0.03, 911.9525)'); Want = 'PASS' },
        @{ Name = 'guest_has_no_events'; Host = @('NET_EXPLOSION path=local killed=1 dead=1 at=(0.0, 0.03, 911.9525)');
           Guest = @('NET_CASTLE t=20 role=guest detached=1'); Want = 'NOT_PROVEN' },
        @{ Name = 'host_has_no_events'; Host = @('NET_CASTLE t=20 role=host detached=0');
           Guest = @('NET_EXPLOSION path=dead killed=1 dead=1 at=(0.0, 0.03, 911.9525)'); Want = 'NOT_PROVEN' },
        @{ Name = 'empty_logs'; Host = @(); Guest = @(); Want = 'NOT_PROVEN' },
        @{ Name = 'equal_aggregates_wrong_place'; Host = @('NET_EXPLOSION path=local killed=2 dead=2 at=(0.0, 0.03, 911.9525)');
           Guest = @('NET_EXPLOSION path=dead killed=2 dead=2 at=(0.0, 0.03, 950.0)'); Want = 'FAIL' },
        @{ Name = 'duplicate_event_on_guest'; Host = @('NET_EXPLOSION path=local killed=1 dead=1 at=(0.0, 0.03, 911.9525)');
           Guest = @(
                'NET_EXPLOSION path=dead killed=1 dead=1 at=(0.0, 0.03, 911.9525)',
                'NET_EXPLOSION path=dead killed=1 dead=1 at=(0.0, 0.03, 911.9525)'); Want = 'FAIL' },
        @{ Name = 'proxy_dealt_local_damage'; Host = @('NET_EXPLOSION path=local killed=1 dead=1 at=(0.0, 0.03, 911.9525)');
           Guest = @(
                'NET_EXPLOSION path=dead killed=1 dead=1 at=(0.0, 0.03, 911.9525)',
                'NET_EXPLOSION path=local killed=1 dead=1 at=(0.0, 0.03, 900.0)'); Want = 'FAIL' },
        @{ Name = 'truncated_line'; Host = @('NET_EXPLOSION path=local killed=1 dead=1 at=(0.0, 0.03, 911.9525)');
           Guest = @('NET_EXPLOSION path=dead killed='); Want = 'NOT_PROVEN' },
        @{ Name = 'killed_differs'; Host = @('NET_EXPLOSION path=local killed=1 dead=1 at=(0.0, 0.03, 911.9525)');
           Guest = @('NET_EXPLOSION path=dead killed=0 dead=1 at=(0.0, 0.03, 911.9525)'); Want = 'FAIL' }
    )

    $temp = Join-Path ([System.IO.Path]::GetTempPath()) ('dsh_cat_fixture_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $temp | Out-Null
    $failures = @()
    foreach ($fixture in $fixtures) {
        $hostPath = Join-Path $temp ($fixture.Name + '_host.log')
        $guestPath = Join-Path $temp ($fixture.Name + '_guest.log')
        if ($null -ne $fixture.Host) { Set-Content -Path $hostPath -Value $fixture.Host -Encoding UTF8 }
        if ($null -ne $fixture.Guest) { Set-Content -Path $guestPath -Value $fixture.Guest -Encoding UTF8 }
        $check = Test-ProxyNoDamage -HostLog $hostPath -GuestLog $guestPath
        if ($check.Verdict -eq $fixture.Want) {
            Write-Host ("PASS  fixture " + $fixture.Name + " -> " + $check.Verdict)
        } else {
            Write-Host ("FAIL  fixture " + $fixture.Name + " -> " + $check.Verdict + " (ожидалось " + $fixture.Want + ")")
            $failures += $fixture.Name
        }
    }
    Remove-Item -Recurse -Force $temp -ErrorAction SilentlyContinue

    if ($failures.Count -gt 0) {
        Write-Host ("DSH_NET damage fixture FAILED: " + ($failures -join ', '))
        exit 1
    }
    Write-Host ("DSH_NET damage fixture PASSED: " + $fixtures.Count + " случаев")
    exit 0
}
