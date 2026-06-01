-- =============================================================
-- NutrAI 예제 데이터 & 테스트 쿼리
-- 실행 전제: NutrAi_DB.sql 이 먼저 실행되어 있어야 함
-- =============================================================

USE `mydb`;

-- =============================================================
-- 1. 알레르기 마스터 데이터
-- =============================================================
INSERT INTO `allergy_master` (`allergy_code`, `allergy_name`) VALUES
  ('EGG',        '달걀'),
  ('MILK',       '우유'),
  ('BUCKWHEAT',  '메밀'),
  ('PEANUT',     '땅콩'),
  ('SOYBEAN',    '대두'),
  ('WHEAT',      '밀'),
  ('MACKEREL',   '고등어'),
  ('CRAB',       '게'),
  ('SHRIMP',     '새우'),
  ('PORK',       '돼지고기'),
  ('PEACH',      '복숭아'),
  ('TOMATO',     '토마토'),
  ('SULFITE',    '아황산류'),
  ('WALNUT',     '호두'),
  ('CHICKEN',    '닭고기'),
  ('BEEF',       '쇠고기'),
  ('SQUID',      '오징어'),
  ('SHELLFISH',  '조개류'),
  ('PINE_NUT',   '잣');


-- =============================================================
-- 2. 유저 3명 (비밀번호: bcrypt 더미 해시)
-- =============================================================
INSERT INTO `users` (`email`, `password_hash`, `nickname`, `status`) VALUES
  ('alice@example.com', '$2b$12$dummyhashAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA', '앨리스', 'active'),
  ('bob@example.com',   '$2b$12$dummyhashBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB', '밥',    'active'),
  ('carol@example.com', '$2b$12$dummyhashCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC', '캐롤',  'active');


-- =============================================================
-- 3. 유저 프로필
-- =============================================================
INSERT INTO `user_profiles`
  (`users_id`, `gender`, `birth_date`, `height_cm`, `weight_kg`,
   `activity_level`, `target_kcal`, `goal_type`, `condition`)
VALUES
  (1, 'female', '1998-03-15', 163.00, 55.00, 'moderate', 1800.00, 'diet',       '철분 부족'),
  (2, 'male',   '1995-07-22', 178.50, 80.00, 'high',     2500.00, 'muscle',     NULL),
  (3, 'female', '2000-11-05', 170.00, 62.50, 'low',      1600.00, 'maintain',   '유당불내증');


-- =============================================================
-- 4. 유저 알레르기 (user_id → allergy_master_id 참조)
-- =============================================================
-- 앨리스: 달걀, 밀
INSERT INTO `user_allergies` (`users_id`, `allergy_master_id`) VALUES (1, 1), (1, 6);
-- 밥: 새우, 게
INSERT INTO `user_allergies` (`users_id`, `allergy_master_id`) VALUES (2, 9), (2, 8);
-- 캐롤: 우유
INSERT INTO `user_allergies` (`users_id`, `allergy_master_id`) VALUES (3, 2);


-- =============================================================
-- 5. 식사 기록 (meals)
-- =============================================================
INSERT INTO `meals`
  (`users_id`, `meal_type`, `eaten_at`, `memo`, `source_type`,
   `total_kcal`, `total_carb_g`, `total_protein_g`, `total_fat_g`)
VALUES
  -- 앨리스: 2025-05-18 아침 (카메라)
  (1, 'breakfast', '2025-05-18 08:10:00', NULL,          'camera', 520.00, 72.00, 18.00, 12.00),
  -- 앨리스: 2025-05-18 점심 (수동)
  (1, 'lunch',     '2025-05-18 12:30:00', '한식 도시락', 'manual', 780.00, 110.00, 32.00, 18.00),
  -- 밥: 2025-05-18 아침 (카메라)
  (2, 'breakfast', '2025-05-18 07:45:00', NULL,          'camera', 650.00, 80.00, 35.00, 15.00),
  -- 밥: 2025-05-18 저녁 (수동)
  (2, 'dinner',    '2025-05-18 19:20:00', '치킨',        'manual', 1100.00, 60.00, 80.00, 55.00),
  -- 캐롤: 2025-05-18 점심 (카메라)
  (3, 'lunch',     '2025-05-18 12:00:00', NULL,          'camera', 600.00, 90.00, 25.00, 14.00);


-- =============================================================
-- 6. 식사 음식 상세 (meal_foods)
-- =============================================================
-- meal_id=1 (앨리스 아침, 카메라)
INSERT INTO `meal_foods`
  (`meals_id`, `food_name`, `amount_g`, `kcal`, `carb_g`, `protein_g`, `fat_g`, `confidence`)
