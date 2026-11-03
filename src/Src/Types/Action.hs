module Src.Types.Action
  ( Action (..)
  , Scope (..)
  ) where

import Data.Text (Text)
import Src.Types.Spec (DistroboxSpec, FlatpakId, FlatpakOverride, PackageName)

data Scope
  = User
  | System
  deriving (Eq, Ord, Show)

data Action
  = InstallOstree PackageName
  | RemoveOstree PackageName
  | InstallFlatpak FlatpakId Scope (Maybe Text)
  | RemoveFlatpak FlatpakId Scope
  | ApplyFlatpakOverride FlatpakId Scope FlatpakOverride
  | CreateDistrobox DistroboxSpec
  deriving (Eq, Ord, Show)
