@echo off
rem ============================================================================
rem  MAFIOZI - PESOCHNITSA (1 podopytnyj zhitel' "тест 1")
rem  Chto uzhe rabotaet i vklyucheno nizhe:
rem   * gorodok: obychnye doma ubrany, ostayutsya tol'ko zdaniya dlya zhitelej
rem   * tri kopii palacco (BOLNITSA / BANK / RESTORAN) s podpisyami nad kryshami
rem   * svobodnye dveri (polotno otvedeno, kollicii net) - mozhno vojti peshkom
rem   * odin zhitel' "тест 1": podpis' + HP + energiya nad golovoj (skvoz' steny)
rem   * uron ot vystrela primenyaetsya MGNOVENNO, porog <50% -> cel' "bolnitsa"
rem   * energiya <20% -> cel' "restoran"; energiya NE zamedlyaet dvizhenie
rem   * plita ploshchadi palacco vpisana v reestr polov (P1) - hod'ba rabotaet
rem   * pryamoe rulevanie do tsentra "BOLNITSY" (--city-simple-hospital)
rem  Chtoby vernut' vseh 286 zhitelej - uberi --city-qa=1 i --city-simple-hospital.
rem ============================================================================
start "" "%LOCALAPPDATA%\MafioziTools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe" --path "%~dp0game" res://scenes/main_city.tscn -- --city-qa=1 --city-resident-name="тест 1" --city-resident-diag=1 --city-simple-hospital=1 --city-plaza-support-plate=1 --city-medical-threshold=0.5 --city-energy-drain-per-m=1.0 --city-energy-threshold=0.2 --city-palazzo-clones=1 --city-clone-step=22 --city-town=1 --city-door-free-entry=1 --city-site-door-physics=1 --city-needs=1 --city-shop-release=1 --city-player-shop=1 --city-nav-pump-budget-us=12000 --city-nav-pump-every=1 --city-daily-slice=286 --city-walk-pose=1 --city-pose-far-cap=512 --city-clear-cache=1 --city-timing=0 --city-health-lease
