from typing import Dict, List, Set
from collections import ChainMap

from .items import ALL_CHARTS, ITGManiaChart

class ITGManiaCollections:
    """Contains all the data of ITGMania, dumped from charts.csv"""
    STARTING_CODE = 57300000


    chart_items: Dict[str, int] = {}
    song_locations: Dict[str, int] = {}

    filler_items: Dict[str, int] = {
        "Bonus Percentage": STARTING_CODE + 20000,
    }

    mod_items: Dict[str, int] = {
        "Mirror": STARTING_CODE + 15000,
        "Left Right Mirror": STARTING_CODE + 15001,
        "Up Down Mirror": STARTING_CODE + 15002,
        "Speed 350bpm": STARTING_CODE + 15003,
        "Speed 450bpm": STARTING_CODE + 15004,
        "Speed 550bpm": STARTING_CODE + 15005,
        "Speed 650bpm": STARTING_CODE + 15006,
        "Speed 750bpm": STARTING_CODE + 15007,
        "Speed Any BPM": STARTING_CODE + 15008,
        "90% Mini": STARTING_CODE + 15009,
        "70% Mini": STARTING_CODE + 15010,
        "50% Mini": STARTING_CODE + 15011,
        "Any Mini": STARTING_CODE + 15012,
        "Dark Filter": STARTING_CODE + 15013,
        "Darker Filter": STARTING_CODE + 15014,
        "Darkest Filter": STARTING_CODE + 15015,
    }

    filler_item_weights: Dict[str, int] = {
        "Bonus Percentage": 1,
    }

    item_names_to_id: ChainMap = ChainMap(
        {c.name: 57300001 + i for i, c in enumerate(ALL_CHARTS)},
        filler_items,
        mod_items
    )
    location_names_to_id: ChainMap = ChainMap(song_locations)

    def __init__(self) -> None:
        for chart in ALL_CHARTS:
            self.song_locations[f"{chart.name}-0"] = self.STARTING_CODE
            self.song_locations[f"{chart.name}-1"] = self.STARTING_CODE + 1
            self.song_locations[f"{chart.name}-85"] = self.STARTING_CODE + 2
            self.song_locations[f"{chart.name}-90"] = self.STARTING_CODE + 3
            self.song_locations[f"{chart.name}-96"] = self.STARTING_CODE + 4
            self.song_locations[f"{chart.name}-98"] = self.STARTING_CODE + 5
            self.song_locations[f"{chart.name}-99"] = self.STARTING_CODE + 6
            self.song_locations[f"{chart.name}-quad"] = self.STARTING_CODE + 7
            self.song_locations[f"{chart.name}-quint"] = self.STARTING_CODE + 8
            self.STARTING_CODE += 10
