module Lambda.ExpressionUtils exposing (..)

import Lambda.Context exposing (..)
import Lambda.ContextUtils exposing (addbinding, ctxlength, getbinding)
import Lambda.Expression exposing (..)
import Set exposing (Set)


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


{-| Return free variables of type (for H-M)

Doesn't take ctx -> doesn't return TyVars that are already bound in ctx
In H-M if a var is free in type, it uses the TyName enum, not the TyVar

-}
ftvTy : Ty -> Set String
ftvTy ty =
    case ty of
        TyName s ->
            Set.singleton s

        TyArr ty1 ty2 ->
            ftvTy ty1
                |> Set.union (ftvTy ty2)

        TyVar _ _ ->
            Set.empty

        TyAll _ ty1 ->
            ftvTy ty1

        TyConst _ ->
            Set.empty


ftvCtx : Context -> Set String
ftvCtx ctx =
    ctx
        |> List.map
            (\( s, b ) ->
                case b of
                    VarBind ty ->
                        ftvTy ty

                    TyVarBind ->
                        Set.singleton s

                    _ ->
                        Set.empty
            )
        |> List.foldl Set.union Set.empty


ftvTerm : Term -> Set String
ftvTerm term =
    case term of
        TmVar _ _ _ ->
            Set.empty

        TmAbs _ _ maybeTy t1 ->
            maybeTy
                |> Maybe.map ftvTy
                |> Maybe.withDefault Set.empty
                |> Set.union (ftvTerm t1)

        TmApp _ t1 t2 ->
            ftvTerm t1 |> Set.union (ftvTerm t2)

        TmIf _ t1 t2 t3 ->
            ftvTerm t1 |> Set.union (ftvTerm t2) |> Set.union (ftvTerm t3)

        TmLet _ _ t1 t2 ->
            ftvTerm t1 |> Set.union (ftvTerm t2)

        TmTAbs _ _ t1 ->
            ftvTerm t1

        TmTApp _ t1 ty1 ->
            ftvTerm t1 |> Set.union (ftvTy ty1)

        TmConst _ _ ->
            Set.empty


{-| Substitution of Ty for free type variable
-}
type alias SubstitutionFtv =
    List ( Ty, String )


{-| Applies free variable substitution on type
-}
substFtvTy : SubstitutionFtv -> Ty -> Ty
substFtvTy ss tyTop =
    let
        substOne tyS varName ty =
            case ty of
                TyName name ->
                    if varName == name then
                        tyS

                    else
                        ty

                TyArr ty1 ty2 ->
                    TyArr (substOne tyS varName ty1) (substOne tyS varName ty2)

                TyAll x ty1 ->
                    TyAll x <| substOne tyS varName ty1

                _ ->
                    ty
    in
    ss
        |> List.foldr (\( tyS, varName ) -> substOne tyS varName) tyTop


substFtvCtx : SubstitutionFtv -> Context -> Context
substFtvCtx ss ctx =
    ctx
        |> List.map
            (Tuple.mapSecond <|
                \b ->
                    case b of
                        VarBind t ->
                            VarBind <| substFtvTy ss t

                        _ ->
                            b
            )


substFtvTerm : SubstitutionFtv -> Term -> Term
substFtvTerm ss t =
    tmmap (\fi _ x n -> TmVar fi x n) (\_ -> substFtvTy ss) 0 t


{-| Substitutes primarily to the vars of first expression
-}
unifyType : Ty -> Ty -> Result String SubstitutionFtv
unifyType ty1 ty2 =
    case ( ty1, ty2 ) of
        ( TyName name1, TyName name2 ) ->
            if name1 == name2 then
                Ok []

            else
                Ok [ ( ty2, name1 ) ]

        ( TyName name, _ ) ->
            if Set.member name (ftvTy ty2) then
                Err <| "Variable " ++ name ++ " is free in type 2"

            else
                Ok [ ( ty2, name ) ]

        ( _, TyName name ) ->
            if Set.member name (ftvTy ty1) then
                Err <| "Variable " ++ name ++ " is free in type 1"

            else
                Ok [ ( ty1, name ) ]

        ( TyConst c1, TyConst c2 ) ->
            if c1 == c2 then
                Ok []

            else
                Err <| "Type constants '" ++ Debug.toString c1 ++ "' & '" ++ Debug.toString c2 ++ "' are not compatible"

        ( TyArr ty11 ty12, TyArr ty21 ty22 ) ->
            unifyType ty11 ty21
                |> Result.andThen
                    (\justS1 ->
                        unifyType (substFtvTy justS1 ty12) (substFtvTy justS1 ty22)
                            |> Result.andThen (\justS2 -> Ok <| justS2 ++ justS1)
                    )

        ( TyAll name1 _, _ ) ->
            Err <| "Types should be degeneralized. TyAll '" ++ name1 ++ "' found"

        ( _, TyAll name2 _ ) ->
            Err <| "Types should be degeneralized. TyAll '" ++ name2 ++ "' found"

        -- Not necessary for System H-M (types should not reference variable => should be degeneralized) => for System F
        ( TyVar x1 n1, TyVar x2 n2 ) ->
            if n1 - x1 == n2 - x2 then
                Ok []

            else
                Err <| "Bound variables are not referring to the same bound variable"

        ( _, _ ) ->
            Err <| "Types are not compatible " ++ Debug.toString ( ty1, ty2 )


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


