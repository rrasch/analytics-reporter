#!/usr/bin/env python3

import pandas as pd
import plotly.graph_objects as go
import pycountry

pd.set_option(
    "display.max_columns", None,
    "display.max_rows", None,
    "display.width", 0
)

metric = "pageviews"

sessions = pd.read_csv("sessions.csv", index_col="iso3")

countries = [[country.alpha_3, country.name] for country in pycountry.countries]
countries = pd.DataFrame(countries, columns=['iso3', 'name'])
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
        hovertemplate="<b>%{text}</b><br>%{z}",
        colorscale="Reds",
        autocolorscale=False,
        reversescale=True,
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
    title_text=f"{title[metric]}",
    geo=dict(
        showframe=True, showcoastlines=True, projection_type="equirectangular"
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

fig.show()
fig.write_html(f"{metric}.html")
