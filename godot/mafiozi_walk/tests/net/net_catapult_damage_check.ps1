# DSH_NET - разбор NET_EXPLOSION и проверка «дубль не нанёс урона».
#
# ПОЧЕМУ FAIL-CLOSED. В строке NET_EXPLOSION печатаются только path, killed,
# dead и at. Идентификатора события в логе нет. Поэтому совпадение точек и
# счётчиков НЕ доказывает ни однократность применения, ни отсутствие урона от
# кинематического дубля: одинаковый повтор на обеих сторонах выглядит точно так
# же, как одно честное событие. Такой вывод - NOT_PROVEN, не PASS.
#
# Что проверка делает:
#   * FAIL - явное противоречие по имеющимся данным: у гостя есть path=local
#     (локальный урон дубля), число событий разное, события не совпали попарно
#     (at > 0.05 м, dead=, killed=);
#   * NOT_PROVEN - доказать нечем: нет лога, нет строк, строка обрезана,
#     счётчик отрицательный, событие повторяется (неотличимо от двукратного
#     применения) или у строк нет идентификатора события;
#   * Consistency - отдельно, только про имеющиеся строки: MATCH (совпали
#     попарно), MISMATCH (не совпали), UNKNOWN (сравнивать нечего). Это
#     согласованность данных, а НЕ доказательство отсутствия двойного урона.
#
# PASS здесь не выдаётся принципиально: до появления event_id/kind в
# NET_EXPLOSION корректный вердикт - NOT_PROVEN. Нужные поля перечислены в
# отчёте OPT-20261020-001 (GAP), их добавление - отдельный ID на runtime.
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

function Get-NetEventSignature($record) {
    if ($null -eq $record.At) { return 'no-at' }
    return ('{0:F3},{1:F3},{2:F3}|d{3}|k{4}' -f $record.At[0], $record.At[1], $record.At[2], $record.Dead, $record.Killed)
}

function New-ProxyDamageResult {
    param([string]$Verdict, [string]$Consistency, [string[]]$Reasons, $HostEvents, $GuestEvents, $Pairs)
    return [pscustomobject]@{
        Verdict     = $Verdict
        Consistency = $Consistency
        Reasons     = $Reasons
        HostEvents  = $HostEvents
        GuestEvents = $GuestEvents
        Pairs       = $Pairs
    }
}

# Возвращает [pscustomobject]: Verdict = FAIL | NOT_PROVEN, Consistency = MATCH | MISMATCH | UNKNOWN.
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

    if ($malformed.Count -gt 0) {
        $reasons += ("не разобрано строк NET_EXPLOSION: " + $malformed.Count +
            " (первая: " + $malformed[0].Raw + ")")
        return New-ProxyDamageResult 'NOT_PROVEN' 'UNKNOWN' $reasons $hostEvents $guestEvents @()
    }

    $invalid = @(@($hostEvents) + @($guestEvents) | Where-Object { ($_.Killed -lt 0) -or ($_.Dead -lt 0) })
    if ($invalid.Count -gt 0) {
        $reasons += ("невалидные счётчики (killed/dead < 0): " + $invalid.Count +
            " (первая: " + $invalid[0].Raw + ")")
        return New-ProxyDamageResult 'NOT_PROVEN' 'UNKNOWN' $reasons $hostEvents $guestEvents @()
    }

    if ($hostEvents.Count -eq 0) {
        $reasons += 'host: ни одного применённого взрыва - сверять не с чем'
        return New-ProxyDamageResult 'NOT_PROVEN' 'UNKNOWN' $reasons $hostEvents $guestEvents @()
    }
    if ($guestEvents.Count -eq 0) {
        $reasons += 'guest: ни одного применённого взрыва - отсутствие данных не PASS'
        return New-ProxyDamageResult 'NOT_PROVEN' 'UNKNOWN' $reasons $hostEvents $guestEvents @()
    }

    $guestLocal = @($guestEvents | Where-Object { $_.Path -eq 'local' })
    if ($guestLocal.Count -gt 0) {
        $reasons += ("guest применил урон локально (path=local): " + $guestLocal.Count + " соб." +
            " - это урон кинематического дубля")
        return New-ProxyDamageResult 'FAIL' 'MISMATCH' $reasons $hostEvents $guestEvents @()
    }
    if ($hostEvents.Count -ne $guestEvents.Count) {
        $reasons += ("число взрывов не совпало: host=" + $hostEvents.Count + " guest=" + $guestEvents.Count)
        return New-ProxyDamageResult 'FAIL' 'MISMATCH' $reasons $hostEvents $guestEvents @()
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
    if ($mismatch.Count -gt 0) {
        $reasons += ('события не совпали по событию: ' + ($mismatch -join '; '))
        return New-ProxyDamageResult 'FAIL' 'MISMATCH' $reasons $hostEvents $guestEvents $pairs
    }

    # Строки согласованы, но доказательства однократности нет.
    # Повтор ищем ВНУТРИ каждой стороны: одна и та же строка у хоста и у гостя -
    # это норма (событие и его реплика), а две одинаковые строки на одной
    # стороне уже неотличимы от двукратного применения.
    $repeated = @()
    foreach ($side in @($hostEvents, $guestEvents)) {
        $counts = @{}
        foreach ($record in $side) {
            $key = Get-NetEventSignature $record
            if (-not $counts.ContainsKey($key)) { $counts[$key] = 0 }
            $counts[$key] = $counts[$key] + 1
        }
        foreach ($key in @($counts.Keys)) {
            if ($counts[$key] -gt 1) { $repeated += $key }
        }
    }
    $repeated = @($repeated | Select-Object -Unique)
    if ($repeated.Count -gt 0) {
        $reasons += ("событие повторяется (" + ($repeated -join '; ') + "): одинаковый повтор" +
            " на одной стороне неотличим от двукратного применения")
        $reasons += 'нужен event_id (или kind+порядковый номер) в строке NET_EXPLOSION - GAP'
        return New-ProxyDamageResult 'NOT_PROVEN' 'MATCH' $reasons $hostEvents $guestEvents $pairs
    }

    $reasons += ("строки согласованы попарно (" + $hostEvents.Count + "), но в NET_EXPLOSION нет" +
        " идентификатора события и отметки применения: однократность не доказана")
    $reasons += 'нужны поля event_id (или kind+id), shot/order и признак применения в NET_EXPLOSION - GAP'
    return New-ProxyDamageResult 'NOT_PROVEN' 'MATCH' $reasons $hostEvents $guestEvents $pairs
}

