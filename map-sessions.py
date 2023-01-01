#!/usr/bin/env python3

import pandas as pd
import plotly.data as dt
import plotly.graph_objects as go

pd.set_option(
    "display.max_columns", None,
    "display.max_rows", None,
    "display.width", 0
)

sessions = pd.read_csv("sessions.csv", index_col="iso3")

countries = dt.gapminder().query("year==2007").reset_index()
countries = countries.loc[:, ["iso_alpha", "country"]]
countries = countries.set_index("iso_alpha")

# df = pd.merge(
#     sessions, countries, how="outer", left_index=True, right_index=True
# )
df = sessions.join(countries, how="outer")
df["country"] = df["country"].fillna("Unknown")
df = df.fillna(0)

metric = "pageviews"

fig = go.Figure(
    data=go.Choropleth(
        locations=df.index,
        z=df[metric],
        text=df["country"],
        colorscale="Reds",
        autocolorscale=False,
        reversescale=True,
        marker_line_color="darkgray",
        marker_line_width=0.5,
        colorbar_tickprefix="",
        colorbar_title=metric,
    )
)

fig.update_layout(
    title_text=metric,
    geo=dict(
        showframe=False, showcoastlines=False, projection_type="equirectangular"
    ),
    annotations=[
        dict(
            x=0.55,
            y=0.1,
            xref="paper",
            yref="paper",
            text="",
            showarrow=False,
        )
    ],
)

fig.show()
fig.write_html(f"{metric}.html")
