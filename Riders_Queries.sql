-- Investigate tables to make sure our data is clean. Check to make sure the number of stations is
-- consistent between our two desired dates
SELECT YEAR(date) as 'Year', COUNT(DISTINCT(date)) as 'No. Days'
FROM dbo.Train_Riders
GROUP BY YEAR(date)

SELECT MAX(date)
FROM dbo.Train_Riders

-- Check dataset end date
SELECT *
FROM dbo.Train_Riders
WHERE date = CONVERT(datetime, '2023-03-31')

-- Check desired start date
SELECT *
FROM dbo.Train_Riders
WHERE date = CONVERT(datetime, '2018-03-01')

-- Left Join the two date queries together to find null rows
SELECT p1.station_id, p1.stationname, p1.rides, p2.station_id, p2.stationname, p2.rides
FROM
(
	SELECT *
	FROM dbo.Train_Riders
	WHERE date = CONVERT(datetime, '2018-03-01')
) p1
LEFT JOIN
(
	SELECT *
	FROM dbo.Train_Riders
	WHERE date = CONVERT(datetime, '2023-03-31')
) p2
ON p1.station_id = p2.station_id

-- Check the Lines Info table
SELECT *
FROM dbo.Lines

-- Grab a subsection of the total riders data to fit our dates, delete un-needed rows and
-- add supplementary columns
DROP TABLE IF EXISTS #Clean_Riders
CREATE TABLE #Clean_Riders
(
	station_id int,
	station_name varchar(50),
	date datetime,
	date_year int,
	date_month int,
	date_day int,
	date_day_name varchar(50),
	day_type varchar(50),
	rides int
)

INSERT INTO #Clean_Riders
SELECT station_id, stationname, date, YEAR(date), MONTH(date), DAY(date), DATENAME(WEEKDAY, date), daytype, rides
FROM dbo.Train_Riders
WHERE date >= CONVERT(datetime, '2018-03-01')
AND station_id NOT IN (40200, 40340, 40770)

SELECT *
FROM #Clean_Riders

-- Join our Clean Riders table with System Information to make a full dataset
-- Use Cross Apply to split the lines column into their individual lines, and divide rides by the amount of lines in a stop
-- so duplicate lines aren't added to the data
DROP TABLE IF EXISTS #Full_Lines
SELECT cr.*, lines.*, ltrim(rtrim(f.value)) as 'split_lines',
	rides / (len(lines.lines) - len(replace(lines.lines, ',', '')) +1) as 'updated_rides'
INTO #Full_Lines
FROM #Clean_Riders as cr
LEFT JOIN dbo.Lines as lines
ON cr.station_id = lines.map_id
CROSS APPLY STRING_SPLIT(lines.lines, ',') as f

SELECT *
FROM #Full_Lines

-- Create a CTE with all of our previous queries to make one script that does everything we want
;WITH clean_riders as (
	SELECT station_id, stationname as 'station_name', date, YEAR(date) as 'date_year', MONTH(date) as 'date_month',
		DAY(date) as 'date_day', DATENAME(WEEKDAY, date) as 'date_day_name', daytype as 'day_type', rides
	FROM dbo.Train_Riders
	WHERE date >= CONVERT(datetime, '2018-03-01')
	AND station_id NOT IN (40200, 40340, 40770)
),

full_lines as (
	SELECT *
	FROM #Clean_Riders as cr
	LEFT JOIN dbo.Lines as lines
	ON cr.station_id = lines.map_id
),

adjusted_lines as (
	SELECT fl.*, ltrim(rtrim(f.value)) as 'split_lines', rides / (len(fl.lines) - len(replace(fl.lines, ',', '')) +1) as 'updated_rides'
	FROM full_lines AS fl
	CROSS APPLY STRING_SPLIT(fl.lines, ',') as f
)

SELECT *
FROM adjusted_lines


-- Below are queries that correspond to the visualizations in the Tableau dashboard

-- Yearly riders per line
SELECT date_year, split_lines, SUM(updated_rides) as 'Total Rides'
FROM #Full_Lines
GROUP BY date_year, split_lines
ORDER BY date_year ASC

-- Monthly riders per year per line
SELECT date_year, date_month, split_lines, SUM(updated_rides) as 'Total Rides'
FROM #Full_Lines
GROUP BY date_year, date_month, split_lines
ORDER BY date_year, date_month

-- Yearly riders vs loop stops
SELECT date_year, loop, SUM(updated_rides) as 'Total Rides'
FROM #Full_Lines
GROUP BY date_year, loop
ORDER BY date_year

-- Monthly riders per year vs loop stops
SELECT date_year, date_month, loop, SUM(updated_rides) as 'Total Rides'
FROM #Full_Lines
GROUP BY date_year, date_month, loop
ORDER BY date_year, date_month

-- Yearly riders per day type
SELECT date_year, day_type, SUM(updated_rides) as 'Total Rides'
FROM #Full_Lines
GROUP BY date_year, day_type
ORDER BY date_year

-- Monthly riders per year per day type
SELECT date_year, date_month, day_type, SUM(updated_rides) as 'Total Rides'
FROM #Full_Lines
GROUP BY date_year, date_month, day_type
ORDER BY date_year, date_month