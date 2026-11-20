#!/usr/bin/env python3
"""Формирование иллюстраций отчёта из реальных выводов psql."""
import subprocess
import textwrap
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SHOTS = ROOT / "docs" / "screenshots"
RESULTS = ROOT / "results"
SHOTS.mkdir(parents=True, exist_ok=True)
RESULTS.mkdir(exist_ok=True)

MONO = "/System/Library/Fonts/Menlo.ttc"
LABEL = "/System/Library/Fonts/Supplemental/Arial.ttf"
PSQL = ["psql", "-X", "-v", "ON_ERROR_STOP=1", "-d", "oildepotdb"]

PSET_NOISE = ("Постраничник выключен.", "Стиль границ: 2.", "Null выводится как: \"(null)\".")


def clean_query(text: str) -> str:
    lines = [ln for ln in text.splitlines() if ln not in PSET_NOISE]
    while lines and not lines[0].strip():
        lines.pop(0)
    return "\n".join(lines)


def run_sql(sql: str, name: str, title: str, echo: bool = False) -> str:
    proc = subprocess.run(PSQL + ["-c", sql], capture_output=True, text=True)
    out = (proc.stdout or "") + (proc.stderr or "")
    if echo:
        out = "=> " + sql.strip().rstrip(";") + ";\n" + out
    (RESULTS / f"{name}.txt").write_text(out, encoding="utf-8")
    render(out, name, title)
    return out


def run_file(path: Path, name: str, title: str) -> str:
    proc = subprocess.run(PSQL + ["-f", str(path)], capture_output=True, text=True)
    out = (proc.stdout or "") + (proc.stderr or "")
    (RESULTS / f"{name}.txt").write_text(out, encoding="utf-8")
    render(out, name, title)
    return out


def render(text: str, name: str, title: str) -> Path:
    lines = text.rstrip("\n").split("\n") or [""]
    if not lines:
        lines = [""]
    max_len = max(len(ln) for ln in lines)
    size = 14 if max_len <= 118 else 13 if max_len <= 145 else 12
    fnt = ImageFont.truetype(MONO, size, index=0)
    lf = ImageFont.truetype(LABEL, 15)
    char_w = fnt.getlength("M")
    width = max(900, int(max_len * char_w) + 60)
    line_h = size + 8
    title_h = 44
    height = title_h + 24 + len(lines) * line_h + 18
    img = Image.new("RGB", (width, height), "#F8FAFC")
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, width, title_h], fill="#1F2937")
    d.text((18, 12), title, font=lf, fill="#F8FAFC")
    d.rectangle([10, title_h + 8, width - 10, height - 10], fill="#FFFFFF", outline="#CBD5E1", width=1)
    y = title_h + 20
    for ln in lines:
        color = "#111827"
        if "ERROR:" in ln:
            color = "#B91C1C"
        elif "NOTICE:" in ln or "ACCEPTANCE" in ln:
            color = "#166534"
        elif ln.startswith("Q") and "—" in ln:
            color = "#1D4ED8"
        d.text((28, y), ln, font=fnt, fill=color)
        y += line_h
    path = SHOTS / f"{name}.png"
    img.save(path, "PNG", optimize=True)
    print(path, img.size)
    return path


def query_figures():
    for i in range(1, 24):
        src = RESULTS / f"q{i:02d}.txt"
        text = clean_query(src.read_text(encoding="utf-8"))
        render(text, f"fig_q{i:02d}", f"psql -d oildepotdb -f sql/queries/q{i:02d}.sql")


