module Lambda.ExpressionUtils exposing (..)

import Lambda.Context exposing (..)
import Lambda.ContextUtils exposing (addbinding, ctxlength, getbinding, index2name)
import Lambda.Expression exposing (..)


{-| Shift indices by `d` if idx is greater than `c` in term `t`
-}
termShiftAbove : Int -> Int -> Term -> Term
termShiftAbove d ctx t =
    let
        shiftVar fi c x n =
            if x >= c then
                TmVar fi (x + d) (n + d)

            else
                TmVar fi x (n + d)
    in
    tmmap shiftVar (typeShiftAbove d) ctx t


{-| Shift indices by `d` in term `t`
-}
termShift : Int -> Term -> Term
termShift d t =
    termShiftAbove d 0 t


{-| Beta reduction of term or type variable.
NOTE: Not needed for working with types only.
-}
termSubst : Int -> Term -> Term -> Term
termSubst jIdx s t =
    let
        substVar fi j x n =
            if x == j then
                termShift j s

            else
                TmVar fi x n

        substType j tyT =
            tyT
    in
    tmmap substVar substType jIdx t


{-| Substitute var with idx `j` for `tyS` in term `t`.
-}
tytermSubst : Ty -> Int -> Term -> Term
tytermSubst tyS jIdx t =
    let
        substVar fi c x n =
            TmVar fi x n

        substType j tyT =
            typeSubst tyS j tyT
    in
    tmmap substVar substType jIdx t


{-| Beta reduction of term variable in a term.
-}
termSubstTop : Term -> Term -> Term
termSubstTop s t =
    termShift -1 (termSubst 0 (termShift 1 s) t)


{-| Beta reduction of type variable in a term.
-}
tytermSubstTop : Ty -> Term -> Term
tytermSubstTop tyS t =
    termShift -1 (tytermSubst (typeShift 1 tyS) 0 t)


{-| Map over term. Apply onvar and ontype functions with current ctx length.
-}
tmmap : (Info -> Int -> Int -> Int -> Term) -> (Int -> Ty -> Ty) -> Int -> Term -> Term
tmmap onvar ontype ctx term =
    let
        walk c t =
            case t of
                TmVar fi x n ->
                    onvar fi c x n

                TmAbs fi x tyT1 t2 ->
                    TmAbs fi x (Maybe.map (ontype c) tyT1) (walk (c + 1) t2)

                TmApp fi t1 t2 ->
                    TmApp fi (walk c t1) (walk c t2)

                TmIf fi t1 t2 t3 ->
                    TmIf fi (walk c t1) (walk c t2) (walk c t3)

                TmLet fi x t1 t2 ->
                    TmLet fi x (walk c t1) (walk (c + 1) t2)

                TmTAbs fi tyX t2 ->
                    TmTAbs fi tyX (walk (c + 1) t2)

                TmTApp fi t1 tyT2 ->
                    TmTApp fi (walk c t1) (ontype c tyT2)

                TmConst fi x ->
                    TmConst fi x
    in
    walk ctx term



-- Chapter 25 - An ML Implementation of System F


{-| Shift indices by `d` if idx is greater than `c` in type `tyT`
-}
typeShiftAbove : Int -> Int -> Ty -> Ty
typeShiftAbove d c tyT =
    let
        shiftVar cc x n =
            if x >= cc then
                TyVar (x + d) (n + d)

            else
                TyVar x (n + d)
    in
    tymap shiftVar (\_ -> TyName) c tyT


{-| Shift all indices by `d` in type `tyT`
-}
typeShift : Int -> Ty -> Ty
typeShift d tyT =
    typeShiftAbove d 0 tyT


{-| Substitute type variable
with de Bruijn index `j`
for type `tyS`
in type `tyT`
-}
typeSubst : Ty -> Int -> Ty -> Ty
typeSubst tyS jIdx tyT =
    let
        substVar j x n =
            if x == j then
                -- The size of ctx is `j` => shift the substitution by `j`
                typeShift j tyS

            else
                TyVar x n
    in
    tymap substVar (\_ -> TyName) jIdx tyT


{-| Beta reduction step. Reduce with substitution for `tyS` in `tyT`
-}
typeSubstTop : Ty -> Ty -> Ty
typeSubstTop tyS tyT =
    -- Always substitute for the 0-th variable
    -- Shift the result so that the variable disappears
    typeShift -1 (typeSubst (typeShift 1 tyS) 0 tyT)


{-| Map over type. Walk the type recursively and apply `onvar`(current ctx length, var idx, var ctx length) on variables
-}
tymap : (Int -> Int -> Int -> Ty) -> (Int -> String -> Ty) -> Int -> Ty -> Ty
tymap onvar onname ctx typeT =
    let
        walk c tyT =
            case tyT of
                TyVar x n ->
                    onvar c x n

                TyArr tyT1 tyT2 ->
                    TyArr (walk c tyT1) (walk c tyT2)

                TyAll tyX tyT2 ->
                    TyAll tyX (walk (c + 1) tyT2)

                TyName s ->
                    onname c s

                TyConst _ ->
                    tyT
    in
    walk ctx typeT



-- ---------------------------


type alias Substitution =
    List ( Ty, String )



{-
   -- subst only works when tyall are on top levels and for unifyType purposes
   subst : Substitution -> Ty -> Ty
   subst context ss ty =
       let
           substOne ctx ty1 varName ty = case ty of
               TyVar x n -> if index2name I ctx x ==
       ss
        |> List.foldr (\(ty1, varName) -> substOne context ty1 varName)

   --    Debug.todo "Implement substitution application"
-}


