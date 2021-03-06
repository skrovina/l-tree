module Lambda.ParserTests exposing (..)

import Expect exposing (Expectation)
import Lambda.Parse exposing (..)
import Parser
import Result
import Test exposing (..)


termExprTest : Test
termExprTest =
    describe "termExpr"
        [ test "should parse term variable" <|
            \_ ->
                Parser.run termExpr "termVar1"
                    |> Expect.equal (Result.Ok <| TmVar "termVar1")
        , test "should parse term variableWith white space" <|
            \_ ->
                Parser.run termExpr "  termVar1  "
                    |> Expect.equal (Result.Ok <| TmVar "termVar1")
        , test "should parse term application" <|
            \_ ->
                Parser.run termExpr "termVar1 termVar2"
                    |> Expect.equal (Result.Ok <| TmApp (TmVar "termVar1") (TmVar "termVar2"))
        , test "should parse term application with spaces" <|
            \_ ->
                Parser.run termExpr "  termVar1  termVar2  "
                    |> Expect.equal (Result.Ok <| TmApp (TmVar "termVar1") (TmVar "termVar2"))
        , test "should parse term application with brackets" <|
            \_ ->
                Parser.run termExpr "(termVar1 termVar2)"
                    |> Expect.equal (Result.Ok <| TmApp (TmVar "termVar1") (TmVar "termVar2"))
        , test "should parse term application with brackets and spaces" <|
            \_ ->
                Parser.run termExpr "  (  termVar1  termVar2  )  "
                    |> Expect.equal (Result.Ok <| TmApp (TmVar "termVar1") (TmVar "termVar2"))
        , test "should parse multiple term applications" <|
            \_ ->
                Parser.run termExpr "termVar1 termVar2 termVar3"
                    |> Expect.equal
                        (Result.Ok <|
                            TmApp
                                (TmApp
                                    (TmVar "termVar1")
                                    (TmVar "termVar2")
                                )
                                (TmVar "termVar3")
                        )
        , test "should parse multiple term applications with brackets" <|
            \_ ->
                Parser.run termExpr "  termVar1  ( termVar2  termVar3 )  "
                    |> Expect.equal
                        (Result.Ok <|
                            TmApp
                                (TmVar "termVar1")
                                (TmApp
                                    (TmVar "termVar2")
                                    (TmVar "termVar3")
                                )
                        )
        , test "should parse application of abstraction" <|
            \_ ->
                Parser.run termExpr "termVar1 (lambda x: X. x)"
                    |> Expect.equal
                        (Result.Ok <|
                            TmApp
                                (TmVar "termVar1")
                                (TmAbs "x" (Just <| TyVar "X") (TmVar "x"))
                        )
        , test "should parse abstraction of application" <|
            \_ ->
                Parser.run termExpr "lambda x: X. termVar1 x"
                    |> Expect.equal
                        (Result.Ok <|
                            TmAbs "x"
                                (Just <| TyVar "X")
                                (TmApp
                                    (TmVar "termVar1")
                                    (TmVar "x")
                                )
                        )
        , test "should parse type abstraction" <|
            \_ ->
                Parser.run termExpr "Lambda TypeVar1 . termVar1"
                    |> Expect.equal (Result.Ok <| TmTAbs "TypeVar1" (TmVar "termVar1"))
        , test "should parse multiple type abstractions" <|
            \_ ->
                Parser.run termExpr "Lambda TypeVar1 . Lambda TypeVar2 . termVar1"
                    |> Expect.equal
                        (Result.Ok <|
                            TmTAbs "TypeVar1"
                                (TmTAbs "TypeVar2"
                                    (TmVar "termVar1")
                                )
                        )
        , test "should parse type application" <|
            \_ ->
                Parser.run termExpr "termVar1 [TypeVar1]"
                    |> Expect.equal
                        (Result.Ok <|
                            TmTApp
                                (TmVar "termVar1")
                                (TyVar "TypeVar1")
                        )
        , test "should parse multiple type applications" <|
            \_ ->
                Parser.run termExpr "termVar1 [TypeVar1] [TypeVar2]"
                    |> Expect.equal
                        (Result.Ok <|
                            TmTApp
                                (TmTApp
                                    (TmVar "termVar1")
                                    (TyVar "TypeVar1")
                                )
                                (TyVar "TypeVar2")
                        )
        , test "should parse multiple type applications with spaces" <|
            \_ ->
                Parser.run termExpr "  termVar1  [  TypeVar1  ]  [  TypeVar2  ]  "
                    |> Expect.equal
                        (Result.Ok <|
                            TmTApp
                                (TmTApp
                                    (TmVar "termVar1")
                                    (TyVar "TypeVar1")
                                )
                                (TyVar "TypeVar2")
                        )
        , test "should parse type applications with type abstraction and term application" <|
            \_ ->
                Parser.run termExpr "(Lambda TypeVar1. lambda termVar1: TypeVar1. termVar1 termVar1) [TermVar1]"
                    |> Expect.equal
                        (Result.Ok <|
                            TmTApp
                                (TmTAbs
                                    "TypeVar1"
                                    (TmAbs
                                        "termVar1"
                                        (Just <| TyVar "TypeVar1")
                                        (TmApp
                                            (TmVar "termVar1")
                                            (TmVar "termVar1")
                                        )
                                    )
                                )
                                (TyVar "TermVar1")
                        )
        , test "should parse let expression" <|
            \_ ->
                Parser.run termExpr "let termVar1=termVar2 in termVar1"
                    |> Expect.equal
                        (Result.Ok <|
                            TmLet
                                "termVar1"
                                (TmVar "termVar2")
                                (TmVar "termVar1")
                        )
        , test "should parse let expression with spaces" <|
            \_ ->
                Parser.run termExpr "   let  termVar1  =  termVar2  in  termVar1   "
                    |> Expect.equal
                        (Result.Ok <|
                            TmLet
                                "termVar1"
                                (TmVar "termVar2")
                                (TmVar "termVar1")
                        )
        , test "should parse preprocessed complex expression with symbols" <|
            \_ ->
                Parser.run termExpr (preprocess "Let x = ^X. \\x: Forall X. X. \\y: X. x y in x [Bool -> Bool]")
                    |> Expect.equal
                        (Result.Ok <|
                            TmLet
                                "x"
                                (TmTAbs
                                    "X"
                                    (TmAbs
                                        "x"
                                        (Just <|
                                            TyAll
                                                "X"
                                                (TyVar "X")
                                        )
                                        (TmAbs
                                            "y"
                                            (Just <| TyVar "X")
                                            (TmApp
                                                (TmVar "x")
                                                (TmVar "y")
                                            )
                                        )
                                    )
                                )
                                (TmTApp
                                    (TmVar "x")
                                    (TyArr
                                        (TyVar "Bool")
                                        (TyVar "Bool")
                                    )
                                )
                        )
        , test "should parse multiple if-then-else expressions" <|
            \_ ->
                Parser.run termExpr "if termVar1 then termVar2 else if termVar3 then termVar4 else termVar5"
                    |> Expect.equal
                        (Result.Ok <|
                            TmIf
                                (TmVar "termVar1")
                                (TmVar "termVar2")
                                (TmIf
                                    (TmVar "termVar3")
                                    (TmVar "termVar4")
                                    (TmVar "termVar5")
                                )
                        )
        , test "should parse multiple if-then-else expressions with spaces" <|
            \_ ->
                Parser.run termExpr
                    ("  if  termVar1  then  termVar2  else "
                        ++ " if   termVar3   then   termVar4   else   termVar5  "
                    )
                    |> Expect.equal
                        (Result.Ok <|
                            TmIf
                                (TmVar "termVar1")
                                (TmVar "termVar2")
                                (TmIf
                                    (TmVar "termVar3")
                                    (TmVar "termVar4")
                                    (TmVar "termVar5")
                                )
                        )
        ]


