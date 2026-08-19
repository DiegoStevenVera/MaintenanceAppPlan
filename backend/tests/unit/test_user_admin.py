from app.database import Base
import app.user_admin  # noqa: F401


def test_user_admin_loads_the_complete_orm_schema() -> None:
    table_names = {table.name for table in Base.metadata.sorted_tables}

    assert {"users", "work_areas"} <= table_names
