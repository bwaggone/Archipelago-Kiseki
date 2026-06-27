from __future__ import annotations
from typing import TYPE_CHECKING, NamedTuple, Optional, Dict
from BaseClasses import Item, ItemClassification

import csv
import os
from math import floor

if TYPE_CHECKING:
    from .world import ITGMania

"""
Items in ITGManaia are either charts, or visual mods (appearance options, speed mods, etc).
"""

class ITGManiaItem(Item):
    game = "ITGMania"

class ITGManiaChart():
    def __init__(self, name, style, difficulty, hash):
        self.name = name
        self.style = style
        self.difficulty = difficulty
        self.hash = hash
    name = None
    style = None
    difficulty = None
    hash = None

ALL_CHARTS = None

def get_song_data() -> list[ITGManiaChart]:
    global ALL_CHARTS
    if ALL_CHARTS is not None:
        return ALL_CHARTS

    ALL_CHARTS = []
    seen_names = set()
    with open(os.path.join(os.getcwd(), "worlds/ITGMania/songs.csv"), mode="r", encoding="utf-8") as f:
        reader = csv.reader(f)
        for row in reader:
            chart_name = row[0]
            if chart_name not in seen_names:
                seen_names.add(chart_name)
                ALL_CHARTS.append(ITGManiaChart(chart_name, row[1], row[2], row[3]))
    return ALL_CHARTS

chart_pool = get_song_data()

def create_item(world: ITGMania, name: str) -> ITGManiaItem:
    mod_item = world.itgm_collection.mod_items.get(name)
    if mod_item:
        classification = ItemClassification.filler if "Mirror" in name else ItemClassification.useful
        return ITGManiaItem(name, classification, mod_item, world.player)

    filler = world.itgm_collection.filler_items.get(name)
    if filler:
        return ITGManiaItem(name, ItemClassification.filler, filler, world.player)
    
    chart = world.itgm_collection.item_names_to_id.get(name)
    if chart:
        return ITGManiaItem(name, ItemClassification.progression, chart, world.player)

def create_all_items(world: ITGMania) -> None:
    # Total locations is determined by the number of active locations per selected song
    # e.g., if you've got the 85 and 90 score checks enabled, each song will have 4 locations: -0, -1, -85, -90
    active_suffixes = ["-0", "-1"]
    if world.options.include_85_score_checks:
        active_suffixes.append("-85")
    if world.options.include_90_score_checks:
        active_suffixes.append("-90")
    if world.options.include_96_score_checks:
        active_suffixes.append("-96")
    if world.options.include_98_score_checks:
        active_suffixes.append("-98")
    if world.options.include_99_score_checks:
        active_suffixes.append("-99")
    if world.options.include_quad_score_checks:
        active_suffixes.append("-quad")
    if world.options.include_quint_score_checks:
        active_suffixes.append("-quint")

    num_charts = len(world.starting_songs) + len(world.included_songs)
    location_count = num_charts * len(active_suffixes)

    # 1. Add 1 copy of every song in included_songs (these are the unlockable songs)
    for song_name in world.included_songs:
        world.multiworld.itempool.append(create_item(world, song_name))

    # 2. Add speed/appearance mod items if enabled
    if world.options.enable_mod_items:
        for mod_name in world.itgm_collection.mod_items.keys():
            world.multiworld.itempool.append(create_item(world, mod_name))

    # 3. Fill the remaining spots with filler items
    item_count = len(world.included_songs)
    if world.options.enable_mod_items:
        item_count += len(world.itgm_collection.mod_items)
        
    items_left = location_count - item_count

    for _ in range(max(0, items_left)):
        world.multiworld.itempool.append(create_item(world, world.get_filler_item_name()))