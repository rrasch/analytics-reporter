#!/usr/bin/env python3
#
# https://developers.google.com/analytics/devguides/config/mgmt/v3/quickstart/service-py
# https://stackoverflow.com/questions/59840150/google-analytics-data-to-pandas-dataframe

import httplib2
from apiclient.discovery import build
from oauth2client import client
from oauth2client import file
from oauth2client import tools

from geonamescache import GeonamesCache
from geonamescache.mappers import country

import argparse
import dateparser
import fiscalyear as fy
import logging
import os.path
import pandas as pd
import pprint
import re
import sys


SCOPE = ['https://www.googleapis.com/auth/analytics.readonly']

CLIENT_SECRET_FILE = 'client_secret.json'

CREDENTIAL_FILE = 'credentials.json'


def get_service(api_name, api_version, scope, client_secrets_path):
    """Get a service that communicates to a Google API.

    Args:
        api_name: string The name of the api to connect to.
        api_version: string The api version to connect to.
        scope: A list of strings representing the auth scopes
               to authorize for the connection.
        client_secrets_path: string A path to a valid client secrets file.

    Returns:
        A service that is connected to the specified API.
    """
    # Parse command-line arguments.
    parser = argparse.ArgumentParser(
            formatter_class=argparse.RawDescriptionHelpFormatter,
            parents=[tools.argparser])
    flags = parser.parse_args([])

    dirname = os.path.join(os.environ['HOME'], '.analytics')
    credential_path = os.path.join(dirname, CREDENTIAL_FILE)
    client_secret_file = os.path.join(dirname, CLIENT_SECRET_FILE)

    # Set up a Flow object to be used if we need to authenticate.
    flow = client.flow_from_clientsecrets(
            client_secret_file, scope=SCOPE,
            message=tools.message_if_missing(client_secret_file))

    # Prepare credentials, and authorize HTTP object with
    # them.  If the credentials don't exist or are invalid
    # run through the native client flow. The Storage object
    # will ensure that if successful the good credentials
    # will get written back to a file.
    storage = file.Storage(credential_path)
    credentials = storage.get()
    if credentials is None or credentials.invalid:
        credentials = tools.run_flow(flow, storage, flags)
    http = credentials.authorize(http=httplib2.Http())

    # Build the service object.
    service = build(api_name, api_version, http=http)

    return service


def get_profile_ids(service, account_list=None):
    # Use the Analytics service object to get profile ids.

    # Get a list of all Google Analytics accounts
    # for the authorized user.
    accounts = service.management().accounts().list().execute()

    profile_ids = []

    for account in accounts.get('items'):
        name = account.get('name')
        print(name)

        if account_list and name not in account_list:
            continue

        account_id = account.get('id')

        # Get a list of all views (profiles) for property.
        profiles = service.management().profiles().list(
                accountId=account_id,
                webPropertyId='~all').execute()

        for profile in profiles.get('items'):
            if "master view" not in profile.get('name'):
                continue
            print(profile.get('name'))
            profile_ids.append(profile.get('id'))

    return profile_ids


def get_results(service, profile_id, start_date, end_date):
    # Use the Analytics Service Object to query the Core Reporting API
    # for the number of sessions, users, and pageviews from
    # start_date to end_date.
    return service.data().ga().get(
            ids='ga:' + profile_id,
            start_date=start_date,
            end_date=end_date,
            metrics='ga:sessions,ga:users,ga:pageviews',
            dimensions='ga:countryIsoCode'
            ).execute()


def conv_iso_2_to_3(iso_2):
    return countries[iso_2]['iso3']


def set_int(df):
    cols = list(df.columns)
    df[cols] = df[cols].astype(int)


def create_dataframe(results):
    column_names = []
    for header in results.get('columnHeaders'):
        column_names.append(header.get('name'))
    data = results.get('rows')
    df = pd.DataFrame(data, columns = column_names)
    df = df.set_index('ga:countryIsoCode')
    set_int(df)
    return df


def parse_date(date):
    return dateparser.parse(date).strftime('%Y-%m-%d')


def main():

    fy.setup_fiscal_calendar(start_month=9)
    now = fy.FiscalDateTime.now()
    start_date = now.prev_fiscal_quarter.start.strftime('%Y-%m-%d')
    end_date = now.prev_fiscal_quarter.end.strftime('%Y-%m-%d')
    print(start_date)
    print(end_date)

    parser = argparse.ArgumentParser(
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
        description="Retrieve Google Analytics data.")
    parser.add_argument("-d", "--debug",
        help="Enable debugging messages", action="store_true")
    parser.add_argument("output_file", metavar="OUTPUT_FILE",
        nargs="?",
        default="sessions.csv",
        help="Output CSV file")
    parser.add_argument("-s", "--start-date",
        default=start_date,
        help="Start date")
    parser.add_argument("-e", "--end-date",
        default=end_date,
        help="End date")
    parser.add_argument("-a", "--account-list",
        type=lambda arg: arg.split(','),
        help="Comma separated list of ga accounts")
    args = parser.parse_args()

    pprint.pprint(args)

    if args.start_date != start_date:
        args.start_date = parse_date(args.start_date)
        print(args.start_date)

    if args.end_date != end_date:
        args.end_date = parse_date(args.end_date)
        print(args.end_date)

    pd.set_option('display.max_columns', None)
    pd.set_option('display.max_rows', None)
    pd.set_option('display.max_colwidth', None)
    # pd.set_option('display.float_format', '{:,.0f}'.format)

    gc = GeonamesCache()
    global countries
    countries = gc.get_countries()
    countries['ZZ'] = {'iso3': 'ZZZ'}

    mapper = country(from_key='iso', to_key='iso3')

    scope = ['https://www.googleapis.com/auth/analytics.readonly']

    # Authenticate and construct service.
    service = get_service('analytics', 'v3', scope, 'client_secrets.json')

    profile_ids = get_profile_ids(service, args.account_list)
    pprint.pprint(profile_ids)

    total = pd.DataFrame()

    for profile_id in profile_ids:
        results = get_results(service, profile_id,
            args.start_date, args.end_date)
        df = create_dataframe(results)
        with pd.option_context('display.max_rows', None,
                'display.max_columns', None):
            print(df)
        total = total.add(df, fill_value=0)

    total.index = [conv_iso_2_to_3(i) for i in total.index]
    total.index.name = 'iso3'
    total.columns = [re.sub(r'^ga:', '', col) for col in total.columns]
    set_int(total)

    total.to_csv(args.output_file)

    #print(total)

if __name__ == '__main__':
    main()
