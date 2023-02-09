#!/usr/bin/env python3

from datetime import datetime
import argparse
import fiscalyear as fy
import os
import pandas as pd
import plotly.graph_objects as go
import pycountry
import re
import sys


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
        r"_(\d{4}-\d{2}-\d{2})_(\d{4}-\d{2}-\d{2}).csv", file, flags)
    if mtch:
        return (
            convert_date(mtch.group(1))
            + " to "
            + convert_date(mtch.group(2))
        )
    raise ValueError("Can't extract date range from {file}")


def plot_interactive(metric, csv_file, html_file):
    date_range = get_date_range(csv_file)

    if not html_file:
        html_file = f"{args.metric}.html"

    fy.setup_fiscal_calendar(start_month=9)

    pd.set_option(
        "display.max_columns",
        None,
        "display.max_rows",
        None,
        "display.width",
        0,
    )

    sessions = pd.read_csv(csv_file, index_col="iso3")

    countries = [
        [country.alpha_3, country.name] for country in pycountry.countries
    ]
    countries = pd.DataFrame(countries, columns=["iso3", "name"])
    countries = countries.set_index("iso3")

    df = sessions.join(countries, how="outer")

    df = df.fillna(0)

    df = df.sort_values(by=[metric], ascending=False)

    title = {
        "pageviews": "Views",
        "sessions": "Sessions",
        "users": "Users",
    }

    fig = go.Figure(
        data=go.Choropleth(
            locations=df.index,
            z=df[metric],
            text=df["name"],
            hovertemplate="<b>%{text}</b><br>%{z}<extra></extra>",
            colorscale="Reds",
            autocolorscale=False,
            reversescale=False,
            marker_line_color="darkgray",
            marker_line_width=0.5,
            colorbar_tickprefix="",
            colorbar_title=title[metric],
        )
    )

    labels = [name if i < 10 else None for i, name in enumerate(df["name"])]

    fig.add_trace(
        go.Scattergeo(
            locations=df.index,
            text=labels,
            mode="text",
            hoverinfo="skip",
        )
    )

    annotation_text = f"Top ten countries for {title[metric]}:<br>"
    for i in range(0, 10):
        annotation_text += f"<br>{i+1}. {labels[i]}"

    fig.update_layout(
        title_text=f"{title[metric]} by Country for {date_range}",
        geo=dict(
            showframe=True,
            showcoastlines=True,
            projection_type="equirectangular",
        ),
        annotations=[
            dict(
                x=0.15,
                y=0.35,
                xref="paper",
                yref="paper",
                align="left",
                font=dict(
                    size=14,
                ),
                text=annotation_text,
                showarrow=False,
            )
        ],
    )

    if html_file:
        fig.write_html(html_file)

    if sys.stdout.isatty() and "DISPLAY" in os.environ:
        fig.show()


def main():
    parser = argparse.ArgumentParser(
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
        description="Plot data from csv using plotly.")
    parser.add_argument("csv_file", help="Input CSV file")
    parser.add_argument("html_file", nargs="?",
        help="Output HTML file")
    parser.add_argument("--metric", "-m", default="pageviews",
        choices=["sessions", "users" , "pageviews"],
        help="GA metric to be displayed")
    args = parser.parse_args()

    plot_interactive(args.metric, args.csv_file, args.html_file)


if __name__ == '__main__':
    main()
