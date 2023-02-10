#!/usr/bin/env python3

# from mpl_toolkits.axes_grid1 import make_axes_locatable
from slugify import slugify
import argparse
import geopandas as gpd
import matplotlib.pyplot as plt
import os
import pandas as pd
import re
import sys
import util


def human_format(num):
    num = float("{:.3g}".format(num))
    magnitude = 0
    while abs(num) >= 1000:
        magnitude += 1
        num /= 1000.0
    return "{}{}".format(
        "{:f}".format(num).rstrip("0").rstrip("."),
        ["", "K", "M", "B", "T"][magnitude],
    )


def plot_static(metric, csv_file, img_file):
    try:
        date_range = util.get_date_range(csv_file)
    except ValueError as e:
        print("Can't get date range filename: {csv_file}")
        date_range = ""

    shapefile = os.path.join(
        os.path.expanduser("~"),
        "Downloads",
        "ne_10m_admin_0_map_units",
        "ne_10m_admin_0_map_units.shp",
    )

    color_steps = 9
    color_map = "OrRd"
    # figure in inches (width, height)
    figsize = (16, 10)
    color_water = "lightskyblue"
    description = "Description"

    plt.rcParams["figure.dpi"] = 100
    plt.rcParams["savefig.dpi"] = 150

    f, ax = plt.subplots(figsize=figsize, edgecolor="black")
    # ax.set_aspect('equal')
    ax.set_facecolor(color_water)
    # divider = make_axes_locatable(ax)
    # cax = divider.append_axes("right", size="5%", pad=0.1)

    # Create a GeoDataFrame from the Admin 0 - Countries shapefile
    # available from Natural Earth Data and show a sample of 5 records.
    # We only read the ADM0_A3 and geometry columns, which contain the
    # 3-letter country codes defined in ISO 3166-1 alpha-3 and the
    # country shapes as polygons respectively.
    ne_cols = ["ISO_A3", "NAME", "NAME_LONG", "geometry"]
    ne_data = gpd.read_file(shapefile)
    ne_data = ne_data[ne_cols]
    ne_data = ne_data.to_crs("+proj=robin")

    # ne_data = gpd.read_file(gpd.datasets.get_path("naturalearth_lowres"))
    # ne.data = ne_data[list(map(str.lower, ne_cols))]

    # ne_data.plot(ax=ax, color='white', edgecolor=None, linewidth=1)

    title = util.titlecase(f"{metric} by country")
    if date_range:
        title += " " + date_range

    if not img_file:
        img_file = "{slugify(title)}.jpg"

    # Read google analytics data into dataframe
    ga_data = pd.read_csv(csv_file)
    print(ga_data.sample(5))

    # Next we merge the data frames on the columns containing the
    # 3-letter country codes and show summary statistics as returned
    # from the describe method.
    df = ne_data.merge(ga_data, left_on="ISO_A3", right_on="iso3", how="left")

    # The merge operation above returned a GeoDataFrame. From this data
    # structure it is very easy to create a choropleth map by invoking the
    # plot method. We need to specify the column to plot and since we
    # don't want a continuous color scale we set scheme to equal_interval
    # and the number of classes k to 9. We also set the size of the figure
    # and show a legend in the plot.
    df.plot(
        ax=ax,
        # cax=cax,
        figsize=figsize,
        column=metric,
        cmap=color_map,
        edgecolor="black",
        linewidth=0.1,
        scheme="equal_interval",
        # scheme="percentiles",
        # scheme="quantiles",
        k=color_steps,
        legend=True,
        legend_kwds={
            "loc": "lower left",
            "fmt": "{:.0f}",
            "title": f"{metric.title()}",
            "frameon": False,
        },
        missing_kwds={
            "color": "lightgrey",
            "edgecolor": "red",
            "hatch": "///",
            "label": "No values recorded",
        },
    )

    legend = ax.get_legend()
    legend_texts = legend.get_texts()
    for i, label_text in enumerate(legend_texts[:-1]):
        lower, upper = re.split(r"\s*,\s*", label_text.get_text().strip())
        lower = human_format(float(lower))
        upper = human_format(float(upper))
        label_text.set_text(f"{lower} - {upper}")

    ax.set_facecolor(color_water)
    ax.tick_params(bottom=False, labelbottom=False, left=False, labelleft=False)
    ax.set_title(title, fontdict={"fontsize": 20}, loc="center", pad=12)

    # ax.annotate(description, xy=(0.1, 0.1), size=12, xycoords="figure fraction")
    # ax.text(
    #     0.5,
    #     -0.1,
    #     description,
    #     size=12,
    #     ha="center",
    #     va="baseline",
    #     transform=ax.transAxes,
    #     wrap=True,
    # )

    df["coords"] = df["geometry"].apply(
        lambda x: x.representative_point().coords[0]
    )
    df["area"] = df["geometry"].area

    df = df.sort_values(by="area", ascending=False)

    df.head(25).apply(
        lambda x: ax.annotate(
            text=f"{x['NAME']}\n{human_format(x['pageviews'])}",
            xy=x.coords,
            horizontalalignment="center",
            verticalalignment="center",
        ),
        axis=1,
    )

    if img_file:
        plt.savefig(img_file)

    if sys.stdout.isatty() and "DISPLAY" in os.environ:
        plt.show()


def main():
    pd.set_option(
        "display.max_columns", None,
        "display.max_rows", None,
        "display.width", 0
    )

    parser = argparse.ArgumentParser(
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
        description="Plot data from csv.")
    parser.add_argument("csv_file", help="Input CSV file")
    parser.add_argument("img_file", nargs="?",
        help="Output image file")
    parser.add_argument("--metric", "-m", default="pageviews",
        choices=["sessions", "users" , "pageviews"],
        help="GA metric to be displayed")
    args = parser.parse_args()

    plot_static(args.metric, args.csv_file, args.img_file)


if __name__ == '__main__':
    main()
