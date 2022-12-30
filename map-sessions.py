#!/usr/bin/env python3

import pandas as pd
import plotly.graph_objects as go

df = pd.read_csv("sessions.csv")

metric = "pageviews"

fig = go.Figure(
    data=go.Choropleth(
        locations=df["iso3"],
        z=df[metric],
        text=df["iso3"],
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
