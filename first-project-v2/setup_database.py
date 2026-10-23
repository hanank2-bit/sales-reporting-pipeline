"""
Step 1 - Build the database.

Reads data/raw_sales_export.csv, cleans it, and loads it into a SQLite
database at data/sales.db. SQLite is a single file, so there is nothing
to install and nothing to configure.

Run:  python setup_database.py
"""

import csv
import sqlite3
from datetime import datetime
from pathlib import Path

BASE = Path(__file__).parent
RAW_CSV = BASE / "data" / "raw_sales_export.csv"
DB_PATH = BASE / "data" / "sales.db"


def parse_date(value):
    """Handle the two date formats the export produces. Return ISO or None."""
    value = value.strip()
    if not value:
        return None
    for fmt in ("%Y-%m-%d", "%d/%m/%Y"):
        try:
            return datetime.strptime(value, fmt).date().isoformat()
        except ValueError:
            continue
    return None


def to_int(value):
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def to_float(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def load_rows():
    """Read the CSV and yield cleaned rows, skipping anything unusable."""
    seen = set()
    with RAW_CSV.open(newline="", encoding="utf-8-sig") as handle:
        for row in csv.DictReader(handle):
            order_date = parse_date(row["order_date"])
            quantity = to_int(row["quantity"])
            unit_price = to_float(row["unit_price"])
            discount_pct = to_float(row["discount_pct"]) or 0.0
            customer = row["customer"].strip()

            # Reject rows we cannot report on, rather than guessing.
            if not order_date or quantity is None or unit_price is None:
                continue
            if not customer:
                continue

            # Exact-duplicate removal, on the fields that identify an order line.
            fingerprint = (order_date, customer, row["sku"], quantity, unit_price)
            if fingerprint in seen:
                continue
            seen.add(fingerprint)

            line_total = round(quantity * unit_price * (1 - discount_pct / 100), 2)

            yield (
                order_date,
                customer,
                row["region"].strip() or "Unknown",
                row["channel"].strip(),
                row["category"].strip(),
                row["sku"].strip(),
                row["product_name"].strip(),
                quantity,
                unit_price,
                discount_pct,
                line_total,
            )


SCHEMA = """
DROP TABLE IF EXISTS sales;

CREATE TABLE sales (
    order_id     INTEGER PRIMARY KEY AUTOINCREMENT,
    order_date   TEXT    NOT NULL,
    customer     TEXT    NOT NULL,
    region       TEXT    NOT NULL,
    channel      TEXT    NOT NULL,
    category     TEXT    NOT NULL,
    sku          TEXT    NOT NULL,
    product_name TEXT    NOT NULL,
    quantity     INTEGER NOT NULL,
    unit_price   REAL    NOT NULL,
    discount_pct REAL    NOT NULL DEFAULT 0,
    line_total   REAL    NOT NULL
);

CREATE INDEX idx_sales_date     ON sales(order_date);
CREATE INDEX idx_sales_customer ON sales(customer);
CREATE INDEX idx_sales_category ON sales(category);
"""


def main():
    rows = list(load_rows())

    connection = sqlite3.connect(DB_PATH)
    connection.executescript(SCHEMA)
    connection.executemany(
        """
        INSERT INTO sales (
            order_date, customer, region, channel, category,
            sku, product_name, quantity, unit_price, discount_pct, line_total
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        rows,
    )
    connection.commit()

    count = connection.execute("SELECT COUNT(*) FROM sales").fetchone()[0]
    revenue = connection.execute("SELECT ROUND(SUM(line_total), 2) FROM sales").fetchone()[0]
    connection.close()

    print(f"Database written to {DB_PATH}")
    print(f"Rows loaded:       {count}")
    print(f"Total line revenue: {revenue}")


if __name__ == "__main__":
    main()
