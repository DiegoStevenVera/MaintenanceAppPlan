from modules.asset_management.interfaces.schemas import AssetDTO, AssetHistoryEntryDTO


class SeedAssetRepository:
    def __init__(self) -> None:
        self._assets = [
            AssetDTO(
                id="asset-crk-1",
                name="CRK 1",
                category="Gabinetes",
                asset_type="ATS",
                subsystem="ATS",
                serial_or_code="EQ-1A-026",
                part_number=None,
                status="Activo",
                physical_location="Patio Santa Anita -> Sala tecnica ATS -> Gabinetes ATS",
                is_business_anchor=True,
            ),
            AssetDTO(
                id="asset-crk-2",
                name="CRK 2",
                category="Gabinetes",
                asset_type="ATS",
                subsystem="ATS",
                serial_or_code="EQ-1A-027",
                part_number=None,
                status="Activo",
                physical_location="Patio Santa Anita -> Sala tecnica ATS -> Gabinetes ATS",
                is_business_anchor=True,
            ),
            AssetDTO(
                id="asset-frontam-colectora",
                name="CUBICULO EQUIPADO DEL FRONTAM - COLECTORA",
                category="Gabinetes",
                asset_type="Frontam",
                subsystem="CBTC",
                serial_or_code="EQ-1A-180",
                part_number=None,
                status="Activo",
                physical_location="Estacion Colectora Industrial -> Sala tecnica -> Sala 2.21",
                is_business_anchor=True,
                children=["Gabinete / conjunto principal", "Modulo interno", "Tarjeta de comunicacion"],
            ),
            AssetDTO(
                id="asset-zc4",
                name="ZC4",
                category="Gabinetes",
                asset_type="Zone Controller",
                subsystem="CBTC",
                serial_or_code="EQ-1A-036",
                part_number=None,
                status="Activo",
                physical_location="Estacion asignada -> Sala tecnica CBTC -> Gabinete ZC",
                is_business_anchor=True,
            ),
        ]
        self._history = {
            "asset-crk-1": [
                AssetHistoryEntryDTO(
                    id="hist-crk-1-001",
                    report_type="preventive",
                    report_id="hist-prv-crk-1",
                    title="Inspeccion de CRK 1",
                    performed_at="2026-05-07T09:00:00-05:00",
                    result="Equipo operativo",
                )
            ],
            "asset-frontam-colectora": [
                AssetHistoryEntryDTO(
                    id="hist-frontam-001",
                    report_type="preventive",
                    report_id="hist-prv-frontam-colectora",
                    title="Inspeccion de gabinete Frontam",
                    performed_at="2026-05-22T10:00:00-05:00",
                    result="Equipo medio operativo",
                )
            ],
        }

    def list_assets(self, q: str | None = None, business_anchor: bool | None = None) -> list[AssetDTO]:
        assets = self._assets
        if business_anchor is not None:
            assets = [asset for asset in assets if asset.is_business_anchor is business_anchor]
        if q:
            query = q.casefold()
            assets = [
                asset
                for asset in assets
                if query in asset.name.casefold()
                or query in asset.category.casefold()
                or query in asset.asset_type.casefold()
                or query in asset.serial_or_code.casefold()
            ]
        return assets

    def get_asset(self, asset_id: str) -> AssetDTO | None:
        return next((asset for asset in self._assets if asset.id == asset_id), None)

    def get_history(self, asset_id: str) -> list[AssetHistoryEntryDTO]:
        return self._history.get(asset_id, [])


asset_repository = SeedAssetRepository()
