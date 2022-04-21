module Types exposing (..)

import Http
import Html exposing (Html, text)

import Either exposing (Either)
import Loading exposing (Loading(..))

import Generated.Types exposing (..)
import HsCore.Helpers as H



type SelectedTerm = SelectedBinder Binder
                  | SelectedExternal ExternalName

selectedTermToInt : SelectedTerm -> Int
selectedTermToInt term = case term of
    SelectedBinder b -> H.binderToInt b
    SelectedExternal e -> H.externalNameToInt e

type alias Model = 
    { projectMetaLoading : Loading ProjectMeta
    , moduleLoading : Loading Module
    , selectedTerm : Maybe SelectedTerm
    , hideTypes : Bool
    }

type Msg = MsgGotProjectMeta (Result Http.Error ProjectMeta)
         | MsgLoadModule String Int
         | MsgGotModule (Result Http.Error Module)
         | MsgSelectTerm SelectedTerm
         | MsgNextPhase Module
         | MsgPrevPhase Module
         | MsgViewSettingsToggleHideTypes