if ($SelfTest) {
    # Синтетические логи, не игра. Сценарии - по разбору OPT-20261020-001.
    $fixtures = @(
        @{ Name = 'one_event_consistent'; Host = @('NET_EXPLOSION path=local killed=1 dead=1 at=(0.0, 0.03, 911.9525)');
           Guest = @('NET_EXPLOSION path=dead killed=1 dead=1 at=(0.0, 0.03, 911.9525)');
           Expect = 'NOT_PROVEN'; Consistency = 'MATCH' },
        @{ Name = 'two_events_consistent'; Host = @(
                'NET_EXPLOSION path=local killed=1 dead=1 at=(0.0, 0.03, 911.9525)',
                'NET_EXPLOSION path=local killed=0 dead=0 at=(0.0, 0.03, 911.9525)');
           Guest = @(
                'NET_EXPLOSION path=dead killed=1 dead=1 at=(0.0, 0.03, 911.9525)',
                'NET_EXPLOSION path=dead killed=0 dead=0 at=(0.0, 0.03, 911.9525)');
           Expect = 'NOT_PROVEN'; Consistency = 'MATCH'; Reason = 'согласованы' },
        @{ Name = 'identical_repeat_both_sides'; Host = @(
                'NET_EXPLOSION path=local killed=1 dead=1 at=(0.0, 0.03, 911.9525)',
                'NET_EXPLOSION path=local killed=1 dead=1 at=(0.0, 0.03, 911.9525)');
           Guest = @(
                'NET_EXPLOSION path=dead killed=1 dead=1 at=(0.0, 0.03, 911.9525)',
                'NET_EXPLOSION path=dead killed=1 dead=1 at=(0.0, 0.03, 911.9525)');
           Expect = 'NOT_PROVEN'; Consistency = 'MATCH'; Reason = 'повтор' },
        @{ Name = 'negative_counters_both_sides'; Host = @('NET_EXPLOSION path=local killed=-1 dead=-1 at=(0.0, 0.03, 911.9525)');
           Guest = @('NET_EXPLOSION path=dead killed=-1 dead=-1 at=(0.0, 0.03, 911.9525)');
           Expect = 'NOT_PROVEN'; Consistency = 'UNKNOWN'; Reason = 'невалидные' },
        @{ Name = 'negative_killed_one_side'; Host = @('NET_EXPLOSION path=local killed=1 dead=1 at=(0.0, 0.03, 911.9525)');
           Guest = @('NET_EXPLOSION path=dead killed=-1 dead=1 at=(0.0, 0.03, 911.9525)');
           Expect = 'NOT_PROVEN'; Consistency = 'UNKNOWN'; Reason = 'невалидные' },
        @{ Name = 'guest_has_no_events'; Host = @('NET_EXPLOSION path=local killed=1 dead=1 at=(0.0, 0.03, 911.9525)');
           Guest = @('NET_CASTLE t=20 role=guest detached=1'); Expect = 'NOT_PROVEN'; Consistency = 'UNKNOWN' },
        @{ Name = 'host_has_no_events'; Host = @('NET_CASTLE t=20 role=host detached=0');
           Guest = @('NET_EXPLOSION path=dead killed=1 dead=1 at=(0.0, 0.03, 911.9525)');
           Expect = 'NOT_PROVEN'; Consistency = 'UNKNOWN' },
        @{ Name = 'empty_logs'; Host = @(); Guest = @(); Expect = 'NOT_PROVEN'; Consistency = 'UNKNOWN' },
        @{ Name = 'wrong_place'; Host = @('NET_EXPLOSION path=local killed=2 dead=2 at=(0.0, 0.03, 911.9525)');
           Guest = @('NET_EXPLOSION path=dead killed=2 dead=2 at=(0.0, 0.03, 950.0)');
           Expect = 'FAIL'; Consistency = 'MISMATCH' },
        @{ Name = 'duplicate_event_on_guest'; Host = @('NET_EXPLOSION path=local killed=1 dead=1 at=(0.0, 0.03, 911.9525)');
           Guest = @(
                'NET_EXPLOSION path=dead killed=1 dead=1 at=(0.0, 0.03, 911.9525)',
                'NET_EXPLOSION path=dead killed=1 dead=1 at=(0.0, 0.03, 911.9525)');
           Expect = 'FAIL'; Consistency = 'MISMATCH' },
        @{ Name = 'proxy_dealt_local_damage'; Host = @('NET_EXPLOSION path=local killed=1 dead=1 at=(0.0, 0.03, 911.9525)');
           Guest = @(
                'NET_EXPLOSION path=dead killed=1 dead=1 at=(0.0, 0.03, 911.9525)',
                'NET_EXPLOSION path=local killed=1 dead=1 at=(0.0, 0.03, 900.0)');
           Expect = 'FAIL'; Consistency = 'MISMATCH' },
        @{ Name = 'truncated_line'; Host = @('NET_EXPLOSION path=local killed=1 dead=1 at=(0.0, 0.03, 911.9525)');
           Guest = @('NET_EXPLOSION path=dead killed='); Expect = 'NOT_PROVEN'; Consistency = 'UNKNOWN' },
        @{ Name = 'killed_differs'; Host = @('NET_EXPLOSION path=local killed=1 dead=1 at=(0.0, 0.03, 911.9525)');
           Guest = @('NET_EXPLOSION path=dead killed=0 dead=1 at=(0.0, 0.03, 911.9525)');
           Expect = 'FAIL'; Consistency = 'MISMATCH' },
        @{ Name = 'host_has_extra_event'; Host = @(
                'NET_EXPLOSION path=local killed=1 dead=1 at=(0.0, 0.03, 911.9525)',
                'NET_EXPLOSION path=local killed=1 dead=1 at=(0.0, 0.03, 940.0)');
           Guest = @('NET_EXPLOSION path=dead killed=1 dead=1 at=(0.0, 0.03, 911.9525)');
           Expect = 'FAIL'; Consistency = 'MISMATCH' }
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
        $ok = ($check.Verdict -eq $fixture.Expect)
        if ($null -ne $fixture.Consistency -and $check.Consistency -ne $fixture.Consistency) { $ok = $false }
        if ($fixture.ContainsKey('Reason')) {
            $joined = ($check.Reasons -join ' | ')
            if ($joined -notmatch [regex]::Escape($fixture.Reason)) { $ok = $false }
        }
        $line = ("{0}  fixture {1} -> verdict={2} consistency={3}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $fixture.Name, $check.Verdict, $check.Consistency)
        Write-Host $line
        Write-Host ("      expected " + $fixture.Expect + " / " + $fixture.Consistency + $(if ($fixture.ContainsKey('Reason')) { " / " + $fixture.Reason } else { '' }))
        Write-Host ("      actual   " + $check.Verdict + " / " + $check.Consistency + " :: " + (($check.Reasons) -join ' | '))
        if (-not $ok) { $failures += $fixture.Name }
    }
    Remove-Item -Recurse -Force $temp -ErrorAction SilentlyContinue

    if ($failures.Count -gt 0) {
        Write-Host ("DSH_NET damage fixture FAILED: " + ($failures -join ', '))
        exit 1
    }
    Write-Host ("DSH_NET damage fixture PASSED: " + $fixtures.Count + " случаев")
    exit 0
}