termVarTest : Test
termVarTest =
    describe "termVar"
        [ test "should parse term variable" <|
            \_ ->
                Parser.run termVar "termVar1"
                    |> Expect.equal (Result.Ok <| "termVar1")
        ]


typeExprTest : Test
typeExprTest =
    describe "typeExpr"
        [ test "should parse type variable" <|
            \_ ->
                Parser.run typeExpr "TypeVar1"
                    |> Expect.equal (Result.Ok <| TyVar "TypeVar1")
        , test "should parse type arrow" <|
            \_ ->
                Parser.run typeExpr "(TypeVar1 -> TypeVar2)"
                    |> Expect.equal (Result.Ok <| TyArr (TyVar "TypeVar1") (TyVar "TypeVar2"))
        , test "should parse type arrow without brackets" <|
            \_ ->
                Parser.run typeExpr "TypeVar1 -> TypeVar2"
                    |> Expect.equal (Result.Ok <| TyArr (TyVar "TypeVar1") (TyVar "TypeVar2"))
        , test "should parse multiple type arrows" <|
            \_ ->
                Parser.run typeExpr "TypeVar1 -> TypeVar2 -> TypeVar3"
                    |> Expect.equal (Result.Ok <| TyArr (TyVar "TypeVar1") (TyArr (TyVar "TypeVar2") (TyVar "TypeVar3")))
        , test "should parse type generalization" <|
            \_ ->
                Parser.run typeExpr "(forall TypeVar1. TypeVar1)"
                    |> Expect.equal (Result.Ok <| TyAll "TypeVar1" (TyVar "TypeVar1"))
        , test "should parse type generalization without brackets" <|
            \_ ->
                Parser.run typeExpr "forall TypeVar1. TypeVar1"
                    |> Expect.equal (Result.Ok <| TyAll "TypeVar1" (TyVar "TypeVar1"))
        , test "should parse type generalization with list" <|
            \_ ->
                Parser.run typeExpr "forall TypeVar1, TypeVar2, TypeVar3. TypeVar1 -> TypeVar2 -> TypeVar3"
                    |> Expect.equal
                        (Result.Ok <|
                            TyAll "TypeVar1" <|
                                TyAll "TypeVar2" <|
                                    TyAll "TypeVar3" <|
                                        (TyArr (TyVar "TypeVar1") <| TyArr (TyVar "TypeVar2") (TyVar "TypeVar3"))
                        )
        , test "should parse complex expr." <|
            \_ ->
                Parser.run typeExpr "forall TypeVar1. forall TypeVar2. TypeVar1 -> (TypeVar1 -> TypeVar2) -> TypeVar2"
                    |> Expect.equal
                        (Result.Ok <|
                            TyAll "TypeVar1"
                                (TyAll "TypeVar2"
                                    (TyArr
                                        (TyVar "TypeVar1")
                                        (TyArr
                                            (TyArr
                                                (TyVar "TypeVar1")
                                                (TyVar "TypeVar2")
                                            )
                                            (TyVar "TypeVar2")
                                        )
                                    )
                                )
                        )
        , test "should parse complex expr. with spaces" <|
            \_ ->
                Parser.run typeExpr "   forall  TypeVar1  .  forall  TypeVar2  .  TypeVar1   ->  (  TypeVar1  ->  TypeVar2  )  ->  TypeVar2"
                    |> Expect.equal
                        (Result.Ok <|
                            TyAll "TypeVar1"
                                (TyAll "TypeVar2"
                                    (TyArr
                                        (TyVar "TypeVar1")
                                        (TyArr
                                            (TyArr
                                                (TyVar "TypeVar1")
                                                (TyVar "TypeVar2")
                                            )
                                            (TyVar "TypeVar2")
                                        )
                                    )
                                )
                        )
        ]


