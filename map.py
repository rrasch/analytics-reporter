#!/usr/bin/env python3

# Load the necessary modules and specify the files for input and output, set the number of colors to use, the size of the figure in inches (width, height) and meta information about what is displayed.

import geopandas as gpd
import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import os

from slugify import slugify

from mpl_toolkits.axes_grid1 import make_axes_locatable

# from mpl_toolkits.basemap import Basemap

#datafile = os.path.expanduser('~/data/worldbank/API_IT.NET.USER.ZS_DS2_en_csv_v2.csv')
datafile = os.path.expanduser('sessions.csv')
shapefile = os.path.expanduser('~/data/geo/naturalearthdata.com/ne_10m_admin_0_countries_lakes/countries/ne_10m_admin_0_countries_lakes.shp')

#colors = 9
colors = 6
cmap = 'OrRd'
#figsize = (16, 10)
figsize = (10, 10)
year = '2016'
#cols = ['Country Name', 'Country Code', year]
#cols = ['ga:countryIsoCode', 'ga:country', 'ga:sessions']
cols = ['ga:countryIsoCode', 'ga:sessions']
#title = 'Individuals using the Internet (% of population) in {}'.format(year)
title = 'Sessions by Country'
imgfile = 'img/{}.png'.format(slugify(title))

description = '''
Individuals who have used the Internet from any location in the last 3 months via any device based on the International Telecommunication Union, World Telecommunication/ICT Development Report and database. Data: World Bank - worldbank.org • Author: Ramiro Gómez - ramiro.org'''.strip()

f, ax = plt.subplots(figsize=figsize, edgecolor='k')
#f, ax = plt.subplots()

ax.set_aspect('equal')

water = 'lightskyblue'
earth = 'tan'

ax.set_facecolor(water)

divider = make_axes_locatable(ax)

# cax = divider.append_axes("right", size="5%", pad=0.1)


# Create a GeoDataFrame from the Admin 0 - Countries shapefile available from Natural Earth Data and show a sample of 5 records. We only read the ADM0_A3 and geometry columns, which contain the 3-letter country codes defined in ISO 3166-1 alpha-3 and the country shapes as polygons respectively.
#gdf = gpd.read_file(shapefile)[['ADM0_A3', 'geometry']].to_crs('+proj=robin')
#gdf = gpd.read_file(shapefile)[['ISO_A2', 'geometry']].to_crs('+proj=robin')
#gdf = gpd.read_file(shapefile)[['ISO_A2', 'geometry']].to_crs('EPSG:3395')
gdf = gpd.read_file(shapefile)
gdf = gdf[(gdf.POP_EST>0) & (gdf.NAME!="Antarctica")]
gdf = gdf[['ISO_A2', 'geometry']].to_crs('EPSG:3395')
# gdf = gpd.read_file(shapefile)[['ISO_A2', 'geometry']]
print(gdf.sample(5))

gdf.plot(ax=ax, color='white', edgecolor=None, linewidth=1)


# Next read the datafile downloaded from the World Bank Open Data site and create a pandas DataFrame that contains values for Country Code, Country Name and the percentages of Internet users in the year 2016.
#df = pd.read_csv(datafile, skiprows=4, usecols=cols)
df = pd.read_csv(datafile, usecols=cols)
print(df.sample(5))

# Next we merge the data frames on the columns containing the 3-letter country codes and show summary statistics as returned from the describe method.
#merged = gdf.merge(df, left_on='ADM0_A3', right_on='Country Code')
merged = gdf.merge(df, left_on='ISO_A2', right_on='ga:countryIsoCode')
print(merged.describe())
print(merged.sample(5))
merged.to_csv('merged.csv')

# merged.set_value(2, 'ga:sessions', None)
# merged.set_value(4, 'ISO_A2', None)
# 
# print(merged[merged.isna().any(axis=1)])
# exit(1)

"""
The merge operation above returned a GeoDataFrame. From this data structure it is very easy to create a choropleth map by invoking the plot method. We need to specify the column to plot and since we don't want a continuous color scale we set scheme to equal_interval and the number of classes k to 9. We also set the size of the figure and show a legend in the plot.
"""
#merged.dropna().plot(ax=ax, column='ga:sessions', cmap=cmap, scheme='equal_interval', k=colors, legend=True)
# merged.dropna().plot(ax=ax, column='ga:sessions', cmap=cmap, scheme='percentiles', k=colors, legend=True, legend_kwds={'loc': 'lower left'})
# merged.dropna().plot(ax=ax, column='ga:sessions', cmap=cmap, legend=True, legend_kwds={'loc': 'lower left'})
#merged.dropna().plot(ax=ax, column='ga:sessions', cmap=cmap, scheme='percentiles', k=colors, legend=True)
#merged.dropna().plot(ax=ax, cax=cax, column='ga:sessions', cmap=cmap, legend=True)
merged.dropna().plot(ax=ax, column='ga:sessions', cmap=cmap)


# merged[merged.isna().any(axis=1)].plot(ax=ax, color='#fafafa', hatch='///')

ax.set_xlabel('x label')
ax.set_ylabel('y label')
#ax.legend()
ax.set_title(title, fontdict={'fontsize': 20}, loc='center', pad=12)
#ax.annotate(description, xy=(0.5, 0.5), size=12, xycoords='figure fraction')
#ax.annotate(description, xy=(0.15, 0.05), size=12, xycoords='figure fraction')
ax.text(0.5, -0.1, description, size=12, ha='center', va='baseline', transform=ax.transAxes, wrap=True)

#ax.set_axis_off()
ax.add_artist(ax.patch)
ax.patch.set_zorder(-1)
#ax.set_xlim([-1.5e7, 1.7e7])
#ax.get_legend().set_bbox_to_anchor((.12, .4))
#ax.get_legend().set_bbox_to_anchor((-0.05, 0.3))
# ax.get_figure()

ax.spines['bottom'].set_color('Red')
ax.spines['top'].set_color('0.5')
ax.spines['right'].set_color('0.5')
ax.spines['left'].set_color('0.5')

plt.show()

