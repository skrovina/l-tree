module Model exposing (..)

import Material
import Message exposing (Msg)
import RuleTree.Model
import Substitutor.Model


type alias Model =
    { ruleTree : RuleTree.Model.RuleTree
    , substitution : Substitutor.Model.Model
    , showErrors : Bool
    , mdc : Material.Model Msg
    }