VALUES
  (1, '흰쌀밥',   150.00, 252.00, 55.50, 4.50, 0.45, 0.9820),
  (1, '미역국',   200.00, 48.00,  4.00,  4.00, 1.60, 0.9510),
  (1, '계란후라이', 60.00, 97.00,  0.50,  6.30, 7.50, 0.9700),
  (1, '김치',     50.00,  19.00,  2.80,  1.50, 0.30, 0.9880),
  (1, '시금치나물',40.00,  15.00,  1.80,  1.50, 0.40, 0.9300);

-- meal_id=2 (앨리스 점심, 수동)
INSERT INTO `meal_foods`
  (`meals_id`, `food_name`, `amount_g`, `kcal`, `carb_g`, `protein_g`, `fat_g`, `confidence`)
VALUES
  (2, '흰쌀밥',   200.00, 336.00, 74.00, 6.00, 0.60, NULL),
  (2, '된장찌개', 300.00, 120.00, 10.00, 9.00, 4.00, NULL),
  (2, '불고기',   100.00, 220.00, 8.00,  17.00, 13.00, NULL),
  (2, '깍두기',    50.00,  22.00,  4.00,  0.80, 0.30, NULL);

-- meal_id=3 (밥 아침, 카메라)
INSERT INTO `meal_foods`
  (`meals_id`, `food_name`, `amount_g`, `kcal`, `carb_g`, `protein_g`, `fat_g`, `confidence`)
VALUES
  (3, '오트밀',   80.00,  300.00, 54.00, 10.00, 6.00, 0.9650),
  (3, '바나나',  120.00,  107.00, 27.00,  1.30, 0.40, 0.9820),
  (3, '삶은달걀', 60.00,  78.00,   0.60,  6.30, 5.30, 0.9900),
  (3, '아몬드밀크',200.00, 30.00,  2.00,  1.00, 1.00, 0.9100);

-- meal_id=5 (캐롤 점심, 카메라)
INSERT INTO `meal_foods`
  (`meals_id`, `food_name`, `amount_g`, `kcal`, `carb_g`, `protein_g`, `fat_g`, `confidence`)
VALUES
  (5, '김치볶음밥', 250.00, 410.00, 72.00, 12.00,  8.00, 0.9430),
  (5, '계란후라이',  60.00,  97.00,  0.50,  6.30,  7.50, 0.9750),
  (5, '단무지',      30.00,  12.00,  3.00,  0.20,  0.05, 0.9610);


-- =============================================================
-- 7. 식사 이미지 (meal_images) — camera source 만
-- =============================================================
INSERT INTO `meal_images` (`meals_id`, `image_url`) VALUES
  (1, 'https://storage.example.com/meals/user1/20250518_0810.jpg'),
  (3, 'https://storage.example.com/meals/user2/20250518_0745.jpg'),
  (5, 'https://storage.example.com/meals/user3/20250518_1200.jpg');


-- =============================================================
-- 8. AI 음식 분석 결과 (food_analysis_result)
-- =============================================================
-- meal_image_id=1 (앨리스 아침)
INSERT INTO `food_analysis_result`
  (`meal_images_id`, `detected_food_name`, `estimated_amount_g`, `confidence`, `raw_label`)
VALUES
  (1, '흰쌀밥',    150.00, 0.9820, 'cooked_rice'),
  (1, '미역국',    200.00, 0.9510, 'seaweed_soup'),
  (1, '계란후라이', 60.00, 0.9700, 'fried_egg'),
  (1, '김치',       50.00, 0.9880, 'kimchi'),
  (1, '시금치나물', 40.00, 0.9300, 'spinach_side');

-- meal_image_id=2 (밥 아침)
INSERT INTO `food_analysis_result`
  (`meal_images_id`, `detected_food_name`, `estimated_amount_g`, `confidence`, `raw_label`)
VALUES
  (2, '오트밀',     80.00, 0.9650, 'oatmeal'),
  (2, '바나나',    120.00, 0.9820, 'banana'),
  (2, '삶은달걀',   60.00, 0.9900, 'boiled_egg'),
  (2, '아몬드밀크', 200.00, 0.9100, 'almond_milk');

-- meal_image_id=3 (캐롤 점심)
INSERT INTO `food_analysis_result`
  (`meal_images_id`, `detected_food_name`, `estimated_amount_g`, `confidence`, `raw_label`)
VALUES
  (3, '김치볶음밥', 250.00, 0.9430, 'kimchi_fried_rice'),
  (3, '계란후라이',  60.00, 0.9750, 'fried_egg'),
  (3, '단무지',      30.00, 0.9610, 'pickled_radish');


-- =============================================================
-- 테스트 쿼리
-- =============================================================

