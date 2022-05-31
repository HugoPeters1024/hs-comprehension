module Main exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Types exposing (..)
import Browser exposing (Document)
import Url exposing (Url)
import Loading exposing (..)

import Time
import Task
import Dict exposing (Dict)
import Set.Any exposing (AnySet)

import Pages.Code as Code
import Pages.Overview as Overview

import Bootstrap.CDN as CDN

import UI.Tabs as Tabs
import ContextMenu

main : Program () Model Msg
main = Browser.document
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }

init : () -> (Model, Cmd Msg)
init _ = 
    let (ctxMenu, ctxCmd) = ContextMenu.init
    in (
           { pageTab = Tabs.init
           , capturesLoading = Loading Nothing
           , timezone = Time.utc
           , overviewTab =
               { enabledProjects = Set.Any.empty .captureName
               }
           , idGen = 0
           , codeTabs = Dict.empty
           , ctxMenu = ctxMenu
           }
        , Cmd.batch 
           [ Task.perform MsgAdjustTimeZone Time.here
           , Overview.init
           , Cmd.map MsgCtxMenu ctxCmd
           ]
        )



addCodeTab : CodeTab -> Model -> Model
addCodeTab tab model = { model | codeTabs = Dict.insert tab.id tab model.codeTabs }

subscriptions : Model -> Sub Msg
subscriptions model = 
    Sub.batch 
        (
            (Sub.map MsgCtxMenu (ContextMenu.subscriptions model.ctxMenu))
            ::
            (List.map Code.subscriptions (Dict.values model.codeTabs))
        )


viewCodeTabs model =
    let 
        renderTab tab = 
            Tabs.item
                { name = tab.name
                , content = Code.view model tab
                }
    in List.map renderTab (Dict.values model.codeTabs)

getCtxMenuItems : CtxMenu -> List (List (ContextMenu.Item, Msg))
getCtxMenuItems context = case context of
    OnTerm name -> 
        [ [ (ContextMenu.item ("Term: " ++ name), MsgCtxMenuItem 1)
          ] 
        ]

view : Model -> Document Msg
view m = 
    { title = "hs-comprehension"
    , body = [ CDN.stylesheet 
             , node "link" [rel "stylesheet", href "/style.css", type_ "text/css"] []
             , node "link" [rel "stylesheet", href "/pygments.css", type_ "text/css"] []
             , div []
                [ContextMenu.view
                    ContextMenu.defaultConfig
                    MsgCtxMenu
                    getCtxMenuItems
                    m.ctxMenu
                ]
             , Tabs.config MsgPageTab
                 |> Tabs.items
                     (
                     [ Tabs.item
                         { name = "Overview"
                         , content = Overview.view m
                         }
                     ]
                     ++ viewCodeTabs m
                     )
                 |> Tabs.view m.pageTab
             ] 
    }

updateDictWithEffect : (v -> (v, e)) -> Dict comparable v -> comparable -> Maybe (Dict comparable v, e)
updateDictWithEffect f dict key = Dict.get key dict
   |> Maybe.map (\v -> let (nv, e) = f v in (Dict.insert key nv dict, e))

update : Msg -> Model -> (Model, Cmd Msg)
update msg model = case msg of
    MsgGotCaptures res -> ({model | capturesLoading = Loading.loadFromResult res}, Cmd.none)
    MsgPageTab tabmsg -> ({model | pageTab = Tabs.update tabmsg model.pageTab}, Cmd.none)
    MsgAdjustTimeZone zone -> ({model | timezone = zone}, Cmd.none)
    MsgCodeMsg tid codemsg -> case updateDictWithEffect (Code.update codemsg) model.codeTabs tid of
        Just (ntabs, cmd) ->({model | codeTabs = ntabs}, cmd)
        Nothing -> (model, Cmd.none)
    MsgOverViewTab tabmsg ->
        let (ntab, cmd) = Overview.update tabmsg model.overviewTab
        in ({model | overviewTab = ntab}, cmd)
    MsgOpenCodeTab -> 
        if (Set.Any.isEmpty model.overviewTab.enabledProjects)
        then (model, Cmd.none)
        else
            let (nmodel, codeTab, cmd) = Code.makeCodeTab model (Set.Any.toList model.overviewTab.enabledProjects)
            in (addCodeTab codeTab nmodel, cmd)
    MsgCtxMenu ctx -> 
        let (ctxMenu, cmd) = ContextMenu.update ctx model.ctxMenu
        in ({model | ctxMenu = ctxMenu}, Cmd.map MsgCtxMenu cmd) 
    MsgCtxMenuItem item -> (model, Cmd.none)


