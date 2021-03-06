module Lambda.Parse exposing (..)

import Char
import List.Extra
import Parser exposing (..)
import Set


type Term
    = TmVar String
    | TmAbs String (Maybe Ty) Term
    | TmApp Term Term
    | TmIf Term Term Term
    | TmTAbs String Term
    | TmTApp Term Ty
    | TmLet String Term Term


type Ty
    = TyVar String
    | TyArr Ty Ty
    | TyAll String Ty


type Binding
    = VarBind String (Maybe Ty)
    | TyVarBind String


type TyContext
    = TyContext (List Binding)


type alias Error =
    { row : Int, col : Int }


{-| Reserved keywords
-}
keywords =
    [ "Lambda", "lambda", "let", "Let", "in", "In", "forall", "Forall", "forAll", "ForAll" ]
        ++ [ "if", "If", "then", "Then", "else", "Else" ]


symbols =
    { lambda = "λ"
    , capitalLambda = "Λ"
    , forAll = "∀"
    , arrow = "→"
    }


preprocess : String -> String
preprocess =
    String.replace "\\" symbols.lambda
        >> String.replace "lambda " symbols.lambda
        >> String.replace "Lambda " symbols.capitalLambda
        >> String.replace "|" symbols.capitalLambda
        >> String.replace "^" symbols.capitalLambda
        >> String.replace "Let " "let "
        >> String.replace "In " "in "
        >> String.replace "forall " symbols.forAll
        >> String.replace "forAll " symbols.forAll
        >> String.replace "Forall " symbols.forAll
        >> String.replace "ForAll " symbols.forAll
        >> String.replace "->" symbols.arrow
        >> String.replace "If " "if "
        >> String.replace "Then " "then "
        >> String.replace "Else " "else "


termAbsLambdaSymbol : Parser ()
termAbsLambdaSymbol =
    oneOf
        [ symbol symbols.lambda
        , keyword "lambda"
        , symbol "\\"
        ]


typeAbsLambdaSymbol : Parser ()
typeAbsLambdaSymbol =
    oneOf
        [ symbol symbols.capitalLambda
        , keyword "Lambda"
        ]


forAllSymbol : Parser ()
forAllSymbol =
    oneOf
        [ symbol symbols.forAll
        , keyword "forall"
        , keyword "forAll"
        , keyword "Forall"
        , keyword "ForAll"
        ]


arrowSymbol : Parser ()
arrowSymbol =
    oneOf
        [ symbol symbols.arrow
        , symbol "->"
        ]


letSymbol : Parser ()
letSymbol =
    oneOf
        [ keyword "let"
        , keyword "Let"
        ]


inSymbol : Parser ()
inSymbol =
    oneOf
        [ keyword "in"
        , keyword "In"
        ]


ifSymbol : Parser ()
ifSymbol =
    oneOf
        [ keyword "if"
        , keyword "If"
        ]


thenSymbol : Parser ()
thenSymbol =
    oneOf
        [ keyword "then"
        , keyword "Then"
        ]


elseSymbol : Parser ()
elseSymbol =
    oneOf
        [ keyword "else"
        , keyword "Else"
        ]


termVar : Parser String
termVar =
    variable
        { start = Char.isLower
        , inner = \c -> Char.isAlphaNum c || c == '_'
        , reserved = Set.fromList keywords
        }


typeVar : Parser String
typeVar =
    variable
        { start = Char.isUpper
        , inner = \c -> Char.isAlphaNum c || c == '_'
        , reserved = Set.fromList keywords
        }


{-| Abstraction
-}
termAbs : Parser Term
termAbs =
    succeed TmAbs
        |. termAbsLambdaSymbol
        |. spaces
        |= termVar
        |. spaces
        |= maybeTypeAnnotation
        |. spaces
        |. symbol "."
        |. spaces
        |= lazy (\_ -> termExpr)


maybeTypeAnnotation : Parser (Maybe Ty)
maybeTypeAnnotation =
    oneOf
        [ succeed Just
            |. symbol ":"
            |. spaces
            |= typeExpr
        , succeed Nothing
        ]


{-| Type abstraction
-}
typeAbs : Parser Term
typeAbs =
    succeed TmTAbs
        |. typeAbsLambdaSymbol
        |. spaces
        |= typeVar
        |. spaces
        |. symbol "."
        |. spaces
        |= lazy (\_ -> termExpr)


{-| Type expression
-}
typeExpr : Parser Ty
typeExpr =
    succeed identity
        |. spaces
        |= typeSubExpr
        |> andThen (\subExpr -> arrowExprHelp [ subExpr ])


tyAllVars : Parser (List String)
tyAllVars =
    succeed identity
        |= sequence
            { start = ""
            , separator = ","
            , end = ""
            , spaces = spaces
            , item = typeVar
            , trailing = Forbidden
            }
        |> andThen checkAbsVars


checkAbsVars : List String -> Parser (List String)
checkAbsVars vars =
    if List.length vars == 0 then
        problem "No variable"

    else
        succeed vars


tyAll : Parser (Ty -> Ty)
tyAll =
    succeed identity
        |. forAllSymbol
        |. spaces
        |= tyAllVars
        |. spaces
        |. symbol "."
        |. spaces
        |> andThen
            (List.map TyAll
                >> List.foldl (\tyAllVar acc -> \f -> acc (tyAllVar f)) (\x -> x)
                >> succeed
            )


