from collections.abc import Mapping
from typing import Any

# Imports of base Archipelago modules must be absolute.
from worlds.AutoWorld import World

# Imports of your world's files must be relative.
from . import items, locations, regions, rules, web_world, ITGManiaCollection
from . import options as itgm_options

# APQuest will go through all the parts of the world api one step at a time,
# with many examples and comments across multiple files.
# If you'd rather read one continuous document, or just like reading multiple sources,
# we also have this document specifying the entire world api:
# https://github.com/ArchipelagoMW/Archipelago/blob/main/docs/world%20api.md


# The world class is the heart and soul of an apworld implementation.
# It holds all the data and functions required to build the world and submit it to the multiworld generator.
# You could have all your world code in just this one class, but for readability and better structure,
# it is common to split up world functionality into multiple files.
# This implementation in particular has the following additional files, each covering one topic:
# regions.py, locations.py, rules.py, items.py, options.py and web_world.py.
# It is recommended that you read these in that specific order, then come back to the world class.
class ITGMania(World):
    """
    ITGMania is a rhythm game engine. While the world references this specific engine, it can be compatible with others,
    dependent on if the engine and theme can accept the relevant module.
    """
    game = "ITGMania"

    # The WebWorld is a definition class that governs how this world will be displayed on the website.
    web = web_world.ITGManiaWebWorld()

    # This is how we associate the options defined in our options.py with our world.
    options_dataclass = itgm_options.ITGManiaOptions
    options: itgm_options.ITGManiaOptions

    starting_songs: list[str]
    included_songs: list[str]

    item_name_groups = {
        "Songs": {c.name for c in ITGManiaCollection.ALL_CHARTS},
        "Mods": {name for name in ITGManiaCollection.ITGManiaCollections.mod_items.keys()},
    }

    def generate_early(self) -> None:
        from .items import get_song_data
        from Options import OptionError

        available_charts = get_song_data()

        num_charts = self.options.number_of_charts.value
        num_starting = min(self.options.number_of_starting_charts.value, num_charts)

        if len(available_charts) < num_charts:
            raise OptionError(f"Not enough charts found in charts.csv to fulfill the requested {num_charts} charts (found {len(available_charts)} available charts).")

        selected_charts = self.random.sample(available_charts, num_charts)
        self.random.shuffle(selected_charts)

        self.starting_songs = [chart.name for chart in selected_charts[:num_starting]]
        self.included_songs = [chart.name for chart in selected_charts[num_starting:]]

        if self.options.enable_mod_items:
            active_suffixes = ["-0", "-1"]
            if self.options.include_85_score_checks: active_suffixes.append("-85")
            if self.options.include_90_score_checks: active_suffixes.append("-90")
            if self.options.include_96_score_checks: active_suffixes.append("-96")
            if self.options.include_98_score_checks: active_suffixes.append("-98")
            if self.options.include_99_score_checks: active_suffixes.append("-99")
            if self.options.include_quad_score_checks: active_suffixes.append("-quad")
            if self.options.include_quint_score_checks: active_suffixes.append("-quint")

            location_count = num_charts * len(active_suffixes)
            unlocks_count = num_charts - num_starting
            mod_count = len(self.itgm_collection.mod_items)

            if location_count < unlocks_count + mod_count:
                raise OptionError(
                    f"Not enough locations ({location_count}) to hold both unlockable songs ({unlocks_count}) "
                    f"and enabled mod items ({mod_count}). Please increase 'number_of_charts' or decrease "
                    f"'number_of_starting_charts' or enable more score checks."
                )

        # Programmatically exclude high score locations from progression
        high_score_suffixes = []
        if self.options.include_98_score_checks:
            high_score_suffixes.append("-98")
        if self.options.include_99_score_checks:
            high_score_suffixes.append("-99")
        if self.options.include_quad_score_checks:
            high_score_suffixes.append("-quad")
        if self.options.include_quint_score_checks:
            high_score_suffixes.append("-quint")

        for song in self.starting_songs + self.included_songs:
            for suffix in high_score_suffixes:
                self.options.exclude_locations.value.add(f"{song}{suffix}")

        for song in self.starting_songs:
            self.multiworld.push_precollected(self.create_item(song))

    itgm_collection = ITGManiaCollection.ITGManiaCollections()

    # Our world class must have a static location_name_to_id and item_name_to_id defined.
    # We define these in regions.py and items.py respectively, so we just set them here.
    location_name_to_id = itgm_collection.location_names_to_id
    item_name_to_id = itgm_collection.item_names_to_id

    # There is always one region that the generator starts from & assumes you can always go back to.
    # This defaults to "Menu", but you can change it by overriding origin_region_name.
    origin_region_name = "Songwheel"

    # Our world class must have certain functions ("steps") that get called during generation.
    # The main ones are: create_regions, set_rules, create_items.
    # For better structure and readability, we put each of these in their own file.
    def create_regions(self) -> None:
        regions.create_and_connect_regions(self)
        locations.create_all_locations(self)

    def set_rules(self) -> None:
        rules.set_all_rules(self)

    def create_items(self) -> None:
        items.create_all_items(self)

    # Our world class must also have a create_item function that can create any one of our items by name at any time.
    # We also put this in a different file, the same one that create_items is in.
    def create_item(self, name: str) -> items.ITGManiaItem:
        return items.create_item(self, name)

    # For features such as item links and panic-method start inventory, AP may ask your world to create extra filler.
    # The way it does this is by calling get_filler_item_name.
    # For this purpose, your world *must* have at least one infinitely repeatable item (usually filler).
    # You must override this function and return this infinitely repeatable item's name.
    # In our case, we defined a function called get_random_filler_item_name for this purpose in our items.py.
    def get_filler_item_name(self) -> str:
        return "Bonus Percentage"

    # There may be data that the game client will need to modify the behavior of the game.
    # This is what slot_data exists for. Upon every client connection, the slot's slot_data is sent to the client.
    # slot_data is just a dictionary using basic types, that will be converted to json when sent to the client.
    def fill_slot_data(self) -> Mapping[str, Any]:
        # If you need access to the player's chosen options on the client side, there is a helper for that.
        return self.options.as_dict(
            "fail_allowed", "passing_score", "score_type", "number_of_charts",
            "number_of_starting_charts", "group_size", "win_count"
        )