-- [T1] 유저 목록 + 프로필 조인
SELECT
  u.id,
  u.email,
  u.nickname,
  up.gender,
  up.height_cm,
  up.weight_kg,
  up.target_kcal,
  up.goal_type,
  up.condition
FROM users u
LEFT JOIN user_profiles up ON up.users_id = u.id
ORDER BY u.id;


-- [T2] 유저별 알레르기 목록
SELECT
  u.nickname,
  am.allergy_code,
  am.allergy_name
FROM user_allergies ua
JOIN users         u  ON u.id  = ua.users_id
JOIN allergy_master am ON am.id = ua.allergy_master_id
ORDER BY u.id, am.allergy_code;


-- [T3] 특정 날짜(2025-05-18) 앨리스(user_id=1)의 식사 요약
SELECT
  m.meal_type,
  m.eaten_at,
  m.source_type,
  m.total_kcal,
  m.total_carb_g,
  m.total_protein_g,
  m.total_fat_g
FROM meals m
WHERE m.users_id = 1
  AND DATE(m.eaten_at) = '2025-05-18'
ORDER BY m.eaten_at;


-- [T4] 특정 식사(meal_id=1)의 음식 상세
SELECT
  mf.food_name,
  mf.amount_g,
  mf.kcal,
  mf.carb_g,
  mf.protein_g,
  mf.fat_g,
  mf.confidence
FROM meal_foods mf
WHERE mf.meals_id = 1
ORDER BY mf.kcal DESC;


-- [T5] 유저별 일일 총 칼로리 집계
SELECT
  u.nickname,
  DATE(m.eaten_at)         AS meal_date,
  SUM(m.total_kcal)        AS day_kcal,
  SUM(m.total_carb_g)      AS day_carb_g,
  SUM(m.total_protein_g)   AS day_protein_g,
  SUM(m.total_fat_g)       AS day_fat_g,
  up.target_kcal,
  ROUND(SUM(m.total_kcal) / up.target_kcal * 100, 1) AS kcal_pct
FROM meals m
JOIN users         u  ON u.id  = m.users_id
LEFT JOIN user_profiles up ON up.users_id = m.users_id
GROUP BY u.id, u.nickname, meal_date, up.target_kcal
ORDER BY u.id, meal_date;


-- [T6] 카메라로 찍은 식사에서 AI 분석 결과 조회
SELECT
  u.nickname,
  m.meal_type,
  m.eaten_at,
  mi.image_url,
  far.detected_food_name,
  far.estimated_amount_g,
  far.confidence,
  far.raw_label
FROM food_analysis_result far
JOIN meal_images mi ON mi.id       = far.meal_images_id
JOIN meals       m  ON m.id        = mi.meals_id
JOIN users       u  ON u.id        = m.users_id
ORDER BY far.confidence DESC;


-- [T7] confidence 낮은 AI 탐지 결과 (0.95 미만)
SELECT
  u.nickname,
  far.detected_food_name,
  far.confidence,
  far.raw_label
FROM food_analysis_result far
JOIN meal_images mi ON mi.id    = far.meal_images_id
JOIN meals       m  ON m.id     = mi.meals_id
JOIN users       u  ON u.id     = m.users_id
WHERE far.confidence < 0.95
ORDER BY far.confidence ASC;


-- [T8] 알레르기 있는 유저가 해당 알레르기 음식을 먹은 기록 (달걀 예시)
SELECT
  u.nickname,
  am.allergy_name       AS allergy,
  mf.food_name          AS eaten_food,
  m.eaten_at
FROM meal_foods mf
JOIN meals           m   ON m.id  = mf.meals_id
JOIN users           u   ON u.id  = m.users_id
JOIN user_allergies  ua  ON ua.users_id = u.id
JOIN allergy_master  am  ON am.id = ua.allergy_master_id
WHERE mf.food_name LIKE CONCAT('%', '달걀', '%')
  AND am.allergy_name = '달걀';


-- [T9] 식사 source_type 별 건수 통계
SELECT
  source_type,
  COUNT(*)          AS meal_count,
  AVG(total_kcal)   AS avg_kcal
FROM meals
GROUP BY source_type;


-- [T10] 데이터 정합성 확인: meals total_kcal vs meal_foods 합산 비교
SELECT
  m.id             AS meal_id,
  m.total_kcal     AS stored_kcal,
  ROUND(SUM(mf.kcal), 2) AS calc_kcal,
  ROUND(m.total_kcal - SUM(mf.kcal), 2) AS diff
FROM meals m
JOIN meal_foods mf ON mf.meals_id = m.id
GROUP BY m.id, m.total_kcal
ORDER BY ABS(m.total_kcal - SUM(mf.kcal)) DESC;