degeneralizeType : Context -> Ty -> Ty
degeneralizeType ctx ty =
    case ty of
        TyAll _ _ ->
            degeneralizeTypeTop ctx ty |> degeneralizeType ctx

        _ ->
            ty


degeneralizeTermTop : Context -> Term -> Term
degeneralizeTermTop ctx t =
    case t of
        TmTAbs _ varName t1 ->
            let
                onvar c x n =
                    if c - ctxlength ctx - x == 0 then
                        TyName varName

                    else
                        TyVar x n

                ctxl =
                    ctxlength ctx
            in
            t1
                |> -- degeneralize types of the term t1 such that the TyVars are replaced by TyName
                   tmmap (\fi _ x n -> TmVar fi x n) (tymap onvar (\_ -> TyName)) ctxl
                |> termShift -1

        _ ->
            t


freshVarName : Set String -> String -> String
freshVarName freeVars varName =
    let
        countedFreshVarName : Set String -> String -> Int -> String
        countedFreshVarName fv vn counter =
            let
                countedVarName =
                    varName
                        ++ (if counter == 0 then
                                ""

                            else
                                String.fromInt counter
                           )
            in
            if Set.member countedVarName freeVars then
                countedFreshVarName fv vn (counter + 1)

            else
                countedVarName
    in
    countedFreshVarName freeVars varName 0


renameBoundVarsWithFresh : Set String -> Ty -> Ty
renameBoundVarsWithFresh freeVars ty =
    case ty of
        TyAll varName ty1 ->
            let
                fresh =
                    freshVarName freeVars varName
            in
            TyAll fresh <| renameBoundVarsWithFresh (Set.insert fresh freeVars) ty1

        TyArr ty1 ty2 ->
            TyArr
                (renameBoundVarsWithFresh freeVars ty1)
                (renameBoundVarsWithFresh freeVars ty2)

        _ ->
            ty


topBoundVars : Ty -> Set String
topBoundVars ty =
    case ty of
        TyAll varName ty1 ->
            Set.insert varName <| topBoundVars ty1

        _ ->
            Set.empty


isSpecializedType : Context -> Ty -> Ty -> Result String Bool
isSpecializedType ctx tyGen tySpec =
    let
        degeneralizedTyGen =
            degeneralizeType ctx tyGen

        renamedTySpec =
            renameBoundVarsWithFresh
                (ftvTy degeneralizedTyGen
                    |> Set.union (ftvTy tySpec)
                    |> Set.union (ftvCtx ctx)
                )
                tySpec

        degeneralizedTySpec =
            degeneralizeType ctx renamedTySpec

        unification =
            unifyType degeneralizedTyGen degeneralizedTySpec
    in
    unification
        |> Result.map
            (\u ->
                u
                    |> List.all
                        (\( tyS, varName ) ->
                            -- substitution must be into the generic type
                            Set.member varName (ftvTy degeneralizedTyGen)
                                -- var must be bound var of the generic type
                                && Set.member varName (topBoundVars tyGen)
                        )
            )


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


{-| Type equivalency of 2 types. Might be in different contexts.
Useful for e.g. comparing type of variable in ctx with type of whole expression
-}
equalTypes : Context -> Ty -> Context -> Ty -> Bool
equalTypes ctx1 ty1 ctx2 ty2 =
    let
        _ =
            Debug.log "equalTypes (ctx1, ty1)" ( ctx1, ty1 )

        _ =
            Debug.log "equalTypes (ctx2, ty2)" ( ctx2, ty2 )

        ctxlengthDiff =
            ctxlength ctx1 - ctxlength ctx2
    in
    if ctxlengthDiff > 0 then
        (List.drop ctxlengthDiff ctx1 == ctx2)
            && (ty1 == typeShift ctxlengthDiff ty2)

    else
        (List.drop -ctxlengthDiff ctx2 == ctx1)
            && (typeShift -ctxlengthDiff ty1 == ty2)