{-| Type sub expression
TODO: Mark brackets with new value constructor?
-}
typeSubExpr : Parser Ty
typeSubExpr =
    oneOf
        [ succeed (<|)
            |= tyAll
            |= lazy (\_ -> typeExpr)
        , succeed identity
            |= map TyVar typeVar
            |. spaces
        , succeed identity
            |. symbol "("
            |. spaces
            |= lazy (\_ -> typeExpr)
            |. spaces
            |. symbol ")"
            |. spaces
        ]


{-| Arrow expression helper

typeSubExpr consumes spaces at the end of sub expression so that `arrowExprHelp` doesn't need to start with `spaces`. Consuming spaces at beginning of oneOf that cause
problem in `oneOf`.
If parser encounters '.' it should not consider it as an operator but it should end consuming.
Inspired by <https://github.com/elm/parser/blob/master/examples/Math.elm>

`arrowExprFinalize` is inside `lazy` so that it's not evaluated every time `arrowExprHelp` is called

-}
arrowExprHelp : List Ty -> Parser Ty
arrowExprHelp revOps =
    oneOf
        [ succeed identity
            |. arrowSymbol
            |. spaces
            |= typeSubExpr
            |> andThen (\op -> arrowExprHelp (op :: revOps))
        , lazy (\_ -> checkIfNoOperands <| arrowExprFinalize revOps)
        ]


{-| Applies operator on the reversed list of operands

Results in an expr. associated from right

-}
arrowExprFinalize : List Ty -> Maybe Ty
arrowExprFinalize revOps =
    List.Extra.foldl1 (\expr acc -> TyArr expr acc) revOps


checkIfNoOperands : Maybe a -> Parser a
checkIfNoOperands maybeResult =
    case maybeResult of
        Just result ->
            succeed result

        Nothing ->
            problem "operator has no operands"


{-| Term expression
-}
termExpr : Parser Term
termExpr =
    succeed identity
        |. spaces
        |= termSubExpr
        |> andThen appExprHelp


{-| Term sub expression
-}
termSubExpr : Parser Term
termSubExpr =
    oneOf
        [ map TmVar termVar
        , termAbs
        , typeAbs
        , letExpr
        , ifExpr
        , succeed identity
            |. symbol "("
            |. spaces
            |= lazy (\_ -> termExpr)
            |. spaces
            |. symbol ")"
            |. spaces
        ]


{-| Type application sub expression
-}
termTyAppSubExpr : Parser Ty
termTyAppSubExpr =
    succeed identity
        |. symbol "["
        |. spaces
        |= typeExpr
        |. spaces
        |. symbol "]"


appExprHelp : Term -> Parser Term
appExprHelp term =
    succeed identity
        |. spaces
        |= oneOf
            [ oneOf
                [ map (TmApp term) termSubExpr
                , map (TmTApp term) termTyAppSubExpr
                ]
                |> andThen appExprHelp
            , succeed term
            ]


{-| Let expressions
-}
letExpr : Parser Term
letExpr =
    succeed TmLet
        |. letSymbol
        |. spaces
        |= termVar
        |. spaces
        |. symbol "="
        |= lazy (\_ -> termExpr)
        |. spaces
        |. inSymbol
        |= lazy (\_ -> termExpr)


{-| If-Then-Else expression
-}
ifExpr : Parser Term
ifExpr =
    succeed TmIf
        |. ifSymbol
        |. spaces
        |= lazy (\_ -> termExpr)
        |. spaces
        |. thenSymbol
        |. spaces
        |= lazy (\_ -> termExpr)
        |. spaces
        |. elseSymbol
        |. spaces
        |= lazy (\_ -> termExpr)


binding : Parser Binding
binding =
    oneOf
        [ succeed VarBind
            |= termVar
            |. spaces
            |= maybeTypeAnnotation
        , map TyVarBind typeVar
        ]


{-| List of context bindings expression
-}
typeContext : Parser TyContext
typeContext =
    succeed TyContext
        |. spaces
        |= sequence
            { start = ""
            , separator = ","
            , end = ""
            , spaces = spaces
            , item = binding
            , trailing = Optional
            }
        |. spaces


transformError : List Parser.DeadEnd -> Error
transformError =
    List.head
        >> Maybe.map (\deadEnd -> { row = deadEnd.row, col = deadEnd.col })
        >> Maybe.withDefault { row = 0, col = 0 }


runParser parser text =
    Parser.run parser text
        |> Result.mapError transformError


parseTerm : String -> Result Error Term
parseTerm =
    succeed identity
        |. spaces
        |= termExpr
        |. spaces
        |. end
        |> runParser


parseType : String -> Result Error Ty
parseType =
    succeed identity
        |. spaces
        |= typeExpr
        |. spaces
        |. end
        |> runParser


parseTypeVar : String -> Result Error String
parseTypeVar =
    succeed identity
        |. spaces
        |= typeVar
        |. spaces
        |. end
        |> runParser


parseCtx : String -> Result Error TyContext
parseCtx =
    succeed identity
        |. spaces
        |= typeContext
        |. spaces
        |. end
        |> runParser
