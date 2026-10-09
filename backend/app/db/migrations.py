import logging
from sqlalchemy import text
from backend.app.db.session import engine, Base

logger = logging.getLogger("recordguard.migrations")

def ensure_db_schema():
    """
    Ensures that all tables and columns required by the updated schema exist on existing SQLite tables,
    enabling seamless hot-restarts without dropping existing tables or corrupting reviewer data.
    """
    Base.metadata.create_all(bind=engine)
    with engine.connect() as conn:
        try:
            # Check findings table
            res = conn.execute(text("PRAGMA table_info(findings)")).fetchall()
            existing_cols = {row[1] for row in res}
            
            columns_to_add = [
                ("document_a_id", "VARCHAR(36)"),
                ("document_b_id", "VARCHAR(36)"),
                ("unit_a", "VARCHAR(64)"),
                ("unit_b", "VARCHAR(64)"),
                ("status_a", "VARCHAR(32)"),
                ("status_b", "VARCHAR(32)"),
                ("uncertainty_notes", "TEXT"),
                ("clinically_verified", "BOOLEAN DEFAULT 0"),
                ("verified_conclusion", "TEXT"),
                ("user_id", "VARCHAR(128)"),
            ]
            
            for col_name, col_type in columns_to_add:
                if col_name not in existing_cols:
                    logger.info(f"Adding missing column to findings table: {col_name} {col_type}")
                    conn.execute(text(f"ALTER TABLE findings ADD COLUMN {col_name} {col_type}"))

            # Check user_id in patients, documents, comparisons
            table_checks = [
                ("patients", [("user_id", "VARCHAR(128)")]),
                ("documents", [("user_id", "VARCHAR(128)")]),
                ("comparisons", [("user_id", "VARCHAR(128)")]),
                ("users", [("email", "VARCHAR(128)"), ("updated_at", "DATETIME")]),
            ]

            for table_name, cols in table_checks:
                try:
                    t_info = conn.execute(text(f"PRAGMA table_info({table_name})")).fetchall()
                    t_cols = {row[1] for row in t_info}
                    for c_name, c_type in cols:
                        if c_name not in t_cols:
                            logger.info(f"Adding missing column to {table_name}: {c_name} {c_type}")
                            conn.execute(text(f"ALTER TABLE {table_name} ADD COLUMN {c_name} {c_type}"))
                except Exception as ex:
                    logger.warning(f"Error checking {table_name} schema: {ex}")
                    
            conn.commit()
        except Exception as e:
            logger.warning(f"Schema migration check encountered non-fatal error: {e}")