unifyType : Context -> Ty -> Context -> Ty -> Result String Substitution
unifyType ctx1 ty1 ctx2 ty2 =
    Debug.todo "Unimplemented!"



{-
   case ( ty1, ty2 ) of
       ( TyVar x _, _ ) ->
           index2name I ctx1 x
               |> Result.fromMaybe ("Variable " ++ Debug.toString ty1 ++ " not found in context")
               |> Result.map (\name -> [ ( ty2, name ) ])

       ( _, TyVar x _ ) ->
           index2name I ctx2 x
               |> Result.fromMaybe ("Variable " ++ Debug.toString ty1 ++ " not found in context")
               |> Result.map (\name -> [ ( ty1, name ) ])

       ( TyName name1, TyName name2 ) ->
           if name1 == name2 then
               Ok []

           else
               Err <| "Type names '" ++ name1 ++ "' & '" ++ name2 ++ "' are not compatible"

       ( TyArr ty11 ty12, TyArr ty21 ty22 ) ->
           unifyType ctx1 ty11 ctx2 ty21
               |> Result.andThen
                   (\justS1 ->
                       unifyType ctx1 (subst justS1 ty12) ctx2 (subst justS1 ty22)
                           |> Result.andThen (\justS2 -> Ok <| justS2 ++ justS1)
                   )

       ( TyAll name1 ty11, _ ) ->
           unifyType (addbinding ctx1 name1 TyVarBind) ty11 ctx2 ty2

       ( _, TyAll name2 ty21 ) ->
           unifyType ctx1 ty1 (addbinding ctx1 name2 TyVarBind) ty21

       ( _, _ ) ->
           Err ""
-}


degeneralizeTypeTop : Context -> Ty -> Ty
degeneralizeTypeTop ctx ty =
    case ty of
        TyAll varName ty1 ->
            let
                onvar c x n =
                    if c - ctxlength ctx - x == 0 then
                        TyName varName

                    else
                        TyVar x n
            in
            tymap onvar (\_ -> TyName) (ctxlength ctx) ty1
                |> typeShift -1

        _ ->
            ty


generalizeTypeTop : Context -> Ty -> String -> Ty
generalizeTypeTop ctx ty varName =
    let
        onvar _ x n =
            TyVar x n

        onname c name =
            if name == varName then
                -- Also shift the replacing context length
                TyVar (c - ctxlength ctx) (c + 1)

            else
                TyName name

        ty1 =
            ty
                -- shift other vars first
                |> typeShift 1
                |> tymap onvar onname (ctxlength ctx)
    in
    TyAll varName ty1


equalTypes : Context -> Ty -> Context -> Ty -> Bool
equalTypes ctx1 ty1 ctx2 ty2 =
    let
        _ =
            Debug.log "equalTypes (ctx1, ty1)" ( ctx1, ty1 )

        _ =
            Debug.log "equalTypes (ctx2, ty2)" ( ctx2, ty2 )
    in
    case ( ty1, ty2 ) of
        ( TyConst s1, TyConst s2 ) ->
            s1 == s2

        ( TyName s1, TyName s2 ) ->
            s1 == s2

        ( TyAll s1 ty11, TyAll s2 ty21 ) ->
            equalTypes
                (addbinding ctx1 s1 TyVarBind)
                ty11
                (addbinding ctx2 s2 TyVarBind)
                ty21

        ( TyArr ty11 ty12, TyArr ty21 ty22 ) ->
            equalTypes
                ctx1
                ty11
                ctx2
                ty21
                && equalTypes
                    ctx1
                    ty12
                    ctx2
                    ty22

        ( TyVar i1 l1, TyVar i2 l2 ) ->
            case ( getbinding ctx1 (i1 + (ctxlength ctx1 - l1)), getbinding ctx2 (i2 + (ctxlength ctx2 - l2)) ) of
                ( Just TyVarBind, Just TyVarBind ) ->
                    l2 - l1 == i2 - i1

                ( Just NameBind, Just NameBind ) ->
                    l2 - l1 == i2 - i1

                ( Just (VarBind varTy1), Just (VarBind varTy2) ) ->
                    l2 - l1 == i2 - i1

                _ ->
                    False

        _ ->
            False



{-
   equalTypesExact : Context -> Ty -> Context -> Ty -> Bool
   equalTypesExact ctx1 ty1 ctx2 ty2 =
       case ( ty1, ty2 ) of
           ( TyName s1, TyName s2 ) ->
               s1 == s2

           ( TyAll s1 ty11, TyAll s2 ty21 ) ->
               (s1 == s2)
                   && equalTypes
                       (addbinding ctx1 s1 TyVarBind)
                       ty11
                       (addbinding ctx2 s2 TyVarBind)
                       ty21

           ( TyArr ty11 ty12, TyArr ty21 ty22 ) ->
               equalTypes
                   ctx1
                   ty11
                   ctx2
                   ty21
                   && equalTypes
                       ctx1
                       ty12
                       ctx2
                       ty22

           ( TyVar i1 l1, TyVar i2 l2 ) ->
               (getbinding ctx1 (i1 + (ctxlength ctx1 - l1))
                   == getbinding ctx2 (i2 + (ctxlength ctx2 - l2))
               )
                   && (index2name I ctx1 (i1 + (ctxlength ctx1 - l1))
                           == index2name I ctx2 (i2 + (ctxlength ctx2 - l2))
                      )
                   && (l2 - l1 == i2 - i1)

           _ ->
               False
-}
