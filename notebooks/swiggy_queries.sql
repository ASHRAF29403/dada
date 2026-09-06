
-- ---------------------------------------------------------------------------------

-- إنشاء قاعدة البيانات الجديدة
CREATE DATABASE SwiggyDB;
GO

-- استخدام قاعدة البيانات التي تم إنشاؤها
USE SwiggyDB;
GO


-- ---------------------------------------------------------------------------------

-- أ) التحقق من وجود قيم فارغة (Null Check) في جميع الأعمدة

SELECT 
    SUM(CASE WHEN state IS NULL THEN 1 ELSE 0 END) AS null_state,
    SUM(CASE WHEN city IS NULL THEN 1 ELSE 0 END) AS null_city,
    SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END) AS null_order_date,
    SUM(CASE WHEN restaurant_name IS NULL THEN 1 ELSE 0 END) AS null_restaurant_name,
    SUM(CASE WHEN location IS NULL THEN 1 ELSE 0 END) AS null_location,
    SUM(CASE WHEN category IS NULL THEN 1 ELSE 0 END) AS null_category,
    SUM(CASE WHEN dish_name IS NULL THEN 1 ELSE 0 END) AS null_dish_name,
    SUM(CASE WHEN price IS NULL THEN 1 ELSE 0 END) AS null_price,
    SUM(CASE WHEN rating IS NULL THEN 1 ELSE 0 END) AS null_rating,
    SUM(CASE WHEN rating_count IS NULL THEN 1 ELSE 0 END) AS null_rating_count
FROM swiggy_data;
GO

-- ب) التحقق من وجود نصوص فارغة (Empty Strings) في الأعمدة الوصفية (Dimensions)
SELECT * 
FROM swiggy_data
WHERE state = ''
   OR city = ''
   OR restaurant_name = ''
   OR location = ''
   OR category = ''
   OR dish_name = '';
GO

-- ج) الكشف عن الصفوف المكررة (Duplicate Detection)

SELECT 
    state, city, order_date, restaurant_name, location, category, dish_name, price, rating, rating_count,
    COUNT(*) AS duplicate_count
FROM swiggy_data
GROUP BY state, city, order_date, restaurant_name, location, category, dish_name, price, rating, rating_count
HAVING COUNT(*) > 1;
GO

-- د) حذف الصفوف المكررة والإبقاء على نسخة واحدة (Delete Duplicates)

WITH DuplicateCTE AS (
    SELECT *,
           ROW_NUMBER() OVER(
               PARTITION BY state, city, order_date, restaurant_name, location, category, dish_name, price, rating, rating_count 
               ORDER BY (SELECT NULL)
           ) AS RN
    FROM swiggy_data
)
DELETE FROM DuplicateCTE 
WHERE RN > 1;
GO


-- ---------------------------------------------------------------------------------
-- القسم 3: تصميم نموذج البيانات النجمي (Star Schema - Dimensional Modeling)
-- ---------------------------------------------------------------------------------

-- 1) إنشاء جدول أبعاد التاريخ (dim_date)
CREATE TABLE dim_date (
    date_id INT IDENTITY(1,1) PRIMARY KEY,
    full_date DATE NOT NULL,
    year INT NOT NULL,
    month INT NOT NULL,
    month_name VARCHAR(20) NOT NULL,
    quarter INT NOT NULL,
    day INT NOT NULL,
    week_number INT NOT NULL
);
GO

-- 2) إنشاء جدول أبعاد الموقع الجغرافي (dim_location)
CREATE TABLE dim_location (
    location_id INT IDENTITY(1,1) PRIMARY KEY,
    state VARCHAR(100) NOT NULL,
    city VARCHAR(100) NOT NULL,
    location VARCHAR(200) NOT NULL
);
GO

-- 3) إنشاء جدول أبعاد المطاعم (dim_restaurant)
CREATE TABLE dim_restaurant (
    restaurant_id INT IDENTITY(1,1) PRIMARY KEY,
    restaurant_name VARCHAR(200) NOT NULL
);
GO