def main():
    query_figures()
    run_sql(
        "SELECT datname AS database, pg_encoding_to_char(encoding) AS encoding, "
        "datcollate AS collation FROM pg_database WHERE datname = 'oildepotdb';",
        "fig_03_db_create", "psql -d postgres -c \"SELECT ... FROM pg_database ...\"")
    run_sql("\\dt", "fig_04_dt", "psql -d oildepotdb -c \"\\dt\"")
    run_sql("\\d products", "fig_05_describe_products", "psql -d oildepotdb -c \"\\d products\"")
    run_sql("\\di", "fig_06_indexes", "psql -d oildepotdb -c \"\\di\"")
    run_sql(
        "EXPLAIN (ANALYZE, BUFFERS) SELECT d.delivery_number, d.delivery_date, d.invoice_number, "
        "d.status, d.total_amount FROM deliveries d JOIN suppliers s ON s.id_supplier = d.id_supplier "
        "WHERE s.name = 'ООО «Нефтеснаб»' AND d.delivery_date BETWEEN DATE '2025-09-01' "
        "AND DATE '2025-12-31' ORDER BY d.delivery_date, d.delivery_number;",
        "fig_07_explain", "psql -d oildepotdb -c \"EXPLAIN (ANALYZE, BUFFERS) …\"")
    run_sql(
        "SELECT 'products' AS table_name, COUNT(*) AS row_count FROM products UNION ALL "
        "SELECT 'tanks', COUNT(*) FROM tanks UNION ALL SELECT 'suppliers', COUNT(*) FROM suppliers UNION ALL "
        "SELECT 'clients', COUNT(*) FROM clients UNION ALL SELECT 'price_history', COUNT(*) FROM price_history UNION ALL "
        "SELECT 'deliveries', COUNT(*) FROM deliveries UNION ALL SELECT 'delivery_items', COUNT(*) FROM delivery_items UNION ALL "
        "SELECT 'shipments', COUNT(*) FROM shipments UNION ALL SELECT 'shipment_items', COUNT(*) FROM shipment_items UNION ALL "
        "SELECT 'stock_movements', COUNT(*) FROM stock_movements UNION ALL SELECT 'tank_measurements', COUNT(*) FROM tank_measurements UNION ALL "
        "SELECT 'reserve_forecasts', COUNT(*) FROM reserve_forecasts ORDER BY table_name;",
        "fig_08_counts", "psql -d oildepotdb -c \"SELECT … COUNT(*) …\"")
    run_sql("SELECT * FROM mv_product_stock ORDER BY product_code;",
            "fig_mv_product_stock", "psql -d oildepotdb -c \"SELECT * FROM mv_product_stock …\"")
    run_sql("SELECT month, product_code, shipments_count, volume, revenue, avg_price "
            "FROM mv_monthly_sales ORDER BY month, product_code LIMIT 15;",
            "fig_mv_monthly_sales", "psql -d oildepotdb -c \"SELECT … FROM mv_monthly_sales …\"")
    refresh = RESULTS / "fig_refresh_mv.sql"
    refresh.write_text(
        "\\echo 'REFRESH MATERIALIZED VIEW CONCURRENTLY mv_product_stock;'\n"
        "REFRESH MATERIALIZED VIEW CONCURRENTLY mv_product_stock;\n"
        "\\echo 'REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_sales;'\n"
        "REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_sales;\n"
        "SELECT 'mv_product_stock' AS matview, COUNT(*) AS rows FROM mv_product_stock\n"
        "UNION ALL SELECT 'mv_monthly_sales', COUNT(*) FROM mv_monthly_sales;\n",
        encoding="utf-8")
    run_file(refresh, "fig_refresh_mv", "psql -d oildepotdb -f results/fig_refresh_mv.sql")
    run_sql("SELECT * FROM fn_product_forecast(1, 30, DATE '2026-06-30');",
            "fig_fn_forecast", "psql -d oildepotdb -c \"SELECT * FROM fn_product_forecast(1, 30, DATE '2026-06-30')\"")
    run_sql("CALL sp_build_forecasts(DATE '2026-06-30', 30); "
            "SELECT COUNT(*) AS forecasts, MIN(predicted_reserve) AS min_reserve, MAX(predicted_reserve) AS max_reserve "
            "FROM reserve_forecasts WHERE forecast_date = DATE '2026-06-30';",
            "fig_proc_forecasts", "psql -d oildepotdb -c \"CALL sp_build_forecasts(…); SELECT …\"")
    trigger = RESULTS / "fig_trigger_ok.sql"
    trigger.write_text(textwrap.dedent("""
        BEGIN;
        SELECT current_volume AS before_volume FROM tanks WHERE id_tank = 1;
        INSERT INTO deliveries (id_supplier, delivery_number, delivery_date, invoice_number, status)
        VALUES (1, 'TEST-TRG-001', DATE '2026-06-01', 'INV-TRG-001', 'оформлена')
        RETURNING id_delivery
        \\gset
        INSERT INTO delivery_items (id_delivery, id_product, id_tank, line_no, volume, price_per_liter)
        VALUES (:id_delivery, 1, 1, 1, 1000, 55.00);
        SELECT current_volume AS after_volume FROM tanks WHERE id_tank = 1;
        SELECT d.total_amount,
               (SELECT SUM(total_cost) FROM delivery_items WHERE id_delivery = :id_delivery) AS items_sum
        FROM deliveries d WHERE d.id_delivery = :id_delivery;
        SELECT movement_type, volume, id_delivery_item IS NOT NULL AS linked_to_item
        FROM stock_movements
        WHERE id_delivery_item = (SELECT id_delivery_item FROM delivery_items WHERE id_delivery = :id_delivery);
        ROLLBACK;
    """).lstrip(), encoding="utf-8")
    run_file(trigger, "fig_trigger_ok", "psql -d oildepotdb -f results/fig_trigger_ok.sql")
    run_sql("\\d deliveries", "fig_constraints", "psql -d oildepotdb -c \"\\d deliveries\"")
    run_sql(
        "SELECT 0.1::double precision + 0.2::double precision AS float_sum, "
        "0.1::numeric + 0.2::numeric AS numeric_sum, "
        "(0.1::double precision + 0.2::double precision) = 0.3::double precision AS float_equal, "
        "(0.1::numeric + 0.2::numeric) = 0.3::numeric AS numeric_equal; "
        "SELECT ROUND(SUM(total_cost), 2) AS shipment_items_total, "
        "ROUND(SUM(volume * price_per_liter), 2) AS recalculated, "
        "ROUND(SUM(total_cost), 2) = ROUND(SUM(volume * price_per_liter), 2) AS totals_match "
        "FROM shipment_items;",
        "fig_numeric", "psql -d oildepotdb -c \"SELECT … numeric / double precision …\"")
    # Фрагменты реальных выводов негативных тестов
    tests = (RESULTS / "tests.txt").read_text(encoding="utf-8")
    lines = tests.splitlines()
    blocks = {}
    cur = None
    for ln in lines:
        if ln.startswith("N") and "—" in ln:
            cur = ln.split("—")[0].strip()
            blocks[cur] = []
        if cur:
            blocks[cur].append(ln)
    render("\n".join(blocks.get("N01", [])), "fig_trigger_err",
           "psql -d oildepotdb -f sql/08_tests.sql  (фрагмент N01)")
    render("\n".join(blocks.get("N08", [])), "fig_negative_fk",
           "psql -d oildepotdb -f sql/08_tests.sql  (фрагмент N08)")
    acc = (RESULTS / "acceptance.txt").read_text(encoding="utf-8")
    acc_lines = acc.splitlines()
    keep = []
    for ln in acc_lines:
        s = ln.strip()
        if ln in PSET_NOISE or s in {"SET", "DO", "Постраничник выключен.", "Стиль границ: 2."}:
            continue
        if s.startswith("Null выводится как:"):
            continue
        keep.append(ln)
        if s == "(12 строк)":
            break
    render("\n".join(keep), "fig_acceptance", "psql -d oildepotdb -f sql/99_acceptance.sql")


if __name__ == "__main__":
    main()