termAbsTest : Test
termAbsTest =
    describe "termAbs"
        [ test "should parse term abstraction" <|
            \_ ->
                Parser.run termAbs "lambda termVar1 : TypeVar1 . termVar1"
                    |> Expect.equal (Result.Ok <| TmAbs "termVar1" (Just <| TyVar "TypeVar1") (TmVar "termVar1"))
        , test "should parse multiple term abstractions" <|
            \_ ->
                Parser.run termAbs "lambda termVar1 : TypeVar1 . lambda termVar2 : TypeVar2 . termVar1"
                    |> Expect.equal
                        (Result.Ok <|
                            TmAbs "termVar1"
                                (Just <| TyVar "TypeVar1")
                                (TmAbs "termVar2"
                                    (Just <| TyVar "TypeVar2")
                                    (TmVar "termVar1")
                                )
                        )
        , test "should parse multiple term abstractions without type annotations" <|
            \_ ->
                Parser.run termAbs "lambda termVar1 . lambda termVar2 . termVar1"
                    |> Expect.equal
                        (Result.Ok <|
                            TmAbs "termVar1"
                                Nothing
                                (TmAbs "termVar2"
                                    Nothing
                                    (TmVar "termVar1")
                                )
                        )
        ]


typeAbsTest : Test
typeAbsTest =
    describe "typeAbs"
        [ test "should parse type abstraction" <|
            \_ ->
                Parser.run typeAbs "Lambda TypeVar1 . termVar1"
                    |> Expect.equal (Result.Ok <| TmTAbs "TypeVar1" (TmVar "termVar1"))
        , test "should parse multiple type abstractions" <|
            \_ ->
                Parser.run typeAbs "Lambda TypeVar1 . Lambda TypeVar2 . termVar1"
                    |> Expect.equal
                        (Result.Ok <|
                            TmTAbs "TypeVar1"
                                (TmTAbs "TypeVar2"
                                    (TmVar "termVar1")
                                )
                        )
        ]


