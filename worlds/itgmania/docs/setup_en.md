# ITGMania Archipelago Setup Guide

ITGMania is a rhythm game engine. This guide explains how to set up ITGMania to play in an Archipelago multiworld.

## Installation

1. Decide and populate your song pool. There will be a module provided that can
   dump your song pool on ITGMania startup. From there, filter the song pool by
   simply removing lines.
2. Place the songs.csv file within the itgmania world directory in the server,
   then you may proceed with world generation.
3. If multiple players have different song pools, then append each CSV file
   with the name of the player so that seed generation can select the
   appropriate song pool per person.
4. Visit the [Archipelago Client](https://github.com/bwaggone/ITGMania-Archipelago-Module) github page and follow the instructions
   to install the module within your ITGMania install.

## Options

- **Number of Charts**: Total number of charts you wish to include in your seed.
- **Number of Starting Charts**: The number of charts you start with unlocked.
- **Group Size**: If greater than 1, you must clear all charts in the previous group before accessing charts in the next group.
- **Win Count**: The number of song clears needed to win the game.
- **Fail Allowed**: If enabled, failing a song counts as a pass (if immediate continue is enabled in ITGMania).
- **Passing Score**: Desired score type grade threshold to clear a chart.
- **Score Type**: Grade type to evaluate (EX, High EX, etc.).

## Usage in-game and features

-- Automatic playlist generation for the seed: The module will update and reload the
   song wheel when new charts are recieved
-- In-game AP tracking: Press F10 from the songwheel to see the current AP game status.
-- Pop-up notifications: In relevants screens, you will see pop-ups when items
   are sent and received.