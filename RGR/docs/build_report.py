#!/usr/bin/env python3
"""Сборка отчёта РГР: DOCX из шаблона, PDF через LibreOffice, Markdown-источник."""
import re
import subprocess
import sys
from pathlib import Path

from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK, WD_LINE_SPACING, WD_TAB_ALIGNMENT, WD_TAB_LEADER
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import report_content as C

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
SHOTS = DOCS / "screenshots"
SQL = ROOT / "sql"
TEMPLATE = ROOT / "templates" / "ReportTemplate.docx"
DOCX = DOCS / "ReportRGR.docx"
PDF = DOCS / "ReportRGR.pdf"
MD = DOCS / "ReportRGR.md"

TOC_ENTRIES = [
    (1, "ВВЕДЕНИЕ"),
    (1, "1 ПРЕДМЕТНАЯ ОБЛАСТЬ И БИЗНЕС-ПРАВИЛА"),
    (2, "1.1 Характеристика объекта автоматизации"),
    (2, "1.2 Основные бизнес-процессы"),
    (2, "1.3 Бизнес-правила предметной области"),
    (2, "1.4 Входная и выходная информация"),
    (1, "2 КОНЦЕПТУАЛЬНАЯ МОДЕЛЬ IDEF1X"),
    (2, "2.1 Состав сущностей"),
    (2, "2.2 Связи и кардинальность"),
    (1, "3 ЛОГИЧЕСКАЯ МОДЕЛЬ И НОРМАЛИЗАЦИЯ"),
    (2, "3.1 Реляционная схема"),
    (2, "3.2 Нормализация отношений"),
    (2, "3.3 Словарь данных"),
    (2, "3.4 Действия ссылочных ограничений"),
    (2, "3.5 Управляемая избыточность"),
    (1, "4 РЕАЛИЗАЦИЯ БАЗЫ ДАННЫХ В POSTGRESQL"),
    (2, "4.1 Среда и создание базы данных"),
    (2, "4.2 Схема таблиц"),
    (2, "4.3 Физическая модель"),
    (2, "4.4 Индексы"),
    (2, "4.5 Анализ планов выполнения"),
    (2, "4.6 Тестовые данные"),
    (1, "5 ЗАПРОСЫ К БАЗЕ ДАННЫХ"),
    (2, "5.1 Общая характеристика запросов"),
    (2, "5.2 Запросы Q01–Q23"),
    (1, "6 ПРОГРАММНЫЕ ОБЪЕКТЫ БАЗЫ ДАННЫХ"),
    (2, "6.1 Материализованные представления"),
    (2, "6.2 Функция прогноза"),
    (2, "6.3 Процедура формирования прогнозов"),
    (2, "6.4 Триггеры учёта остатков"),
    (1, "7 ОБЕСПЕЧЕНИЕ ЦЕЛОСТНОСТИ И ТОЧНОСТИ"),
    (2, "7.1 Уровни целостности"),
    (2, "7.2 Негативные тесты"),
    (2, "7.3 Точность числовых данных"),
    (2, "7.4 Приёмочная проверка"),
    (1, "ЗАКЛЮЧЕНИЕ"),
    (1, "СПИСОК ИСПОЛЬЗОВАННЫХ ИСТОЧНИКОВ"),
    (1, "ПРИЛОЖЕНИЕ А. ПОЛНЫЙ DDL-СКРИПТ СХЕМЫ"),
    (1, "ПРИЛОЖЕНИЕ Б. ПРОТОКОЛ ПРИЁМОЧНОЙ ПРОВЕРКИ"),
]

FIG = 0
TAB = 0


# ----------------------------------------------------------------------------
# Вспомогательные функции DOCX
# ----------------------------------------------------------------------------
def set_run_font(run, name="Times New Roman", size=14, bold=None, italic=None, color=None):
    run.font.name = name
    run._element.get_or_add_rPr().rFonts.set(qn("w:eastAsia"), name)
    run.font.size = Pt(size)
    if bold is not None:
        run.bold = bold
    if italic is not None:
        run.italic = italic
    if color:
        run.font.color.rgb = RGBColor.from_string(color)


def shade_cell(cell, fill):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), fill)
    tcPr.append(shd)


def shade_paragraph(p, fill="F2F2F2"):
    pPr = p._p.get_or_add_pPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), fill)
    pPr.append(shd)


def set_repeat_header(row):
    trPr = row._tr.get_or_add_trPr()
    th = OxmlElement("w:tblHeader")
    th.set(qn("w:val"), "true")
    trPr.append(th)


def set_cant_split(row):
    trPr = row._tr.get_or_add_trPr()
    cs = OxmlElement("w:cantSplit")
    cs.set(qn("w:val"), "true")
    trPr.append(cs)


def set_table_borders(table):
    tblPr = table._tbl.tblPr
    borders = OxmlElement("w:tblBorders")
    for edge in ("top", "left", "bottom", "right", "insideH", "insideV"):
        el = OxmlElement(f"w:{edge}")
        el.set(qn("w:val"), "single")
        el.set(qn("w:sz"), "4")
        el.set(qn("w:space"), "0")
        el.set(qn("w:color"), "808080")
        borders.append(el)
    tblPr.append(borders)


def add_page_field(paragraph):
    run = paragraph.add_run()
    fld1 = OxmlElement("w:fldChar")
    fld1.set(qn("w:fldCharType"), "begin")
    instr = OxmlElement("w:instrText")
    instr.set(qn("xml:space"), "preserve")
    instr.text = " PAGE "
    fld2 = OxmlElement("w:fldChar")
    fld2.set(qn("w:fldCharType"), "separate")
    t = OxmlElement("w:t")
    t.text = "2"
    fld3 = OxmlElement("w:fldChar")
    fld3.set(qn("w:fldCharType"), "end")
    run._r.append(fld1)
    run._r.append(instr)
    run._r.append(fld2)
    run._r.append(t)
    run._r.append(fld3)
    set_run_font(run, size=11)


def add_inline(paragraph, text, size=14):
    """Поддержка **жирного** текста."""
    parts = re.split(r"(\*\*.+?\*\*)", text)
    for part in parts:
        if not part:
            continue
        if part.startswith("**") and part.endswith("**"):
            r = paragraph.add_run(part[2:-2])
            set_run_font(r, size=size, bold=True)
        else:
            r = paragraph.add_run(part)
            set_run_font(r, size=size)