letExprTest : Test
letExprTest =
    describe "letExpr"
        [ test "should parse let expression" <|
            \_ ->
                Parser.run letExpr "let termVar1 = termVar2 in termVar1"
                    |> Expect.equal
                        (Result.Ok <|
                            TmLet
                                "termVar1"
                                (TmVar "termVar2")
                                (TmVar "termVar1")
                        )
        , test "should parse multiple let expressions" <|
            \_ ->
                Parser.run letExpr "let termVar1 = termVar2 in let termVar3 = termVar1 in termVar3"
                    |> Expect.equal
                        (Result.Ok <|
                            TmLet
                                "termVar1"
                                (TmVar "termVar2")
                                (TmLet
                                    "termVar3"
                                    (TmVar "termVar1")
                                    (TmVar "termVar3")
                                )
                        )
        ]


ifExprTest : Test
ifExprTest =
    describe "ifExpr"
        [ test "should parse if-then-else expression" <|
            \_ ->
                Parser.run ifExpr "if termVar1 then termVar2 else termVar3"
                    |> Expect.equal
                        (Result.Ok <|
                            TmIf
                                (TmVar "termVar1")
                                (TmVar "termVar2")
                                (TmVar "termVar3")
                        )
        , test "should parse multiple if-then-else expressions" <|
            \_ ->
                Parser.run ifExpr "if termVar1 then termVar2 else if termVar3 then termVar4 else termVar5"
                    |> Expect.equal
                        (Result.Ok <|
                            TmIf
                                (TmVar "termVar1")
                                (TmVar "termVar2")
                                (TmIf
                                    (TmVar "termVar3")
                                    (TmVar "termVar4")
                                    (TmVar "termVar5")
                                )
                        )
        ]


preprocessTest : Test
preprocessTest =
    describe "preprocess"
        [ test "should parse let expression" <|
            \_ ->
                preprocess "Let x = ^X. \\x: Forall X. X. \\y: X. x y In x [Bool -> Bool]"
                    |> Expect.equal "let x = ΛX. λx: ∀X. X. λy: X. x y in x [Bool → Bool]"
        ]


typeContextTest : Test
typeContextTest =
    describe "typeContext"
        [ test "should parse empty typeContext" <|
            \_ ->
                parseCtx ""
                    |> Expect.equal
                        (Result.Ok <|
                            TyContext []
                        )
        , test "should parse single element name bind typeContext" <|
            \_ ->
                parseCtx "termVar1"
                    |> Expect.equal
                        (Result.Ok <|
                            TyContext [ VarBind "termVar1" Nothing ]
                        )
        , test "should parse single element var type bind typeContext" <|
            \_ ->
                parseCtx "termVar1: Bool"
                    |> Expect.equal
                        (Result.Ok <|
                            TyContext [ VarBind "termVar1" (Just <| TyVar "Bool") ]
                        )
        , test "should parse single element var type bind with complex type" <|
            \_ ->
                parseCtx "termVar1: forall TypeVar1. forall TypeVar2. TypeVar1 -> (TypeVar1 -> TypeVar2) -> TypeVar2"
                    |> Expect.equal
                        (Result.Ok <|
                            TyContext
                                [ VarBind "termVar1"
                                    (Just <|
                                        TyAll "TypeVar1"
                                            (TyAll "TypeVar2"
                                                (TyArr
                                                    (TyVar "TypeVar1")
                                                    (TyArr
                                                        (TyArr
                                                            (TyVar "TypeVar1")
                                                            (TyVar "TypeVar2")
                                                        )
                                                        (TyVar "TypeVar2")
                                                    )
                                                )
                                            )
                                    )
                                ]
                        )
        , test "should parse single element type var typeContext" <|
            \_ ->
                parseCtx "TypeVar1"
                    |> Expect.equal
                        (Result.Ok <|
                            TyContext [ TyVarBind "TypeVar1" ]
                        )
        , test "should parse mixed type & term vars" <|
            \_ ->
                parseCtx "TypeVar1, termVar1, TypeVar2, termVar2: TypeVar1"
                    |> Expect.equal
                        (Result.Ok <|
                            TyContext
                                [ TyVarBind "TypeVar1"
                                , VarBind "termVar1" Nothing
                                , TyVarBind "TypeVar2"
                                , VarBind "termVar2" (Just <| TyVar "TypeVar1")
                                ]
                        )
        ]


