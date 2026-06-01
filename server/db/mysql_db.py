import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

MYSQL_URL = os.getenv("MYSQL_URL")
if not MYSQL_URL:
    raise RuntimeError(
        "MYSQL_URL 환경변수가 설정되어 있지 않습니다. "
        "예: MYSQL_URL='mysql+pymysql://<user>:<password>@<host>:<port>/<db>'"
    )

engine = create_engine(MYSQL_URL, pool_pre_ping=True, pool_recycle=3600)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)
Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
