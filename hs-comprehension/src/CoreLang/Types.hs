{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE StandaloneDeriving #-}
module CoreLang.Types where

import GHC.Utils.Outputable (Outputable (..))
import qualified GHC.Core as C
import qualified GHC.Types as C
import qualified GHC.Types.Unique as C
import qualified GHC.Plugins as C

import qualified Data.Text as T
import Data.Text (Text)

import GHC.Generics (Generic)
import Data.Aeson
import Elm (Elm, ElmStreet (..))

data MetaInfo = MetaInfo { modules :: [Text]
                         }
                         deriving (Show, Generic)
                         deriving (Elm, ToJSON, FromJSON) via ElmStreet MetaInfo

data PassInfo = PassInfo { idx :: Int
                         , title :: Text
                         , binds :: [CoreBind]
                         , srcbinders :: [Int]
                         , totalpasses :: Int
                         , modname :: Text
                         }
                 deriving (Show, Generic)
                 deriving (Elm, ToJSON, FromJSON) via ElmStreet PassInfo

data CoreLiteral = CoreLitNumber Text
                 | CoreLitString Text
                 | CoreLitOther Text -- underspecicfied catch all value
                 deriving (Show, Generic)
                 deriving (Elm, ToJSON, FromJSON) via ElmStreet CoreLiteral

data CoreId = CoreId { name :: Text
                     -- only unique in certain scopes
                     , uniquetag :: Text
                     -- actually unique
                     , unique :: Int
                     , vartype :: Text
                     , istyvar :: Bool
                     }
                     deriving (Show, Generic)
                     deriving (Elm, ToJSON, FromJSON) via ElmStreet CoreId

data CoreBind = NonRec CoreId CoreTerm
     deriving (Show, Generic)
     deriving (Elm, ToJSON, FromJSON) via ElmStreet CoreBind

data CoreAltCon = DataAlt Text
                | LitAlt CoreLiteral 
                | DEFAULT
     deriving (Show, Generic)
     deriving (Elm, ToJSON, FromJSON) via ElmStreet CoreAltCon

data CoreAlt = Alt CoreAltCon [CoreId] CoreTerm
     deriving (Show, Generic)
     deriving (Elm, ToJSON, FromJSON) via ElmStreet CoreAlt

data CoreTerm
    = Var CoreId
    | Lit CoreLiteral
    | App CoreTerm CoreTerm
    | Lam CoreId CoreTerm
    | Let CoreBind CoreTerm
    | Case CoreTerm [CoreAlt]
    | Type Text
    | Cast CoreTerm Text
    | Coercion Text
     deriving (Show, Generic)
     deriving (Elm, ToJSON, FromJSON) via ElmStreet CoreTerm
