"""Build a loss-prevention ledger; never edits a map, database or source registry.

The artist's plan is a proposal, not runtime authority. Static catalog rows,
major aliases and potential player properties intentionally remain distinct.
Generated files are disposable; reviewed placement receipts are supplied
separately so regenerating this ledger cannot erase QA progress.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHECKS = ("assetLoaded", "placed", "doorPassed", "collisionPassed",
          "pedestrianRoutePassed", "vehicleRoutePassed", "serverAnchorMatched")


def build_ledger(economy: dict, services: dict, plan: dict) -> dict:
    rows: dict[str, dict] = {}
    for group in ("banks", "businesses"):
        for item in economy[group]:
            key = item["inventoryId"]
            if key in rows:
                raise ValueError(f"duplicate catalog identity: {key}")
            rows[key] = {"id": key, "name": item["name"],
                         "oldRC": [item["coordinates"]["r"], item["coordinates"]["c"]],
                         "interior": copy.deepcopy(item["interior"]),
                         "sources": copy.deepcopy(item["sourceRefs"]),
                         "status": "runtime_definition", "aliases": []}
    for item in services["entities"]:
        key = f'{item["namespace"]}:{item["id"]}'
        if key in rows:
            raise ValueError(f"duplicate catalog identity: {key}")
        rows[key] = {"id": key, "name": item.get("name") or key,
                     "oldRC": [item["r"], item["c"]],
                     "status": item["status"], "sources": [item["source"]],
                     "immutable": item.get("immutable", False),
                     "aliases": copy.deepcopy(item.get("crossReferences", [])),
                     "preserve": copy.deepcopy(item.get("preserve", []))}
    alias_owner = {}
    for row in rows.values():
        for alias in row["aliases"]:
            if alias in alias_owner or alias in rows:
                raise ValueError(f"ambiguous identity alias: {alias}")
            alias_owner[alias] = row["id"]
    for major in economy["majorSites"]:
        owner = alias_owner.get(major["inventoryId"])
        if owner is None:
            raise ValueError(f'major without physical POI: {major["inventoryId"]}')
        coords = major["coordinates"]
        if rows[owner]["oldRC"] != [coords["r"], coords["c"]]:
            raise ValueError(f"major / POI coordinate conflict: {owner}")
        rows[owner]["interior"] = copy.deepcopy(major["interior"])
        rows[owner]["sources"] += major["sourceRefs"]

    planned = {}
    for group in ("banks", "businesses", "pois", "facilities"):
        for item in plan.get("inventory", {}).get(group, []):
            key = item["stable_id"]
            if key in planned:
                raise ValueError(f"duplicate planning identity: {key}")
            planned[key] = item
    conflicts, missing = [], []
    for key, row in rows.items():
        target = planned.get(key)
        row.update({"plannedRC": None, "plannedDistrict": None,
                    "assetBinding": None, "checks": {k: False for k in CHECKS},
                    "placementStatus": "awaiting_binding_and_live_checks"})
        if target:
            row["plannedRC"] = copy.deepcopy(target["planned_rc"])
            row["plannedDistrict"] = target.get("district")
            if target.get("old_rc") != row["oldRC"]:
                conflicts.append({"id": key, "issue": "stale_planning_old_anchor",
                                  "runtimeRC": row["oldRC"], "planOldRC": target.get("old_rc")})
            if row.get("immutable") and row["plannedRC"] != row["oldRC"]:
                conflicts.append({"id": key, "issue": "immutable_anchor_moved"})
        else:
            missing.append(key)
    properties = copy.deepcopy(economy["eligibleGenericBuildings"])
    return {
        "schema": "mafiozi.city-rebuild.loss-prevention-ledger/v1",
        "status": "IN_PROGRESS_NOT_APPLIED", "coordinateOrder": ["r", "c"],
        "counts": {"catalogRows": len(rows), "banks": len(economy["banks"]),
                   "fixedBusinesses": len(economy["businesses"]),
                   "majorAliasesNotAdditionalBuildings": len(alias_owner),
                   "plannedCatalogRows": len(rows) - len(missing),
                   "genericPotentialKeysNotActiveBuildings": len(properties["items"])},
        "rows": list(rows.values()), "missingFromMasterplan": missing,
        "planningConflicts": conflicts,
        "plannedOnlyFacilities": [v for k, v in planned.items() if k not in rows],
        "immutableGeometry": copy.deepcopy(services["immutableGeometry"]),
        "serviceAnchors": copy.deepcopy(services["serviceAnchors"]),
        "districtAnchors": copy.deepcopy(services["districtAnchors"]),
        "genericPotentialProperties": properties,
        "visualReplacementsNotNewBusinesses": copy.deepcopy(economy["renderReplacements"]),
        "coverage": copy.deepcopy(economy["coverage"]),
        "applyGate": {"allowed": False, "reasons": [
            "topology_and_road_crossings_require_native_validation",
            "placement_receipts_and_full_footprint_checks_missing",
            "dynamic_property_snapshot_and_id_crosswalk_missing",
            "server_client_anchor_migration_not_applied",
        ]},
    }


def validate_receipts(ledger: dict, receipts: list[dict], *, dynamic_complete=False) -> list[str]:
    """Fail closed on missing/duplicate IDs and unverifiable migration claims."""
    expected = {row["id"]: row for row in ledger["rows"]}
    actual, errors = {}, []
    for receipt in receipts:
        key = receipt.get("id")
        if key in actual:
            errors.append(f"duplicate receipt:{key}")
        actual[key] = receipt
        if key not in expected:
            errors.append(f"unknown receipt:{key}")
    for key, source in expected.items():
        item = actual.get(key)
        if not item:
            errors.append(f"missing receipt:{key}")
            continue
        if item.get("oldRC") != source["oldRC"]:
            errors.append(f"source anchor mismatch:{key}")
        if source.get("immutable") and item.get("newRC") != source["oldRC"]:
            errors.append(f"immutable anchor moved:{key}")
        if not item.get("assetBinding"):
            errors.append(f"missing asset binding:{key}")
        for check in CHECKS:
            if item.get("checks", {}).get(check) is not True:
                errors.append(f"unchecked {check}:{key}")
    if not dynamic_complete:
        errors.append("dynamic property coverage unknown")
    return errors


def markdown(ledger: dict) -> str:
    lines = ["# Реестр пересборки города", "",
             "Старую рабочую карту пока не удаляли. Это список переноса, не отчёт о готовой расстановке.", "",
             "Статические игровые записи и имущество игроков сохраняются. Совпадение координат не означает один объект.", "",
             "| Объект / ID | Было r,c | Предложено r,c | Расставлен | Вход | Коллизия | Маршруты |",
             "|---|---|---|---|---|---|---|"]
    for row in ledger["rows"]:
        old = ", ".join(map(str, row["oldRC"]))
        new = ", ".join(map(str, row["plannedRC"])) if row["plannedRC"] else "нужно назначить"
        lines.append(f'| {row["name"]} · `{row["id"]}` | {old} | {new} | ☐ | ☐ | ☐ | ☐ |')
    lines += ["", "## Что ещё нельзя потерять", "",
              "- Частные дома, квартиры, штабы и здания, превращённые игроками в бизнес: нужен снимок фактических владений. 101 ключ в каталоге — потенциальные участки, не 101 действующий бизнес.",
              "- Подъезды скорой/пожарных/эвакуаторов, респаун, камеры и конвой полиции, причал/корабль, районные игровые якоря.",
              "- Старый полицейский комплекс целиком и красный мост: защищены отдельными точными областями.",
              "- Асфальт, тротуары, песок, берег, фонари, светофоры, мосты, деревья, лавочки, фонтаны и мусорные урны: отдельные слои расстановки, не новые бизнесы.",
              "- Готовые ломбард, типография, оружейный, букмекерская, клуб и стеклянный павильон — визуальные модели; не создавать из них дубли экономических записей автоматически.", "",
              "## Статус", "",
              f'- В мастер-плане отсутствуют {len(ledger["missingFromMasterplan"])} строки действующего/экспериментального каталога; требуется расстановка.',
              f'- Обнаружено {len(ledger["planningConflicts"])} несовпадений старых якорей с планом; требуется актуализация.',
              "- Полный перенос в main запрещён до проверки реальных владений, входов, проходимости и совпадения серверных координат.", ""]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "docs/city-rebuild")
    args = parser.parse_args()
    paths = [ROOT / "docs/city-rebuild/businesses-banks.inventory.json",
             ROOT / "docs/city-rebuild/services-pois.inventory.json", args.plan]
    data = [json.loads(p.read_text(encoding="utf-8-sig")) for p in paths]
    ledger = build_ledger(*data)
    ledger["inputFingerprints"] = [{"file": p.name, "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in paths]
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "rebuild-ledger.generated.json").write_text(json.dumps(ledger, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (args.output / "REBUILD_CHECKLIST.generated.md").write_text(markdown(ledger), encoding="utf-8")
    print(json.dumps({"counts": ledger["counts"], "planningConflicts": ledger["planningConflicts"],
                      "missingFromMasterplan": ledger["missingFromMasterplan"], "applied": False}, ensure_ascii=False))


if __name__ == "__main__":
    main()