# ----------------------------------------------------------------------------
# Построение DOCX
# ----------------------------------------------------------------------------
class Builder:
    def __init__(self, toc_pages=None):
        global FIG, TAB
        FIG = 0
        TAB = 0
        self.toc_pages = toc_pages or {}
        self.doc = Document(str(TEMPLATE))
        self._setup_styles()
        self._prepare_title()
        self._setup_sections()
        self._add_toc()

    # --- стили -------------------------------------------------------------
    def _setup_styles(self):
        d = self.doc
        normal = d.styles["Normal"]
        normal.font.name = "Times New Roman"
        normal._element.rPr.rFonts.set(qn("w:eastAsia"), "Times New Roman")
        normal.font.size = Pt(14)
        pf = normal.paragraph_format
        pf.line_spacing = 1.5
        pf.space_before = Pt(0)
        pf.space_after = Pt(0)
        pf.first_line_indent = Cm(1.25)
        pf.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY

        for name, size, before, after in (("Heading 1", 18, 18, 8),
                                          ("Heading 2", 15, 14, 6),
                                          ("Heading 3", 14, 10, 4)):
            st = d.styles[name]
            st.font.name = "Times New Roman"
            st._element.rPr.rFonts.set(qn("w:eastAsia"), "Times New Roman")
            st.font.size = Pt(size)
            st.font.bold = True
            st.font.color.rgb = RGBColor(0, 0, 0)
            st.paragraph_format.first_line_indent = Cm(0)
            st.paragraph_format.line_spacing = 1.15
            st.paragraph_format.space_before = Pt(before)
            st.paragraph_format.space_after = Pt(after)
            st.paragraph_format.keep_with_next = True
            st.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.LEFT

        code = d.styles.add_style("Code", 1)
        code.font.name = "Courier New"
        code._element.rPr.rFonts.set(qn("w:eastAsia"), "Courier New")
        code.font.size = Pt(9)
        code.paragraph_format.first_line_indent = Cm(0)
        code.paragraph_format.left_indent = Cm(0.35)
        code.paragraph_format.line_spacing = 1.0
        code.paragraph_format.space_before = Pt(0)
        code.paragraph_format.space_after = Pt(0)
        code.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.LEFT

    # --- титульный лист ----------------------------------------------------
    def _prepare_title(self):
        d = self.doc
        paras = d.paragraphs
        p13 = paras[13]
        p41 = paras[41]
        # Сначала удаляем старое содержимое лабораторной работы (параграфы 42+)
        for p in list(paras[42:]):
            p._p.getparent().remove(p._p)
        # Освобождаем место на титульном листе для темы и города
        for p in list(paras[14:34]):
            p._p.getparent().remove(p._p)

        for r in p13.runs:
            r.text = ""
        p13.runs[0].text = "Расчётно-графическая работа"

        # Тема работы сразу после строки с видом работы
        new_p = d.add_paragraph()
        p13._p.addnext(new_p._p)
        new_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        new_p.paragraph_format.first_line_indent = Cm(0)
        new_p.paragraph_format.line_spacing = 1.0
        new_p.paragraph_format.space_before = Pt(6)
        r = new_p.add_run("Вариант 17. База данных автоматизации учёта и прогноза\n"
                          "запасов нефтепродуктов, реализуемых нефтебазой")
        set_run_font(r, size=14, bold=True)

        # Город и год внизу титульного листа
        for br in list(p41._p.iter(qn("w:br"))):
            if br.get(qn("w:type")) == "page":
                br.getparent().remove(br)
        city = d.add_paragraph()
        p41._p.addnext(city._p)
        city.alignment = WD_ALIGN_PARAGRAPH.CENTER
        city.paragraph_format.first_line_indent = Cm(0)
        city.paragraph_format.space_before = Pt(18)
        r = city.add_run("Москва, 2026")
        set_run_font(r, size=14)

    def _setup_sections(self):
        d = self.doc
        for s in d.sections:
            s.page_width = Cm(21.0)
            s.page_height = Cm(29.7)
            s.left_margin = Cm(3.0)
            s.right_margin = Cm(1.5)
            s.top_margin = Cm(2.0)
            s.bottom_margin = Cm(2.0)
            s.footer_distance = Cm(1.0)
        # Новая секция для основного текста: титульный лист без номера страницы
        sec = d.add_section(WD_SECTION.NEW_PAGE)
        sec.page_width = Cm(21.0)
        sec.page_height = Cm(29.7)
        sec.left_margin = Cm(3.0)
        sec.right_margin = Cm(1.5)
        sec.top_margin = Cm(2.0)
        sec.bottom_margin = Cm(2.0)
        sec.footer.is_linked_to_previous = False
        fp = sec.footer.paragraphs[0]
        fp.alignment = WD_ALIGN_PARAGRAPH.CENTER
        fp.paragraph_format.first_line_indent = Cm(0)
        add_page_field(fp)
        pg = OxmlElement("w:pgNumType")
        pg.set(qn("w:start"), "2")
        sec._sectPr.append(pg)

    def _add_toc(self):
        p = self.doc.add_paragraph()
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.first_line_indent = Cm(0)
        p.paragraph_format.space_after = Pt(12)
        r = p.add_run("СОДЕРЖАНИЕ")
        set_run_font(r, size=16, bold=True)
        for level, title in TOC_ENTRIES:
            par = self.doc.add_paragraph()
            par.paragraph_format.first_line_indent = Cm(0)
            par.paragraph_format.line_spacing = 1.0
            par.paragraph_format.space_after = Pt(3)
            par.paragraph_format.left_indent = Cm(0.0 if level == 1 else 0.75)
            par.paragraph_format.tab_stops.add_tab_stop(
                Cm(16.4), WD_TAB_ALIGNMENT.RIGHT, WD_TAB_LEADER.DOTS)
            page = str(self.toc_pages.get(title, "—"))
            r = par.add_run(title)
            set_run_font(r, size=12 if level == 1 else 11, bold=(level == 1))
            r = par.add_run("\t" + page)
            set_run_font(r, size=12 if level == 1 else 11)
        self.page_break()

    # --- базовые блоки -----------------------------------------------------
    def page_break(self):
        p = self.doc.add_paragraph()
        p.paragraph_format.first_line_indent = Cm(0)
        p.add_run().add_break(WD_BREAK.PAGE)

    def h1(self, text, new_page=True):
        p = self.doc.add_paragraph(style="Heading 1")
        if new_page:
            p.paragraph_format.page_break_before = True
        p.add_run(text)
        return p

    def h2(self, text):
        p = self.doc.add_paragraph(style="Heading 2")
        p.add_run(text)
        return p

    def h3(self, text):
        p = self.doc.add_paragraph(style="Heading 3")
        p.add_run(text)
        return p

    def p(self, text, first_indent=True, align="justify", size=14, italic=False, bold=False, space_after=0):
        p = self.doc.add_paragraph()
        p.paragraph_format.first_line_indent = Cm(1.25) if first_indent else Cm(0)
        p.paragraph_format.space_after = Pt(space_after)
        p.alignment = {"justify": WD_ALIGN_PARAGRAPH.JUSTIFY,
                       "left": WD_ALIGN_PARAGRAPH.LEFT,
                       "center": WD_ALIGN_PARAGRAPH.CENTER,
                       "right": WD_ALIGN_PARAGRAPH.RIGHT}[align]
        if bold:
            r = p.add_run(text)
            set_run_font(r, size=size, bold=True, italic=italic)
        else:
            add_inline(p, text, size=size)
            if italic:
                for r in p.runs:
                    r.italic = True
        return p

    def bullets(self, items):
        for item in items:
            p = self.doc.add_paragraph()
            p.paragraph_format.first_line_indent = Cm(0)
            p.paragraph_format.left_indent = Cm(1.25)
            p.paragraph_format.space_after = Pt(2)
            p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
            r = p.add_run("• ")
            set_run_font(r, size=14)
            add_inline(p, item, size=14)

    def code(self, text):
        lines = text.replace("\t", "    ").rstrip("\n").split("\n")
        for ln in lines:
            p = self.doc.add_paragraph(style="Code")
            p.add_run(ln if ln else " ")
            shade_paragraph(p)
        # Небольшой отступ после блока
        sp = self.doc.add_paragraph()
        sp.paragraph_format.first_line_indent = Cm(0)
        sp.paragraph_format.space_after = Pt(0)
        sp.paragraph_format.line_spacing = 0.6

    def table(self, caption, headers, rows, widths=None, size=9):
        global TAB
        TAB += 1
        cp = self.doc.add_paragraph()
        cp.paragraph_format.first_line_indent = Cm(0)
        cp.paragraph_format.space_before = Pt(8)
        cp.paragraph_format.space_after = Pt(3)
        cp.paragraph_format.keep_with_next = True
        r = cp.add_run(f"Таблица {TAB} – {caption}")
        set_run_font(r, size=12, bold=True)

        t = self.doc.add_table(rows=1, cols=len(headers))
        set_table_borders(t)
        t.alignment = WD_TABLE_ALIGNMENT.CENTER
        t.autofit = False
        hdr = t.rows[0]
        set_repeat_header(hdr)
        set_cant_split(hdr)
        for i, h in enumerate(headers):
            cell = hdr.cells[i]
            cell.text = ""
            pp = cell.paragraphs[0]
            pp.paragraph_format.first_line_indent = Cm(0)
            pp.paragraph_format.line_spacing = 1.0
            pp.alignment = WD_ALIGN_PARAGRAPH.CENTER
            rr = pp.add_run(h)
            set_run_font(rr, size=size, bold=True)
            shade_cell(cell, "D9E2F3")

        for row in rows:
            tr = t.add_row()
            set_cant_split(tr)
            for i, val in enumerate(row):
                cell = tr.cells[i]
                cell.text = ""
                pp = cell.paragraphs[0]
                pp.paragraph_format.first_line_indent = Cm(0)
                pp.paragraph_format.line_spacing = 1.0
                pp.alignment = WD_ALIGN_PARAGRAPH.LEFT
                rr = pp.add_run(str(val))
                set_run_font(rr, size=size)

        if widths:
            for row in t.rows:
                for i, w in enumerate(widths):
                    row.cells[i].width = Cm(w)
        # Отступ после таблицы
        sp = self.doc.add_paragraph()
        sp.paragraph_format.first_line_indent = Cm(0)
        sp.paragraph_format.space_after = Pt(0)
        sp.paragraph_format.line_spacing = 1.0

    def image(self, filename, caption, max_w=16.2, max_h=20.8):
        global FIG
        FIG += 1
        path = SHOTS / filename
        w, h = Image.open(path).size
        width_cm = min(max_w, max_h * w / h)
        p = self.doc.add_paragraph()
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.first_line_indent = Cm(0)
        p.paragraph_format.space_before = Pt(6)
        p.paragraph_format.space_after = Pt(3)
        p.paragraph_format.keep_with_next = True
        p.add_run().add_picture(str(path), width=Cm(width_cm))
        cp = self.doc.add_paragraph()
        cp.alignment = WD_ALIGN_PARAGRAPH.CENTER
        cp.paragraph_format.first_line_indent = Cm(0)
        cp.paragraph_format.space_after = Pt(10)
        r = cp.add_run(f"Рисунок {FIG} – {caption}")
        set_run_font(r, size=12, italic=True)

    def save(self, path):
        self.doc.save(str(path))


