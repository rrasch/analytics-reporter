#!/usr/bin/env python3
#
# https://developers.google.com/analytics/devguides/config/mgmt/v3/quickstart/service-py
# https://stackoverflow.com/questions/59840150/google-analytics-data-to-pandas-dataframe

from datetime import datetime, timedelta

from google.analytics.admin import AnalyticsAdminServiceClient

from google.analytics.data_v1beta import BetaAnalyticsDataClient
from google.analytics.data_v1beta.types import (
    DateRange,
    Dimension,
    Metric,
    MetricType,
    RunReportRequest,
)

from apiclient.discovery import build
from email.mime.application import MIMEApplication
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from geonamescache.mappers import country
from oauth2client import client
from oauth2client import file
from oauth2client import tools
from pprint import pprint
import argparse
import dateparser
import fiscalyear as fy
import httplib2
import logging
import os.path
import pandas as pd
import plot_interactive_map as pim
import plot_static_map as psm
import re
import smtplib
import sys
import yaml


SCOPE = ['https://www.googleapis.com/auth/analytics.readonly']

CLIENT_SECRET_FILE = 'client_secret.json'

CREDENTIAL_FILE = 'credentials.json'

NEW_CRED_FILE = "analytics-ga4.json"

os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = os.path.join(os.environ['HOME'], '.analytics', NEW_CRED_FILE)

def ga4_response_to_df(response):
    dim_len = len(response.dimension_headers)
    metric_len = len(response.metric_headers)
    all_data = []
    for row in response.rows:
        row_data = {}
        for i in range(0, dim_len):
            row_data.update({response.dimension_headers[i].name: row.dimension_values[i].value})
        for i in range(0, metric_len):
            row_data.update({response.metric_headers[i].name: row.metric_values[i].value})
        pprint(row_data)
        all_data.append(row_data)
    df = pd.DataFrame(all_data)
    return df

def print_run_report_response(response):
    """Prints results of a runReport call."""
    # [START analyticsdata_print_run_report_response_header]
    print(f"{response.row_count} rows received")
    for dimensionHeader in response.dimension_headers:
        print(f"Dimension header name: {dimensionHeader.name}")
    for metricHeader in response.metric_headers:
        metric_type = MetricType(metricHeader.type_).name
        print(f"Metric header name: {metricHeader.name} ({metric_type})")
    # [END analyticsdata_print_run_report_response_header]

    # [START analyticsdata_print_run_report_response_rows]
    print("Report result:")
    for rowIdx, row in enumerate(response.rows):
        print(f"\nRow {rowIdx}")
        for i, dimension_value in enumerate(row.dimension_values):
            dimension_name = response.dimension_headers[i].name
            print(f"{dimension_name}: {dimension_value.value}")

        for i, metric_value in enumerate(row.metric_values):
            metric_name = response.metric_headers[i].name
            print(f"{metric_name}: {metric_value.value}")
    # [END analyticsdata_print_run_report_response_rows]

def get_properties() -> list:
    client = AnalyticsAdminServiceClient()
    results = client.list_account_summaries()
    props = []
    for account_summary in results:
        for property_summary in account_summary.property_summaries:
            props.append(property_summary.property)
            print(f"Property resource name: {property_summary.property}")
            print(f"Property display name: {property_summary.display_name}")
            print()
    return props

def get_analytics_v4(start_date, end_date):
    """Runs a report of active users grouped by country."""
    client = BetaAnalyticsDataClient()

    props = get_properties()

    request = RunReportRequest(
        property=props[0],
        dimensions=[
            Dimension(name="country"),
            Dimension(name="city"),
        ],
        metrics=[
            Metric(name="sessions"),
            Metric(name="totalUsers"),
            Metric(name="screenPageViews"),
        ],
        date_ranges=[DateRange(start_date=start_date, end_date=end_date)],
    )
    response = client.run_report(request)
    pprint(response)
    print(ga4_response_to_df(response))
    print_run_report_response(response)



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
    # accounts = service.management().accounts().list().execute()
    accounts = service.management().accountSummaries().list().execute()

    profile_ids = []

    for account in accounts.get('items'):
        name = account.get('name')
        account_id = account.get('id')
        print(f"Account: {name} ({account_id})")
        pprint(account)

        if account_list and name not in account_list:
            continue


        # Get a list of all views (profiles) for property.
        profiles = service.management().profiles().list(
                accountId=account_id,
                webPropertyId='~all').execute()

        for profile in profiles.get('items'):
            print(f"    Profile: {profile.get('name')}")
#             if "master view" not in profile.get('name'):
#                 continue
#             print(f"    Profile: {profile.get('name')}")
            #pprint(profile)
            print()
            profile_ids.append(profile.get('id'))

    exit(1)
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


def get_results_v4(service, profile_id, start_date, end_date):
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

    metrics = ["ga:sessions", "ga:users", "ga:pageviews"]
    dimensions = ['ga:countryIsoCode']

    return (
        analytics.reports()
        .batchGet(
            body={
                "reportRequests": [
                    {
                        "viewId": VIEW_ID,
                        "dateRanges": [
                            {"startDate": start_date, "endDate": end_date}
                        ],
                        "metrics": [
                            {"expression": metric} for metric in metrics
                        ],
                        "dimensions": [
                            {"name": dimension} for dimension in dimensions
                        ],
                    }
                ]
            }
        )
        .execute()
    )



