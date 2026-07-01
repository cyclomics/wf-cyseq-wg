#!/usr/bin/env python
"""
Finalizes the report after collecting all upstream processes.
Merges multiple JSON fragments into a single data structure and injects it into HTML.
"""

import argparse
import glob
import json
import os
import re
from typing import Dict, List

import yaml


def load_report_data(json_file: str) -> dict:
    """Load report data from JSON file."""
    with open(json_file) as f:
        return json.load(f)


def merge_report_fragments(json_paths: List[str]) -> Dict:
    merged_data = {"tabs": [], "cards": [], "plots": []}

    for path in json_paths:
        data = load_report_data(path)

        if "variant-table" in data:
            merged_data["tabs"].append(data["variant-table"])
        else:
            for key in ["cards", "plots"]:
                if key in data:
                    merged_data[key].extend(data[key])

            for key in ["sample_id", "generation_time"]:
                if key in data:
                    merged_data[key] = data[key]

    return merged_data


def calculate_duplication_rate(yaml_file: str) -> float:
    """
    Duplication rate = failed.grouped / run

    YAML format:
        failed:
          grouped: int
        run: int
    """
    with open(yaml_file) as f:
        data = yaml.safe_load(f) or {}

    try:
        grouped_failed = data["failed"]["grouped"]
        total_run = data["run"]
    except KeyError as e:
        raise ValueError(f"Missing expected key in YAML: {e}")

    if total_run == 0:
        return 0.0

    return (grouped_failed / total_run) * 100


def build_duplication_card(rate: float) -> dict:
    """Format duplication rate card."""
    return {
        "name": "Duplication rate",
        "value": f"{rate:.2f}%",
        "tooltip": "Percentage of consensus reads that were marked as read duplicates based on mapping position.",
    }


def inject_into_html(report_data: dict, html_file: str, output_file: str) -> None:
    """Inject finalized report_data as JSON into the HTML and write output."""
    report_data["final"] = True
    json_data = json.dumps(report_data)

    with open(html_file) as f:
        html = f.read()

    html = re.sub(
        r'<script id="embedded-data" type="application/json">.*?</script>',
        lambda _: (
            f'<script id="embedded-data" type="application/json">{json_data}</script>'
        ),
        html,
        flags=re.S,
    )

    with open(output_file, "w") as f:
        f.write(html)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", nargs="+", required=True)
    parser.add_argument("--yaml", required=True)
    parser.add_argument("--html", required=True)
    parser.add_argument("--sample_id", required=True)
    parser.add_argument(
        "--epi2me_report",
        action="store_true",
        help="Generate timestamped report for EPI2ME",
    )
    parser.add_argument("--clean_dir", type=str, required=False)

    args = parser.parse_args()

    # Merge JSON fragments
    final_report_data = merge_report_fragments(args.json)

    # Add duplication card
    try:
        dup_rate = calculate_duplication_rate(args.yaml)
        final_report_data["cards"].append(build_duplication_card(dup_rate))
    except Exception as e:
        print(f"[WARN] Could not compute duplication rate: {e}")

    # Inject into HTML
    inject_into_html(final_report_data, args.html, f"report_{args.sample_id}.html")

    # Cleanup
    if args.epi2me_report and args.clean_dir and os.path.exists(args.clean_dir):
        search_pattern = os.path.join(args.clean_dir, f"report_{args.sample_id}_*.html")

        for old_file in glob.glob(search_pattern):
            print(f"Attempting to delete stale stream report: {old_file}")
            try:
                os.remove(old_file)
            except OSError as e:
                print(f"Skipping locked file: {old_file}. Error: {e}")
    else:
        print(
            f"No clean directory specified or directory does not exist: {args.clean_dir}"
        )


if __name__ == "__main__":
    main()
