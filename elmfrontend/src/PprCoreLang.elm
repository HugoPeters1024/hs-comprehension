module PprCoreLang exposing (viewCoreBind)

import Core.Generated.Types exposing (..)

import Html exposing (Html, text, span)
import Html.Attributes exposing (class)

import Char
import List
import State
import State exposing (State)

type alias PPState msg = { indent : Int
                         , result : List (Html msg)
                         , toplevel : Bool
                         }

type alias PP msg = State (PPState msg) ()

runPP : PP msg -> PPState msg -> PPState msg
runPP = State.evalState 

defaultState : PPState msg
defaultState = { indent = 0, result = [], toplevel = True}

viewCoreBind : CoreBind -> List (Html msg)
viewCoreBind bind = (runPP (ppCoreBind bind |> State.vndThen newline) defaultState).result

emit : Html msg -> PP msg
emit node = State.stateMap (\s -> { s | result = s.result ++ [node] })

emitText : String -> PP msg
emitText = emit << text

emitKeyword : String -> PP msg
emitKeyword word = emit <| span [class "kt"] [text word]

emitN : List (Html msg) -> PP msg
emitN nodes = State.stateMap (\s -> { s | result = s.result ++ nodes })

ppSequence : List (PP msg) -> PP msg
ppSequence = State.void << State.sequence

ppSequenceLines : List (PP msg) -> PP msg
ppSequenceLines pps = State.void (State.sequence (List.map (\pp -> State.vndThen pp newline) pps))

newline : PP msg
newline = State.get 
    |> State.andThen (\s -> emit (text ("\n" ++ String.fromList (List.repeat s.indent ' '))))

indented : PP msg -> PP msg
indented pp = State.stateMap (\s -> {s | indent = s.indent + 4})
           |> State.vndThen pp
           |> State.vndThen newline
           |> State.vndThen (State.stateMap (\s -> {s | indent = s.indent - 4}))

parens : PP msg -> PP msg
parens pp = ppSequence [emitText "(", pp, emitText ")"]

parensTerm : CoreTerm -> PP msg
parensTerm term = case term of
    Var i -> ppCoreTerm (Var i)
    Lit l -> ppCoreTerm (Lit l)
    t -> parens (ppCoreTerm t)


ppCoreLit : CoreLiteral -> PP msg
ppCoreLit lit = case lit of
    CoreLitNumber l -> emit <| span [class "mi"] [text l]
    CoreLitString l -> emit <| span [class "s"] [text l]
    CoreLitOther l -> emitText l

ppCoreBndr : CoreBndr -> PP msg
ppCoreBndr bndr = State.withState <| \s -> 
    let node = if s.toplevel 
               then span [class "nf"] [text bndr.name] 
               else text bndr.name 
    in emit node

ppCoreBind : CoreBind -> PP msg
ppCoreBind (NonRec b e) = ppCoreBndr b 
                                  |> State.vndThen (State.stateMap (\s -> { s | toplevel = False }))
                                  |> State.vndThen (emit (text " = "))
                                  |> State.vndThen (ppCoreTerm e)

ppCoreAltCon : CoreAltCon -> PP msg
ppCoreAltCon alt = case alt of
    DataAlt i -> ppCoreVar i
    LitAlt l -> ppCoreLit l
    DEFAULT -> emitText "_"

ppCoreAlt : CoreAlt -> PP msg
ppCoreAlt alt = case alt of
    (Alt con _ e) -> ppSequence [ppCoreAltCon con, emitText " -> ", ppCoreTerm e]

ppCoreVar : String -> PP msg
ppCoreVar name =
    let cons = case List.head (String.toList name) of
            Just x -> Char.isUpper x
            Nothing -> False
        node = if cons then span [class "kt"] [text name] else text name
    in emit node

ppCoreTerm : CoreTerm -> PP msg
ppCoreTerm term = case term of
    Var i -> ppCoreVar i
    Lit l -> ppCoreLit l
    App e a -> ppSequence [ppCoreTerm e, emitText " ", parensTerm a]
    Lam b e -> ppSequence [emitText "\\", ppCoreBndr b, emitText " -> ", ppCoreTerm e]
    Let b e -> ppSequence [emitKeyword "let ", ppCoreBind b, emitKeyword " in ", ppCoreTerm e]
    Case e alts -> ppSequence [ emitKeyword "case "
                              , ppCoreTerm e
                              , emitKeyword " of"
                              , indented <| ppSequenceLines (List.map ppCoreAlt alts)]
    Type t -> emitText t

    _ -> emitText "Unsupported"



