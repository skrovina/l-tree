module Lambda.InfererTests exposing (..)

import Expect exposing (Expectation)
import Inferer.Inferer exposing (buildTree)
import Lambda.Expression exposing (..)
import Model exposing (Rule(..))
import Test exposing (..)
import Utils.Tree exposing (Tree(..))


buildTreeTest : Test
buildTreeTest =
    describe "buildTree"
        [ test "should build tree" <|
            \_ ->
                buildTree [] (TmConst I TmTrue)
                    |> Expect.equal (Ok <| Node { ctx = [], term = TmConst I TmTrue, ty = TyConst TyBool, rule = TTrue, ss = [] } [])
        ]