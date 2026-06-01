import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

MYSQL_URL = os.getenv(
    "MYSQL_URL",
    "mysql+pymysql://nutrai:nutrai1234@100.127.151.47:3307/mydb"
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