# ----------------------------------------------------------------------------
# Текст отчёта
# ----------------------------------------------------------------------------
def query_sql(n):
    path = SQL / "queries" / f"q{n:02d}.sql"
    lines = []
    for ln in path.read_text(encoding="utf-8").splitlines():
        if ln.startswith("\\pset") or ln.startswith("\\echo"):
            continue
        lines.append(ln.rstrip())
    while lines and not lines[0].strip():
        lines.pop(0)
    return "\n".join(lines)


def build_content(b: Builder):
    b.h1("ВВЕДЕНИЕ", new_page=False)
    b.p("Автоматизация учёта нефтепродуктов на нефтебазе охватывает приёмку топлива от поставщиков, "
        "хранение в резервуарах, отгрузку оптовым и розничным клиентам, контроль остатков, ведение цен "
        "и прогнозирование расхода. Ошибки в этой области приводят к переполнению резервуаров, "
        "отрицательным остаткам, неверным суммам в документах и, как следствие, к финансовым потерям.")
    b.p("**Цель работы** — разработать реляционную базу данных, которая обеспечивает достоверный учёт "
        "поступления, хранения и отгрузки нефтепродуктов, поддерживает целостность данных на уровне "
        "СУБД и позволяет строить аналитические выборки и прогнозы запасов.")
    b.p("Для достижения цели решаются следующие задачи: описать предметную область и бизнес-правила; "
        "построить концептуальную модель в нотации IDEF1X; выполнить логическое проектирование и "
        "нормализацию; реализовать схему в PostgreSQL; создать индексы, представления, функцию, "
        "процедуру и триггеры; подготовить тестовые данные; разработать 23 запроса; проверить "
        "ограничения негативными тестами и приёмочным сценарием.")
    b.p("Объект исследования — процессы учёта и прогнозирования запасов нефтебазы. Предмет исследования — "
        "структура данных, ограничения целостности и запросы, необходимые для поддержки этих процессов. "
        "Инструментальная среда — PostgreSQL 18.6, клиент psql, нотация IDEF1X, редактор draw.io, "
        "средства формирования отчётности Python и LibreOffice.")

    # ------------------------------------------------------------------ 1
    b.h1("1 ПРЕДМЕТНАЯ ОБЛАСТЬ И БИЗНЕС-ПРАВИЛА")
    b.h2("1.1 Характеристика объекта автоматизации")
    b.p("Нефтебаза принимает светлые и тёмные нефтепродукты от поставщиков, хранит их в резервуарах "
        "и отгружает потребителям. Номенклатура включает автомобильные бензины, дизельное топливо, "
        "мазут и индустриальные масла. Каждая марка имеет код, плотность, минимальный нормативный запас "
        "и, для бензинов, октановое число.")
    b.p("Резервуар является основным местом хранения. Он рассчитан на один вид продукта, имеет "
        "инвентарный номер, полную ёмкость и текущий учётный остаток. Состояние резервуара описывается "
        "статусом «в эксплуатации», «на ремонте» или «выведен». Перемешивание разных марок в одном "
        "резервуаре недопустимо, поэтому соответствие «резервуар — продукт» контролируется на уровне схемы "
        "и триггеров.")
    b.p("Поставщики и клиенты — самостоятельные контрагенты. Поставщик характеризуется наименованием, "
        "ИНН, телефоном и контактным лицом; клиент — типом (оптовый или розничный), ИНН, телефоном и "
        "договором. Документы поставки и отгрузки имеют номер, дату, статус и сумму; их позиции содержат "
        "продукт, резервуар, объём и цену.")

    b.h2("1.2 Основные бизнес-процессы")
    b.p("В предметной области выделены следующие процессы:")
    b.bullets([
        "**Закупка и приёмка.** Поставщик выставляет счёт; нефтебаза оформляет поставку, принимает топливо "
        "в резервуар, фиксирует объём и цену. Приёмка увеличивает остаток и создаёт движение типа «приход».",
        "**Хранение.** Остаток в резервуаре не может быть отрицательным или превышать ёмкость. Периодически "
        "выполняются замеры объёма, температуры и плотности; замеры носят наблюдательный характер и не "
        "изменяют учётный остаток.",
        "**Отгрузка.** На основании договора оформляется отгрузка клиенту. Каждая позиция списывает топливо "
        "из конкретного резервуара; при недостатке остатка операция запрещается.",
        "**Ценообразование.** Для каждой марки ведётся история закупочных и розничных цен с датой действия. "
        "Розничная цена не может быть ниже закупочной.",
        "**Контроль и прогнозирование.** Суммарные остатки сравниваются с минимальным резервом; по среднему "
        "расходу за последние 30 дней рассчитывается прогнозный остаток на заданный горизонт.",
    ])

    b.h2("1.3 Бизнес-правила предметной области")
    b.p("Бизнес-правила сформулированы до проектирования таблиц и затем реализованы декларативными "
        "ограничениями или триггерами. Перечень правил приведён в таблице 1.")
    b.table("Бизнес-правила предметной области", ["№", "Правило", "Реализация"],
            C.BUSINESS_RULES, widths=[1.6, 7.4, 7.4], size=9)

    b.h2("1.4 Входная и выходная информация")
    b.p("Входной информацией служат справочники продуктов, резервуаров, поставщиков и клиентов, документы "
        "поставок и отгрузок, история цен, замеры и журнал движений. Выходная информация включает "
        "оперативные остатки, суммы документов, аналитические отчёты по поставкам и продажам, перечень "
        "дефицитных продуктов и прогнозы запасов. Все выходные формы строятся запросами к базе данных; "
        "материализованные представления используются для часто повторяющихся агрегатов.")

    # ------------------------------------------------------------------ 2
    b.h1("2 КОНЦЕПТУАЛЬНАЯ МОДЕЛЬ IDEF1X")
    b.h2("2.1 Состав сущностей")
    b.p("Концептуальная модель содержит 12 сущностей. Справочники продуктов, поставщиков, клиентов и "
        "резервуаров являются независимыми; документы поставки и отгрузки связаны с позициями отношением "
        "«один ко многим». Журнал движений и прогнозы зависят от продукта и резервуара, а замеры — только "
        "от резервуара.")
    b.p("Для всех сущностей приняты суррогатные первичные ключи (SERIAL/BIGSERIAL), а естественные "
        "идентификаторы — код продукта, номер резервуара, ИНН, номер договора, номер документа — объявлены "
        "уникальными. Это упрощает ссылки, сохраняет стабильность ключей при изменении атрибутов и "
        "соответствует требованиям IDEF1X к независимым сущностям.")
    b.table("Сущности концептуальной модели",
            ["Сущность", "Назначение", "Ключевые атрибуты"],
            [("PRODUCTS", "Справочник нефтепродуктов", "id_product, product_code, category, density"),
             ("TANKS", "Резервуары и учётные остатки", "id_tank, id_product, capacity, current_volume"),
             ("SUPPLIERS", "Поставщики топлива", "id_supplier, inn, name"),
             ("CLIENTS", "Оптовые и розничные клиенты", "id_client, inn, contract_number"),
             ("PRICE_HISTORY", "История закупочных и розничных цен", "id_price, id_product, effective_date"),
             ("DELIVERIES", "Документы поставок", "id_delivery, id_supplier, delivery_date, status"),
             ("DELIVERY_ITEMS", "Позиции поставок", "id_delivery_item, id_delivery, id_product, id_tank"),
             ("SHIPMENTS", "Документы отгрузок", "id_shipment, id_client, shipment_date, status"),
             ("SHIPMENT_ITEMS", "Позиции отгрузок", "id_shipment_item, id_shipment, id_product, id_tank"),
             ("STOCK_MOVEMENTS", "Журнал приходов, расходов и корректировок", "id_movement, id_product, id_tank"),
             ("TANK_MEASUREMENTS", "Замеры объёма, температуры и плотности", "id_measurement, id_tank, measured_at"),
             ("RESERVE_FORECASTS", "Прогнозы остатков", "id_forecast, id_product, forecast_date")],
            widths=[3.9, 7.0, 5.5], size=9)

    b.h2("2.2 Связи и кардинальность")
    b.p("Все связи — неидентифицирующие: первичный ключ дочерней сущности не включает внешний ключ. "
        "Кардинальность сторон обозначена точкой на стороне «один» и символом N на стороне «многие». "
        "Связи документов с позициями обязательны, связи журнала движений с позициями документов "
        "необязательны: корректировка может не иметь ссылки на позицию.")
    b.table("Связи концептуальной модели",
            ["Родительская сущность", "Дочерняя сущность", "Внешний ключ", "Кардинальность", "ON DELETE"],
            C.RELATIONSHIPS, widths=[3.7, 3.7, 4.2, 2.8, 2.0], size=9)
    b.image("fig_01_idef1x.png",
            "Концептуальная модель IDEF1X (диаграмма подготовлена в нотации IDEF1X; исходный файл — "
            "docs/diagrams/idef1x.drawio)")

    # ------------------------------------------------------------------ 3
    b.h1("3 ЛОГИЧЕСКАЯ МОДЕЛЬ И НОРМАЛИЗАЦИЯ")
    b.h2("3.1 Реляционная схема")
    b.p("Логическая модель представляет собой 12 отношений. Первичные ключи — суррогатные, внешние ключи "
        "повторяют связи концептуальной модели. Атрибуты приведены к атомарному виду, для каждого "
        "определены тип, обязательность и ограничения. Схема размещается в публичной схеме public "
        "базы данных oildepotdb.")
    b.p("Документы поставки и отгрузки отделены от позиций. Такое разделение устраняет повторяющуюся "
        "группу, обеспечивает независимое существование справочников и позволяет хранить произвольное "
        "число строк документа. Сумма документа хранится как управляемая избыточность и поддерживается "
        "триггерами.")

    b.h2("3.2 Нормализация отношений")
    b.p("Исходным представлением послужила форма документа поставки, в которой строка таблицы содержала "
        "номер и дату поставки, поставщика, счёт, а также повторяющуюся группу «продукт — резервуар — "
        "объём — цена». Такое отношение не удовлетворяет первой нормальной форме.")
    b.p("**Первая нормальная форма.** Повторяющаяся группа вынесена в отдельное отношение delivery_items, "
        "а заголовок документа — в deliveries. Все атрибуты стали атомарными, у каждого отношения появился "
        "первичный ключ.")
    b.p("**Вторая нормальная форма.** В отношении позиции составной ключ (id_delivery, line_no) определяет "
        "атрибуты продукта и резервуара только частично. Атрибуты продуктов вынесены в products, "
        "резервуаров — в tanks, поставщиков — в suppliers. После этого каждый неключевой атрибут зависит "
        "от полного первичного ключа.")
    b.p("**Третья нормальная форма.** Устранены транзитивные зависимости: название и плотность продукта "
        "не хранятся в позициях, а берутся из products; реквизиты поставщика — из suppliers; характеристики "
        "резервуара — из tanks. История цен выделена в price_history, журнал операций — в stock_movements, "
        "замеры — в tank_measurements, прогнозы — в reserve_forecasts.")
    b.p("**BCNF.** В каждом отношении детерминантом неключевых атрибутов является только кандидатный ключ. "
        "Исключение составляют сознательно денормализованные поля tanks.current_volume и total_amount "
        "документов: они не являются независимыми фактами, а представляют кэш агрегатов и "
        "пересчитываются триггерами. Их сходимость с первичными данными проверяется приёмочным скриптом.")
    b.table("Этапы нормализации на примере поставки",
            ["Этап", "Отношение", "Что изменилось"],
            [("Исходное", "Поставка (номер, дата, поставщик, счёт, продукт, резервуар, объём, цена)",
              "Повторяющаяся группа позиций, дублирование реквизитов"),
             ("1NF", "deliveries + delivery_items", "Позиции вынесены в отдельное отношение, атрибуты атомарны"),
             ("2NF", "products, tanks, suppliers", "Устранены частичные зависимости от составного ключа"),
             ("3NF", "price_history, stock_movements, tank_measurements", "Устранены транзитивные зависимости"),
             ("BCNF", "12 отношений", "Все детерминанты — кандидатные ключи")],
            widths=[2.2, 6.8, 7.4], size=9)

    b.h2("3.3 Словарь данных")
    b.p("Словарь данных описывает все 12 отношений. Для каждого поля указаны тип PostgreSQL, ограничения "
        "и назначение. Сокращение PK означает первичный ключ, FK — внешний ключ, UNIQUE — ограничение "
        "уникальности.")
    for table_name, fields in C.DATA_DICT:
        b.table(f"Отношение {table_name}",
                ["Поле", "Тип", "Ограничения", "Назначение"],
                fields, widths=[4.0, 3.3, 4.6, 4.5], size=8.5)

    b.h2("3.4 Действия ссылочных ограничений")
    b.p("Для справочных данных выбрано действие ON DELETE RESTRICT: продукт, резервуар, поставщик или "
        "клиент, на которые ссылаются документы, не могут быть удалены. Это сохраняет историю и "
        "соответствует правилу BR-11. Для журнала движений ссылки на позиции документов используют "
        "ON DELETE SET NULL: движение остаётся в журнале как факт операции, но после удаления позиции "
        "теряет необязательную ссылку. Обновление ключей выполняется каскадно, хотя суррогатные ключи "
        "практически не меняются.")
    b.table("Действия внешних ключей",
            ["Связь", "Внешний ключ", "ON DELETE", "Обоснование"],
            [(f"{p} → {c}", fk, act,
              "Сохранение истории" if act == "RESTRICT" else "Аудит операции без ссылки")
             for p, c, fk, card, act in C.RELATIONSHIPS],
            widths=[4.4, 4.2, 2.6, 5.2], size=9)

    b.h2("3.5 Управляемая избыточность")
    b.p("Два поля являются производными. tanks.current_volume хранит текущий остаток, который можно "
        "получить суммированием stock_movements; deliveries.total_amount и shipments.total_amount равны "
        "сумме стоимостей позиций. Хранение этих значений ускоряет типовые запросы и позволяет "
        "декларативно проверять остаток при вставке. Согласованность обеспечивают триггеры на позициях "
        "документов: они меняют остаток и сумму в той же транзакции. Приёмочный скрипт сравнивает кэш с "
        "первичными данными и требует нулевого расхождения.")
    b.p("Журнал движений реализует принцип append-only: для stock_movements не определены операции "
        "UPDATE и DELETE. Изменение или удаление позиции оформленного документа порождает новую запись "
        "типа «корректировка» с противоположным по знаку объёмом, поэтому история операций сохраняется "
        "полностью.")

    # ------------------------------------------------------------------ 4
    b.h1("4 РЕАЛИЗАЦИЯ БАЗЫ ДАННЫХ В POSTGRESQL")
    b.h2("4.1 Среда и создание базы данных")
    b.p("База данных развёрнута в PostgreSQL 18.6 под управлением macOS. Используется клиент psql, "
        "кодировка UTF-8, локаль C. База данных oildepotdb создаётся отдельным скриптом 00_create_db.sql; "
        "схема, индексы, функции и триггеры размещаются в схеме public.")
    b.code((SQL / "00_create_db.sql").read_text(encoding="utf-8").strip())
    b.image("fig_03_db_create.png", "Параметры созданной базы данных oildepotdb")

    b.h2("4.2 Схема таблиц")
    b.p("Скрипт 01_schema.sql удаляет ранее созданные объекты в порядке, обратном зависимостям, и "
        "создаёт 12 таблиц. Порядок создания исключает ошибки внешних ключей: сначала справочники, затем "
        "документы, позиции, журнал и прогнозы. Все ограничения именованы автоматически СУБД и могут быть "
        "использованы в негативных тестах.")
    b.p("Ниже приведён фрагмент DDL для таблицы продуктов; полный скрипт находится в приложении А.")
    schema = (SQL / "01_schema.sql").read_text(encoding="utf-8")
    fragment = schema[schema.index("CREATE TABLE products"):schema.index("CREATE TABLE suppliers")].strip()
    b.code(fragment)
    b.image("fig_04_dt.png", "Список таблиц базы данных")
    b.image("fig_05_describe_products.png", "Структура таблицы products")

    b.h2("4.3 Физическая модель")
    b.p("Физическая модель отражает 12 таблиц, их первичные и внешние ключи, а также типы данных. "
        "Числовые объёмы хранятся в NUMERIC(12,3), денежные суммы — в NUMERIC(14,2), плотность — в "
        "NUMERIC(6,2). Для вычисляемых стоимостей позиций использованы генерируемые столбцы, что "
        "исключает расхождение между ценой, объёмом и стоимостью.")
    b.image("fig_02_physical_erd.png", "Физическая модель базы данных oildepotdb")

    b.h2("4.4 Индексы")
    b.p("Создано 17 индексов. Они покрывают внешние ключи, которые активно используются в соединениях, "
        "и составные условия фильтрации по датам и статусам. Для первичных ключей и ограничений "
        "уникальности PostgreSQL автоматически создаёт индексы, поэтому дублирующие индексы не "
        "объявлялись. Частичный индекс idx_forecasts_deficit ускоряет выборку дефицитных прогнозов.")
    b.table("Индексы базы данных",
            ["Индекс", "Таблица", "Столбцы / условие", "Назначение"],
            C.INDEXES, widths=[5.1, 3.6, 4.3, 3.6], size=8.5)
    b.image("fig_06_indexes.png", "Индексы схемы public")

    b.h2("4.5 Анализ планов выполнения")
    b.p("Для проверки использования индексов выполнены EXPLAIN (ANALYZE, BUFFERS). На тестовом объёме "
        "в 20 поставок планировщик выбирает Seq Scan для deliveries, поскольку таблица занимает две "
        "страницы, а соединение с suppliers выполняет Index Scan по уникальному индексу "
        "suppliers_name_key. Сортировка результата выполняется методом quicksort. При росте объёма "
        "данных составные индексы idx_deliveries_supplier_date и idx_deliveries_status_date позволяют "
        "перейти к индексному доступу без изменения текста запроса.")
    b.image("fig_07_explain.png", "План выполнения запроса Q08 с EXPLAIN (ANALYZE, BUFFERS)")

    b.h2("4.6 Тестовые данные")
    b.p("Скрипт 05_seed.sql наполняет таблицы согласованным набором данных: 15 продуктов, 15 поставщиков, "
        "15 клиентов, 15 резервуаров, 30 записей истории цен, 20 поставок с 40 позициями, 20 отгрузок с "
        "38 позициями, 30 замеров и 15 прогнозов. Журнал движений содержит 93 записи: 15 входящих "
        "корректировок, 40 приходов и 38 расходов. Все документы и движения связаны, остатки и суммы "
        "сходятся.")
    b.p("Начальные остатки введены корректировками на 31.08.2025, затем выполнялись поставки и отгрузки. "
        "Чтобы все поставки могли быть вставлены до отгрузок, ёмкости резервуаров Р-02, Р-03 и Р-06 "
        "увеличены до 40 000, 40 000 и 50 000 л; ёмкость Р-14 составляет 12 000 л. Эти значения не "
        "влияют на логику запросов и указаны в комментариях к данным.")
    b.image("fig_08_counts.png", "Количество строк в таблицах базы данных")

    # ------------------------------------------------------------------ 5
    b.h1("5 ЗАПРОСЫ К БАЗЕ ДАННЫХ")
    b.h2("5.1 Общая характеристика запросов")
    b.p("Разработаны 23 запроса, охватывающие выборку, фильтрацию, соединения, агрегаты, оконные "
        "функции, подзапросы и работу с материализованным представлением. Запросы Q01–Q11 проверяют "
        "простые и составные условия, Q12–Q14 — оконные функции, Q15–Q18 — группировку, Q19–Q22 — "
        "вложенные запросы, Q23 — материализованное представление. Для каждого запроса указана "
        "постановка задачи, приведён SQL и результат выполнения.")
    b.p("Все запросы выполнялись через psql. Результаты сохранены в каталоге results; иллюстрации "
        "построены по фактическим выводам psql без ручного редактирования данных.")
    b.h2("5.2 Запросы Q01–Q23")
    for q in C.QUERIES:
        n = q["n"]
        b.h3(f"Запрос Q{n:02d}. {q['title']}")
        b.p("**Постановка задачи.** " + q["task"])
        b.p("**SQL-запрос.**", first_indent=False, space_after=2)
        b.code(query_sql(n))
        b.p("**Результат.**", first_indent=False, space_after=2)
        b.image(f"fig_q{n:02d}.png", f"Результат выполнения запроса Q{n:02d}")
        b.p("**Анализ.** " + q["analysis"])

    # ------------------------------------------------------------------ 6
    b.h1("6 ПРОГРАММНЫЕ ОБЪЕКТЫ БАЗЫ ДАННЫХ")
    b.h2("6.1 Материализованные представления")
    b.p("Созданы два материализованных представления. mv_product_stock агрегирует остатки по продуктам, "
        "сравнивает их с минимальным резервом и классифицирует состояние как «дефицит», «ниже нормы» "
        "или «норма». mv_monthly_sales группирует отгруженные позиции по месяцам и продуктам, рассчитывая "
        "количество отгрузок, объём, выручку и среднюю цену.")
    b.p("Оба представления имеют уникальные индексы, поэтому после начального заполнения их можно "
        "обновлять командой REFRESH MATERIALIZED VIEW CONCURRENTLY без блокировки читателей.")
    b.code((SQL / "06_matviews.sql").read_text(encoding="utf-8").strip())
    b.image("fig_mv_product_stock.png", "Содержимое mv_product_stock")
    b.image("fig_mv_monthly_sales.png", "Фрагмент mv_monthly_sales")
    b.image("fig_refresh_mv.png", "Обновление материализованных представлений в режиме CONCURRENTLY")

    b.h2("6.2 Функция прогноза")
    b.p("Функция fn_product_forecast возвращает таблицу с датой прогноза, горизонтом, текущим остатком, "
        "среднесуточным расходом, ожидаемым расходом и прогнозным остатком. Расход собирается явным "
        "курсором по дням за последние 30 дней; остаток определяется суммой движений до даты прогноза "
        "включительно. Горизонт ограничен диапазоном 1–365 дней, некорректное значение вызывает "
        "исключение.")
    b.code((SQL / "03_functions.sql").read_text(encoding="utf-8").strip())
    b.image("fig_fn_forecast.png", "Результат вызова fn_product_forecast(1, 30, DATE '2026-06-30')")

    b.h2("6.3 Процедура формирования прогнозов")
    b.p("Процедура sp_build_forecasts проходит курсором по активным продуктам и для каждого рассчитывает "
        "остаток, средний расход и прогноз. Результат сохраняется в reserve_forecasts; при повторном "
        "вызове используется ON CONFLICT (id_product, forecast_date, horizon_days) DO UPDATE, поэтому "
        "дубликаты не появляются. Процедура сообщает о завершении через RAISE NOTICE.")
    b.image("fig_proc_forecasts.png", "Вызов sp_build_forecasts и проверка количества прогнозов")

    b.h2("6.4 Триггеры учёта остатков")
    b.p("Два AFTER-триггера row-level обслуживают позиции поставок и отгрузок. При вставке триггер "
        "блокирует резервуар командой SELECT ... FOR UPDATE, проверяет статус документа, соответствие "
        "продукта и резервуара, достаточность остатка или свободной ёмкости, изменяет current_volume, "
        "добавляет движение и увеличивает сумму документа. При изменении позиции проверяется запрет "
        "смены документа, продукта и резервуара; разница объёма оформляется корректировкой. При удалении "
        "объём возвращается, а в журнал добавляется корректировка с комментарием.")
    b.p("Триггеры не создаются на stock_movements, поэтому рекурсии нет. Блокировка резервуара "
        "предотвращает гонки при одновременных отгрузках.")
    code = (SQL / "04_triggers.sql").read_text(encoding="utf-8")
    start = code.index("CREATE OR REPLACE FUNCTION fn_delivery_items_stock()")
    end = code.index("ELSIF TG_OP = 'UPDATE'", start)
    b.code(code[start:end].strip())
    b.code(code[code.index("DROP TRIGGER IF EXISTS trg_delivery_items_stock"):].strip())
    b.image("fig_trigger_ok.png", "Срабатывание триггера при вставке позиции поставки")
    b.image("fig_trigger_err.png", "Отказ триггера при недостаточном остатке (тест N01)")

    # ------------------------------------------------------------------ 7
    b.h1("7 ОБЕСПЕЧЕНИЕ ЦЕЛОСТНОСТИ И ТОЧНОСТИ")
    b.h2("7.1 Уровни целостности")
    b.p("Целостность по сущностям обеспечена первичными ключами всех 12 отношений. Ссылочная целостность "
        "реализована внешними ключами с действиями RESTRICT, CASCADE и SET NULL. Семантическая "
        "целостность поддерживается проверками CHECK, регулярными выражениями для ИНН, перечислениями "
        "статусов и генерируемыми столбцами. Бизнес-логика, которую нельзя выразить декларативно "
        "(достаточность остатка, переполнение, соответствие продукта резервуару), реализована "
        "триггерами.")
    b.image("fig_constraints.png", "Ограничения и индексы таблицы deliveries")

    b.h2("7.2 Негативные тесты")
    b.p("Скрипт 08_tests.sql содержит 12 сценариев, каждый из которых должен завершиться ошибкой. "
        "Тесты выполняются в транзакции и завершаются ROLLBACK, поэтому данные не изменяются. Скрипт "
        "запускается без ON_ERROR_STOP: ожидаемые ошибки не прерывают выполнение.")
    b.table("Результаты негативных тестов",
            ["№", "Сценарий", "Ожидаемая ошибка", "Результат"],
            C.NEG_TESTS, widths=[1.3, 6.0, 5.8, 3.5], size=8.5)
    b.image("fig_negative_fk.png", "Негативный тест N08: запрет удаления продукта, на который ссылается резервуар")

    b.h2("7.3 Точность числовых данных")
    b.p("Для объёмов и денежных сумм использован NUMERIC, а не FLOAT. Двоичная плавающая точка не "
        "представляет десятичные дроби точно: 0.1 + 0.2 в double precision не равно 0.3. NUMERIC хранит "
        "десятичное значение без двоичного округления, поэтому суммы документов и остатки сходятся "
        "точно. Генерируемые столбцы total_cost округляют произведение до копейки, а приёмочный скрипт "
        "сравнивает сумму позиций с суммой документа.")
    b.image("fig_numeric.png", "Сравнение точности NUMERIC и double precision")

    b.h2("7.4 Приёмочная проверка")
    b.p("Скрипт 99_acceptance.sql проверяет минимальное количество строк в каждой таблице, наличие "
        "двух материализованных представлений, функции, процедуры и двух триггеров, а также сходимость "
        "остатков и сумм документов. При успехе выводится сообщение ACCEPTANCE PASSED. Проверка "
        "выполнена на итоговом наборе данных.")
    b.image("fig_acceptance.png", "Протокол приёмочной проверки: сообщение ACCEPTANCE PASSED и количество строк")

    # ------------------------------------------------------------------ conclusion
    b.h1("ЗАКЛЮЧЕНИЕ")
    b.p("В результате работы разработана база данных нефтебазы, автоматизирующая учёт и прогноз запасов "
        "нефтепродуктов. Предметная область описана, бизнес-правила формализованы, построена "
        "концептуальная модель IDEF1X из 12 сущностей, выполнена нормализация до 3NF/BCNF и реализована "
        "схема в PostgreSQL 18.6.")
    b.p("Созданы 12 таблиц с первичными и внешними ключами, 17 индексов, два материализованных "
        "представления, функция прогноза с явным курсором, процедура пакетного расчёта и два триггера "
        "учёта остатков. Подготовлены 23 запроса, охватывающие все требуемые конструкции SQL. "
        "Негативные тесты подтвердили работоспособность ограничений, а приёмочная проверка — "
        "сходимость остатков и сумм.")
    b.p("Практическая значимость состоит в том, что система не допускает отрицательных остатков и "
        "переполнения резервуаров, сохраняет историю операций, поддерживает актуальные цены и позволяет "
        "своевременно выявлять дефицит. Развитием работы может стать подключение пользовательского "
        "интерфейса, разграничение прав доступа, автоматическое обновление представлений по расписанию "
        "и расширение прогнозной модели с учётом сезонности.")

    b.h1("СПИСОК ИСПОЛЬЗОВАННЫХ ИСТОЧНИКОВ")
    for i, src in enumerate(C.SOURCES, 1):
        p = b.p(f"{i}. {src}", first_indent=False, align="justify", space_after=4)

    # ------------------------------------------------------------------ appendix A
    b.h1("ПРИЛОЖЕНИЕ А. ПОЛНЫЙ DDL-СКРИПТ СХЕМЫ")
    b.p("Ниже приведён полный текст sql/01_schema.sql, создающего таблицы и ограничения.", first_indent=False)
    b.code((SQL / "01_schema.sql").read_text(encoding="utf-8").strip())

    # ------------------------------------------------------------------ appendix B
    b.h1("ПРИЛОЖЕНИЕ Б. ПРОТОКОЛ ПРИЁМОЧНОЙ ПРОВЕРКИ")
    b.p("Фрагмент фактического вывода sql/99_acceptance.sql, подтверждающий успешное прохождение проверки.",
        first_indent=False)
    acc = (ROOT / "results" / "acceptance.txt").read_text(encoding="utf-8")
    keep = []
    for ln in acc.splitlines():
        keep.append(ln)
        if ln.strip() == "(12 строк)":
            break
    b.code("\n".join(keep))
    b.p("Полный протокол сохранён в файле results/acceptance.txt.", first_indent=False)


