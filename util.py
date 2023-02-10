from datetime import datetime
import fiscalyear as fy
import re


def convert_date(date_str):
    return datetime.strptime(date_str, "%Y-%m-%d").strftime("%B %Y")


def get_date_range(file):
    flags = re.IGNORECASE
    mtch = re.search(r"_Q([1-4])_(\d{4}).csv$", file, flags)
    if mtch:
        qtr = int(mtch.group(1))
        year = int(mtch.group(2))
        fiscal_qtr = fy.FiscalQuarter(year, qtr)
        return (
            fiscal_qtr.start.strftime("%B %Y")
            + " to "
            + fiscal_qtr.end.strftime("%B %Y")
        )
    mtch = re.search(
        r"_(\d{4}-\d{2}-\d{2})_(\d{4}-\d{2}-\d{2}).csv", file, flags
    )
    if mtch:
        return (
            convert_date(mtch.group(1)) + " to " + convert_date(mtch.group(2))
        )
    raise ValueError("Can't extract date range from {file}")


def titlecase(text, exceptions="and by the"):
    exceptions = [e.lower() for e in exceptions.split(" ")]
    text = text.split()
    for i, word in enumerate(text):
        lword = word.lower()
        text[i] = word.title() if i == 0 or lword not in exceptions else lword
    return " ".join(text)
