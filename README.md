# Sales Reporting Pipeline
## Findings
Manchester is the strongest region, leading on both orders (166) and revenue. Leeds is the weakest earner. Its customers pay almost exactly the same prices as Manchester's (£49.03 vs £49.23 per item) but buy 2.2 fewer items per order on average. Discounting doesn't explain this, because Leeds has the lowest average discount of any region.

Across the business, orders with no discount have the highest average value, so discounts don't appear to grow order size. It would be worth testing smaller or fewer discounts to see whether revenue holds up.

Recommendation: to raise order size in Leeds, offer free delivery above a minimum order value, or bundle deals that reward buying more items.

A complete, working reporting pipeline: a messy CSV in, a formatted Excel
workbook out, with a SQL database in the middle.

This is portfolio project 1 from the roadmap. It is deliberately the same
shape as paid work: clean the client's data, load it into a database,
answer twelve business questions in SQL, hand back a report.

## Requirements

```bash
pip install pandas openpyxl
```

SQLite ships with Python. There is no database server to install.

## Running it

```bash
python setup_database.py     # CSV  ->  data/sales.db
python run_reports.py        # db   ->  reports/sales_report.xlsx
```

The first command prints how many rows were loaded. The second prints each
report name with its row count, then writes the workbook.

## What is in here

| Path | What it is |
|---|---|
| `data/raw_sales_export.csv` | The client's messy export, exactly as received |
| `setup_database.py` | Cleaning and loading logic |
| `sql/reports.sql` | All twelve report queries, levelled 1 to 4 |
| `run_reports.py` | Runs each query and writes the workbook |
| `reports/` | Output |

## The mess deliberately in the raw file

Real exports are not clean, and the cleaning code is the part clients pay
for. This file contains:

- **Two date formats** mixed together (`2026-03-14` and `14/3/2026`)
- **14 exact duplicate rows**
- **Whitespace around customer names**, so `"  Ardent Retail Ltd "` and
  `"Ardent Retail Ltd"` would group separately without `.strip()`
- **Blank regions**, filled with `"Unknown` rather than dropped
- **A non-numeric quantity** (`"three"`) that has to be rejected, not guessed
- **A row with no date** at all

Try removing one cleaning step at a time and watch what happens to the
report totals. That is the fastest way to understand why each line is there.

## What to change to make it yours

1. Swap in a real dataset — a UK government open dataset, or your own
   exported data — and keep the same pipeline shape.
2. Add a query of your own to `sql/reports.sql`. It is picked up
   automatically, as long as it starts with a `-- name:` line.
3. Add a chart to the workbook with pandas and openpyxl.
4. Schedule it: cron on Linux or macOS, Task Scheduler on Windows.

## The SQL, by level

**Level 1 — grouping and aggregation.** `GROUP BY`, `COUNT`, `SUM`,
`AVG`, `LIMIT`, and `strftime` for dates.

**Level 2 — filtering and shape.** `HAVING` versus `WHERE`, subqueries,
`CASE WHEN` bucketing.

**Level 3 — window functions.** Running totals with `SUM() OVER`,
`LAG` for month-on-month growth, `ROW_NUMBER()` partitioned to rank
within a category.

**Level 4 — CTEs and cohort analysis.** `WITH` clauses, self-joins
through a customer timeline, and the retention cohort report that clients
actually ask for.

Work through them in order. Every query is commented with what it teaches.