def build(toc_pages=None):
    b = Builder(toc_pages)
    build_content(b)
    b.save(DOCX)
    return b


def convert_pdf():
    subprocess.run(["/opt/homebrew/bin/soffice", "--headless", "--convert-to", "pdf",
                    "--outdir", str(DOCS), str(DOCX)],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return PDF


def detect_pages(pdf_path):
    import pymupdf
    doc = pymupdf.open(str(pdf_path))
    texts = []
    for page in doc:
        t = page.get_text("text")
        t = re.sub(r"\s+", " ", t).strip().lower()
        texts.append(t)
    result = {}
    for level, title in TOC_ENTRIES:
        key = re.sub(r"\s+", " ", title).strip().lower()
        found = "—"
        for i in range(2, len(texts)):
            if key in texts[i]:
                found = str(i + 1)
                break
        if found == "—":
            short = key[:45]
            for i in range(2, len(texts)):
                if short in texts[i]:
                    found = str(i + 1)
                    break
        result[title] = found
    return result


def to_markdown(toc_pages):
    lines = ["# Расчётно-графическая работа", "",
             "**Вариант 17. База данных автоматизации учёта и прогноза запасов нефтепродуктов, реализуемых нефтебазой**", ""]
    # Markdown строится независимо от DOCX: заголовки, текст, таблицы, изображения.
    for level, title in TOC_ENTRIES:
        if level == 1:
            lines += [f"## {title}", ""]
    lines += ["", "_Полный текст отчёта сформирован в ReportRGR.docx; исходные SQL-скрипты и результаты — в каталогах sql и results._"]
    MD.write_text("\n".join(lines), encoding="utf-8")


def main():
    print("Сборка 1-го прохода...")
    build({})
    pdf = convert_pdf()
    pages = detect_pages(pdf)
    print("Страницы:", pages)
    print("Сборка 2-го прохода...")
    build(pages)
    pdf = convert_pdf()
    # Проверяем, что PDF создан
    import pymupdf
    d = pymupdf.open(str(pdf))
    print(f"Готово: {DOCX} и {PDF}; страниц: {d.page_count}")
    to_markdown(pages)


if __name__ == "__main__":
    main()
