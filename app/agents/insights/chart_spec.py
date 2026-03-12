"""Build chart specs from text2sql query results for time-series and categorical insights."""
from typing import List, Dict, Any, Optional
import re
from datetime import datetime, date


# Column name patterns: time/period vs numeric value
TIME_LIKE_PATTERNS = re.compile(
    r"^(month|date|period|year|quarter|week|month_year|label|bucket|bucket_label)$",
    re.I,
)
VALUE_LIKE_PATTERNS = re.compile(
    r"^(amount|sum|total|rent|collected|revenue|avg|average|count|value)$",
    re.I,
)
# Also match partials: month_*, *_month, amount_*, total_*, etc.
TIME_LIKE_KEYWORDS = ("month", "date", "period", "year", "quarter", "label", "bucket")
VALUE_LIKE_KEYWORDS = ("amount", "sum", "total", "rent", "collected", "revenue", "avg", "average", "count", "value")


def _is_time_like_column(col: str) -> bool:
    col_lower = col.lower().replace("_", " ")
    if TIME_LIKE_PATTERNS.match(col.strip()):
        return True
    return any(k in col_lower for k in TIME_LIKE_KEYWORDS)


def _is_value_like_column(col: str) -> bool:
    col_lower = col.lower().replace("_", " ")
    if VALUE_LIKE_PATTERNS.match(col.strip()):
        return True
    return any(k in col_lower for k in VALUE_LIKE_KEYWORDS)


def _coerce_number(v: Any) -> Optional[float]:
    if v is None:
        return None
    if isinstance(v, (int, float)):
        return float(v)
    try:
        return float(str(v).replace(",", "").strip())
    except (ValueError, TypeError):
        return None


def _format_label(v: Any) -> str:
    if v is None:
        return ""
    if isinstance(v, (datetime, date)):
        return v.strftime("%b %Y") if hasattr(v, "strftime") else str(v)
    s = str(v).strip()
    if len(s) > 20:
        return s[:17] + "..."
    return s


def build_chart_spec(
    data: List[Dict[str, Any]],
    question: str = "",
) -> Optional[Dict[str, Any]]:
    """
    From a list of row dicts (e.g. from text2sql), produce a chart spec if the data
    looks chartable: time/category column + numeric column.
    Returns None if data is empty or not chartable.
    """
    if not data or not isinstance(data, list):
        return None
    rows = data[:50]  # cap for chart
    if not rows:
        return None
    first = rows[0]
    if not isinstance(first, dict):
        return None
    columns = list(first.keys())
    if len(columns) < 2:
        return None

    # Prefer: first column = label, second = value (common for generated SQL)
    label_col: Optional[str] = None
    value_col: Optional[str] = None
    for col in columns:
        if label_col is None and (_is_time_like_column(col) or _is_value_like_column(col)):
            if _is_time_like_column(col):
                label_col = col
            elif _is_value_like_column(col) and value_col is None:
                value_col = col
    for col in columns:
        if value_col is None and _is_value_like_column(col):
            value_col = col
        if label_col is None and col != value_col:
            label_col = col
    if not value_col:
        for col in columns:
            vals = [row.get(col) for row in rows if row.get(col) is not None]
            if vals and all(_coerce_number(v) is not None for v in vals):
                value_col = col
                break
    if not label_col:
        label_col = columns[0]
    if not value_col:
        value_col = columns[1] if len(columns) > 1 else None
    if not label_col or not value_col:
        return None

    labels: List[str] = []
    values: List[float] = []
    for row in rows:
        lbl = _format_label(row.get(label_col))
        num = _coerce_number(row.get(value_col))
        if num is not None:
            labels.append(lbl)
            values.append(num)

    if not labels or not values or len(labels) != len(values):
        return None

    # Prefer line for 5+ points (time series), bar for fewer or categorical
    chart_type = "line" if len(labels) >= 5 else "bar"
    title = (question.strip() or "Insight").rstrip("?.")
    if len(title) > 60:
        title = title[:57] + "..."
    return {
        "chartType": chart_type,
        "labels": labels,
        "values": values,
        "title": title or "Rent over time",
        "valueLabel": value_col,
    }