-- 4) إنشاء جدول أبعاد تصنيفات الطعام (dim_category)
CREATE TABLE dim_category (
    category_id INT IDENTITY(1,1) PRIMARY KEY,
    category VARCHAR(100) NOT NULL
);
GO

-- 5) إنشاء جدول أبعاد الأطباق (dim_dish)
CREATE TABLE dim_dish (
    dish_id INT IDENTITY(1,1) PRIMARY KEY,
    dish_name VARCHAR(200) NOT NULL
);
GO

-- 6) إنشاء جدول الحقائق المركزي (fact_swiggy_orders) مع ربطه بجداول الأبعاد عبر مفاتيح أجنبية
CREATE TABLE fact_swiggy_orders (
    order_id INT IDENTITY(1,1) PRIMARY KEY,
    date_id INT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    rating DECIMAL(4,2) NOT NULL,
    rating_count INT NOT NULL,
    location_id INT NOT NULL,
    restaurant_id INT NOT NULL,
    category_id INT NOT NULL,
    dish_id INT NOT NULL,
    CONSTRAINT FK_fact_date FOREIGN KEY (date_id) REFERENCES dim_date(date_id),
    CONSTRAINT FK_fact_location FOREIGN KEY (location_id) REFERENCES dim_location(location_id),
    CONSTRAINT FK_fact_restaurant FOREIGN KEY (restaurant_id) REFERENCES dim_restaurant(restaurant_id),
    CONSTRAINT FK_fact_category FOREIGN KEY (category_id) REFERENCES dim_category(category_id),
    CONSTRAINT FK_fact_dish FOREIGN KEY (dish_id) REFERENCES dim_dish(dish_id)
);
GO


-- ---------------------------------------------------------------------------------
-- القسم 4: تعبئة وإدراج البيانات في جداول الأبعاد والحقائق (Data Ingestion)
-- ---------------------------------------------------------------------------------

-- 1) إدراج البيانات في جدول التاريخ (dim_date)
INSERT INTO dim_date (full_date, year, month, month_name, quarter, day, week_number)
SELECT DISTINCT 
    order_date,
    YEAR(order_date) AS year,
    MONTH(order_date) AS month,
    DATENAME(MONTH, order_date) AS month_name,
    DATEPART(QUARTER, order_date) AS quarter,
    DAY(order_date) AS day,
    DATEPART(WEEK, order_date) AS week_number
FROM swiggy_data
WHERE order_date IS NOT NULL;
GO

-- 2) إدراج البيانات في جدول الموقع الجغرافي (dim_location)
INSERT INTO dim_location (state, city, location)
SELECT DISTINCT state, city, location
FROM swiggy_data
WHERE state IS NOT NULL AND city IS NOT NULL AND location IS NOT NULL;
GO

-- 3) إدراج البيانات في جدول المطاعم (dim_restaurant)
INSERT INTO dim_restaurant (restaurant_name)
SELECT DISTINCT restaurant_name
FROM swiggy_data
WHERE restaurant_name IS NOT NULL;
GO

-- 4) إدراج البيانات في جدول تصنيفات الطعام (dim_category)
INSERT INTO dim_category (category)
SELECT DISTINCT category
FROM swiggy_data
WHERE category IS NOT NULL;
GO

-- 5) إدراج البيانات في جدول الأطباق (dim_dish)
INSERT INTO dim_dish (dish_name)
SELECT DISTINCT dish_name
FROM swiggy_data
WHERE dish_name IS NOT NULL;
GO

-- 6) تعبئة جدول الحقائق الرئيسي (fact_swiggy_orders) بربط الجداول المؤقتة لاستخراج الـ IDs المناسبة
INSERT INTO fact_swiggy_orders (date_id, price, rating, rating_count, location_id, restaurant_id, category_id, dish_id)
SELECT 
    dd.date_id,
    s.price,
    s.rating,
    s.rating_count,
    dl.location_id,
    dr.restaurant_id,
    dc.category_id,
    ds.dish_id
