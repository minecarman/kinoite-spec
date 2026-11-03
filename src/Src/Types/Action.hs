module Src.Types.Action
  ( Action (..)
  , Scope (..)
  ) where

import Src.Types.Spec (DistroboxSpec, FlatpakId, PackageName)

data Scope
  = User
  | System
  deriving (Eq, Ord, Show)

data Action
  = InstallOstree PackageName
  | RemoveOstree PackageName
  | InstallFlatpak FlatpakId Scope
  | RemoveFlatpak FlatpakId Scope
  | CreateDistrobox DistroboxSpec
  deriving (Eq, Ord, Show)
