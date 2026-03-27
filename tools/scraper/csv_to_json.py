"""
Convert mta_stations_merged.csv → one JSON file per line in assets/data/nyc/.

Track positions are assigned linearly: station 1 → 0.02, last → 0.98.

Passenger counts are derived from 2024 ridership, scaled per-line so the
busiest station on each line maps to 30 and the quietest non-zero station
maps to 2.  Terminal stations (passengers=0 in the game) are set to 0.
"""

import csv, json, os, re

CSV_PATH  = os.path.join(os.path.dirname(__file__), 'output', 'mta_stations_merged.csv')
OUT_DIR   = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'data', 'nyc')

LINE_NAMES = {
    '1': '1 Train', '2': '2 Train', '3': '3 Train',
    '4': '4 Train', '5': '5 Train', '6': '6 Train', '7': '7 Train',
    'A': 'A Train', 'B': 'B Train', 'C': 'C Train', 'D': 'D Train',
    'E': 'E Train', 'F': 'F Train', 'G': 'G Train', 'J': 'J Train',
    'L': 'L Train', 'M': 'M Train', 'N': 'N Train', 'Q': 'Q Train',
    'R': 'R Train', 'W': 'W Train', 'Z': 'Z Train',
    'S_B': 'S Train (Franklin Ave)',
    'S_M': 'S Train (42nd St)',
    'S_Q': 'S Train (Rockaway)',
}

def parse_ridership(s):
    """Parse ridership string like '1,385,093' → int, or 0 if missing."""
    s = s.strip().replace(',', '')
    return int(s) if s.isdigit() else 0

def scale_passengers(ridership, max_ridership):
    """Scale ridership to game passenger count [2, 30], or 0 for terminals."""
    if ridership == 0:
        return 0
    if max_ridership == 0:
        return 0
    ratio = ridership / max_ridership
    return max(2, round(ratio * 30))

def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    with open(CSV_PATH, newline='', encoding='utf-8') as f:
        rows = list(csv.DictReader(f))

    # Group by line, preserving sequence order.
    by_line = {}
    for row in rows:
        line = row['line']
        by_line.setdefault(line, []).append(row)
    for line in by_line:
        by_line[line].sort(key=lambda r: int(r['sequence']))

    for line, stations in by_line.items():
        n = len(stations)

        # Per-line ridership max (excluding terminals for scaling).
        ridershipValues = [
            parse_ridership(s['ridership_2024'])
            for s in stations
            if s['terminal'].strip().lower() != 'yes'
        ]
        max_ridership = max(ridershipValues) if ridershipValues else 1

        station_list = []
        for i, s in enumerate(stations):
            track_pos = round(0.02 + i / (n - 1) * 0.96, 6) if n > 1 else 0.5

            is_terminal = s['terminal'].strip().lower() == 'yes'
            ridership   = parse_ridership(s['ridership_2024'])
            passengers  = 0 if is_terminal else scale_passengers(ridership, max_ridership)

            entry = {
                'name':           s['station_name'].strip(),
                'stop_type':      s['stop_type'].strip(),
                'passengers':     passengers,
                'track_position': track_pos,
                'lat':            float(s['gtfs_lat']) if s['gtfs_lat'] else None,
                'lon':            float(s['gtfs_lon']) if s['gtfs_lon'] else None,
            }
            # Drop null lat/lon
            if entry['lat'] is None:
                del entry['lat']
                del entry['lon']

            station_list.append(entry)

        filename   = line.lower() + '_train.json'
        line_name  = LINE_NAMES.get(line, f'{line} Train')
        out_path   = os.path.join(OUT_DIR, filename)

        data = {
            'system':   'nyc',
            'line':     line,
            'name':     line_name,
            'stations': station_list,
        }

        with open(out_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2)

        print(f'  {filename}: {n} stations')

    print(f'\nWrote {len(by_line)} files to {os.path.abspath(OUT_DIR)}')

if __name__ == '__main__':
    main()
