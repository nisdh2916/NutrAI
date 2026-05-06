from datetime import datetime
from sqlalchemy import (
    BigInteger, Column, DateTime, Date, ForeignKey,
    String, Text, DECIMAL, UniqueConstraint,
)
from sqlalchemy.orm import relationship
from .mysql_db import Base


class User(Base):
    __tablename__ = "users"

    id            = Column(BigInteger, primary_key=True, autoincrement=True)
    email         = Column(String(100), nullable=False, unique=True)
    password_hash = Column(String(255), nullable=False)
    nickname      = Column(String(50), nullable=False)
    status        = Column(String(20), nullable=False, default="active")
    crated_at     = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at    = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    profile    = relationship("UserProfile", back_populates="user", uselist=False)
    allergies  = relationship("UserAllergy", back_populates="user")
    meals      = relationship("Meal", back_populates="user")


class Food(Base):
    __tablename__ = "foods"

    id               = Column(BigInteger, primary_key=True, autoincrement=True)
    external_food_id = Column(String(100))
    food_name        = Column(String(150), nullable=False)
    source_name      = Column(String(50))
    last_synced_at   = Column(DateTime)
    created_at       = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at       = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    meal_foods = relationship("MealFood", back_populates="food")


class AllergyMaster(Base):
    __tablename__ = "allergy_master"

    id           = Column(BigInteger, primary_key=True, autoincrement=True)
    allergy_code = Column(String(30), nullable=False, unique=True)
    allergy_name = Column(String(100), nullable=False)

    user_allergies = relationship("UserAllergy", back_populates="allergy_master")


class UserProfile(Base):
    __tablename__ = "user_profiles"

    id             = Column(BigInteger, primary_key=True, autoincrement=True)
    users_id       = Column(BigInteger, ForeignKey("users.id"), nullable=False)
    gender         = Column(String(20))
    birth_date     = Column(Date)
    height_cm      = Column(DECIMAL(5, 2))
    weight_kg      = Column(DECIMAL(5, 2))
    activity_level = Column(String(20))
    target_kacl    = Column(DECIMAL(7, 2))
    goal_type      = Column(String(45))
    created_at     = Column(DateTime, nullable=False, default=datetime.utcnow)
    update_at      = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("User", back_populates="profile")


class UserAllergy(Base):
    __tablename__ = "user_allergies"

    id                = Column(BigInteger, primary_key=True, autoincrement=True)
    users_id          = Column(BigInteger, ForeignKey("users.id"), nullable=False)
    allergy_master_id = Column(BigInteger, ForeignKey("allergy_master.id"), nullable=False)
    created_at        = Column(DateTime, nullable=False, default=datetime.utcnow)

    user           = relationship("User", back_populates="allergies")
    allergy_master = relationship("AllergyMaster", back_populates="user_allergies")


class Meal(Base):
    __tablename__ = "meals"

    id              = Column(BigInteger, primary_key=True, autoincrement=True)
    users_id        = Column(BigInteger, ForeignKey("users.id"), nullable=False)
    meal_type       = Column(String(20), nullable=False)
    eaten_at        = Column(DateTime, nullable=False)
    memo            = Column(Text)
    source_type     = Column(String(20), nullable=False, default="manual")
    total_kcal      = Column(DECIMAL(8, 2))
    total_carb_g    = Column(DECIMAL(8, 2))
    total_protein_g = Column(DECIMAL(8, 2))
    total_fat_g     = Column(DECIMAL(8, 2))
    created_at      = Column(DateTime, nullable=False, default=datetime.utcnow)
    update_at       = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    user       = relationship("User", back_populates="meals")
    meal_foods = relationship("MealFood", back_populates="meal")
    images     = relationship("MealImage", back_populates="meal")


class MealFood(Base):
    __tablename__ = "meal_foods"

    id               = Column(BigInteger, primary_key=True, autoincrement=True)
    meals_id         = Column(BigInteger, ForeignKey("meals.id"), nullable=False)
    foods_id         = Column(BigInteger, ForeignKey("foods.id"), nullable=False)
    external_food_id = Column(String(100))
    food_name        = Column(String(150), nullable=False)
    amount_g         = Column(DECIMAL(8, 2), nullable=False)
    kcal             = Column(DECIMAL(8, 2), nullable=False)
    carb_g           = Column(DECIMAL(8, 2), nullable=False)
    protein_g        = Column(DECIMAL(8, 2), nullable=False)
    fat_g            = Column(DECIMAL(8, 2), nullable=False)
    confidence       = Column(DECIMAL(5, 4))
    created_at       = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at       = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    meal = relationship("Meal", back_populates="meal_foods")
    food = relationship("Food", back_populates="meal_foods")


class MealImage(Base):
    __tablename__ = "meal_images"

    id          = Column(BigInteger, primary_key=True, autoincrement=True)
    meals_id    = Column(BigInteger, ForeignKey("meals.id"), nullable=False)
    image_url   = Column(String(500), nullable=False)
    created_at  = Column(DateTime, nullable=False, default=datetime.utcnow)
    uploaded_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    meal             = relationship("Meal", back_populates="images")
    analysis_results = relationship("FoodAnalysisResult", back_populates="meal_image")


class FoodAnalysisResult(Base):
    __tablename__ = "food_analysis_result"

    id                    = Column(BigInteger, primary_key=True, autoincrement=True)
    meal_images_id        = Column(BigInteger, ForeignKey("meal_images.id"), nullable=False)
    detected_food_name    = Column(String(150), nullable=False)
    external_food_id      = Column(String(100))
    extimated_amount_g    = Column(DECIMAL(8, 2))
    confidence            = Column(DECIMAL(5, 4))
    raw_label             = Column(String(150))
    created_at            = Column(DateTime, nullable=False, default=datetime.utcnow)

    meal_image = relationship("MealImage", back_populates="analysis_results")
