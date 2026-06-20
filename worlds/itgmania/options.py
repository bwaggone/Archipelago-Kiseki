from dataclasses import dataclass

from Options import Choice, OptionGroup, PerGameCommonOptions, Range, Toggle, FreeText

# In this file, we define the options the player can pick.
# The most common types of options are Toggle, Range and Choice.

# Options will be in the game's template yaml.
# They will be represented by checkboxes, sliders etc. on the game's options page on the website.
# (Note: Options can also be made invisible from either of these places by overriding Option.visibility.

# For further reading on options, you can also read the Options API Document:
# https://github.com/ArchipelagoMW/Archipelago/blob/main/docs/options%20api.md


# The first type of Option we'll discuss is the Toggle.
# A toggle is an option that can either be on or off. This will be represented by a checkbox on the website.
# The default for a toggle is "off".
# If you want a toggle to be on by default, you can use the "DefaultOnToggle" class instead of the "Toggle" class.

class FailAllowed(Toggle):
    """To allow a fail to still count toward completion. By enabling this, you can "pass" the song in Archipelago if ImmediateContinue is enabled in ITGMania."""
    display_name = "Fail Allowed"

class PassingScore(Range):
    """
    Desired Score to allow for a "passing" grade, acceptable by Archipelago. Set to zero if you want any clear to count.
    """

    display_name = "Passing Score"

    range_start = 0
    range_end = 100
    default = 0


class ScoreType(Choice):
    """Which score would you like to be graded on? Defaults to EX."""
    display_name = "Score Type"
    option_money = 0
    option_ex = 1
    option_high_ex = 2
    default = 1 

class NumberOfCharts(Range):
    """
    Set for the desired number of charts to count toward completion.
    """

    display_name = "Number of Charts"

    range_start = 0
    range_end = 1000
    default = 20

class NumberOfStartingCharts(Range):
    """
    How many charts to start with? The rest will be considered unlockable.
    """

    display_name = "Number of Starting Charts"

    range_start = 0
    range_end = 10
    default = 3

class GroupSize(Range):
    """
    Number of charts in a group. If greater than 1, you must clear all charts in a group
    before any chart in the next group becomes accessible in logic.
    """
    display_name = "Group Size"
    range_start = 1
    range_end = 100
    default = 1


class WinCount(Range):
    """
    The number of song charts passed/cleared required to win the game.
    """
    display_name = "Win Count"
    range_start = 1
    range_end = 1000
    default = 15


class Include85ScoreChecks(Toggle):
    """Include a check for reaching an 85% score on each chart."""
    display_name = "Include 85% Score Checks"

class Include90ScoreChecks(Toggle):
    """Include a check for reaching a 90% score on each chart."""
    display_name = "Include 90% Score Checks"

class Include96ScoreChecks(Toggle):
    """Include a check for reaching a 96% score on each chart."""
    display_name = "Include 96% Score Checks"

class Include98ScoreChecks(Toggle):
    """Include a check for reaching a 98% score on each chart (excluded from progression)."""
    display_name = "Include 98% Score Checks"

class Include99ScoreChecks(Toggle):
    """Include a check for reaching a 99% score on each chart (excluded from progression)."""
    display_name = "Include 99% Score Checks"

class IncludeQuadScoreChecks(Toggle):
    """Include a check for reaching a 100% money score (Quad) on each chart (excluded from progression)."""
    display_name = "Include Quad Score Checks"

class IncludeQuintScoreChecks(Toggle):
    """Include a check for reaching a 100% EX score (Quint) on each chart (excluded from progression)."""
    display_name = "Include Quint Score Checks"

class EnableModItems(Toggle):
    """Enable speed mods and appearance mods as items in the pool."""
    display_name = "Enable Mod Items"


@dataclass
class ITGManiaOptions(PerGameCommonOptions):
    fail_allowed: FailAllowed
    passing_score: PassingScore
    score_type: ScoreType
    number_of_charts: NumberOfCharts
    number_of_starting_charts: NumberOfStartingCharts
    group_size: GroupSize
    win_count: WinCount
    include_85_score_checks: Include85ScoreChecks
    include_90_score_checks: Include90ScoreChecks
    include_96_score_checks: Include96ScoreChecks
    include_98_score_checks: Include98ScoreChecks
    include_99_score_checks: Include99ScoreChecks
    include_quad_score_checks: IncludeQuadScoreChecks
    include_quint_score_checks: IncludeQuintScoreChecks
    enable_mod_items: EnableModItems


# If we want to group our options by similar type, we can do so as well. This looks nice on the website.
option_groups = [
    OptionGroup(
        "Completion Criteria",
        [NumberOfStartingCharts, NumberOfCharts, PassingScore, GroupSize, WinCount],
    ),
    OptionGroup(
        "Modifiers",
        [ScoreType, FailAllowed, EnableModItems],
    ),
    OptionGroup(
        "Score/Grade Checks",
        [
            Include85ScoreChecks, Include90ScoreChecks, Include96ScoreChecks,
            Include98ScoreChecks, Include99ScoreChecks, IncludeQuadScoreChecks, IncludeQuintScoreChecks
        ],
    ),
]

# Finally, we can define some option presets if we want the player to be able to quickly choose a specific "mode".
option_presets = {
    "default": {
        "fail_allowed": False,
    },
}

