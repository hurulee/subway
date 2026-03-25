"""
MTA Subway Station Scraper
Usage:
  1. Save each line's HTML page from the MTA website
  2. Place all HTML files in the same folder as this script
  3. Name them like: A_train.html, 1_train.html, etc.
  4. Run: python scrape_mta_html.py
  5. Output: mta_subway_stations.csv
"""

from bs4 import BeautifulSoup
import csv
import os
import glob


def parse_features(features_text):
    """Parse the 'Other Station Features' column."""
    text = features_text.lower()

    # Stop type
    if 'local and express' in text or 'local station, express' in text:
        stop_type = 'local_and_express'
    elif 'express' in text:
        stop_type = 'express'
    else:
        stop_type = 'local'

    # Structure
    if 'elevated' in text:
        structure = 'elevated'
    elif 'at grade' in text or 'at-grade' in text:
        structure = 'at_grade'
    elif 'open cut' in text:
        structure = 'open_cut'
    elif 'viaduct' in text:
        structure = 'viaduct'
    else:
        structure = 'subway'

    # ADA
    ada = 'yes' if 'ada accessible' in text else 'no'

    # Terminal
    terminal = 'yes' if 'terminal' in text else 'no'

    return stop_type, structure, ada, terminal


def scrape_html_file(filepath, line_name):
    """Scrape a single HTML file and return list of station dicts."""
    with open(filepath, 'r', encoding='utf-8') as f:
        html = f.read()

    soup = BeautifulSoup(html, 'html.parser')
    stations = []
    sequence = 1

    # Find all table sections — each has an h2 heading above it
    table_divs = soup.find_all('div', class_='mta-mb-500 mta-table')

    for div in table_divs:
        # Get section heading (e.g. "Bronx stations", "Manhattan stations", branch names)
        h2 = div.find('h2')
        section_name = h2.get_text(strip=True) if h2 else 'Main'

        # Find the table inside this div
        table = div.find('table')
        if not table:
            continue

        # Get all rows except header
        rows = table.find_all('tr')[1:]  # skip header row

        for row in rows:
            cols = row.find_all('td')
            if len(cols) < 5:
                continue

            station_name = cols[0].get_text(strip=True)
            transfers = cols[3].get_text(strip=True)
            features = cols[4].get_text(strip=True)

            # Clean up station name (remove BOM character if present)
            station_name = station_name.replace('\ufeff', '').strip()

            if not station_name:
                continue

            stop_type, structure, ada, terminal = parse_features(features)

            stations.append({
                'line': line_name,
                'sequence': sequence,
                'section': section_name,
                'station_name': station_name,
                'stop_type': stop_type,
                'structure': structure,
                'transfers': transfers,
                'ada': ada,
                'terminal': terminal,
            })
            sequence += 1

    return stations


def main():
    # Find all HTML files in uploads directory
    html_files = glob.glob('input/*_train.html')

    if not html_files:
        print("No HTML files found matching pattern '*_train.html'")
        print("Please name your files like: A_train.html, 1_train.html, etc.")
        return

    all_stations = []

    for filepath in sorted(html_files):
        # Extract line name from filename (e.g. "A_train.html" -> "A")
        filename = os.path.basename(filepath)
        line_name = filename.replace('_train.html', '').upper()

        print(f"Processing {filename} -> Line {line_name}...")

        try:
            stations = scrape_html_file(filepath, line_name)
            all_stations.extend(stations)
            print(f"  -> {len(stations)} stations found")
        except Exception as e:
            print(f"  ERROR: {e}")

    if not all_stations:
        print("No stations found!")
        return

    # Write CSV
    output_path = 'output/mta_subway_stations_scraped.csv'
    fieldnames = ['line', 'sequence', 'section', 'station_name',
                  'stop_type', 'structure', 'transfers', 'ada', 'terminal']

    with open(output_path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(all_stations)

    print(f"\nDone! {len(all_stations)} total stations written to {output_path}")
    print(f"Lines processed: {', '.join(sorted(set(s['line'] for s in all_stations)))}")


if __name__ == '__main__':
    main()