inst : Context -> Ty -> Ty
inst ctx tyGen =
    tyGen
        |> renameBoundVarsWithFresh (ftvTy tyGen |> Set.union (ftvCtx ctx))
        |> degeneralizeType ctx


gen : Context -> Ty -> Ty
gen ctx ty =
    let
        fv =
            Set.diff (ftvTy ty) (ftvCtx ctx) |> Set.toList
    in
    fv |> List.foldr (\var accTy -> generalizeTypeTop ctx accTy var) ty


w : Context -> Term -> Result String ( SubstitutionFtv, Ty )
w ctx t =
    case t of
        TmVar _ x _ ->
            case getbinding ctx x of
                Just (VarBind ty) ->
                    Ok <| ( [], inst ctx ty )

                _ ->
                    Err "Var is not bound in the context with type"

        TmAbs _ varName maybeType t1 ->
            let
                fromType =
                    maybeType
                        |> Maybe.withDefault (TyName <| freshVarName (ftvCtx ctx) "X")

                ctx1 =
                    addbinding ctx varName (VarBind fromType)
            in
            w ctx1 t1
                |> Result.map (\( s, toType ) -> ( s, substFtvTy s (TyArr fromType toType) ))

        TmApp _ t1 t2 ->
            w ctx t1
                |> Result.andThen
                    (\( s1, ro ) ->
                        w (substFtvCtx s1 ctx) t2
                            |> Result.andThen
                                (\( s2, tau ) ->
                                    let
                                        tauPrime =
                                            TyName <|
                                                freshVarName
                                                    (ftvCtx ctx
                                                        |> Set.union (ftvTy ro)
                                                        |> Set.union (ftvTy tau)
                                                    )
                                                    "X"
                                    in
                                    unifyType (substFtvTy s2 ro) (TyArr tau tauPrime)
                                        |> Result.map
                                            (\s3 -> ( s3 ++ s2 ++ s1, substFtvTy s3 tauPrime ))
                                )
                    )

        TmConst _ c ->
            case c of
                TmTrue ->
                    Ok ( [], TyConst TyBool )

                TmFalse ->
                    Ok ( [], TyConst TyBool )

        TmLet _ varName t1 t2 ->
            w ctx t1
                |> Result.andThen
                    (\( s1, tau ) ->
                        let
                            ctx1 =
                                substFtvCtx s1 ctx

                            genTy =
                                gen ctx1 tau
                        in
                        w (addbinding ctx varName (VarBind genTy)) t2
                            |> Result.map
                                (\( s2, tauPrime ) -> ( s2 ++ s1, tauPrime ))
                    )

        -- Extension of W to work with System F terms
        TmTAbs _ tyVarName _ ->
            degeneralizeTermTop ctx t
                |> w ctx
                |> Result.andThen
                    (\( s1, ty ) ->
                        unifyType (substFtvTy s1 (TyName tyVarName)) (TyName tyVarName)
                            |> Result.map (\s2 -> ( s2 ++ s1, substFtvTy s2 ty ))
                    )
                |> Result.map (Tuple.mapSecond <| \gTy -> generalizeTypeTop ctx gTy tyVarName)

        TmTApp _ t1 tyS ->
            w ctx t1
                |> Result.andThen
                    (\( s1, tyAbs ) ->
                        case tyAbs of
                            TyAll _ ty1 ->
                                Ok ( s1, typeSubstTop tyS ty1 )

                            _ ->
                                Err "Type can be applied only on type abstraction term"
                    )

        _ ->
            Err "Not implemented"


typeOf : Context -> Term -> Result String Ty
typeOf ctx t =
    w ctx t
        |> Result.map Tuple.second
        |> Result.map (gen ctx)


