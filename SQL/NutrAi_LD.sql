CREATE TABLE user_profile (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    member_no TEXT,
    nickname TEXT NOT NULL,
    gender TEXT,
    birth_date TEXT,
    height_cm REAL,
    weight_kg REAL,
    activity_level TEXT,
    target_kcal REAL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE food (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    food_no TEXT,
    food_name TEXT NOT NULL,
    kcal REAL NOT NULL DEFAULT 0,
    carb_g REAL NOT NULL DEFAULT 0,
    protein_g REAL NOT NULL DEFAULT 0,
    fat_g REAL NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE meal (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    meal_no TEXT,
    user_id INTEGER NOT NULL,
    meal_type TEXT NOT NULL,
    eaten_at TEXT NOT NULL,
    memo TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES user_profile(id)
);

CREATE TABLE meal_food (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    meal_id INTEGER NOT NULL,
    food_id INTEGER NOT NULL,
    amount_g REAL,
    serving_count REAL DEFAULT 1,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (meal_id) REFERENCES meal(id),
    FOREIGN KEY (food_id) REFERENCES food(id)
);

CREATE TABLE local_user_allergy (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    allergy_code TEXT NOT NULL,
    allergy_name TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES user_profile(id),
    UNIQUE (user_id, allergy_code)
);

CREATE INDEX idx_meal_user_id ON meal(user_id);
CREATE INDEX idx_meal_eaten_at ON meal(eaten_at);
CREATE INDEX idx_meal_food_meal_id ON meal_food(meal_id);
CREATE INDEX idx_meal_food_food_id ON meal_food(food_id);
CREATE INDEX idx_local_user_allergy_user_id ON local_user_allergy(user_id);