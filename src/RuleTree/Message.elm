module RuleTree.Message exposing (..)

import Bootstrap.Dropdown as Dropdown
import Bootstrap.Popover as Popover
import Lambda.Rule exposing (Rule)
import RuleTree.Model exposing (TextKind)


type Msg
    = TextChangedMsg (List Int) TextKind String
    | HintPremisesMsg (List Int)
    | HintRuleSelectionMsg (List Int)
    | HintBranchMsg (List Int)
    | RemoveMsg (List Int)
    | RuleSelectedMsg (List Int) Rule
    | ClearTreeMsg
    | RuleDropdownMsg (List Int) Dropdown.State
    | RuleStatusPopoverMsg (List Int) Popover.State