areHMTypesEquivalent : Context -> Ty -> Ty -> Result String ()
areHMTypesEquivalent ctx ty1 ty2 =
    let
        renTy1 =
            renameBoundVarsWithFresh (ftvTy ty1 |> Set.union (ftvTy ty2) |> Set.union (ftvCtx ctx)) ty1

        degTy1 =
            renTy1
                |> degeneralizeType ctx

        renTy2 =
            renameBoundVarsWithFresh (ftvTy degTy1 |> Set.union (ftvTy ty2) |> Set.union (ftvCtx ctx)) ty2

        degTy2 =
            renTy2
                |> degeneralizeType ctx

        getTyName ty =
            case ty of
                TyName varName ->
                    varName

                _ ->
                    ""
    in
    unifyType degTy1 degTy2
        |> Result.andThen
            (\s1 ->
                unifyType degTy2 degTy1
                    |> Result.andThen
                        (\s2 ->
                            let
                                degTy1IsAtLeastAsGeneralAsDegTy2 =
                                    \_ ->
                                        if
                                            s1
                                                |> List.all
                                                    (\( _, varName ) -> Set.member varName (ftvTy degTy1))
                                        then
                                            Ok ()

                                        else
                                            Err "Type 1 is not as general as Type 2"

                                degTy2IsAtLeastAsGeneralAsDegTy1 =
                                    \_ ->
                                        if
                                            s2
                                                |> List.all
                                                    (\( _, varName ) -> Set.member varName (ftvTy degTy2))
                                        then
                                            Ok ()

                                        else
                                            Err "Type 2 is not as general as Type 1"

                                typesEquallyGeneralized =
                                    \_ ->
                                        if
                                            (Set.map (TyName >> substFtvTy s1 >> getTyName) (topBoundVars renTy1) == topBoundVars renTy2)
                                                && (Set.map (TyName >> substFtvTy s2 >> getTyName) (topBoundVars renTy2) == topBoundVars renTy1)
                                        then
                                            Ok ()

                                        else
                                            Err "Types are not equivalently generalized"
                            in
                            Ok ()
                                |> Result.andThen degTy1IsAtLeastAsGeneralAsDegTy2
                                |> Result.andThen degTy2IsAtLeastAsGeneralAsDegTy1
                                |> Result.andThen typesEquallyGeneralized
                        )
            )


isTyInTypeSystem : TypeSystem -> Ty -> Bool
isTyInTypeSystem =
    let
        isTyInTypeSystemRanked rank typeSystem ty =
            case ty of
                TyVar _ _ ->
                    case typeSystem of
                        SimplyTyped ->
                            False

                        HM _ ->
                            True

                        SystemF ->
                            True

                TyArr ty1 ty2 ->
                    isTyInTypeSystemRanked (rank + 1) typeSystem ty1
                        && isTyInTypeSystemRanked rank typeSystem ty2

                TyAll _ ty1 ->
                    case typeSystem of
                        SimplyTyped ->
                            False

                        HM _ ->
                            (rank <= 1)
                                && isTyInTypeSystemRanked rank typeSystem ty1

                        SystemF ->
                            isTyInTypeSystemRanked rank typeSystem ty1

                TyName _ ->
                    True

                TyConst _ ->
                    True
    in
    isTyInTypeSystemRanked 1


isTermInTypeSystem : TypeSystem -> Term -> Bool
isTermInTypeSystem typeSystem term =
    case term of
        TmVar _ _ _ ->
            True

        TmAbs _ _ (Just ty) _ ->
            isTyInTypeSystem typeSystem ty

        TmAbs _ _ Nothing _ ->
            case typeSystem of
                SimplyTyped ->
                    False

                HM _ ->
                    True

                SystemF ->
                    False

        TmApp _ t1 t2 ->
            isTermInTypeSystem typeSystem t1 && isTermInTypeSystem typeSystem t2

        TmIf _ t1 t2 t3 ->
            isTermInTypeSystem typeSystem t1
                && isTermInTypeSystem typeSystem t2
                && isTermInTypeSystem typeSystem t3

        TmLet _ _ t1 t2 ->
            isTermInTypeSystem typeSystem t1
                && isTermInTypeSystem typeSystem t2

        TmTAbs _ _ t ->
            case typeSystem of
                SimplyTyped ->
                    False

                HM _ ->
                    False

                SystemF ->
                    isTermInTypeSystem typeSystem t

        TmTApp _ t ty ->
            case typeSystem of
                SimplyTyped ->
                    False

                HM _ ->
                    False

                SystemF ->
                    isTermInTypeSystem typeSystem t && isTyInTypeSystem typeSystem ty

        TmConst _ _ ->
            True


isCtxInTypeSystem : TypeSystem -> Context -> Bool
isCtxInTypeSystem typeSystem ctx =
    ctx
        |> List.all
            (\( _, binding ) ->
                case binding of
                    VarBind ty ->
                        isTyInTypeSystem typeSystem ty

                    NameBind ->
                        True

                    TyVarBind ->
                        False
            )
