module ViewModel exposing (..)

import Lambda.Parse exposing (parseCtx, parseTerm, parseType)
import Lambda.ParseTransform exposing (fromParseContext, fromParseTerm, fromParseType)
import Lambda.Rule exposing (ExprTree, RuleError(..), TyRule, tryRule)
import Model exposing (Rule, TreeModel)
import Utils.Tree exposing (Tree(..))


type alias TreeViewDataError =
    { row : Int, col : Int }


type alias TreeViewDataResult =
    { text : String, error : Maybe RuleError }


type alias TreeViewData =
    Tree
        { ctx : TreeViewDataResult
        , term : TreeViewDataResult
        , ty : TreeViewDataResult
        , rule : Rule
        , result : String
        }


getExprTree : TreeModel -> ExprTree
getExprTree t =
    t
        |> Utils.Tree.map
            (\{ ctx, term, ty, rule } ->
                let
                    ctxExpr =
                        parseCtx ctx
                            |> Result.mapError ParseError
                            |> Result.andThen
                                (\parsedCtx ->
                                    fromParseContext parsedCtx
                                        |> Result.mapError ParseTransformError
                                )

                    termExpr =
                        parseTerm term
                            |> Result.mapError ParseError
                            |> Result.andThen
                                (\parsedTerm ->
                                    ctxExpr
                                        |> Result.mapError (\_ -> PrerequisiteDataError)
                                        |> Result.andThen
                                            (\okContext ->
                                                fromParseTerm okContext parsedTerm
                                                    |> Result.mapError ParseTransformError
                                            )
                                )

                    tyExpr =
                        parseType ty
                            |> Result.mapError ParseError
                            |> Result.andThen
                                (\parsedTy ->
                                    ctxExpr
                                        |> Result.mapError (\_ -> PrerequisiteDataError)
                                        |> Result.andThen
                                            (\okContext ->
                                                fromParseType okContext parsedTy
                                                    |> Result.mapError ParseTransformError
                                            )
                                )
                in
                { ctx = ctxExpr
                , term = termExpr
                , ty = tyExpr
                , rule = rule
                }
            )


getTreeViewData : TreeModel -> TreeViewData
getTreeViewData t =
    let
        zipper origNode _ exprNode exprTree =
            let
                extractError result =
                    case result of
                        Err e ->
                            Just e

                        Ok _ ->
                            Nothing
            in
            { ctx = { text = origNode.ctx, error = extractError exprNode.ctx }
            , term = { text = origNode.term, error = extractError exprNode.term }
            , ty = { text = origNode.ty, error = extractError exprNode.ty }
            , rule = origNode.rule
            , result = tryRule exprTree
            }
    in
    Utils.Tree.zipWithExtra zipper t (getExprTree t)