def conv_iso_2_to_3(iso_2):
    # return countries[iso_2]['iso3']
    if iso_2 == "ZZ":
        return "ZZZ"
    else:
        return country(from_key='iso', to_key='iso3')(iso_2)


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


def get_analytics(account_list, start_date, end_date, output_file):
    scope = ['https://www.googleapis.com/auth/analytics.readonly']

    # Authenticate and construct service.
    service = get_service('analytics', 'v3', scope, 'client_secrets.json')

    reporting_service = get_service("analyticsreporting", "v4", scope, "client_secrets.json")

    profile_ids = get_profile_ids(service, account_list)
    print("profile ids:")
    pprint(profile_ids)

    total = pd.DataFrame()

    for profile_id in profile_ids:
        results = get_results_v4(reporting_service, profile_id, start_date, end_date)
        df = create_dataframe(results)
        print(df)
        total = total.add(df, fill_value=0)

    total.index = [conv_iso_2_to_3(i) for i in total.index]
    total.index.name = 'iso3'
    total.columns = [re.sub(r'^ga:', '', col) for col in total.columns]
    set_int(total)

    total.to_csv(output_file)


def change_ext(filename, new_ext):
    basename, ext = os.path.splitext(filename)
    return f"{basename}.{new_ext}"


def sendmail(mailfrom, mailto, start_date, end_date, url, attachments):
    subject = (
        "Google Analystics Choropleth Maps for "
        + start_date
        + " to "
        + end_date
    )

    msg = MIMEMultipart()
    msg["From"] = mailfrom
    msg["To"] = ", ".join(mailto)
    msg["Subject"] = subject

    body = subject + "\n\n"

    parts = []
    for attachment in attachments:
        basename = os.path.basename(attachment)
        ishtml = basename.endswith("html")

        if ishtml:
            body += "Interactive Map:\n"
        else:
            body += "Static Map:\n"
        body += f"{url}/{basename}\n\n"

        if ishtml:
            continue

        with open(attachment, "rb") as f:
            part = MIMEApplication(f.read(), Name=basename)
        part["Content-Disposition"] = f"attachment; filename={basename}"
        parts.append(part)

    msg.attach(MIMEText(body, "plain"))
    for part in parts:
        msg.attach(part)

    try:
        smtp = smtplib.SMTP("localhost")
        smtp.sendmail(mailfrom, mailto, msg.as_string())
        print("Sent email.")
    except Exception as e:
        print(f"Could not send mail: {e}")


def main():
    pd.set_option('display.max_columns', None)
    pd.set_option('display.max_rows', None)
    pd.set_option('display.max_colwidth', None)
    # pd.set_option('display.float_format', '{:,.0f}'.format)

    with open("config.yaml") as f:
        config = yaml.safe_load(f)
    config = {k.lstrip(":"): v for k, v in config.items()}

    fy.setup_fiscal_calendar(start_month=9)
    now = fy.FiscalDateTime.now() + timedelta(1)
    start_date = now.prev_fiscal_quarter.start.strftime('%Y-%m-%d')
    end_date = now.prev_fiscal_quarter.end.strftime('%Y-%m-%d')

    parser = argparse.ArgumentParser(
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
        description="Retrieve Google Analytics data.")
    parser.add_argument("-d", "--debug",
        help="Enable debugging messages", action="store_true")
    parser.add_argument("output_file", metavar="OUTPUT_FILE",
        nargs="?",
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

    pprint(f"command line args: {args}")

    if args.start_date != start_date:
        start_date = parse_date(args.start_date)

    if args.end_date != end_date:
        end_date = parse_date(args.end_date)

    if args.output_file:
        output_file = args.output_file
#     else:
#         account = "-".join(args.account_list) if args.account_list else "all"
#         output_file = os.path.join(
#             config["output_dir"],
#             f"sessions_{account}_{start_date}_{end_date}.csv",
#         )
# 
#     output_dir = os.path.dirname(output_file)

    print(f"start date: {start_date}")
    print(f"end date: {end_date}")
#     print(f"output_file: {output_file}")
#     print(f"output_dir: {output_dir}")

    get_analytics_v4(start_date, end_date)

#     if os.path.isfile(output_file):
#         print(f"Output file {output_file} already exists.")
#     else:
#         if not (os.path.isdir(output_dir) and os.access(output_dir, os.W_OK)):
#             print(f"{output_dir} is not a writable directory.")
#             exit(1)
#         get_analytics(args.account_list, start_date, end_date, output_file)

#     html_file = change_ext(output_file, "html")
#     if not os.path.isfile(html_file):
#         pim.plot_interactive("pageviews", output_file, html_file)
# 
#     img_file = change_ext(output_file, "jpg")
#     if not os.path.isfile(img_file):
#         psm.plot_static("pageviews", output_file, img_file)
# 
#     sendmail(
#         config["mailfrom"],
#         config["mailto"],
#         start_date,
#         end_date,
#         config["reports_url"],
#         [html_file, img_file],
#     )


if __name__ == '__main__':
    main()