FROM swiggy_data s
LEFT JOIN dim_date dd ON s.order_date = dd.full_date
LEFT JOIN dim_location dl ON s.state = dl.state AND s.city = dl.city AND s.location = dl.location
LEFT JOIN dim_restaurant dr ON s.restaurant_name = dr.restaurant_name
LEFT JOIN dim_category dc ON s.category = dc.category
LEFT JOIN dim_dish ds ON s.dish_name = ds.dish_name;
GO


-- ---------------------------------------------------------------------------------
-- القسم 5: ربط الجداول الكامل وعرض الهيكل النهائي (Schema Verification Join)
-- ---------------------------------------------------------------------------------

-- استعلام لاسترجاع الجدول بالكامل مع دمج جداول الأبعاد للتأكد من نجاح الروابط
SELECT 
    f.order_id,
    d.full_date, d.year, d.month_name,
    l.state, l.city, l.location,
    r.restaurant_name,
    c.category,
    ds.dish_name,
    f.price, f.rating, f.rating_count
FROM fact_swiggy_orders f
INNER JOIN dim_date d ON f.date_id = d.date_id
INNER JOIN dim_location l ON f.location_id = l.location_id
INNER JOIN dim_restaurant r ON f.restaurant_id = r.restaurant_id
INNER JOIN dim_category c ON f.category_id = c.category_id
INNER JOIN dim_dish ds ON f.dish_id = ds.dish_id;
GO


-- ---------------------------------------------------------------------------------
-- القسم 6: مؤشرات الأداء الرئيسية (KPIs - Key Performance Indicators)
-- ---------------------------------------------------------------------------------

-- أ) إجمالي عدد الطلبات (Total Orders)
SELECT COUNT(*) AS total_orders 
FROM fact_swiggy_orders;
GO

-- ب) إجمالي الإيرادات بالمليون (Total Revenue in Million INR)
SELECT 
    FORMAT(CONVERT(FLOAT, SUM(price)) / 1000000.0, 'N2') + ' INR Million' AS total_revenue
FROM fact_swiggy_orders;
GO

-- ج) متوسط سعر الطبق (Average Dish Price)
SELECT 
    FORMAT(AVG(price), 'N2') + ' INR' AS average_dish_price
FROM fact_swiggy_orders;
GO

-- د) متوسط التقييمات (Average Ratings)
SELECT 
    AVG(rating) AS average_rating
FROM fact_swiggy_orders;
GO


-- ---------------------------------------------------------------------------------
-- القسم 7: التحليلات الزمنية للطلبات (Date-Based Deep Dive Analysis)
-- ---------------------------------------------------------------------------------

-- أ) اتجاهات الطلبات الشهرية (Monthly Order Trends) مع الإيرادات
SELECT 
    d.year,
    d.month,
    d.month_name,
    COUNT(*) AS total_orders,
    SUM(f.price) AS total_revenue
FROM fact_swiggy_orders f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.year, d.month, d.month_name
ORDER BY total_orders DESC;
GO

-- ب) اتجاهات الطلبات الربع سنوية (Quarterly Order Trends)
SELECT 
    d.quarter,
    COUNT(*) AS total_orders
FROM fact_swiggy_orders f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.quarter
ORDER BY total_orders DESC;
GO

-- ج) اتجاهات النمو السنوية (Yearly Trends)
SELECT 
    d.year,
    COUNT(*) AS total_orders
FROM fact_swiggy_orders f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.year;
GO

-- د) أنماط الطلبات حسب أيام الأسبوع (Day of Week Patterns)
SELECT 
    DATENAME(WEEKDAY, d.full_date) AS day_of_week,
    COUNT(*) AS total_orders
FROM fact_swiggy_orders f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY DATENAME(WEEKDAY, d.full_date), DATEPART(WEEKDAY, d.full_date)
ORDER BY DATEPART(WEEKDAY, d.full_date);
GO


-- ---------------------------------------------------------------------------------
-- القسم 8: التحليل الجغرافي (Location-Based Analysis)
-- ---------------------------------------------------------------------------------

-- أ) أفضل 10 مدن من حيث حجم الطلبات (Top 10 Cities by Order Volume)
SELECT TOP 10
    l.city,
    COUNT(*) AS total_orders
