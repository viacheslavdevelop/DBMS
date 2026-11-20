#!/usr/bin/env python3
"""Генерация диаграмм IDEF1X и физической ERD (PNG + draw.io)."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from xml.sax.saxutils import escape

OUT = Path(__file__).resolve().parent / "diagrams"
OUT.mkdir(parents=True, exist_ok=True)

FONT_REG = "/System/Library/Fonts/Menlo.ttc"
FONT_BOLD = "/System/Library/Fonts/Menlo.ttc"
FONT_LABEL = "/System/Library/Fonts/Supplemental/Arial.ttf"

IDEF_W = 400
IDEF_XS = [40, 600, 1160]
IDEF_YS = [120, 430, 740, 1050]
IDEF_HEADER = 46
IDEF_ROW = 34

IDEF_ENTITIES = [
    ("suppliers", "SUPPLIERS", IDEF_XS[0], IDEF_YS[0], [
        ("PK", "id_supplier"), ("", "inn"), ("", "name")]),
    ("deliveries", "DELIVERIES", IDEF_XS[0], IDEF_YS[1], [
        ("PK", "id_delivery"), ("FK", "id_supplier"), ("", "delivery_date")]),
    ("delivery_items", "DELIVERY_ITEMS", IDEF_XS[0], IDEF_YS[2], [
        ("PK", "id_delivery_item"), ("FK", "id_delivery"), ("FK", "id_product")]),
    ("stock_movements", "STOCK_MOVEMENTS", IDEF_XS[0], IDEF_YS[3], [
        ("PK", "id_movement"), ("FK", "id_product"), ("", "volume")]),
    ("products", "PRODUCTS", IDEF_XS[1], IDEF_YS[0], [
        ("PK", "id_product"), ("", "product_code"), ("", "category")]),
    ("tanks", "TANKS", IDEF_XS[1], IDEF_YS[1], [
        ("PK", "id_tank"), ("FK", "id_product"), ("", "capacity")]),
    ("price_history", "PRICE_HISTORY", IDEF_XS[1], IDEF_YS[2], [
        ("PK", "id_price"), ("FK", "id_product"), ("", "retail_price")]),
    ("reserve_forecasts", "RESERVE_FORECASTS", IDEF_XS[1], IDEF_YS[3], [
        ("PK", "id_forecast"), ("FK", "id_product"), ("", "predicted_reserve")]),
    ("clients", "CLIENTS", IDEF_XS[2], IDEF_YS[0], [
        ("PK", "id_client"), ("", "name"), ("", "client_type")]),
    ("shipments", "SHIPMENTS", IDEF_XS[2], IDEF_YS[1], [
        ("PK", "id_shipment"), ("FK", "id_client"), ("", "shipment_date")]),
    ("shipment_items", "SHIPMENT_ITEMS", IDEF_XS[2], IDEF_YS[2], [
        ("PK", "id_shipment_item"), ("FK", "id_shipment"), ("FK", "id_product")]),
    ("tank_measurements", "TANK_MEASUREMENTS", IDEF_XS[2], IDEF_YS[3], [
        ("PK", "id_measurement"), ("FK", "id_tank"), ("", "volume")]),
]

IDEF_EDGES = [
    ("suppliers", "deliveries", [(240, 276), (240, 430)]),
    ("deliveries", "delivery_items", [(240, 586), (240, 740)]),
    ("delivery_items", "stock_movements", [(240, 896), (240, 1050)]),
    ("products", "tanks", [(800, 276), (800, 430)]),
    ("clients", "shipments", [(1360, 276), (1360, 430)]),
    ("shipments", "shipment_items", [(1360, 586), (1360, 740)]),
    ("products", "price_history", [(600, 200), (540, 200), (540, 800), (600, 800)]),
    ("products", "reserve_forecasts", [(1000, 200), (1080, 200), (1080, 1100), (1000, 1100)]),
    ("products", "delivery_items", [(600, 230), (560, 230), (560, 830), (440, 830)]),
    ("tanks", "delivery_items", [(600, 500), (520, 500), (520, 860), (440, 860)]),
    ("products", "shipment_items", [(1000, 230), (1100, 230), (1100, 800), (1160, 800)]),
    ("tanks", "shipment_items", [(1000, 520), (1120, 520), (1120, 830), (1160, 830)]),
    ("products", "stock_movements", [(600, 250), (480, 250), (480, 1150), (440, 1150)]),
    ("tanks", "stock_movements", [(600, 540), (500, 540), (500, 1180), (440, 1180)]),
    ("shipment_items", "stock_movements", [(1360, 896), (1400, 896), (1400, 1260), (160, 1260), (160, 1206)]),
    ("tanks", "tank_measurements", [(1000, 560), (1140, 560), (1140, 1120), (1160, 1120)]),
]

PHYS_W = 540
PHYS_XS = [40, 630, 1220]
PHYS_YS = [100, 500, 900, 1300]
PHYS_HEADER = 46
PHYS_ROW = 36

PHYS_ENTITIES = [
    ("products", "products", PHYS_XS[0], PHYS_YS[0], [
        ("PK", "id_product", "SERIAL"), ("", "product_code", "VARCHAR(10)"),
        ("", "density", "NUMERIC(6,2)")]),
    ("tanks", "tanks", PHYS_XS[0], PHYS_YS[1], [
        ("PK", "id_tank", "SERIAL"), ("FK", "id_product", "INTEGER"),
        ("", "capacity", "NUMERIC(12,3)")]),
    ("price_history", "price_history", PHYS_XS[0], PHYS_YS[2], [
        ("PK", "id_price", "BIGSERIAL"), ("FK", "id_product", "INTEGER"),
        ("", "retail_price", "NUMERIC(10,2)")]),
    ("stock_movements", "stock_movements", PHYS_XS[0], PHYS_YS[3], [
        ("PK", "id_movement", "BIGSERIAL"), ("FK", "id_product", "INTEGER"),
        ("", "volume", "NUMERIC(12,3)")]),
    ("suppliers", "suppliers", PHYS_XS[1], PHYS_YS[0], [
        ("PK", "id_supplier", "SERIAL"), ("", "inn", "VARCHAR(12)"),
        ("", "name", "VARCHAR(100)")]),
    ("deliveries", "deliveries", PHYS_XS[1], PHYS_YS[1], [
        ("PK", "id_delivery", "SERIAL"), ("FK", "id_supplier", "INTEGER"),
        ("", "delivery_date", "DATE")]),
    ("delivery_items", "delivery_items", PHYS_XS[1], PHYS_YS[2], [
        ("PK", "id_delivery_item", "BIGSERIAL"), ("FK", "id_delivery", "INTEGER"),
        ("", "volume", "NUMERIC(12,3)")]),
    ("reserve_forecasts", "reserve_forecasts", PHYS_XS[1], PHYS_YS[3], [
        ("PK", "id_forecast", "BIGSERIAL"), ("FK", "id_product", "INTEGER"),
        ("", "predicted_reserve", "NUMERIC(12,3)")]),
    ("clients", "clients", PHYS_XS[2], PHYS_YS[0], [
        ("PK", "id_client", "SERIAL"), ("", "name", "VARCHAR(100)"),
        ("", "client_type", "VARCHAR(20)")]),
    ("shipments", "shipments", PHYS_XS[2], PHYS_YS[1], [
        ("PK", "id_shipment", "SERIAL"), ("FK", "id_client", "INTEGER"),
        ("", "shipment_date", "DATE")]),
    ("shipment_items", "shipment_items", PHYS_XS[2], PHYS_YS[2], [
        ("PK", "id_shipment_item", "BIGSERIAL"), ("FK", "id_shipment", "INTEGER"),
        ("", "volume", "NUMERIC(12,3)")]),
    ("tank_measurements", "tank_measurements", PHYS_XS[2], PHYS_YS[3], [
        ("PK", "id_measurement", "BIGSERIAL"), ("FK", "id_tank", "INTEGER"),
        ("", "volume", "NUMERIC(12,3)")]),
]

PHYS_EDGES = [
    ("suppliers", "deliveries", [(900, 262), (900, 500)]),
    ("deliveries", "delivery_items", [(900, 662), (900, 900)]),
    ("clients", "shipments", [(1490, 262), (1490, 500)]),
    ("shipments", "shipment_items", [(1490, 662), (1490, 850), (1490, 900)]),
    ("products", "tanks", [(310, 262), (310, 500)]),
    ("products", "price_history", [(40, 180), (20, 180), (20, 1000), (40, 1000)]),
    ("tanks", "delivery_items", [(630, 560), (610, 560), (610, 980), (630, 980)]),
    ("tanks", "shipment_items", [(1170, 560), (1200, 560), (1200, 940), (1220, 940)]),
    ("products", "shipment_items", [(580, 210), (610, 210), (610, 860), (1200, 860), (1200, 900)]),
    ("products", "reserve_forecasts", [(580, 240), (600, 240), (600, 1380), (630, 1380)]),
    ("tanks", "tank_measurements", [(1170, 600), (1220, 600), (1220, 1380), (1220, 1380)]),
    ("delivery_items", "stock_movements", [(630, 1040), (610, 1040), (610, 1440), (580, 1440)]),
    ("shipment_items", "stock_movements", [(1220, 1040), (1700, 1040), (1700, 1510), (310, 1510), (310, 1462)]),
]

def font(path, size):
    return ImageFont.truetype(path, size, index=0)

def draw_dashed_line(draw, p1, p2, fill, width=2, dash=12):
    import math
    x1, y1 = p1; x2, y2 = p2
    dist = math.hypot(x2 - x1, y2 - y1)
    if dist == 0:
        return
    dx = (x2 - x1) / dist; dy = (y2 - y1) / dist
    pos = 0
    while pos < dist:
        end = min(pos + dash, dist)
        draw.line([(x1 + dx * pos, y1 + dy * pos), (x1 + dx * end, y1 + dy * end)],
                  fill=fill, width=width)
        pos = end + dash

def draw_path(draw, points, fill, width=2, dash=12):
    for a, b in zip(points, points[1:]):
        draw_dashed_line(draw, a, b, fill, width, dash)

def draw_label(draw, xy, text, fnt, fill="#1F3864", bg="#FFFFFF"):
    l, t, r, b = draw.textbbox((0, 0), text, font=fnt)
    w, h = r - l, b - t
    x, y = xy
    draw.rounded_rectangle([x - 4, y - 2, x + w + 4, y + h + 5], radius=3, fill=bg)
    draw.text((x, y - 2), text, font=fnt, fill=fill)
    return w, h

def point_along(points, distance, reverse=False):
    import math
    pts = list(reversed(points)) if reverse else points
    for a, b in zip(pts, pts[1:]):
        seg = math.hypot(b[0] - a[0], b[1] - a[1])
        if seg >= distance:
            t = distance / seg if seg else 0
            return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
        distance -= seg
    return pts[-1]

def render_entity(draw, e, physical=False):
    key, title, x, y, attrs = e
    width = PHYS_W if physical else IDEF_W
    header_h = PHYS_HEADER if physical else IDEF_HEADER
    row_h = PHYS_ROW if physical else IDEF_ROW
    height = header_h + row_h * len(attrs) + 8
    draw.rectangle([x, y, x + width, y + height], fill="#F7F9FC", outline="#2F5597", width=2)
    draw.rectangle([x, y, x + width, y + header_h], fill="#1F3864", outline="#2F5597", width=2)
    tf = font(FONT_REG, 26 if not physical else 24)
    draw.text((x + 10, y + 8), title, font=tf, fill="#FFFFFF")
    af = font(FONT_REG, 25 if not physical else 24)
    tagf = font(FONT_REG, 22 if not physical else 17)
    tf2 = font(FONT_REG, 18)
    for i, attr in enumerate(attrs):
        tag, name = attr[0], attr[1]
        typ = attr[2] if physical and len(attr) > 2 else ""
        ry = y + header_h + 5 + i * row_h
        if tag:
            color = "#8B1E1E" if tag == "PK" else "#1E5C8B"
            draw.text((x + 8, ry), tag, font=tagf, fill=color)
        draw.text((x + 46, ry), name, font=af, fill="#111111")
        if typ:
            tw = tf2.getlength(typ)
            draw.text((x + width - tw - 10, ry + 4), typ, font=tf2, fill="#555555")
        if i < len(attrs) - 1:
            draw.line([(x + 6, ry + row_h - 3), (x + width - 6, ry + row_h - 3)], fill="#D9E2F3", width=1)
    return height

def diagram(entities, edges, path, title, subtitle, width, height, physical=False):
    img = Image.new("RGB", (width, height), "#FFFFFF")
    d = ImageDraw.Draw(img)
    d.text((40, 26), title, font=font(FONT_LABEL, 34), fill="#1F3864")
    d.text((40, 72), subtitle, font=font(FONT_LABEL, 20), fill="#444444")
    colors = ["#2F5597", "#7F4F24", "#385723", "#7030A0", "#C00000", "#0F7B6C"]
    for i, (_, child, points) in enumerate(edges):
        color = "#6C8EBF" if physical else colors[i % len(colors)]
        draw_path(d, points, color, width=2, dash=11)
    for e in entities:
        render_entity(d, e, physical)
    lf = font(FONT_LABEL, 22)
    for i, (parent, child, points) in enumerate(edges):
        color = "#6C8EBF" if physical else colors[i % len(colors)]
        p0, p1 = points[0], points[-1]
        d.ellipse([p0[0] - 5, p0[1] - 5, p0[0] + 5, p0[1] + 5], fill=color)
        if physical:
            d.polygon([(p1[0], p1[1]), (p1[0] - 10, p1[1] - 6), (p1[0] - 10, p1[1] + 6)], fill=color)
        else:
            lc = point_along(points, 32, reverse=True)
            draw_label(d, (lc[0] - 18, lc[1] - 24), "N", lf)
    lf2 = font(FONT_LABEL, 21)
    if physical:
        d.text((40, height - 40), "PK — первичный ключ;  FK — внешний ключ;  пунктир — связь 1:N",
               font=lf2, fill="#444444")
    else:
        d.text((40, height - 40),
               "Точка — сторона «один»;  N — сторона «многие»;  пунктир — неидентифицирующая связь",
               font=lf2, fill="#444444")
    img.save(path, "PNG")
    print(path, img.size)

def drawio_xml(entities, edges, path):
    W = 1600
    cells = []
    ids = {}
    for idx, (key, title, x, y, attrs) in enumerate(entities):
        ids[key] = f"e{idx+2}"
        rows = []
        for attr in attrs:
            tag, name = attr[0], attr[1]
            prefix = f"[{tag}] " if tag else ""
            rows.append(escape(prefix + name))
        label = escape(title) + "&#xa;" + "&#xa;".join(rows)
        h = 46 + 30 * len(attrs)
        cells.append(
            f'<mxCell id="{ids[key]}" value="{label}" style="rounded=0;whiteSpace=wrap;html=1;'
            f'fillColor=#F7F9FC;strokeColor=#2F5597;fontFamily=Times New Roman;fontSize=13;'
            f'verticalAlign=top;align=left;spacingLeft=8;spacingTop=4;" vertex="1" parent="1">'
            f'<mxGeometry x="{x}" y="{y}" width="400" height="{h}" as="geometry"/></mxCell>'
        )
    for i, (parent, child, points) in enumerate(edges):
        cells.append(
            f'<mxCell id="edge{i+2}" style="edgeStyle=orthogonalEdgeStyle;dashed=1;html=1;'
            f'endArrow=ERmany;startArrow=ERone;startFill=0;endFill=0;strokeColor=#2F5597;" '
            f'edge="1" parent="1" source="{ids[parent]}" target="{ids[child]}">'
            f'<mxGeometry relative="1" as="geometry"/></mxCell>'
        )
    xml = (
        '<mxfile host="app.diagrams.net" modified="2026-11-19T00:00:00.000Z" agent="RGR" version="24.0.0">'
        '<diagram id="idef1x" name="IDEF1X">'
        f'<mxGraphModel dx="1600" dy="900" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" '
        f'arrows="1" fold="1" page="1" pageScale="1" pageWidth="{W}" pageHeight="1320" math="0" shadow="0">'
        '<root><mxCell id="0"/><mxCell id="1" parent="0"/>'
        + "".join(cells) +
        '</root></mxGraphModel></diagram></mxfile>'
    )
    Path(path).write_text(xml, encoding="utf-8")
    print(path)

diagram(IDEF_ENTITIES, IDEF_EDGES, OUT / "idef1x.png",
        "Концептуальная модель IDEF1X — учёт и прогноз запасов нефтепродуктов",
        "12 сущностей; неидентифицирующие связи 1:N; PK — суррогатные, естественные ключи UNIQUE",
        1600, 1320, physical=False)

diagram(PHYS_ENTITIES, PHYS_EDGES, OUT / "physical_erd.png",
        "Физическая модель базы данных oildepotdb (PostgreSQL)",
        "12 таблиц; PK/FK; типы NUMERIC для объёмов, денег и плотности",
        1800, 1560, physical=True)

drawio_xml(IDEF_ENTITIES, IDEF_EDGES, OUT / "idef1x.drawio")
