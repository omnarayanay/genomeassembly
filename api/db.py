import os
from sqlalchemy import create_engine, Column, String, JSON
from sqlalchemy.orm import declarative_base, sessionmaker

DATABASE_URL = os.environ.get("DATABASE_URL", "sqlite:///data/db/runs.sqlite")

engine = create_engine(
    DATABASE_URL, connect_args={"check_same_thread": False}
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

class RunRecord(Base):
    __tablename__ = "runs"

    run_id = Column(String, primary_key=True, index=True)
    sample_id = Column(String, index=True) # just using first sample for now, or JSON
    status = Column(String, default="queued")
    current_stage = Column(String, nullable=True)
    config_snapshot = Column(JSON, nullable=True)
    tool_versions = Column(JSON, nullable=True)
    metrics = Column(JSON, nullable=True)
    created_at = Column(String)
    started_at = Column(String, nullable=True)
    finished_at = Column(String, nullable=True)
    log_path = Column(String, nullable=True)

Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