FROM fact_swiggy_orders f
JOIN dim_location l ON f.location_id = l.location_id
GROUP BY l.city
ORDER BY total_orders DESC;
GO

-- ب) أقل 10 مدن طلباً (Bottom 10 Cities by Order Volume)
SELECT TOP 10
    l.city,
    COUNT(*) AS total_orders
FROM fact_swiggy_orders f
JOIN dim_location l ON f.location_id = l.location_id
GROUP BY l.city
ORDER BY total_orders ASC;
GO

-- ج) مساهمة الإيرادات حسب الولايات المختلفة (Revenue Contribution by State)
SELECT 
    l.state,
    SUM(f.price) AS total_revenue
FROM fact_swiggy_orders f
JOIN dim_location l ON f.location_id = l.location_id
GROUP BY l.state
ORDER BY total_revenue DESC;
GO


-- ---------------------------------------------------------------------------------
-- القسم 9: أداء الأطعمة والمطاعم (Food & Restaurant Performance Analysis)
-- ---------------------------------------------------------------------------------

-- أ) أفضل 10 مطاعم حسب حجم الطلبات (Top 10 Restaurants by Orders)
SELECT TOP 10
    r.restaurant_name,
    COUNT(*) AS total_orders
FROM fact_swiggy_orders f
JOIN dim_restaurant r ON f.restaurant_id = r.restaurant_id
GROUP BY r.restaurant_name
ORDER BY total_orders DESC;
GO

-- ب) أفضل تصنيفات الطعام مبيعاً (Top Food Categories)
SELECT 
    c.category,
    COUNT(*) AS total_orders
FROM fact_swiggy_orders f
JOIN dim_category c ON f.category_id = c.category_id
GROUP BY c.category
ORDER BY total_orders DESC;
GO

-- ج) الأطباق الأكثر طلباً (Top 10 Most Ordered Dishes)
SELECT TOP 10
    ds.dish_name,
    COUNT(*) AS total_orders
FROM fact_swiggy_orders f
JOIN dim_dish ds ON f.dish_id = ds.dish_id
GROUP BY ds.dish_name
ORDER BY total_orders DESC;
GO

-- د) تحليل أداء تقييمات التصنيفات المختلفة (Cuisine Performance)
SELECT 
    c.category,
    COUNT(*) AS total_orders,
    AVG(f.rating) AS average_rating
FROM fact_swiggy_orders f
JOIN dim_category c ON f.category_id = c.category_id
GROUP BY c.category
ORDER BY total_orders DESC;
GO


-- ---------------------------------------------------------------------------------
-- القسم 10: سلوكيات الإنفاق والتقييمات للعملاء (Customer Spending & Ratings Insights)
-- ---------------------------------------------------------------------------------

-- أ) تقسيم مستويات إنفاق العملاء (Customer Spend Buckets)
SELECT 
    CASE 
        WHEN price < 100 THEN 'أقل من 100 روبية'
        WHEN price BETWEEN 100 AND 199 THEN 'من 100 إلى 199 روبية'
        WHEN price BETWEEN 200 AND 299 THEN 'من 200 إلى 299 روبية'
        WHEN price BETWEEN 300 AND 499 THEN 'من 300 إلى 499 روبية'
        ELSE '500 روبية فأكثر'
    END AS price_range,
    COUNT(*) AS total_orders
FROM fact_swiggy_orders
GROUP BY 
    CASE 
        WHEN price < 100 THEN 'أقل من 100 روبية'
        WHEN price BETWEEN 100 AND 199 THEN 'من 100 إلى 199 روبية'
        WHEN price BETWEEN 200 AND 299 THEN 'من 200 إلى 299 روبية'
        WHEN price BETWEEN 300 AND 499 THEN 'من 300 إلى 499 روبية'
        ELSE '500 روبية فأكثر'
    END
ORDER BY total_orders DESC;
GO

-- ب) تحليل توزيع التقييمات على الطلبات (Ratings Distribution Analysis)
SELECT 
    rating,
    COUNT(*) AS rating_count
FROM fact_swiggy_orders
GROUP BY rating
ORDER BY rating DESC;
GO
