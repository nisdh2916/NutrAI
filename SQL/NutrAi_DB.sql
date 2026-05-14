-- MySQL Workbench Forward Engineering

SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

-- -----------------------------------------------------
-- Schema mydb
-- -----------------------------------------------------
DROP SCHEMA IF EXISTS `mydb` ;

-- -----------------------------------------------------
-- Schema mydb
-- -----------------------------------------------------
CREATE SCHEMA IF NOT EXISTS `mydb` DEFAULT CHARACTER SET utf8 ;
USE `mydb` ;

-- -----------------------------------------------------
-- Table `mydb`.`users`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mydb`.`users` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `email` VARCHAR(100) NOT NULL,
  `password_hash` VARCHAR(255) NOT NULL,
  `nickname` VARCHAR(50) NOT NULL,
  `status` VARCHAR(20) NOT NULL,
  `crated_at` DATETIME NOT NULL,
  `updated_at` DATETIME NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `email_UNIQUE` (`email` ASC) VISIBLE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mydb`.`allergy_master`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mydb`.`allergy_master` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `allergy_code` VARCHAR(30) NOT NULL,
  `allergy_name` VARCHAR(100) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `allergy_code_UNIQUE` (`allergy_code` ASC) VISIBLE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mydb`.`user_profiles`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mydb`.`user_profiles` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `users_id` BIGINT NOT NULL,
  `gender` VARCHAR(20) NULL,
  `birth_date` DATE NULL,
  `height_cm` DECIMAL(5,2) NULL,
  `weight_kg` DECIMAL(5,2) NULL,
  `activity_level` VARCHAR(20) NULL,
  `target_kacl` DECIMAL(7,2) NULL,
  `goal_type` VARCHAR(45) NULL,
  `created_at` DATETIME NOT NULL,
  `update_at` DATETIME NOT NULL,
  PRIMARY KEY (`id`),
  INDEX `fk_user_profiles_users_idx` (`users_id` ASC) VISIBLE,
  CONSTRAINT `fk_user_profiles_users`
    FOREIGN KEY (`users_id`)
    REFERENCES `mydb`.`users` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mydb`.`user_allergies`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mydb`.`user_allergies` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `users_id` BIGINT NOT NULL,
  `allergy_master_id` BIGINT NOT NULL,
  `created_at` DATETIME NOT NULL,
  PRIMARY KEY (`id`),
  INDEX `fk_user_allergies_users1_idx` (`users_id` ASC) VISIBLE,
  INDEX `fk_user_allergies_allergy_master1_idx` (`allergy_master_id` ASC) VISIBLE,
  CONSTRAINT `fk_user_allergies_users1`
    FOREIGN KEY (`users_id`)
    REFERENCES `mydb`.`users` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_user_allergies_allergy_master1`
    FOREIGN KEY (`allergy_master_id`)
    REFERENCES `mydb`.`allergy_master` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mydb`.`meals`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mydb`.`meals` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `users_id` BIGINT NOT NULL,
  `meal_type` VARCHAR(20) NOT NULL,
  `eaten_at` DATETIME NOT NULL,
  `memo` TEXT NULL,
  `source_type` VARCHAR(20) NOT NULL,
  `total_kcal` DECIMAL(8,2) NULL,
  `total_carb_g` DECIMAL(8,2) NULL,
  `total_protein_g` DECIMAL(8,2) NULL,
  `total_fat_g` DECIMAL(8,2) NULL,
  `created_at` DATETIME NOT NULL,
  `update_at` DATETIME NOT NULL,
  PRIMARY KEY (`id`),
  INDEX `fk_meals_users1_idx` (`users_id` ASC) VISIBLE,
  CONSTRAINT `fk_meals_users1`
    FOREIGN KEY (`users_id`)
    REFERENCES `mydb`.`users` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mydb`.`meal_foods`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mydb`.`meal_foods` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `meals_id` BIGINT NOT NULL,
  `food_name` VARCHAR(150) NOT NULL,
  `amount_g` DECIMAL(8,2) NOT NULL,
  `kcal` DECIMAL(8,2) NOT NULL,
  `carb_g` DECIMAL(8,2) NOT NULL,
  `protein_g` DECIMAL(8,2) NOT NULL,
  `fat_g` DECIMAL(8,2) NOT NULL,
  `confidence` DECIMAL(5,4) NULL,
  `created_at` DATETIME NOT NULL,
  `updated_at` DATETIME NOT NULL,
  PRIMARY KEY (`id`),
  INDEX `fk_meal_foods_meals1_idx` (`meals_id` ASC) VISIBLE,
  CONSTRAINT `fk_meal_foods_meals1`
    FOREIGN KEY (`meals_id`)
    REFERENCES `mydb`.`meals` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mydb`.`meal_images`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mydb`.`meal_images` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `meals_id` BIGINT NOT NULL,
  `image_url` VARCHAR(500) NOT NULL,
  `created_at` DATETIME NOT NULL,
  `uploaded_at` DATETIME NOT NULL,
  PRIMARY KEY (`id`),
  INDEX `fk_meal_images_meals1_idx` (`meals_id` ASC) VISIBLE,
  CONSTRAINT `fk_meal_images_meals1`
    FOREIGN KEY (`meals_id`)
    REFERENCES `mydb`.`meals` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `mydb`.`food_analysis_result`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mydb`.`food_analysis_result` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `meal_images_id` BIGINT NOT NULL,
  `food_analysis_resultcol` VARCHAR(45) NULL,
  `detected_food_name` VARCHAR(150) NOT NULL,
  `external_food_id` VARCHAR(100) NULL,
  `extimated_amount_g` DECIMAL(8,2) NULL,
  `confidence` DECIMAL(5,4) NULL,
  `raw_label` VARCHAR(150) NULL,
  `created_at` DATETIME NOT NULL,
  INDEX `fk_food_analysis_result_meal_images1_idx` (`meal_images_id` ASC) VISIBLE,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_food_analysis_result_meal_images1`
    FOREIGN KEY (`meal_images_id`)
    REFERENCES `mydb`.`meal_images` (`id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
