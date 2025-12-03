#!/usr/bin/env python3
"""
upload_to_box.py — Upload a file to Box using rclone and box_links.py.

Usage:
    ./upload_to_box.py localfile.pdf box:folder/path [--remote-name NAME] [--overwrite]

Example:
    ./upload_to_box.py report.pdf box:shared/reports --remote-name final.pdf
"""

import argparse
import logging
import sys
from pathlib import Path

from box_links import upload_and_get_link


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "Upload a file to Box using rclone and generate a shared link."
        )
    )

    parser.add_argument(
        "local_file",
        help="Path to the local file to upload",
    )

    parser.add_argument(
        "remote_folder",
        help="Box remote folder (e.g. 'box:shared/reports')",
    )

    parser.add_argument(
        "--remote-name",
        default=None,
        help="Filename to use on Box (default: same as local filename)",
    )

    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Overwrite the file on Box if it already exists",
    )

    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Enable debug logging",
    )

    return parser.parse_args()


def main():
    args = parse_args()

    # Configure logging
    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(levelname)s: %(message)s",
    )

    local_path = Path(args.local_file)
    if not local_path.exists():
        logging.error("Local file does not exist: %s", local_path)
        sys.exit(1)

    logging.info("Uploading %s to %s", local_path, args.remote_folder)

    try:
        link = upload_and_get_link(
            str(local_path),
            args.remote_folder,
            remote_filename=args.remote_name,
            overwrite=args.overwrite,
        )
    except Exception as e:
        logging.error("Upload or link generation failed: %s", e)
        sys.exit(2)

    if link is None:
        logging.error("Upload failed or link could not be generated.")
        sys.exit(3)

    print(link)
    return 0


if __name__ == "__main__":
    sys.exit(main())