parseTermTest : Test
parseTermTest =
    describe "parseTerm"
        [ test "should parse term variable" <|
            \_ ->
                parseTerm "termVar1"
                    |> Expect.equal (Result.Ok <| TmVar "termVar1")
        , test "should parse term variableWith white space" <|
            \_ ->
                parseTerm "  termVar1  "
                    |> Expect.equal (Result.Ok <| TmVar "termVar1")
        , test "should parse term application" <|
            \_ ->
                parseTerm "termVar1 termVar2"
                    |> Expect.equal (Result.Ok <| TmApp (TmVar "termVar1") (TmVar "termVar2"))
        , test "should parse term application with spaces" <|
            \_ ->
                parseTerm "  termVar1  termVar2  "
                    |> Expect.equal (Result.Ok <| TmApp (TmVar "termVar1") (TmVar "termVar2"))
        , test "should parse term application with brackets" <|
            \_ ->
                parseTerm "(termVar1 termVar2)"
                    |> Expect.equal (Result.Ok <| TmApp (TmVar "termVar1") (TmVar "termVar2"))
        ]


parseTypeTest : Test
parseTypeTest =
    describe "parseType"
        [ test "should parse type variable" <|
            \_ ->
                parseType "TypeVar1"
                    |> Expect.equal (Result.Ok <| TyVar "TypeVar1")
        , test "should parse type arrow" <|
            \_ ->
                parseType "(TypeVar1 -> TypeVar2)"
                    |> Expect.equal (Result.Ok <| TyArr (TyVar "TypeVar1") (TyVar "TypeVar2"))
        , test "should parse type arrow without brackets" <|
            \_ ->
                parseType "TypeVar1 -> TypeVar2"
                    |> Expect.equal (Result.Ok <| TyArr (TyVar "TypeVar1") (TyVar "TypeVar2"))
        , test "should parse multiple type arrows" <|
            \_ ->
                parseType "TypeVar1 -> TypeVar2 -> TypeVar3"
                    |> Expect.equal (Result.Ok <| TyArr (TyVar "TypeVar1") (TyArr (TyVar "TypeVar2") (TyVar "TypeVar3")))
        , test "should parse type generalization" <|
            \_ ->
                parseType "(forall TypeVar1. TypeVar1)"
                    |> Expect.equal (Result.Ok <| TyAll "TypeVar1" (TyVar "TypeVar1"))
        ]


parseCtxTest : Test
parseCtxTest =
    describe "parseCtx"
        [ test "should parse empty typeContext" <|
            \_ ->
                parseCtx ""
                    |> Expect.equal
                        (Result.Ok <|
                            TyContext []
                        )
        , test "should parse single element name bind typeContext" <|
            \_ ->
                parseCtx "termVar1"
                    |> Expect.equal
                        (Result.Ok <|
                            TyContext [ VarBind "termVar1" Nothing ]
                        )
        , test "should parse single element var type bind typeContext" <|
            \_ ->
                parseCtx "termVar1: Bool"
                    |> Expect.equal
                        (Result.Ok <|
                            TyContext [ VarBind "termVar1" (Just <| TyVar "Bool") ]
                        )
        , test "should parse single element var type bind with complex type" <|
            \_ ->
                parseCtx "termVar1: forall TypeVar1. forall TypeVar2. TypeVar1 -> (TypeVar1 -> TypeVar2) -> TypeVar2"
                    |> Expect.equal
                        (Result.Ok <|
                            TyContext
                                [ VarBind "termVar1"
                                    (Just <|
                                        TyAll "TypeVar1"
                                            (TyAll "TypeVar2"
                                                (TyArr
                                                    (TyVar "TypeVar1")
                                                    (TyArr
                                                        (TyArr
                                                            (TyVar "TypeVar1")
                                                            (TyVar "TypeVar2")
                                                        )
                                                        (TyVar "TypeVar2")
                                                    )
                                                )
                                            )
                                    )
                                ]
                        )
        , test "should parse single element type var typeContext" <|
            \_ ->
                parseCtx "TypeVar1"
                    |> Expect.equal
                        (Result.Ok <|
                            TyContext [ TyVarBind "TypeVar1" ]
                        )
        , test "should parse mixed type & term vars" <|
            \_ ->
                parseCtx "TypeVar1, termVar1, TypeVar2, termVar2: TypeVar1"
                    |> Expect.equal
                        (Result.Ok <|
                            TyContext
                                [ TyVarBind "TypeVar1"
                                , VarBind "termVar1" Nothing
                                , TyVarBind "TypeVar2"
                                , VarBind "termVar2" (Just <| TyVar "TypeVar1")
                                ]
                        )
        ]
